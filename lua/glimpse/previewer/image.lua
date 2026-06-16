--- Previewer for images.
local M = {}

local preview_route = require('glimpse.preview_route')

--- Show an image through the configured preview route.
--- @param filepath string
function M.show(filepath)
	preview_route.show(filepath)
end

--- Preview an image in the current preview target.
--- @param filepath string
function M.preview(filepath)
	preview_route.preview(filepath)
end

return M
