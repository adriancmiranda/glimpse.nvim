--- Helpers for centered floating preview windows.
local M = {}

local tracked = {}
local augroup_name = 'GlimpseFloatPreview'
local autocmds_ready = false

---@class GlimpseFloatOptions
---@field title? string
---@field title_pos? string
---@field border? string
---@field kind? GlimpseFloatKind Preview type used for type-specific configuration
---@field max_width? number|'auto'
---@field max_height? number|'auto'
---@field min_width? number
---@field min_height? number
---@field margin_x? number
---@field margin_y? number
---@field focusable? boolean
---@field close_key? string
---@field content_height? number|fun(width: number): number Expected content height before the buffer is populated
---@field on_resize? fun(width: number, height: number, win: number, buf: number) Called after the float is reflowed

local function clamp(value, min_value, max_value)
	return math.max(min_value, math.min(max_value, value))
end

local function apply_config(opts)
	opts = opts or {}
	local configured = require('glimpse').get_config().float or {}
	local kind_config = opts.kind and configured[opts.kind] or nil
	local resolved = vim.tbl_extend('force', {}, opts)

	for option, field in pairs({ max_width = 'width', max_height = 'height' }) do
		if type(kind_config) == 'table' and kind_config[field] ~= nil then
			resolved[option] = kind_config[field]
		elseif configured[field] ~= nil then
			resolved[option] = configured[field]
		end
	end

	return resolved
end

local function resolve_width(opts)
	opts = apply_config(opts)
	local margin_x = opts.margin_x or 4
	local min_width = opts.min_width or 20
	local max_width = opts.max_width or 80
	local columns = math.max(vim.o.columns - margin_x, min_width)
	if max_width == 'auto' then
		max_width = columns
	end

	local width = clamp(math.floor(math.min(max_width, columns)), min_width, columns)
	return width, opts
end

local function compute_size(buf, opts)
	local width
	width, opts = resolve_width(opts)
	local margin_y = opts.margin_y or 4
	local min_height = opts.min_height or 4
	local max_height = opts.max_height or math.huge
	local lines = math.max(vim.o.lines - margin_y, min_height)
	if max_height == 'auto' then
		max_height = lines
	end

	local line_count = opts.content_height
	if type(line_count) == 'function' then
		line_count = line_count(width)
	end
	line_count = line_count or (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_line_count(buf) or 1)
	local height = clamp(math.floor(math.min(math.min(max_height, line_count), lines)), min_height, lines)
	return width, height
end

--- Resolve the final width for float options without opening a window.
--- @param opts? GlimpseFloatOptions
--- @return number width
function M.resolve_width(opts)
	return resolve_width(opts)
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
		title_pos = opts.title and (opts.title_pos or 'center') or nil,
		focusable = opts.focusable ~= false,
	},
		width,
		height
end

local function clear(win)
	tracked[win] = nil
end

local function reflow_win(win, meta)
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(meta.buf) then
		clear(win)
		return
	end

	local config, width, height = build_config(meta.buf, meta.opts)
	vim.api.nvim_win_set_config(win, config)

	local on_resize = meta.opts and meta.opts.on_resize
	if type(on_resize) == 'function' then
		pcall(on_resize, width, height, win, meta.buf)
	end
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
				reflow_win(win, meta)
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
	local close_key = (opts and opts.close_key) or require('glimpse').get_config().keys.close
	if close_key then
		vim.keymap.set('n', close_key, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, silent = true })
	end
	return win
end

--- Recenter a tracked float now.
--- @param win number
function M.reflow(win)
	local meta = tracked[win]
	if not meta then
		return
	end
	reflow_win(win, meta)
end

return M
