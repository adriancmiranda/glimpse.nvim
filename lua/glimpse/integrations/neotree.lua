local M = {}

local preview_win = nil
local preview_buf = nil

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseNeoTree', { clear = true })
	local util = require('glimpse.util')
	local config = require('glimpse').get_config()
	local neotree_config = config.integrations.neotree
	local auto_preview = true
	if type(neotree_config) == 'table' and neotree_config.auto_preview ~= nil then
		auto_preview = neotree_config.auto_preview
	end

	if not auto_preview then
		return
	end

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
					end, config.debounce.prefetch)
				end,
			})

			-- Cleanup preview when Neo-tree buffer is closed
			vim.api.nvim_create_autocmd('BufWipeout', {
				buffer = info.buf,
				group = group,
				callback = function()
					M._close_preview()
				end,
			})
		end,
	})

	-- Cleanup preview when Neo-tree window is closed
	vim.api.nvim_create_autocmd('WinClosed', {
		group = group,
		callback = function(ev)
			local win = tonumber(ev.match)
			if not win then
				return
			end
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == 'neo-tree' then
				M._close_preview()
			end
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
	local pane = require('glimpse.strategy.pane')
	if pane._wezterm_preview_pane then
		vim.fn.jobstart(
			{ 'wezterm', 'cli', 'kill-pane', '--pane-id', pane._wezterm_preview_pane },
			{ on_exit = function() end }
		)
		pane._wezterm_preview_pane = nil
	end
end

return M
