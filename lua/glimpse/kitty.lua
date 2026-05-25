--- Kitty Graphics Protocol implementation for image transmission.
--- @see spec https://sw.kovidgoyal.net/kitty/graphics-protocol/

local M = {}

local image_id_counter = 0
local convert_cache = {}
local dims_cache = {}

local function get_config()
	return require('glimpse').get_config()
end

--- Build a cache key that includes mtime for automatic invalidation.
--- @param filepath string
--- @param suffix string
--- @return string
local function make_cache_key(filepath, suffix)
	local stat = vim.uv.fs_stat(filepath)
	local mtime = stat and tostring(stat.mtime.sec) or '0'
	return filepath .. ':' .. mtime .. ':' .. suffix
end

local function get_cache_dir()
	local dir = get_config().cache_dir
	vim.fn.mkdir(dir, 'p')
	return dir
end

--- Return extra safety arguments for SVGs.
--- @param filepath string
--- @return string[] args
local function svg_safety_args(filepath)
	local ext = (filepath:match('%.(%w+)$') or ''):lower()
	if ext == 'svg' or ext == 'svgz' then
		return { '-define', 'svg:xml-parse-huge=false', '-define', 'svg:extern-resources=false' }
	end
	return {}
end

--- Read PNG dimensions directly from the header (without spawning a process).
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
	if not M._pane_offset then
		local pane_id = vim.fn.system({ 'tmux', 'display-message', '-p', '#{pane_id}' })
		local pane_num = tonumber(vim.trim(pane_id):match('%%(%d+)')) or 0
		M._pane_offset = pane_num * 10000
	end
	return M._pane_offset + image_id_counter
end

--- Encode a string as base64.
--- @param str string
--- @return string
local function base64(str)
	if vim.base64 and vim.base64.encode then
		return vim.base64.encode(str)
	end
	return vim.fn.system('printf "%s" ' .. vim.fn.shellescape(str) .. ' | base64'):gsub('%s+', '')
end

--- Send a Kitty Graphics Protocol command to the terminal.
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
	-- Wrap in tmux passthrough when running inside tmux
	if os.getenv('TMUX') then
		cmd = '\027Ptmux;' .. cmd:gsub('\027', '\027\027') .. '\027\\'
	end
	io.stdout:write(cmd)
end

--- Delete an image from the terminal by ID.
--- @param id number
function M.delete(id)
	send({ a = 'd', d = 'i', i = id, q = 2 })
end

--- Delete all images from the terminal.
function M.delete_all()
	send({ a = 'd', q = 2 })
end

--- Transmit an image to the terminal via file path (synchronous).
--- The terminal reads the file directly from disk.
---@param filepath string PNG file path
--- @param opts? { width?: number }
--- @return number|nil id, string|nil err, number|nil w_px, number|nil h_px
function M.transmit(filepath, opts)
	opts = opts or {}
	local id = next_id()
	local width_px = (opts.width or 80) * get_config().cell_size.width
	local cache_key = make_cache_key(filepath, tostring(width_px))
	local tmp = convert_cache[cache_key]

	if not tmp or vim.fn.filereadable(tmp) == 0 then
		if vim.fn.executable('magick') == 0 then
			return nil, 'magick not found'
		end
		tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
		local cmd = vim.list_extend({ 'magick' }, svg_safety_args(filepath))
		vim.list_extend(cmd, { filepath, '-resize', width_px .. '>', tmp })
		vim.fn.system(cmd)
		if vim.v.shell_error ~= 0 then
			return nil, 'magick falhou'
		end
		convert_cache[cache_key] = tmp
	end

	local info = vim.fn.system({ 'magick', 'identify', '-format', '%w %h', tmp })
	local w_px, h_px = info:match('(%d+) (%d+)')
	w_px = tonumber(w_px) or width_px
	h_px = tonumber(h_px) or 400

	send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(tmp) })
	return id, nil, w_px, h_px
end

--- Transmit an image to the terminal asynchronously.
--- @param filepath string
--- @param opts? { width?: number, height?: number }
--- @param callback fun(id: number|nil, err: string|nil, w_px: number|nil, h_px: number|nil)
---@return number|nil job_id External job ID (nil if resolved via cache/FFI)
function M.transmit_async(filepath, opts, callback)
	opts = opts or {}
	local width_px = (opts.width or 80) * get_config().cell_size.width
	local height_px = (opts.height or 40) * get_config().cell_size.height
	local cache_key = make_cache_key(filepath, width_px .. 'x' .. height_px)
	local id = next_id()

	-- Cache hit: dimensions are already known, file is already converted
	if dims_cache[cache_key] and convert_cache[cache_key] then
		local dims = dims_cache[cache_key]
		send({ a = 'T', t = 'f', i = id, f = 100, U = 1, q = 2, data = base64(convert_cache[cache_key]) })
		callback(id, nil, dims.w, dims.h)
		return
	end

	-- Small PNG that already fits: use it directly
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

	-- Try MagickWand FFI (instant, without an external process)
	local mw_ok, magickwand = pcall(require, 'glimpse.magickwand')
	if mw_ok and magickwand.available() then
		local png_data, w, h, _ = magickwand.convert(filepath, width_px, height_px)
		if png_data then
			-- Save to cache for future re-renders
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
		-- FFI failed, fall back
	end

	-- Fallback: magick CLI (asynchronous)
	if vim.fn.executable('magick') == 0 then
		callback(nil, 'magick not found')
		return
	end
	local tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
	local cmd = vim.list_extend({ 'magick' }, svg_safety_args(filepath))
	vim.list_extend(cmd, {
		filepath,
		'-resize',
		width_px .. 'x' .. height_px .. '>',
		'-write',
		tmp,
		'-format',
		'%w %h',
		'info:',
	})
	local job_id = vim.fn.jobstart(cmd, {
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
	return job_id
end

--- Pre-convert an image in the background (populate the cache).
--- @param filepath string
--- @param opts? { width?: number, height?: number }
function M.prefetch(filepath, opts)
	opts = opts or {}
	local width_px = (opts.width or 80) * get_config().cell_size.width
	local height_px = (opts.height or 40) * get_config().cell_size.height
	local cache_key = make_cache_key(filepath, width_px .. 'x' .. height_px)

	if convert_cache[cache_key] then
		return
	end

	if vim.fn.executable('magick') == 0 then
		return
	end

	local tmp = get_cache_dir() .. '/' .. vim.fn.sha256(cache_key) .. '.png'
	local cmd = vim.list_extend({ 'magick' }, svg_safety_args(filepath))
	vim.list_extend(cmd, {
		filepath,
		'-resize',
		width_px .. 'x' .. height_px .. '>',
		'-write',
		tmp,
		'-format',
		'%w %h',
		'info:',
	})
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			vim.schedule(function()
				convert_cache[cache_key] = tmp
				local output = table.concat(data or {}, '')
				local w_px, h_px = output:match('(%d+) (%d+)')
				dims_cache[cache_key] = { w = tonumber(w_px), h = tonumber(h_px) }
			end)
		end,
	})
end

return M
