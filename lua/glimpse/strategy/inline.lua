--- @see credits https://github.com/folke/snacks.nvim (snacks.image) - original inspiration
--- Inline rendering via Kitty Graphics Protocol (custom implementation).

local renderer = require('glimpse.renderer')
local preview_state = require('glimpse.preview_state')

local M = {}

local util = require('glimpse.util')

local function debug_log(message)
	if not vim.g.glimpse_debug then
		return
	end

	vim.schedule(function()
		vim.notify('[glimpse.inline] ' .. message, vim.log.levels.DEBUG)
	end)
end

local function resolve_size(cfg_size, mode)
	if type(cfg_size) == 'number' then
		return cfg_size
	end
	if type(cfg_size) == 'table' then
		return cfg_size[mode]
	end
end

local function window_col(win)
	local ok, pos = pcall(vim.api.nvim_win_get_position, win)
	if not ok or type(pos) ~= 'table' then
		return nil
	end
	return pos[2]
end

local function _render_existing_buffer(buf)
	if not vim.api.nvim_buf_is_valid(buf) or renderer.has_placement(buf) then
		return
	end

	local filepath = vim.api.nvim_buf_get_name(buf)
	if filepath == '' or not util.is_image(filepath) then
		return
	end

	if vim.uv.fs_stat(filepath) == nil then
		return
	end

	if util.is_git_lfs_pointer(filepath) then
		return
	end

	renderer.render(buf, filepath, { listed = true })
end

local function _render_existing_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		_render_existing_buffer(buf)
	end
end

--- Show an image in a vsplit, reusing an existing window.
--- @param filepath string
function M.preview(filepath)
	local oil_win = vim.api.nvim_get_current_win()
	local existing_buf = renderer.find_by_filepath(filepath)
	local target_win = nil
	local target_buf = nil
	local target_col = nil
	debug_log(
		string.format(
			'preview filepath=%s oil_win=%d current_win=%d existing_buf=%s',
			filepath,
			oil_win,
			vim.api.nvim_get_current_win(),
			tostring(existing_buf)
		)
	)

	-- Single pass:
	--   (1) Prefer a window showing the same file that is also a preview —
	--       same file opened via keys.open (not marked) is NOT reused so
	--       that buffer stays untouched and a fresh preview split is created.
	--   (2) Otherwise pick the rightmost marked preview window.
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= oil_win and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'image' then
			local buf = vim.api.nvim_win_get_buf(win)
			local marked = preview_state.is_marked(buf)
			debug_log(
				string.format(
					'preview inspect win=%d buf=%d ft=%s marked=%s same=%s',
					win,
					buf,
					vim.bo[buf].filetype,
					tostring(marked),
					tostring(existing_buf == buf)
				)
			)
			if existing_buf == buf and marked then
				target_win = win
				target_buf = buf
				break
			end
			if marked then
				local col = window_col(win)
				if target_win == nil or (col ~= nil and (target_col == nil or col > target_col)) then
					target_win = win
					target_buf = buf
					target_col = col
				end
			end
		end
	end

	if target_win and target_buf then
		debug_log(string.format('preview reuse win=%d buf=%d', target_win, target_buf))
		vim.api.nvim_set_current_win(target_win)
		local placement = renderer.get_placement(target_buf)
		if placement and placement.filepath and placement.filepath:match('^glimpse://video/') then
			require('glimpse.previewer.video').stop(target_buf)
		end
		renderer.render(target_buf, filepath, { bufname = util.preview_buf_name(filepath, target_buf) })
		preview_state.mark(target_buf)
		vim.api.nvim_set_current_win(oil_win)
		return
	end

	-- Create a vsplit with a new buffer
	debug_log('preview create new split')
	vim.cmd('vsplit')
	local cfg = require('glimpse').get_config()
	local win_size = resolve_size(cfg.size, 'right')
	if win_size then
		vim.api.nvim_win_set_width(0, win_size)
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	renderer.render(buf, filepath, { bufname = util.preview_buf_name(filepath, buf) })
	preview_state.mark(buf)
	vim.api.nvim_set_current_win(oil_win)
end

--- Show an image in the current buffer.
--- @param filepath string
function M.show(filepath)
	local buf = vim.api.nvim_get_current_buf()
	renderer.render(buf, filepath)
end

--- Close and clean up the image buffer.
--- @param buf number
--- @param delete_buf? boolean
function M.close(buf, delete_buf)
	renderer.close(buf)
	if delete_buf and vim.api.nvim_buf_is_valid(buf) then
		if vim.api.nvim_get_current_buf() == buf then
			local scratch = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(scratch)
		end

		if #vim.fn.win_findbuf(buf) == 0 then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

--- Register autocmds for rerendering and the q keymap.
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup('ImagePreviewInline', { clear = true })

	-- Intercept image, font, and archive file openings
	vim.api.nvim_create_autocmd('BufReadPost', {
		group = group,
		callback = function(info)
			local filepath = vim.api.nvim_buf_get_name(info.buf)
			if util.is_image(filepath) then
				if util.is_git_lfs_pointer(filepath) then
					return
				end
				renderer.render(info.buf, filepath, { listed = true })
			elseif util.is_font(filepath) then
				require('glimpse.previewer.font').show(filepath)
			elseif util.is_archive(filepath) then
				require('glimpse.previewer.archive').show(filepath)
			end
		end,
	})

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'image',
		group = group,
		callback = function(info)
			vim.keymap.set('n', require('glimpse').get_config().keys.close, function()
				local wins = vim.api.nvim_list_wins()
				M.close(info.buf, true)
				if #wins > 1 then
					local cur_name = vim.api.nvim_buf_get_name(0)
					if cur_name == '' and not vim.bo.modified then
						vim.cmd('quit')
					end
				end
			end, { buffer = info.buf, silent = true })
		end,
	})

	vim.api.nvim_create_autocmd('BufEnter', {
		group = group,
		callback = function(info)
			if vim.bo[info.buf].filetype == 'image' then
				if not vim.b[info.buf]._image_rendered then
					vim.b[info.buf]._image_rendered = true
					if not renderer.has_placement(info.buf) then
						local filepath = vim.api.nvim_buf_get_name(info.buf)
						if filepath ~= '' then
							renderer.register(info.buf, filepath)
						end
					end
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd('TabEnter', {
		group = group,
		callback = function()
			vim.schedule(function()
				local buf = vim.api.nvim_get_current_buf()
				if vim.bo[buf].filetype == 'image' and renderer.has_placement(buf) then
					renderer.rerender(buf)
				end
			end)
		end,
	})

	local resize_timer = nil
	vim.api.nvim_create_autocmd('WinResized', {
		group = group,
		callback = function()
			if resize_timer then
				resize_timer:stop()
			end
			resize_timer = vim.defer_fn(function()
				resize_timer = nil
				for _, win in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_is_valid(win) then
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].filetype == 'image' and renderer.has_placement(buf) then
							renderer.rerender(buf)
						end
					end
				end
			end, require('glimpse').get_config().debounce.resize)
		end,
	})

	vim.schedule(_render_existing_buffers)
end

return M
