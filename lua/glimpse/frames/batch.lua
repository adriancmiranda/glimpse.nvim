--- Batch frame extraction strategy.
--- Runs two ffmpeg jobs in parallel: a quick low-res single-frame preview
--- delivered immediately via on_frame(data, 1, true), and a full-resolution
--- extraction whose frames are delivered all at once when ffmpeg finishes.
local M = {}

--- @param filepath string
--- @param opts? { fps?: number, width?: number, max_frames?: integer }
--- @param on_frame fun(png_data: string, index: integer, is_preview: boolean)
--- @param on_done fun(count: integer|nil, err: string|nil)
--- @return fun() cancel
function M.extract(filepath, opts, on_frame, on_done)
	opts = opts or {}
	local config_video = ((require('glimpse').get_config().video or {}).frames or {})
	local fps = opts.fps or config_video.per_second or 10
	local width = opts.width or 640
	local max_frames = opts.max_frames or config_video.limit or 120

	if vim.fn.executable('ffmpeg') == 0 then
		vim.schedule(function()
			on_done(nil, 'ffmpeg not found')
		end)
		return function() end
	end

	local cancelled = false
	local preview_tmp = vim.fn.tempname() .. '.png'
	local tmp_dir = vim.fn.tempname()
	vim.fn.mkdir(tmp_dir, 'p')

	-- Job 1: single low-res frame for immediate preview
	local preview_job = vim.fn.jobstart({
		'ffmpeg',
		'-y',
		'-i',
		filepath,
		'-frames:v',
		'1',
		'-vf',
		'scale=320:-2',
		'-f',
		'image2',
		preview_tmp,
	}, {
		on_exit = function(_, code)
			if cancelled then
				os.remove(preview_tmp)
				return
			end
			if code == 0 then
				local f = io.open(preview_tmp, 'rb')
				if f then
					local data = f:read('*a')
					f:close()
					on_frame(data, 1, true)
				end
			end
			os.remove(preview_tmp)
		end,
	})

	-- Job 2: full-resolution all frames; delivered all at once when done
	local full_job = vim.fn.jobstart({
		'ffmpeg',
		'-y',
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
			if cancelled then
				vim.fn.delete(tmp_dir, 'rf')
				return
			end
			if code ~= 0 then
				vim.fn.delete(tmp_dir, 'rf')
				on_done(nil, 'ffmpeg failed')
				return
			end
			local count = 0
			local i = 1
			while i <= max_frames do
				local path = string.format(tmp_dir .. '/frame_%04d.png', i)
				if not vim.uv.fs_stat(path) then
					break
				end
				local f = io.open(path, 'rb')
				if f then
					local data = f:read('*a')
					f:close()
					on_frame(data, i, false)
					count = i
				end
				i = i + 1
			end
			vim.fn.delete(tmp_dir, 'rf')
			on_done(count, nil)
		end,
	})

	if preview_job <= 0 or full_job <= 0 then
		pcall(vim.fn.jobstop, preview_job)
		pcall(vim.fn.jobstop, full_job)
		os.remove(preview_tmp)
		vim.fn.delete(tmp_dir, 'rf')
		vim.schedule(function()
			on_done(nil, 'failed to start ffmpeg')
		end)
		return function() end
	end

	return function()
		cancelled = true
		pcall(vim.fn.jobstop, preview_job)
		pcall(vim.fn.jobstop, full_job)
		os.remove(preview_tmp)
		vim.fn.delete(tmp_dir, 'rf')
	end
end

return M
