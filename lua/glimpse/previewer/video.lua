--- Previewer for videos via generated thumbnails.
local M = {}

local thumbnail = require('glimpse.thumbnail')

local function _show_thumbnail(filepath, mode)
	thumbnail.extract_async(filepath, function(thumb)
		if not thumb then
			vim.notify('[glimpse] failed to extract video thumbnail', vim.log.levels.WARN)
			return
		end

		local glimpse = require('glimpse')
		local config = glimpse.get_config()
		if glimpse._should_use_inline() then
			if mode == 'preview' then
				require('glimpse.strategy.inline').preview(thumb)
			else
				require('glimpse.strategy.inline').show(thumb)
			end
		else
			require('glimpse.strategy.pane').show(thumb, {
				position = config.pane_position,
				size = config.pane_size,
			})
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
