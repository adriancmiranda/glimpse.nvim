--- Helpers for centered floating preview windows.
local M = {}

local tracked = {}
local augroup_name = 'GlimpseFloatPreview'
local autocmds_ready = false

---@class GlimpseFloatOptions
---@field title? string
---@field title_pos? string
---@field border? string
---@field max_width? number
---@field max_height? number
---@field min_width? number
---@field min_height? number
---@field margin_x? number
---@field margin_y? number
---@field focusable? boolean

local function clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function compute_size(buf, opts)
	opts = opts or {}
	local margin_x = opts.margin_x or 4
	local margin_y = opts.margin_y or 4
	local min_width = opts.min_width or 20
	local min_height = opts.min_height or 4
	local max_width = opts.max_width or 80
	local max_height = opts.max_height or math.huge

	local columns = math.max(vim.o.columns - margin_x, min_width)
	local lines = math.max(vim.o.lines - margin_y, min_height)
	local line_count = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_line_count(buf) or 1

	local width = clamp(math.floor(math.min(max_width, columns)), min_width, columns)
	local height = clamp(math.floor(math.min(math.min(max_height, line_count), lines)), min_height, lines)
	return width, height
end

local function build_config(buf, opts)
	opts = opts or {}
	local width, height = compute_size(buf, opts)

	return {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = opts.border or 'rounded',
		title = opts.title,
		title_pos = opts.title_pos or 'center',
		focusable = opts.focusable ~= false,
	},
		width,
		height
end

local function clear(win)
	tracked[win] = nil
end

local function setup_autocmds()
	if autocmds_ready then
		return
	end
	autocmds_ready = true

	local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })
	vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
		group = group,
		callback = function()
			for win, meta in pairs(tracked) do
				if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(meta.buf) then
					clear(win)
				else
					local config = build_config(meta.buf, meta.opts)
					vim.api.nvim_win_set_config(win, config)
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd('WinClosed', {
		group = group,
		callback = function(ev)
			local win = tonumber(ev.match)
			if win then
				clear(win)
			end
		end,
	})
end

--- Open a centered floating window for preview content.
--- @param buf number
--- @param opts? GlimpseFloatOptions
--- @return number win
function M.open(buf, opts)
	setup_autocmds()
	local config = build_config(buf, opts)
	local win = vim.api.nvim_open_win(buf, true, config)
	tracked[win] = {
		buf = buf,
		opts = opts or {},
	}
	return win
end

--- Recenter a tracked float now.
--- @param win number
function M.reflow(win)
	local meta = tracked[win]
	if not meta then
		return
	end
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(meta.buf) then
		clear(win)
		return
	end
	vim.api.nvim_win_set_config(win, build_config(meta.buf, meta.opts))
end

return M
