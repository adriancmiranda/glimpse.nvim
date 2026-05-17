--- Implementação do Kitty Graphics Protocol para transmissão de imagens.
--- @see spec https://sw.kovidgoyal.net/kitty/graphics-protocol/

local M = {}

local image_id_counter = 0
local convert_cache = {}
local dims_cache = {}

local function get_config()
	return require('glimpse').get_config()
end

local function get_cache_dir()
	local dir = get_config().cache_dir
	vim.fn.mkdir(dir, 'p')
	return dir
end

--- Lê dimensões de um PNG diretamente do header (sem spawnar processo).
--- @param filepath string
--- @return number|nil w, number|nil h
local function png_dimensions(filepath)
	local f = io.open(filepath, 'rb')
	if not f then
		return nil, nil
	end
	local header = f:read(24)
	f:close()
	if not header or #header < 24 then
		return nil, nil
	end
	-- PNG: bytes 16-19 = width, 20-23 = height (big-endian uint32)
	local w = header:byte(17) * 16777216 + header:byte(18) * 65536 + header:byte(19) * 256 + header:byte(20)
	local h = header:byte(21) * 16777216 + header:byte(22) * 65536 + header:byte(23) * 256 + header:byte(24)
	return w, h
end

--- @return number
local function next_id()
	image_id_counter = image_id_counter + 1
	return image_id_counter
end

--- Codifica string em base64.
--- @param str string
--- @return string
local function base64(str)
	if vim.base64 and vim.base64.encode then
		return vim.base64.encode(str)
	end
	return vim.fn.system('printf "%s" ' .. vim.fn.shellescape(str) .. ' | base64'):gsub('%s+', '')
end

--- Envia um comando do protocolo Kitty Graphics ao terminal.
--- @param params table<string, string|number>
--- @param payload? string
local function send(params, payload)
	local parts = {}
	for k, v in pairs(params) do
		if k ~= 'data' then
			table.insert(parts, k .. '=' .. tostring(v))
		end
	end
	local cmd = '\027_G' .. table.concat(parts, ',')
	if payload then
		cmd = cmd .. ';' .. payload
	elseif params.data then
		cmd = cmd .. ';' .. params.data
	end
	cmd = cmd .. '\027\\'
	-- Dentro do tmux, envolve em passthrough
	if os.getenv('TMUX') then
		cmd = '\027Ptmux;' .. cmd:gsub('\027', '\027\027') .. '\027\\'
	end
	io.stdout:write(cmd)
end

--- Deleta uma imagem do terminal pelo ID.
--- @param id number
function M.delete(id)
	send({ a = 'd', d = 'i', i = id, q = 2 })
end

--- Deleta todas as imagens do terminal.
function M.delete_all()
	send({ a = 'd', q = 2 })
end

--- Transmite uma imagem ao terminal via file path (síncrono).
--- O terminal lê o arquivo diretamente do disco.
--- @param filepath string Caminho do arquivo PNG
--- @param opts? { width?: number }
--- @return number|nil id, string|nil err, number|nil w_px, number|nil h_px
function M.transmit(filepath, opts)
	opts = opts or {}
	local id = next_id()
	local width_px = (opts.width or 80) * get_config().cell_size.width
	local cache_key = filepath .. ':' .. width_px
	local tmp = convert_cache[cache_key]

	if not tmp or vim.fn.filereadable(tmp) == 0 then
		tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
		vim.fn.system(string.format('magick "%s" -resize \'%d>\' "%s"', filepath, width_px, tmp))
		if vim.v.shell_error ~= 0 then
			return nil, 'magick falhou'
		end
		convert_cache[cache_key] = tmp
	end

	local info = vim.fn.system(string.format('magick identify -format "%%w %%h" "%s"', tmp))
	local w_px, h_px = info:match('(%d+) (%d+)')
	w_px = tonumber(w_px) or width_px
	h_px = tonumber(h_px) or 400

	send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(tmp) })
	return id, nil, w_px, h_px
end

--- Transmite uma imagem ao terminal de forma assíncrona.
--- @param filepath string
--- @param opts? { width?: number, height?: number }
--- @param callback fun(id: number|nil, err: string|nil, w_px: number|nil, h_px: number|nil)
function M.transmit_async(filepath, opts, callback)
	opts = opts or {}
	local width_px = (opts.width or 80) * get_config().cell_size.width
	local height_px = (opts.height or 40) * get_config().cell_size.height
	local cache_key = filepath .. ':' .. width_px .. 'x' .. height_px
	local id = next_id()

	-- Cache hit: dimensões já conhecidas, arquivo já convertido
	if dims_cache[cache_key] and convert_cache[cache_key] then
		local dims = dims_cache[cache_key]
		send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(convert_cache[cache_key]) })
		callback(id, nil, dims.w, dims.h)
		return
	end

	-- PNG pequeno que já cabe: usa direto
	local ext = filepath:match('%.(%w+)$')
	if ext and ext:lower() == 'png' then
		local w, h = png_dimensions(filepath)
		if w and h and w <= width_px and h <= height_px then
			convert_cache[cache_key] = filepath
			dims_cache[cache_key] = { w = w, h = h }
			send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(filepath) })
			callback(id, nil, w, h)
			return
		end
	end

	-- Tenta FFI MagickWand (instantâneo, sem processo externo)
	local mw_ok, magickwand = pcall(require, 'glimpse.magickwand')
	if mw_ok and magickwand.available() then
		local png_data, w, h, _ = magickwand.convert(filepath, width_px, height_px)
		if png_data then
			-- Salva no cache para re-renders futuros
			local tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
			local f = io.open(tmp, 'wb')
			if f then
				f:write(png_data)
				f:close()
			end
			convert_cache[cache_key] = tmp
			dims_cache[cache_key] = { w = w, h = h }
			send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(tmp) })
			callback(id, nil, w, h)
			return
		end
		-- FFI falhou, cai no fallback
	end

	-- Fallback: magick CLI (assíncrono)
	local tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
	local cmd = string.format(
		'magick "%s" -resize \'%dx%d>\' -write "%s" -format \'%%w %%h\' info:',
		filepath,
		width_px,
		height_px,
		tmp
	)
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			vim.schedule(function()
				convert_cache[cache_key] = tmp
				local output = table.concat(data or {}, '')
				local w_px, h_px = output:match('(%d+) (%d+)')
				dims_cache[cache_key] = { w = tonumber(w_px), h = tonumber(h_px) }
				send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(tmp) })
				callback(id, nil, tonumber(w_px), tonumber(h_px))
			end)
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.schedule(function()
					callback(nil, 'magick falhou')
				end)
			end
		end,
	})
end

--- Pré-converte uma imagem em background (popula o cache).
--- @param filepath string
--- @param opts? { width?: number, height?: number }
function M.prefetch(filepath, opts)
	opts = opts or {}
	local width_px = (opts.width or 80) * get_config().cell_size.width
	local height_px = (opts.height or 40) * get_config().cell_size.height
	local cache_key = filepath .. ':' .. width_px .. 'x' .. height_px

	if convert_cache[cache_key] then
		return
	end

	local tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
	vim.fn.jobstart(
		string.format(
			'magick "%s" -resize \'%dx%d>\' -write "%s" -format \'%%w %%h\' info:',
			filepath,
			width_px,
			height_px,
			tmp
		),
		{
			stdout_buffered = true,
			on_stdout = function(_, data)
				vim.schedule(function()
					convert_cache[cache_key] = tmp
					local output = table.concat(data or {}, '')
					local w_px, h_px = output:match('(%d+) (%d+)')
					dims_cache[cache_key] = { w = tonumber(w_px), h = tonumber(h_px) }
				end)
			end,
		}
	)
end

return M
