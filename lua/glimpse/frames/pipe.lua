--- Pipe frame extraction strategy.
--- Pipes ffmpeg output directly via image2pipe, detecting PNG frame
--- boundaries in the binary stream to deliver frames with minimal latency.
local M = {}

--- @param filepath string
--- @param opts? { fps?: number, width?: number, max_frames?: integer }
--- @param on_frame fun(png_data: string, index: integer, is_preview: boolean)
--- @param on_done fun(count: integer|nil, err: string|nil)
--- @return fun() cancel
function M.extract(_filepath, _opts, _on_frame, on_done)
	-- TODO: implement
	vim.schedule(function()
		on_done(nil, 'pipe strategy not yet implemented')
	end)
	return function() end
end

return M
