--- Frame extraction router.
--- Selects the extraction strategy based on opts.strategy or
--- config.video.frame_strategy and delegates to the appropriate module.
---
--- Available strategies:
---   'auto'  - selects the best strategy automatically (default)
---   'batch' - preview frame immediately, full frames after ffmpeg finishes
---   'poll'  - incremental delivery as ffmpeg writes files
---   'pipe'  - stream PNG frames from ffmpeg via image2pipe (no temp files for extraction)
local M = {}

local strategies = {
	auto = require('glimpse.frames.auto'),
	batch = require('glimpse.frames.batch'),
	poll = require('glimpse.frames.poll'),
	pipe = require('glimpse.frames.pipe'),
}

--- Extract frames from a video file using the configured strategy.
--- @param filepath string
--- @param opts? { fps?: number, width?: number, max_frames?: integer, strategy?: string }
--- @param on_frame fun(png_data: string, index: integer, is_preview: boolean)
--- @param on_done fun(count: integer|nil, err: string|nil)
--- @return fun() cancel
function M.extract_frames_async(filepath, opts, on_frame, on_done)
	opts = opts or {}
	local frames_cfg = ((require('glimpse').get_config().video or {}).frames or {})
	local name = opts.strategy or frames_cfg.strategy or 'auto'
	local strategy = strategies[name]
	if not strategy then
		vim.schedule(function()
			on_done(nil, string.format("unsupported frame strategy '%s'", tostring(name)))
		end)
		return function() end
	end
	return strategy.extract(filepath, opts, on_frame, on_done)
end

return M
