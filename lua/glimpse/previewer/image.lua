--- Previewer for images.
local M = {}

--- Show an image inline or in an external pane.
--- @param filepath string
function M.show(filepath)
	local glimpse = require('glimpse')
	local config = glimpse.get_config()
	if glimpse._should_use_inline() then
		require('glimpse.strategy.inline').show(filepath)
	else
		require('glimpse.strategy.pane').show(filepath, {
			position = config.pane.position,
			size = config.pane.size,
		})
	end
end

--- Image preview (reuses an existing window).
--- @param filepath string
function M.preview(filepath)
	local glimpse = require('glimpse')
	local config = glimpse.get_config()
	if glimpse._should_use_inline() then
		require('glimpse.strategy.inline').preview(filepath)
	else
		require('glimpse.strategy.pane').show(filepath, {
			position = config.pane.position,
			size = config.pane.size,
		})
	end
end

return M
