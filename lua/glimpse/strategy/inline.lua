--- @see credits https://github.com/folke/snacks.nvim (snacks.image) - original inspiration
--- Inline rendering via Kitty Graphics Protocol (custom implementation).

local renderer = require('glimpse.renderer')
local dir = require('glimpse.dir')

local M = {}

local function _lfs_preview_lines(filepath)
	local util = require('glimpse.util')
	local pointer = util.parse_git_lfs_pointer(filepath)
	if not pointer then
		return {
			'[glimpse] Git LFS pointer detected',
			'tip: run git lfs pull in the repository that owns this file',
		},
			'glimpse_warning'
	end

	return {
		'[glimpse] Git LFS pointer',
		'oid sha256:' .. pointer.oid,
		'size ' .. tostring(pointer.size) .. ' bytes',
		'tip: run git lfs pull in the repository that owns this file',
	},
		'glimpse_warning'
end

--- Show an image in a vsplit, reusing an existing window.
--- @param filepath string
function M.preview(filepath)
	local oil_win = vim.api.nvim_get_current_win()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= oil_win and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'image' then
			local buf = vim.api.nvim_win_get_buf(win)
			renderer.render(buf, filepath)
			dir.follow(filepath)
			return
		end
	end
	-- Create a vsplit with a new buffer
	vim.cmd('vsplit')
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	renderer.render(buf, filepath)
	vim.api.nvim_set_current_win(oil_win)
	dir.follow(filepath)
end

local function _show_lfs_warning(buf, filepath)
	local lines, filetype = _lfs_preview_lines(filepath)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.bo[buf].filetype = filetype
end

--- Show an image in the current buffer.
--- @param filepath string
function M.show(filepath)
	local buf = vim.api.nvim_get_current_buf()
	renderer.render(buf, filepath)
end

--- Close and clean up the image buffer.
--- @param buf number
function M.close(buf)
	renderer.close(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

--- Register autocmds for rerendering and the q keymap.
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup('ImagePreviewInline', { clear = true })
	local util = require('glimpse.util')

	-- Intercept image, font, and archive file openings
	vim.api.nvim_create_autocmd('BufReadPost', {
		group = group,
		callback = function(info)
			local filepath = vim.api.nvim_buf_get_name(info.buf)
			if util.is_image(filepath) then
				if util.is_git_lfs_pointer(filepath) then
					_show_lfs_warning(info.buf, filepath)
					return
				end
				dir.follow(filepath)
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
				M.close(info.buf)
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
end

return M
