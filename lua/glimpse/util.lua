local M = {}

--- Verifica se o arquivo é uma imagem suportada.
--- @param filepath string
--- @return boolean
function M.is_image(filepath)
	local ext = filepath:match('^.+(%..+)$')
	if not ext then
		return false
	end
	local formats = require('glimpse').get_config().formats
	for _, fmt in ipairs(formats) do
		if ext:lower() == fmt then
			return true
		end
	end
	return false
end

--- Verifica se o arquivo é um vídeo suportado.
--- @param filepath string
--- @return boolean
function M.is_video(filepath)
	local ext = filepath:match('^.+(%..+)$')
	if not ext then
		return false
	end
	local video_formats = require('glimpse').get_config().video_formats
	if not video_formats then
		return false
	end
	for _, fmt in ipairs(video_formats) do
		if ext:lower() == fmt then
			return true
		end
	end
	return false
end

--- Verifica se o arquivo é um archive suportado.
--- @param filepath string
--- @return boolean
function M.is_archive(filepath)
	local ext = filepath:match('^.+(%..+)$')
	if not ext then
		return false
	end
	local archive_formats = { '.zip', '.tar', '.tar.gz', '.tgz', '.tar.bz2', '.tar.xz', '.txz', '.jar', '.war', '.apk' }
	for _, fmt in ipairs(archive_formats) do
		if filepath:lower():match(fmt:gsub('%.', '%%.') .. '$') then
			return true
		end
	end
	return false
end

--- Verifica se o arquivo é um banco SQLite.
--- @param filepath string
--- @return boolean
function M.is_sqlite(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return ext == 'db' or ext == 'sqlite' or ext == 'sqlite3'
end

--- Verifica se o arquivo é um certificado X.509.
--- @param filepath string
--- @return boolean
function M.is_cert(filepath)
	local name = filepath:match('([^/]+)$') or ''
	local ext = (name:match('%.([^.]+)$') or ''):lower()
	if ext == 'crt' then
		return true
	end
	if ext ~= 'pem' then
		return false
	end

	local content = vim.fn.readfile(filepath, '', 200)
	if not content or #content == 0 then
		return false
	end

	for _, line in ipairs(content) do
		if
			line:find('BEGIN CERTIFICATE', 1, true)
			or line:find('BEGIN X509 CERTIFICATE', 1, true)
			or line:find('BEGIN TRUSTED CERTIFICATE', 1, true)
		then
			return true
		end
	end

	return false
end

--- Verifica se o arquivo PEM é uma chave privada.
--- @param filepath string
--- @return boolean
local function is_pem_key(filepath)
	local content = vim.fn.readfile(filepath, '', 20)
	if not content or #content == 0 then
		return false
	end

	for _, line in ipairs(content) do
		if
			line:find('BEGIN PRIVATE KEY', 1, true)
			or line:find('BEGIN RSA PRIVATE KEY', 1, true)
			or line:find('BEGIN EC PRIVATE KEY', 1, true)
			or line:find('BEGIN ENCRYPTED PRIVATE KEY', 1, true)
			or line:find('BEGIN OPENSSH PRIVATE KEY', 1, true)
			or line:find('BEGIN PGP PRIVATE KEY BLOCK', 1, true)
		then
			return true
		end
	end

	return false
end

--- Verifica se o arquivo é previewable (imagem, vídeo, certificado, archive ou sqlite).
--- @param filepath string
--- @return boolean
function M.is_previewable(filepath)
	return M.is_image(filepath)
		or M.is_video(filepath)
		or M.is_archive(filepath)
		or M.is_sqlite(filepath)
		or M.is_cert(filepath)
		or M.is_font(filepath)
		or M.is_key(filepath)
end

--- Verifica se o arquivo é uma fonte.
--- @param filepath string
--- @return boolean
function M.is_font(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return ext == 'ttf' or ext == 'otf' or ext == 'woff' or ext == 'woff2'
end

--- Verifica se o arquivo é uma chave GPG ou SSH.
--- @param filepath string
--- @return boolean
function M.is_key(filepath)
	local name = filepath:match('([^/]+)$') or ''
	if name:match('^id_') or name:match('%.pub$') then
		return true
	end
	if name:match('%.pem$') then
		return is_pem_key(filepath)
	end
	local ext = (name:match('%.([^.]+)$') or ''):lower()
	return ext == 'gpg' or ext == 'asc' or ext == 'key' or ext == 'pgp'
end

return M
