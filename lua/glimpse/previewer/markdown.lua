--- Previewer for Markdown files via a configurable CLI renderer.
local M = {}

local auto_refresh = require('glimpse.auto_refresh')
local float = require('glimpse.float')
local preview_cache = require('glimpse.preview_cache')
local util = require('glimpse.util')

local ANSI_16_COLORS = {
	[0] = '#000000',
	[1] = '#800000',
	[2] = '#008000',
	[3] = '#808000',
	[4] = '#000080',
	[5] = '#800080',
	[6] = '#008080',
	[7] = '#c0c0c0',
	[8] = '#808080',
	[9] = '#ff0000',
	[10] = '#00ff00',
	[11] = '#ffff00',
	[12] = '#0000ff',
	[13] = '#ff00ff',
	[14] = '#00ffff',
	[15] = '#ffffff',
}

local ansi_hl_cache = {}

local function rgb_hex(red, green, blue)
	if not red or not green or not blue then
		return nil
	end
	red = math.max(0, math.min(255, red))
	green = math.max(0, math.min(255, green))
	blue = math.max(0, math.min(255, blue))
	return string.format('#%02x%02x%02x', red, green, blue)
end

local function xterm_color(index)
	if not index or index < 0 or index > 255 then
		return nil
	end
	if ANSI_16_COLORS[index] then
		return ANSI_16_COLORS[index]
	end
	if index >= 16 and index <= 231 then
		local value = index - 16
		local steps = { 0, 95, 135, 175, 215, 255 }
		local red = steps[math.floor(value / 36) + 1]
		local green = steps[math.floor((value % 36) / 6) + 1]
		local blue = steps[(value % 6) + 1]
		return rgb_hex(red, green, blue)
	end
	local level = 8 + ((index - 232) * 10)
	return rgb_hex(level, level, level)
end

local function parse_sgr_params(params)
	if params == '' then
		return { 0 }
	end

	local parsed = {}
	for param in params:gsub(':', ';'):gmatch('[^;]+') do
		parsed[#parsed + 1] = tonumber(param) or 0
	end
	return parsed
end

local function ansi_group(style)
	if not style.fg and not style.bg and not style.bold and not style.italic and not style.underline then
		return nil
	end

	local key = table.concat({
		style.fg or 'none',
		style.bg or 'none',
		style.bold and 'bold' or 'plain',
		style.italic and 'italic' or 'roman',
		style.underline and 'underline' or 'none',
	}, ':')
	if ansi_hl_cache[key] then
		return ansi_hl_cache[key]
	end

	local name = 'GlimpseAnsi' .. tostring(vim.tbl_count(ansi_hl_cache) + 1)
	vim.api.nvim_set_hl(0, name, {
		fg = style.fg,
		bg = style.bg,
		bold = style.bold or nil,
		italic = style.italic or nil,
		underline = style.underline or nil,
	})
	ansi_hl_cache[key] = name
	return name
end

local function apply_sgr(style, params)
	local parsed = parse_sgr_params(params)
	local index = 1
	while index <= #parsed do
		local code = parsed[index]
		if code == 0 then
			style.fg = nil
			style.bg = nil
			style.bold = false
			style.italic = false
			style.underline = false
		elseif code == 1 then
			style.bold = true
		elseif code == 3 then
			style.italic = true
		elseif code == 4 then
			style.underline = true
		elseif code == 22 then
			style.bold = false
		elseif code == 23 then
			style.italic = false
		elseif code == 24 then
			style.underline = false
		elseif code == 39 then
			style.fg = nil
		elseif code == 49 then
			style.bg = nil
		elseif code >= 30 and code <= 37 then
			style.fg = xterm_color(code - 30)
		elseif code >= 40 and code <= 47 then
			style.bg = xterm_color(code - 40)
		elseif code >= 90 and code <= 97 then
			style.fg = xterm_color(code - 90 + 8)
		elseif code >= 100 and code <= 107 then
			style.bg = xterm_color(code - 100 + 8)
		elseif code == 38 or code == 48 then
			local is_foreground = code == 38
			local mode = parsed[index + 1]
			if mode == 5 then
				local color = xterm_color(parsed[index + 2])
				if is_foreground then
					style.fg = color
				else
					style.bg = color
				end
				index = index + 2
			elseif mode == 2 then
				local color = rgb_hex(parsed[index + 2], parsed[index + 3], parsed[index + 4])
				if is_foreground then
					style.fg = color
				else
					style.bg = color
				end
				index = index + 4
			end
		end
		index = index + 1
	end
end

local function ansi_to_lines(raw)
	local lines = { '' }
	local highlights = {}
	local style = { fg = nil, bg = nil, bold = false, italic = false, underline = false }
	local row = 0
	local col = 0
	local segment_start
	local segment_group
	local index = 1

	local function close_segment()
		if segment_group and segment_start and col > segment_start then
			highlights[#highlights + 1] = { row, segment_start, col, segment_group }
		end
		segment_start = nil
		segment_group = nil
	end

	local function refresh_segment()
		local group = ansi_group(style)
		if group ~= segment_group then
			close_segment()
			segment_group = group
			segment_start = group and col or nil
		end
	end

	while index <= #raw do
		local esc_start, esc_end, params, command = raw:find('\27%[([%?%d;:]*)([%a])', index)
		if esc_start == index then
			if command == 'm' then
				apply_sgr(style, params or '')
				refresh_segment()
			end
			index = esc_end + 1
		else
			local next_index = esc_start or (#raw + 1)
			local text = raw:sub(index, next_index - 1):gsub('\r', '')
			for chunk, newline in text:gmatch('([^\n]*)(\n?)') do
				if chunk ~= '' then
					refresh_segment()
					lines[#lines] = lines[#lines] .. chunk
					col = col + #chunk
				end
				if newline == '\n' then
					close_segment()
					lines[#lines + 1] = ''
					row = row + 1
					col = 0
				end
				if newline == '' then
					break
				end
			end
			index = next_index
		end
	end

	close_segment()
	while #lines > 0 and lines[#lines] == '' do
		lines[#lines] = nil
	end
	return lines, highlights
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

local function read_file_raw(filepath)
	local ok, lines = pcall(vim.fn.readfile, filepath)
	if not ok then
		return nil, 'failed to read markdown file'
	end
	return table.concat(lines, '\n'), nil
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
	return read_file_raw(filepath)
end

-- Convert raw output to plain lines for text-based consumers.
local function to_lines(raw)
	local lines = ansi_to_lines(raw)
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
--- @return table[]|nil highlights
--- @return string|nil err
function M.preview_data(filepath, width)
	width = width or vim.api.nvim_win_get_width(0)
	local rendered, err = preview_cache.memoize(filepath, 'markdown:' .. tostring(width), function()
		local raw, rendered_lines, run_err = render_lines(filepath, width)
		if not rendered_lines then
			return nil, run_err
		end
		local _, highlights = ansi_to_lines(raw)
		return { lines = rendered_lines, highlights = highlights }, nil
	end)
	if not rendered then
		return nil, nil, err
	end
	return rendered.lines, rendered.highlights, nil
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
