local M = {}

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseLir', { clear = true })
	local util = require('glimpse.util')
	local keys = require('glimpse').get_config().keys

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'lir',
		group = group,
		callback = function(info)
			vim.keymap.set('n', keys.preview, function()
				local lir = require('lir')
				local ctx = lir.get_context()
				local item = ctx:current()
				if not item or item.is_dir then
					return
				end
				local fpath = item.fullpath
				if util.is_video(fpath) then
					local thumbnail = require('glimpse.thumbnail')
					thumbnail.extract_async(fpath, function(target)
						if target then
							vim.schedule(function()
								require('glimpse').preview(target)
							end)
						end
					end)
				elseif util.is_image(fpath) then
					require('glimpse').preview(fpath)
				end
			end, { buffer = info.buf, silent = true, desc = 'Preview image/video' })

			vim.keymap.set('n', keys.open, function()
				local lir = require('lir')
				local ctx = lir.get_context()
				local item = ctx:current()
				if not item or item.is_dir then
					require('lir.actions').edit()
					return
				end
				local fpath = item.fullpath
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
					require('lir.actions').edit()
					vim.schedule(function()
						pcall(vim.api.nvim_buf_set_name, 0, fpath)
					end)
					return
				end
				require('lir.actions').edit()
			end, { buffer = info.buf, silent = true, desc = 'Open file or image/video' })

			-- Prefetch on cursor move
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
						local lir = require('lir')
						local ctx = lir.get_context()
						local item = ctx:current()
						if not item or item.is_dir then
							return
						end
						if util.is_image(item.fullpath) then
							local kitty = require('glimpse.kitty')
							local cols = math.floor(vim.api.nvim_win_get_width(0) / 2)
							local rows = vim.api.nvim_win_get_height(0)
							kitty.prefetch(item.fullpath, { width = cols, height = rows })
						end
					end, require('glimpse').get_config().debounce.prefetch)
				end,
			})
		end,
	})
end

return M
