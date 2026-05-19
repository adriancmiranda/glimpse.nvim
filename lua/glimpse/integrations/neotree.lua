local M = {}

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseNeoTree', { clear = true })
	local util = require('glimpse.util')
	local keys = require('glimpse').get_config().keys

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'neo-tree',
		group = group,
		callback = function(info)
			vim.keymap.set('n', keys.preview, function()
				local state = require('neo-tree.sources.manager').get_state('filesystem')
				local node = state.tree:get_node()
				if not node or node.type ~= 'file' then
					return
				end
				local fpath = node:get_id()
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
				local state = require('neo-tree.sources.manager').get_state('filesystem')
				local node = state.tree:get_node()
				if not node or node.type ~= 'file' then
					return
				end
				local fpath = node:get_id()
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
					vim.cmd('wincmd p')
					vim.cmd('edit ' .. vim.fn.fnameescape(fpath))
					vim.schedule(function()
						pcall(vim.api.nvim_buf_set_name, 0, fpath)
					end)
					return
				end
			end, { buffer = info.buf, silent = true, desc = 'Open image/video' })
		end,
	})
end

return M
