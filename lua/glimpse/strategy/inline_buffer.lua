--- Inline-buffer rendering strategy.
--- Renders the preview directly into the file's own buffer instead of
--- opening a float or split. Designed for direct :edit workflows.
local M = {}

local renderer = require('glimpse.renderer')

-- Original buffer state saved before the preview is applied, keyed by buf.
local _snapshots = {}

local function _restore(buf)
	local snap = _snapshots[buf]
	if not snap then
		return
	end
	_snapshots[buf] = nil

	pcall(renderer.close, buf)
	pcall(vim.api.nvim_del_augroup_by_name, 'GlimpseInlineBuffer_' .. buf)

	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.bo[buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, snap.lines)
	vim.bo[buf].buftype = snap.buftype
	vim.bo[buf].filetype = snap.filetype
	vim.bo[buf].buflisted = snap.buflisted
	vim.bo[buf].bufhidden = snap.bufhidden
	vim.bo[buf].modifiable = snap.modifiable
	vim.bo[buf].readonly = snap.readonly
	vim.bo[buf].modified = false
end

--- Render an image into the current buffer in-place.
--- @param filepath string
function M.show(filepath)
	local buf = vim.api.nvim_get_current_buf()

	if _snapshots[buf] then
		return
	end

	local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
	if not ok then
		return
	end

	_snapshots[buf] = {
		lines = lines,
		modifiable = vim.bo[buf].modifiable,
		readonly = vim.bo[buf].readonly,
		buftype = vim.bo[buf].buftype,
		filetype = vim.bo[buf].filetype,
		buflisted = vim.bo[buf].buflisted,
		bufhidden = vim.bo[buf].bufhidden,
		modified = vim.bo[buf].modified,
	}

	-- Render into this buffer, keeping its original name in statusline/tabline.
	renderer.render(buf, filepath, {
		bufname = vim.api.nvim_buf_get_name(buf),
	})

	-- renderer.render sets buftype='nofile', which breaks :w. Reset it so
	-- BufWritePre fires normally and the user can save.
	vim.bo[buf].buftype = _snapshots[buf] and _snapshots[buf].buftype or ''
	-- Suppress the [+] indicator — content differs from disk intentionally.
	vim.bo[buf].modified = false

	-- Override the q keymap installed by inline.lua's FileType autocmd so that
	-- q restores original content instead of deleting the buffer.
	vim.keymap.set('n', require('glimpse').get_config().keys.close, function()
		M.close(buf)
	end, { buffer = buf, silent = true })

	local group = vim.api.nvim_create_augroup('GlimpseInlineBuffer_' .. buf, { clear = true })

	-- Restore original content before a write so the file on disk stays intact.
	vim.api.nvim_create_autocmd('BufWritePre', {
		buffer = buf,
		group = group,
		callback = function()
			_restore(buf)
		end,
	})

	-- Restore when the user enters insert mode to avoid corrupting the grid.
	vim.api.nvim_create_autocmd('InsertEnter', {
		buffer = buf,
		group = group,
		once = true,
		callback = function()
			_restore(buf)
		end,
	})

	-- Clean up if the buffer is wiped out while the preview is active.
	vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
		buffer = buf,
		group = group,
		once = true,
		callback = function()
			_restore(buf)
		end,
	})
end

--- Restore the original buffer content and remove the preview.
--- @param buf? integer defaults to the current buffer
function M.close(buf)
	_restore(buf or vim.api.nvim_get_current_buf())
end

--- Register global autocmds to auto-apply the inline_buffer preview.
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup('GlimpseInlineBufferStrategy', { clear = true })
	local util = require('glimpse.util')
	local safety_mod = require('glimpse.safety')

	-- Auto-apply when opening an image file directly (:edit, netrw, etc.)
	vim.api.nvim_create_autocmd('BufReadPost', {
		group = group,
		callback = function(info)
			local filepath = vim.api.nvim_buf_get_name(info.buf)
			if not util.is_image(filepath) then
				return
			end
			if util.is_git_lfs_pointer(filepath) then
				return
			end
			local cfg = require('glimpse').get_config()
			local safe = safety_mod.check(filepath, { max_size = cfg.safety.max_file_size })
			if not safe then
				return
			end
			-- Schedule so the buffer is fully initialised before we snapshot it.
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(info.buf) then
					M.show(filepath)
				end
			end)
		end,
	})

	-- Re-render when the window is resized.
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

	-- Re-render when returning to a tab containing an image buffer.
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
end

return M
