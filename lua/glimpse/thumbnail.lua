local M = {}

--- Build the thumbnail path from the filepath and mtime.
--- @param filepath string
--- @param cache_dir string
--- @return string|nil thumb_path
--- @return boolean cached
local function resolve_thumb_path(filepath, cache_dir)
	local stat = vim.uv.fs_stat(filepath)
	if not stat then
		return nil, false
	end
	local hash = vim.fn.sha256(filepath .. tostring(stat.mtime.sec)):sub(1, 16)
	local thumb_path = cache_dir .. '/thumb_' .. hash .. '.png'
	local cached = vim.uv.fs_stat(thumb_path) ~= nil
	return thumb_path, cached
end

--- Extract a video thumbnail using ffmpeg (synchronous).
---@param filepath string Absolute video path
--- @param opts? { cache_dir?: string }
--- @return string|nil thumbnail_path Caminho do thumbnail ou nil se falhar
function M.extract(filepath, opts)
	opts = opts or {}
	local config = require('glimpse').get_config()
	local cache_dir = opts.cache_dir or config.cache_dir

	local thumb_path, cached = resolve_thumb_path(filepath, cache_dir)
	if not thumb_path then
		return nil
	end
	if cached then
		return thumb_path
	end

	vim.fn.mkdir(cache_dir, 'p')

	local cmd = {
		'ffmpeg',
		'-y',
		'-i',
		filepath,
		'-vframes',
		'1',
		'-an',
		'-vf',
		'scale=640:-2',
		thumb_path,
	}
	local result = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify('[glimpse] ffmpeg failed: ' .. result, vim.log.levels.DEBUG)
		return nil
	end

	return thumb_path
end

--- Extract a video thumbnail using ffmpeg (asynchronous).
---@param filepath string Absolute video path
---@param callback fun(thumb_path: string|nil) Called with the path or nil
--- @param opts? { cache_dir?: string }
function M.extract_async(filepath, callback, opts)
	opts = opts or {}
	local config = require('glimpse').get_config()
	local cache_dir = opts.cache_dir or config.cache_dir

	local thumb_path, cached = resolve_thumb_path(filepath, cache_dir)
	if not thumb_path then
		callback(nil)
		return
	end
	if cached then
		callback(thumb_path)
		return
	end

	vim.fn.mkdir(cache_dir, 'p')

	local job_id = vim.fn.jobstart({
		'ffmpeg',
		'-y',
		'-i',
		filepath,
		'-vframes',
		'1',
		'-an',
		'-vf',
		'scale=640:-2',
		thumb_path,
	}, {
		on_exit = function(_, code)
			if code == 0 then
				callback(thumb_path)
			else
				callback(nil)
			end
		end,
	})
	if job_id <= 0 then
		callback(nil)
	end
end

return M
