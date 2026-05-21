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

--- Verifica se o arquivo é previewable (imagem, vídeo, archive ou sqlite).
--- @param filepath string
--- @return boolean
function M.is_previewable(filepath)
	return M.is_image(filepath)
		or M.is_video(filepath)
		or M.is_archive(filepath)
		or M.is_sqlite(filepath)
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
	if name:match('^id_') or name:match('%.pub$') or name:match('%.pem$') then
		return true
	end
	local ext = (name:match('%.([^.]+)$') or ''):lower()
	return ext == 'gpg' or ext == 'asc' or ext == 'key' or ext == 'pgp'
end

return M
