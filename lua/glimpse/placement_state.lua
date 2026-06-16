local util = require('glimpse.util')
local M = {}

--- @class ImagePlacement
--- @field buf number
--- @field image_id number|nil
--- @field filepath string
--- @field closed boolean
--- @field request_id number|nil
--- @field signature table|nil File signature used for cache invalidation
--- @field created_at number|nil Timestamp from vim.uv.hrtime() at creation
--- @field win_cols number|nil Window width when the image was last rendered
--- @field win_rows number|nil Window height when the image was last rendered
--- @field job_id number|nil Active transmit job ID

--- @type table<number, ImagePlacement>
local placements = {}

function M.get(buf)
	return placements[buf]
end

function M.set(buf, placement)
	placements[buf] = placement
end

function M.remove(buf)
	placements[buf] = nil
end

function M.has(buf)
	local placement = placements[buf]
	return placement ~= nil and not placement.closed
end

function M.find_by_filepath(filepath)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			local placement = placements[buf]
			if
				placement
				and placement.filepath
				and util.same_path(placement.filepath, filepath)
				and vim.api.nvim_buf_is_valid(buf)
			then
				return buf
			end
		end
	end

	for buf, placement in pairs(placements) do
		if placement.filepath and util.same_path(placement.filepath, filepath) and vim.api.nvim_buf_is_valid(buf) then
			return buf
		end
	end
end

function M.needs_rerender(buf)
	local placement = placements[buf]
	if not placement or placement.closed then
		return false
	end
	return placement.image_id ~= nil
end

return M
