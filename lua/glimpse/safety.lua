local M = {}

--- Tamanho maximo padrao para processamento (50MB).
local DEFAULT_MAX_SIZE = 50 * 1024 * 1024

--- Valida se um arquivo e seguro para processamento.
--- @param filepath string
--- @param opts? { max_size?: number }
--- @return boolean safe
--- @return string|nil reason
function M.check(filepath, opts)
	opts = opts or {}
	local max_size = opts.max_size or DEFAULT_MAX_SIZE

	-- Verifica se o arquivo existe
	local lstat = vim.uv.fs_lstat(filepath)
	if not lstat then
		return false, 'file not found'
	end

	-- Rejeita symlinks
	if lstat.type == 'link' then
		return false, 'symlink rejected'
	end

	-- Verifica se e um arquivo regular
	if lstat.type ~= 'file' then
		return false, 'not a regular file'
	end

	-- Verifica tamanho (0 = sem limite)
	if max_size > 0 and lstat.size > max_size then
		local size_mb = string.format('%.1fMB', lstat.size / 1048576)
		local limit_mb = string.format('%.0fMB', max_size / 1048576)
		return false, 'file too large (' .. size_mb .. ', max ' .. limit_mb .. ')'
	end

	return true
end

return M
