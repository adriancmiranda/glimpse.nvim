--- Route image-like previews to the inline or pane strategy.
local M = {}

local function pane_opts()
	local glimpse = require('glimpse')
	local config = glimpse.get_config()
	return {
		position = config.pane.position,
		size = config.pane.size,
	}
end

function M.show(filepath)
	local glimpse = require('glimpse')
	if glimpse._should_use_inline() then
		require('glimpse.strategy.inline').show(filepath)
	else
		require('glimpse.strategy.pane').show(filepath, pane_opts())
	end
end

--- @param opts? { window?: string }
function M.preview(filepath, opts)
	local glimpse = require('glimpse')
	if glimpse._should_use_inline() then
		require('glimpse.strategy.inline').preview(filepath, opts)
	else
		require('glimpse.strategy.pane').show(filepath, pane_opts())
	end
end

return M
