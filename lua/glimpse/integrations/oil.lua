local M = {}

local function _edit_file(command, fpath)
	vim.cmd(command .. ' ' .. vim.fn.fnameescape(fpath))
end

function M._open_image(fpath, open_mode)
	local oil = require('oil')
	oil.close()
	if type(open_mode) == 'function' then
		open_mode(fpath)
		return
	end
	local command = open_mode == 'tabedit' and 'tabedit' or 'edit'
	_edit_file(command, fpath)
	vim.schedule(function()
		pcall(vim.api.nvim_buf_set_name, 0, fpath)
	end)
end

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseOil', { clear = true })
	local util = require('glimpse.util')
	local kitty = require('glimpse.kitty')
	local keys = require('glimpse').get_config().keys
	local oil_config = require('glimpse').get_config().integrations.oil

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'oil',
		group = group,
		callback = function(info)
			vim.keymap.set('n', keys.preview, function()
				local oil = require('oil')
				local entry = oil.get_cursor_entry()
				if not entry or entry.type ~= 'file' then
					return
				end
				local dir = oil.get_current_dir()
				if not dir then
					return
				end
				local fpath = vim.fs.joinpath(dir, entry.name)
				if util.is_video(fpath) then
					local thumbnail = require('glimpse.thumbnail')
					thumbnail.extract_async(fpath, function(target)
						if target then
							vim.schedule(function()
								require('glimpse').preview(target)
							end)
						end
					end)
				else
					require('glimpse').preview(fpath)
				end
			end, { buffer = info.buf, silent = true, desc = 'Image/video preview' })

			-- Open image in the configured tab mode or video with an external player
			vim.keymap.set('n', keys.open, function()
				local oil = require('oil')
				local entry = oil.get_cursor_entry()
				if entry and entry.type == 'file' then
					local dir = oil.get_current_dir()
					if not dir then
						return
					end
					local fpath = vim.fs.joinpath(dir, entry.name)
					if util.is_video(fpath) then
						local config = require('glimpse').get_config()
						if config.video_open then
							if type(config.video_open) == 'function' then
								config.video_open(fpath)
							else
								vim.fn.jobstart({ config.video_open, fpath }, { detach = true })
							end
						end
						return
					end
					if util.is_image(fpath) then
						local glimpse = require('glimpse')
						if glimpse._should_use_inline() then
							M._open_image(fpath, oil_config.open)
						else
							local config = glimpse.get_config()
							require('glimpse.strategy.pane').show(fpath, {
								position = config.pane_position,
								size = config.pane_size,
							})
						end
						return
					end
					if util.is_font(fpath) then
						require('glimpse').show(fpath)
						return
					end
				end
				oil.select()
			end, { buffer = info.buf, silent = true, desc = 'Open file or image/video' })

			-- Prefetch
			local prefetch_timer = nil
			vim.api.nvim_create_autocmd('CursorMoved', {
				buffer = info.buf,
				group = group,
				callback = function()
					if prefetch_timer then
						prefetch_timer:stop()
					end
					prefetch_timer = vim.defer_fn(function()
						prefetch_timer = nil
						local oil = require('oil')
						local entry = oil.get_cursor_entry()
						if not entry or entry.type ~= 'file' then
							return
						end
						local dir = oil.get_current_dir()
						if not dir then
							return
						end
						local fpath = vim.fs.joinpath(dir, entry.name)
						if util.is_image(fpath) then
							local cols = math.floor(vim.api.nvim_win_get_width(0) / 2)
							local rows = vim.api.nvim_win_get_height(0)
							kitty.prefetch(fpath, { width = cols, height = rows })
						end
					end, require('glimpse').get_config().debounce.prefetch)
				end,
			})
		end,
	})

	-- Clean up the WezTerm pane when leaving Oil or exiting Neovim
	vim.api.nvim_create_autocmd({ 'BufLeave' }, {
		group = group,
		pattern = 'oil://*',
		callback = function()
			local pane = require('glimpse.strategy.pane')
			if pane._wezterm_preview_pane then
				vim.fn.jobstart(
					{ 'wezterm', 'cli', 'kill-pane', '--pane-id', pane._wezterm_preview_pane },
					{ on_exit = function() end }
				)
				pane._wezterm_preview_pane = nil
			end
		end,
	})

	vim.api.nvim_create_autocmd('VimLeavePre', {
		group = group,
		callback = function()
			local pane = require('glimpse.strategy.pane')
			if pane._wezterm_preview_pane then
				vim.fn.system({ 'wezterm', 'cli', 'kill-pane', '--pane-id', pane._wezterm_preview_pane })
				pane._wezterm_preview_pane = nil
			end
		end,
	})
end

return M
