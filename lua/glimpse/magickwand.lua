--- FFI bindings para libMagickWand - decodificação e resize de imagens em memória.
--- Elimina o overhead de spawnar o processo `magick` CLI (~700ms → ~0ms).

local ffi = require('ffi')

ffi.cdef([[
	typedef void MagickWand;
	typedef int MagickBooleanType;
	typedef int ExceptionType;

	void MagickWandGenesis(void);
	void MagickWandTerminus(void);
	MagickWand *NewMagickWand(void);
	MagickWand *DestroyMagickWand(MagickWand *);
	MagickBooleanType MagickReadImage(MagickWand *, const char *);
	MagickBooleanType MagickResizeImage(MagickWand *, unsigned long, unsigned long, int);
	unsigned long MagickGetImageWidth(MagickWand *);
	unsigned long MagickGetImageHeight(MagickWand *);
	MagickBooleanType MagickSetImageFormat(MagickWand *, const char *);
	unsigned char *MagickGetImageBlob(MagickWand *, unsigned long *);
	void *MagickRelinquishMemory(void *);
	char *MagickGetException(MagickWand *, ExceptionType *);
]])

local M = {}
local lib = nil
local initialized = false

--- Carrega a biblioteca MagickWand.
--- @return boolean success
local function ensure_loaded()
	if lib then
		return true
	end
	local names = {
		-- macOS Homebrew
		'/opt/homebrew/lib/libMagickWand-7.Q16HDRI.dylib',
		'/usr/local/lib/libMagickWand-7.Q16HDRI.dylib',
		-- Linux
		'libMagickWand-7.Q16HDRI.so',
		'libMagickWand-7.Q16.so',
		'libMagickWand-6.Q16HDRI.so',
		'libMagickWand-6.Q16.so',
		-- Generic
		'MagickWand-7.Q16HDRI',
		'MagickWand',
	}
	for _, name in ipairs(names) do
		local ok, l = pcall(ffi.load, name)
		if ok then
			lib = l
			if not initialized then
				lib.MagickWandGenesis()
				initialized = true
			end
			return true
		end
	end
	return false
end

--- Converte e redimensiona uma imagem em memória.
--- @param filepath string Caminho do arquivo de imagem
--- @param max_width number Largura máxima em pixels
--- @param max_height number Altura máxima em pixels
--- @return string|nil png_data Dados PNG em binário, nil se falhou
--- @return number|nil width Largura real
--- @return number|nil height Altura real
--- @return string|nil err Mensagem de erro
function M.convert(filepath, max_width, max_height)
	if not ensure_loaded() then
		return nil, nil, nil, 'libMagickWand não encontrada'
	end

	local wand = lib.NewMagickWand()
	if wand == nil then
		return nil, nil, nil, 'Falha ao criar MagickWand'
	end

	-- Lê a imagem
	if lib.MagickReadImage(wand, filepath) == 0 then
		lib.DestroyMagickWand(wand)
		return nil, nil, nil, 'Falha ao ler imagem: ' .. filepath
	end

	-- Obtém dimensões originais
	local orig_w = tonumber(lib.MagickGetImageWidth(wand))
	local orig_h = tonumber(lib.MagickGetImageHeight(wand))

	-- Calcula resize mantendo proporção (contain, só reduz)
	local w, h = orig_w, orig_h
	if w > max_width or h > max_height then
		local ratio = math.min(max_width / w, max_height / h)
		w = math.floor(w * ratio)
		h = math.floor(h * ratio)
		-- LanczosFilter = 22
		lib.MagickResizeImage(wand, w, h, 22)
	end

	-- Exporta como PNG em memória
	lib.MagickSetImageFormat(wand, 'PNG')
	local size = ffi.new('unsigned long[1]')
	local blob = lib.MagickGetImageBlob(wand, size)

	if blob == nil or size[0] == 0 then
		lib.DestroyMagickWand(wand)
		return nil, nil, nil, 'Falha ao exportar PNG'
	end

	local png_data = ffi.string(blob, size[0])
	lib.MagickRelinquishMemory(blob)
	lib.DestroyMagickWand(wand)

	return png_data, w, h, nil
end

--- Verifica se a biblioteca está disponível.
--- @return boolean
function M.available()
	return ensure_loaded()
end

return M
