--- Previewer for Markdown files via a configurable CLI renderer.
local M = {}

local float = require('glimpse.float')
local preview_cache = require('glimpse.preview_cache')

-- Strip ANSI escape sequences — used only for plain-text consumers (Telescope).
local function strip_ansi(str)
	return str:gsub('\27%[[%d;:]*[mKJHfABCDsuhlGr]', ''):gsub('\27%[%?[%d]*[lh]', ''):gsub('\r', '')
end

-- Return the first tool whose binary is executable, or nil.
local function resolve_tool(tools)
	for _, args in ipairs(tools or {}) do
		if vim.fn.executable(args[1]) == 1 then
			return args
		end
	end
	return nil
end

-- Substitute dynamic placeholders with the actual preview context.
local function build_cmd(tool_args, filepath, width)
	local cmd = {}
	for _, arg in ipairs(tool_args) do
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
	local tool = resolve_tool(tools)
	if not tool then
		return nil, 'no markdown renderer found (install leaf, glow, mdcat, or pandoc)'
	end
	width = width or vim.api.nvim_win_get_width(0)
	local prev_columns = vim.env.COLUMNS
	vim.env.COLUMNS = tostring(width)
	local output = vim.fn.system(build_cmd(tool, filepath, width))
	vim.env.COLUMNS = prev_columns
	if vim.v.shell_error ~= 0 then
		return nil, tool[1] .. ' exited with error'
	end
	return output, nil
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
function M.preview(filepath)
	local float_opts = {
		kind = 'markdown',
		max_width = 100,
	}
	local state = {
		width = nil,
		raw = nil,
		lines = nil,
	}
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
	local chan
	float_opts.on_resize = function()
		if not chan or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if state.raw then
			vim.api.nvim_chan_send(chan, '\27[2J\27[H')
			vim.api.nvim_chan_send(chan, state.raw)
		end
	end
	float.open(buf, float_opts)

	chan = vim.api.nvim_open_term(buf, {})
	vim.api.nvim_chan_send(chan, raw)
end

return M
