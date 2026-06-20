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

-- Substitute '{input}' placeholder with the actual filepath.
local function build_cmd(tool_args, filepath)
	local cmd = {}
	for _, arg in ipairs(tool_args) do
		cmd[#cmd + 1] = arg == '{input}' and filepath or arg
	end
	return cmd
end

-- Run the configured tool and return raw output (may contain ANSI codes).
local function run_tool_raw(filepath)
	local cfg = require('glimpse').get_config()
	local tools = cfg.markdown and cfg.markdown.tools
	local tool = resolve_tool(tools)
	if not tool then
		return nil, 'no markdown renderer found (install leaf, glow, mdcat, or pandoc)'
	end
	local output = vim.fn.system(build_cmd(tool, filepath))
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

--- Return rendered lines for Telescope and other text-based consumers.
--- @param filepath string
--- @return string[]|nil lines
--- @return nil highlights  (treesitter handles markdown highlighting)
--- @return string|nil err
function M.preview_data(filepath)
	local lines, err = preview_cache.memoize(filepath, 'markdown', function()
		local raw, run_err = run_tool_raw(filepath)
		if not raw then
			return nil, run_err
		end
		return to_lines(raw), nil
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
	local raw, err = run_tool_raw(filepath)
	if not raw then
		vim.notify('[glimpse] ' .. (err or 'failed to render markdown'), vim.log.levels.WARN)
		return
	end

	local config = require('glimpse').get_config()
	local buf = vim.api.nvim_create_buf(false, true)
	local chan = vim.api.nvim_open_term(buf, {})
	vim.api.nvim_chan_send(chan, raw)

	float.open(buf, config.pane)
end

return M
