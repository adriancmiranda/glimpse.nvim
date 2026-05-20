local M = {}

--- Remove arquivos do cache com mtime mais antigo que max_age_days.
--- @param cache_dir string
--- @param max_age_days number
function M.cleanup(cache_dir, max_age_days)
	local stat = vim.uv.fs_stat(cache_dir)
	if not stat or stat.type ~= 'directory' then
		return
	end
	local now = os.time()
	local max_age_sec = max_age_days * 86400
	local handle = vim.uv.fs_scandir(cache_dir)
	if not handle then
		return
	end
	while true do
		local name, type = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end
		if type == 'file' then
			local path = cache_dir .. '/' .. name
			local fstat = vim.uv.fs_stat(path)
			if fstat and (now - fstat.mtime.sec) > max_age_sec then
				vim.uv.fs_unlink(path)
			end
		end
	end
end

return M
