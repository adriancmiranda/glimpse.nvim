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

--- Verifica se o arquivo é previewable (imagem ou vídeo).
--- @param filepath string
--- @return boolean
function M.is_previewable(filepath)
	return M.is_image(filepath) or M.is_video(filepath)
end

return M
