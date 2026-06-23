--- Previewer for Markdown files via a configurable CLI renderer.
local M = {}

local auto_refresh = require('glimpse.auto_refresh')
local float = require('glimpse.float')
local preview_cache = require('glimpse.preview_cache')
local util = require('glimpse.util')

-- Strip ANSI escape sequences — used only for plain-text consumers (Telescope).
local function strip_ansi(str)
	return str:gsub('\27%[[%d;:]*[mKJHfABCDsuhlGr]', ''):gsub('\27%[%?[%d]*[lh]', ''):gsub('\r', '')
end

-- Substitute dynamic placeholders with the actual preview context.
local function normalize_tool(tool_args)
	local normalized = vim.deepcopy(tool_args)
	if normalized[1] == 'leaf' then
		local has_inline = false
		for _, arg in ipairs(normalized) do
			if arg == '--inline' then
				has_inline = true
				break
			end
		end
		if not has_inline then
			table.insert(normalized, 2, '--inline')
			table.insert(normalized, 3, 'ansi:{width}')
		end
	end

	return normalized
end

local function build_cmd(tool_args, filepath, width)
	local cmd = {}
	for _, arg in ipairs(normalize_tool(tool_args)) do
		cmd[#cmd + 1] = arg
			:gsub('{input}', function()
				return filepath
			end)
			:gsub('{width}', function()
				return tostring(width)
			end)
	end
	return cmd
end

-- Run the configured tool and return raw output (may contain ANSI codes).
local function run_tool_raw(filepath, width)
	local cfg = require('glimpse').get_config()
	local tools = cfg.markdown and cfg.markdown.tools
	width = width or vim.api.nvim_win_get_width(0)
	local prev_columns = vim.env.COLUMNS
	vim.env.COLUMNS = tostring(width)
	local errors = {}
	for _, tool in ipairs(tools or {}) do
		if vim.fn.executable(tool[1]) == 1 then
			local output = vim.fn.system(build_cmd(tool, filepath, width))
			if vim.v.shell_error == 0 then
				vim.env.COLUMNS = prev_columns
				return output, nil
			end
			errors[#errors + 1] = tool[1] .. ' exited with error'
		end
	end
	vim.env.COLUMNS = prev_columns
	if #errors > 0 then
		return nil, table.concat(errors, '; ')
	end
	return nil, 'no markdown renderer found (install leaf, glow, mdcat, or pandoc)'
end

-- Convert raw output to plain lines (ANSI stripped) for text-based consumers.
local function to_lines(raw)
	local clean = strip_ansi(raw)
	local lines = {}
	for line in (clean .. '\n'):gmatch('([^\n]*)\n') do
		lines[#lines + 1] = line
	end
	while #lines > 0 and lines[#lines] == '' do
		lines[#lines] = nil
	end
	return lines
end

local function display_height(lines, width)
	local height = 0
	for _, line in ipairs(lines) do
		height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / math.max(width, 1)))
	end
	return height
end

local function render_lines(filepath, width)
	local raw, err = run_tool_raw(filepath, width)
	if not raw then
		return nil, nil, err
	end
	return raw, to_lines(raw), nil
end

local function write_term(chan, raw)
	if not chan or not raw then
		return
	end
	vim.api.nvim_chan_send(chan, '\27[3J\27[2J\27[H')
	vim.api.nvim_chan_send(chan, raw)
end

local function redraw()
	pcall(vim.cmd, 'redraw')
end

--- Return rendered lines for Telescope and other text-based consumers.
--- @param filepath string
---@param width? number
--- @return string[]|nil lines
--- @return nil highlights  (treesitter handles markdown highlighting)
--- @return string|nil err
function M.preview_data(filepath, width)
	width = width or vim.api.nvim_win_get_width(0)
	local lines, err = preview_cache.memoize(filepath, 'markdown:' .. tostring(width), function()
		local _, rendered_lines, run_err = render_lines(filepath, width)
		if not rendered_lines then
			return nil, run_err
		end
		return rendered_lines, nil
	end)
	if not lines then
		return nil, nil, err
	end
	return lines, nil, nil
end

--- Render into the current buffer (direct :edit workflow).
--- Uses plain text + filetype=markdown so treesitter handles highlighting.
--- @param filepath string
function M.show(filepath)
	local raw, err = run_tool_raw(filepath)
	if not raw then
		vim.notify('[glimpse] ' .. (err or 'failed to render markdown'), vim.log.levels.WARN)
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, to_lines(raw))
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'markdown'
end

--- Preview in a floating window using a terminal buffer so ANSI colors,
--- bold, italic and other attributes are rendered faithfully.
--- @param filepath string
--- @param opts? { window?: string }
function M.preview(filepath, opts)
	local source_buf = vim.api.nvim_get_current_buf()
	local float_opts = {
		kind = 'markdown',
		max_width = 100,
		window = opts and opts.window,
	}
	local state = {
		width = nil,
		raw = nil,
		lines = nil,
		writing = false,
		last_written_raw = nil,
	}
	local chan
	local render_err
	local function render(width)
		local raw, lines, err = render_lines(filepath, width)
		if not raw then
			return nil, err
		end
		state.width = width
		state.raw = raw
		state.lines = lines
		return raw, nil
	end

	local function write_preview(raw_to_write)
		if raw_to_write == state.last_written_raw then
			return
		end
		state.last_written_raw = raw_to_write
		state.writing = true
		local ok, err = pcall(function()
			write_term(chan, raw_to_write)
			redraw()
		end)
		state.writing = false
		if not ok then
			error(err)
		end
	end

	local raw, err = render(float.resolve_width(float_opts))
	if not raw then
		vim.notify('[glimpse] ' .. (err or 'failed to render markdown'), vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	float_opts.content_height = function(width)
		if state.width ~= width then
			local _, rerender_err = render(width)
			if rerender_err and not render_err then
				render_err = rerender_err
			end
		end
		return display_height(state.lines or {}, width)
	end
	local win
	local user_cursor = nil
	float_opts.on_resize = function(new_width)
		if not chan or not vim.api.nvim_buf_is_valid(buf) or state.writing then
			return
		end
		if new_width and new_width ~= state.width then
			local _, rerender_err = render(new_width)
			if rerender_err then
				vim.notify('[glimpse] ' .. rerender_err, vim.log.levels.WARN)
				return
			end
		end
		write_preview(state.raw)
		local cursor = user_cursor
		if cursor and win and vim.api.nvim_win_is_valid(win) then
			vim.defer_fn(function()
				if vim.api.nvim_win_is_valid(win) then
					pcall(vim.api.nvim_win_set_cursor, win, cursor)
				end
			end, 50)
		end
	end
	win = float.open(buf, float_opts)

	chan = vim.api.nvim_open_term(buf, {})
	write_preview(raw)

	vim.api.nvim_create_autocmd('CursorMoved', {
		buffer = buf,
		callback = function()
			if not state.writing and win and vim.api.nvim_win_is_valid(win) then
				user_cursor = vim.api.nvim_win_get_cursor(win)
			end
		end,
	})

	if vim.api.nvim_buf_is_valid(source_buf) and util.same_path(vim.api.nvim_buf_get_name(source_buf), filepath) then
		auto_refresh.register(source_buf, filepath, function()
			return vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) and chan ~= nil
		end, function()
			if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) or chan == nil then
				return
			end
			local width = state.width or float.resolve_width(float_opts)
			local rerendered, rerender_err = render(width)
			if not rerendered then
				vim.notify('[glimpse] ' .. (rerender_err or 'failed to render markdown'), vim.log.levels.WARN)
				return
			end
			write_preview(state.raw)
		end)
	end
end

return M
