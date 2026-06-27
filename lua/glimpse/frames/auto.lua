--- Auto frame extraction strategy.
--- Selects the best available strategy based on environment heuristics.
--- Prefers pipe (no temp files, lower first-frame latency) when ffmpeg is available.
local M = {}

--- @param filepath string
--- @param opts? { fps?: number, width?: number, max_frames?: integer }
--- @param on_frame fun(png_data: string, index: integer, is_preview: boolean)
--- @param on_done fun(count: integer|nil, err: string|nil)
--- @return fun() cancel
function M.extract(filepath, opts, on_frame, on_done)
	if vim.fn.executable('ffmpeg') == 0 then
		vim.schedule(function()
			on_done(nil, 'ffmpeg not found')
		end)
		return function() end
	end

	return require('glimpse.frames.pipe').extract(filepath, opts, on_frame, on_done)
end

return M
