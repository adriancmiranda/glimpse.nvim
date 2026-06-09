--- Previewer for videos via generated thumbnails.
local M = {}

local thumbnail = require('glimpse.thumbnail')

local _tokens = {}

local function _show_thumbnail(filepath, mode)
	local winid = vim.api.nvim_get_current_win()
	local token = {}
	_tokens[winid] = token
	thumbnail.extract_async(filepath, function(thumb)
		if _tokens[winid] ~= token then
			return
		end
		_tokens[winid] = nil
		if not thumb then
			vim.notify('[glimpse] failed to extract video thumbnail', vim.log.levels.WARN)
			return
		end

		local glimpse = require('glimpse')
		local config = glimpse.get_config()
		local current_win = vim.api.nvim_get_current_win()
		local restore_win = current_win ~= winid and vim.api.nvim_win_is_valid(winid)
		if restore_win then
			vim.api.nvim_set_current_win(winid)
		end
		if glimpse._should_use_inline() then
			if mode == 'preview' then
				require('glimpse.strategy.inline').preview(thumb)
			else
				require('glimpse.strategy.inline').show(thumb)
			end
		else
			require('glimpse.strategy.pane').show(thumb, {
				position = config.pane.position,
				size = config.pane.size,
			})
		end
		if restore_win and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
		end
	end)
end

--- Show a video using a generated thumbnail.
--- @param filepath string
function M.show(filepath)
	_show_thumbnail(filepath, 'show')
end

--- Quick preview of a video using a generated thumbnail.
--- @param filepath string
function M.preview(filepath)
	_show_thumbnail(filepath, 'preview')
end

return M
