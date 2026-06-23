--- Previewer for archives (zip, tar, etc.).
local M = {}
local float = require('glimpse.float')

local archive = require('glimpse.archive')
local preview_cache = require('glimpse.preview_cache')
local shared = require('glimpse.previewer.shared')

local _header_lines = shared.header_lines
local _offset_highlights = shared.offset_highlights

local function _format_full_listing(filepath)
	return preview_cache.memoize(filepath, 'archive/full', function()
		local entries, err = archive.list(filepath)
		if not entries then
			return nil, nil, err
		end

		local lines, highlights = archive.format(entries)
		return lines, highlights
	end)
end

local function _format_summary(filepath)
	return preview_cache.memoize(filepath, 'archive/summary', function()
		local entries, err = archive.list(filepath)
		if not entries then
			return nil, nil, err
		end

		local lines, highlights = archive.summary(entries, filepath)
		_header_lines(filepath, lines)
		return lines, _offset_highlights(highlights, 2)
	end)
end

--- Render the full listing in the current buffer.
--- @param filepath string
function M.show(filepath)
	local lines, highlights, err = _format_full_listing(filepath)
	if not lines then
		vim.notify('[glimpse] ' .. (err or 'failed to read archive'), vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_archive'

	local ns = vim.api.nvim_create_namespace('glimpse_archive')
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, hl in ipairs(highlights) do
		local row = hl[1]
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end
end

--- Preview a summary in a floating window.
--- @param filepath string
function M.preview(filepath, opts)
	local config = require('glimpse').get_config()
	local lines, highlights, err = _format_summary(filepath)
	if not lines then
		vim.notify('[glimpse] ' .. (err or 'failed to read archive'), vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_archive'

	local ns = vim.api.nvim_create_namespace('glimpse_archive_preview')
	for _, hl in ipairs(highlights) do
		local row = hl[1]
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end

	float.open(buf, {
		kind = 'archive',
		title = ' Archive Summary ',
		max_width = 70,
		max_height = #lines,
		window = opts and opts.window,
	})

	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

M.preview_data = _format_summary

return M
