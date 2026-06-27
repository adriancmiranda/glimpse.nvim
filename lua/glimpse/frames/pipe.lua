--- Pipe frame extraction strategy.
--- ffmpeg writes all frames to a single temp file via image2pipe; a timer
--- polls that file with io.open('rb') — which preserves NUL bytes correctly,
--- unlike Neovim's on_stdout which treats NUL as a line separator and would
--- corrupt PNG IDAT (DEFLATE-compressed) data.
--- PNG magic-byte boundaries (\x89PNG\r\n\x1a\n) split frames in the buffer.
local M = {}

local DEFAULT_POLL_MS = 50
local PNG_SIG = '\x89PNG\r\n\x1a\n'

--- @param filepath string
--- @param opts? { fps?: number, width?: number, max_frames?: integer, poll_ms?: integer }
--- @param on_frame fun(png_data: string, index: integer, is_preview: boolean)
--- @param on_done fun(count: integer|nil, err: string|nil)
--- @return fun() cancel
function M.extract(filepath, opts, on_frame, on_done)
	opts = opts or {}
	local config_video = ((require('glimpse').get_config().video or {}).frames or {})
	local fps = opts.fps or config_video.per_second or 10
	local width = opts.width or 640
	local max_frames = opts.max_frames or config_video.limit or 120
	local poll_ms = opts.poll_ms or DEFAULT_POLL_MS

	if vim.fn.executable('ffmpeg') == 0 then
		vim.schedule(function()
			on_done(nil, 'ffmpeg not found')
		end)
		return function() end
	end

	local tmp_file = vim.fn.tempname()
	local buffer = ''
	local file_pos = 0
	local frame_count = 0
	local cancelled = false
	local ffmpeg_done = false
	local ffmpeg_ok = true
	local done_called = false

	local function cleanup()
		os.remove(tmp_file)
	end

	local timer = vim.uv.new_timer()

	local function flush_buffer(is_final)
		local pos = 1
		while true do
			local p1 = buffer:find(PNG_SIG, pos, true)
			if not p1 then
				buffer = ''
				break
			end
			local p2 = buffer:find(PNG_SIG, p1 + #PNG_SIG, true)
			if not p2 then
				if is_final and (#buffer - p1) > #PNG_SIG then
					local frame = buffer:sub(p1)
					frame_count = frame_count + 1
					if frame_count <= max_frames then
						on_frame(frame, frame_count, frame_count == 1)
					end
				end
				buffer = buffer:sub(p1)
				break
			end
			local frame = buffer:sub(p1, p2 - 1)
			frame_count = frame_count + 1
			if frame_count <= max_frames then
				on_frame(frame, frame_count, frame_count == 1)
			end
			pos = p2
			if frame_count >= max_frames then
				buffer = ''
				break
			end
		end
	end

	local function poll()
		if cancelled then
			return
		end

		local f = io.open(tmp_file, 'rb')
		if f then
			f:seek('set', file_pos)
			local new_data = f:read('*a')
			f:close()
			if new_data and #new_data > 0 then
				file_pos = file_pos + #new_data
				buffer = buffer .. new_data
				flush_buffer(false)
			end
		end

		if ffmpeg_done then
			flush_buffer(true)
			buffer = ''
			if not done_called then
				done_called = true
				if not timer:is_closing() then
					timer:stop()
					timer:close()
				end
				cleanup()
				if ffmpeg_ok and frame_count > 0 then
					on_done(frame_count, nil)
				elseif not ffmpeg_ok then
					on_done(nil, 'ffmpeg failed')
				else
					on_done(nil, 'no frames extracted')
				end
			end
			return
		end

		timer:start(poll_ms, 0, vim.schedule_wrap(poll))
	end

	local job_id = vim.fn.jobstart({
		'ffmpeg',
		'-y',
		'-i',
		filepath,
		'-vf',
		string.format('fps=%d,scale=%d:-2', fps, width),
		'-frames:v',
		tostring(max_frames),
		'-f',
		'image2pipe',
		'-vcodec',
		'png',
		tmp_file,
	}, {
		on_exit = function(_, code)
			ffmpeg_done = true
			ffmpeg_ok = code == 0
		end,
	})

	if job_id <= 0 then
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
		buffer = ''
	end
end

return M
