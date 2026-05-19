local M = {}

local preview_win = nil
local preview_buf = nil

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseNeoTree', { clear = true })
	local util = require('glimpse.util')

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'neo-tree',
		group = group,
		callback = function(info)
			local debounce_timer = nil
			local last_path = nil

			vim.api.nvim_create_autocmd('CursorMoved', {
				buffer = info.buf,
				group = group,
				callback = function()
					if debounce_timer then
						debounce_timer:stop()
					end
					debounce_timer = vim.defer_fn(function()
						debounce_timer = nil
						local ok, manager = pcall(require, 'neo-tree.sources.manager')
						if not ok then
							return
						end
						local state = manager.get_state('filesystem')
						if not state or not state.tree then
							return
						end
						local node = state.tree:get_node()
						if not node or node.type ~= 'file' then
							M._close_preview()
							last_path = nil
							return
						end
						local fpath = node:get_id()
						if not util.is_previewable(fpath) then
							M._close_preview()
							last_path = nil
							return
						end
						if fpath == last_path then
							return
						end
						last_path = fpath

						local glimpse = require('glimpse')
						local use_inline = glimpse._should_use_inline()

						local function render(target)
							if use_inline then
								vim.schedule(function()
									M._ensure_preview_win()
									local renderer = require('glimpse.renderer')
									renderer.render(preview_buf, target, { winid = preview_win })
								end)
							else
								local config = glimpse.get_config()
								require('glimpse.strategy.pane').show(target, {
									position = config.pane_position,
									size = config.pane_size,
								})
							end
						end

						if util.is_video(fpath) then
							local thumbnail = require('glimpse.thumbnail')
							thumbnail.extract_async(fpath, function(target)
								if target then
									render(target)
								end
							end)
						else
							render(fpath)
						end
					end, require('glimpse').get_config().debounce.prefetch)
				end,
			})
		end,
	})
end

function M._ensure_preview_win()
	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		return
	end
	local neo_win = vim.api.nvim_get_current_win()
	vim.cmd('botright vsplit')
	preview_win = vim.api.nvim_get_current_win()
	preview_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(preview_win, preview_buf)
	vim.api.nvim_set_current_win(neo_win)
end

function M._close_preview()
	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
	end
	preview_win = nil
	preview_buf = nil
end

return M
