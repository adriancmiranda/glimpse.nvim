--- Poll frame extraction strategy.
--- Starts ffmpeg writing numbered PNG files to a temp directory and polls
--- for new files at a fixed interval, delivering frames as they appear.
--- First frame latency is ~poll_ms after ffmpeg writes the first file.
local M = {}

local DEFAULT_POLL_MS = 100

--- @param filepath string
--- @param opts? { fps?: number, width?: number, max_frames?: integer, poll_ms?: integer }
--- @param on_frame fun(png_data: string, index: integer, is_preview: boolean)
--- @param on_done fun(count: integer|nil, err: string|nil)
--- @return fun() cancel
function M.extract(filepath, opts, on_frame, on_done)
	opts = opts or {}
	local fps = opts.fps or (require('glimpse').get_config().video.frames or {}).per_second or 10
	local width = opts.width or 640
	local max_frames = opts.max_frames or (require('glimpse').get_config().video.frames or {}).limit or 120
	local poll_ms = opts.poll_ms or DEFAULT_POLL_MS

	if vim.fn.executable('ffmpeg') == 0 then
		vim.schedule(function()
			on_done(nil, 'ffmpeg not found')
		end)
		return function() end
	end

	local tmp_dir = vim.fn.tempname()
	vim.fn.mkdir(tmp_dir, 'p')

	local cancelled = false
	local next_frame = 1
	local ffmpeg_done = false
	local ffmpeg_ok = true

	local function cleanup()
		vim.fn.delete(tmp_dir, 'rf')
	end

	-- Use uv timer directly for full lifecycle control
	local timer = vim.uv.new_timer()

	local function poll()
		if cancelled then
			return
		end

		while next_frame <= max_frames do
			local path = string.format(tmp_dir .. '/frame_%04d.png', next_frame)
			if not vim.uv.fs_stat(path) then
				break
			end
			local f = io.open(path, 'rb')
			if not f then
				break
			end
			local data = f:read('*a')
			f:close()
			on_frame(data, next_frame, false)
			next_frame = next_frame + 1
		end

		if ffmpeg_done then
			timer:stop()
			timer:close()
			cleanup()
			if ffmpeg_ok then
				on_done(next_frame - 1, nil)
			else
				on_done(nil, 'ffmpeg failed')
			end
			return
		end

		timer:start(poll_ms, 0, vim.schedule_wrap(poll))
	end

	local job_id = vim.fn.jobstart({
		'ffmpeg',
		'-i',
		filepath,
		'-vf',
		string.format('fps=%d,scale=%d:-2', fps, width),
		'-frames:v',
		tostring(max_frames),
		'-f',
		'image2',
		tmp_dir .. '/frame_%04d.png',
	}, {
		on_exit = function(_, code)
			ffmpeg_done = true
			ffmpeg_ok = code == 0
		end,
	})

	if job_id <= 0 then
		timer:stop()
		timer:close()
		cleanup()
		vim.schedule(function()
			on_done(nil, 'failed to start ffmpeg')
		end)
		return function() end
	end

	timer:start(poll_ms, 0, vim.schedule_wrap(poll))

	return function()
		cancelled = true
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		pcall(vim.fn.jobstop, job_id)
		cleanup()
	end
end

return M
