local M = {}

--- Resolve a path to its canonical absolute form.
--- @param path string
--- @return string
function M.normalize_path(path)
	return vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

--- Return true when two file paths refer to the same file.
--- @param left string|nil
--- @param right string|nil
--- @return boolean
function M.same_path(left, right)
	if left == right then
		return true
	end
	if left == nil or right == nil then
		return false
	end
	return M.normalize_path(left) == M.normalize_path(right)
end

--- Check whether the file is a supported image.
--- @param filepath string
--- @return boolean
function M.is_image(filepath)
	local ext = filepath:match('^.+(%..+)$')
	if not ext then
		return false
	end
	local formats = require('glimpse').get_config().image.formats
	for _, fmt in ipairs(formats) do
		if ext:lower() == fmt then
			return true
		end
	end
	return false
end

--- Check whether the file is a Git LFS pointer instead of the real asset.
--- @param filepath string
--- @return boolean
function M.parse_git_lfs_pointer(filepath)
	if vim.uv.fs_stat(filepath) == nil then
		return nil
	end

	local content = vim.fn.readfile(filepath, '', 3)
	if not content or #content < 3 then
		return nil
	end

	if content[1] ~= 'version https://git-lfs.github.com/spec/v1' then
		return nil
	end

	local oid = content[2]:match('^oid sha256:([0-9a-f]+)$')
	local size = content[3]:match('^size (%d+)$')
	if not oid or not size then
		return nil
	end

	return {
		version = content[1],
		oid = oid,
		size = tonumber(size),
	}
end

--- Check whether the file is a Git LFS pointer instead of the real asset.
--- @param filepath string
--- @return boolean
function M.is_git_lfs_pointer(filepath)
	return M.parse_git_lfs_pointer(filepath) ~= nil
end

--- Check whether the file is a supported video.
--- @param filepath string
--- @return boolean
function M.is_video(filepath)
	local ext = filepath:match('^.+(%..+)$')
	if not ext then
		return false
	end
	local video_formats = require('glimpse').get_config().video.formats
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

--- Check whether the file is a supported archive.
--- @param filepath string
--- @return boolean
function M.is_archive(filepath)
	local ext = filepath:match('^.+(%..+)$')
	if not ext then
		return false
	end
	local archive_formats = require('glimpse').get_config().archive.formats
	for _, fmt in ipairs(archive_formats) do
		if filepath:lower():match(fmt:gsub('%.', '%%.') .. '$') then
			return true
		end
	end
	return false
end

--- Check whether the file is an SQLite database.
--- @param filepath string
--- @return boolean
function M.is_sqlite(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return ext == 'db' or ext == 'sqlite' or ext == 'sqlite3'
end

--- Check whether the file is an X.509 certificate.
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

--- Check whether the PEM file is a private key.
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

--- Check whether the file is previewable (image, video, certificate, archive, or SQLite).
--- @param filepath string
--- @return boolean
function M.is_previewable(filepath)
	return M.is_image(filepath)
		or M.is_video(filepath)
		or M.is_model(filepath)
		or M.is_markdown(filepath)
		or M.is_plantuml(filepath)
		or M.is_archive(filepath)
		or M.is_sqlite(filepath)
		or M.is_cert(filepath)
		or M.is_font(filepath)
		or M.is_key(filepath)
end

--- Check whether the file is a font.
--- @param filepath string
--- @return boolean
function M.is_font(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return ext == 'ttf' or ext == 'otf' or ext == 'woff' or ext == 'woff2'
end

local _plantuml_exts = { puml = true, plantuml = true, pu = true, wsd = true, iuml = true }

--- Check whether the file is a PlantUML diagram.
--- @param filepath string
--- @return boolean
function M.is_plantuml(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return _plantuml_exts[ext] == true
end

local _model_exts = {
	obj = true,
	fbx = true,
	dae = true,
	glb = true,
	gltf = true,
	['3ds'] = true,
	['3mf'] = true,
	ply = true,
	stl = true,
	off = true,
	x = true,
	dxf = true,
	wrl = true,
	vrml = true,
	stp = true,
	step = true,
	igs = true,
	iges = true,
	abc = true,
	brep = true,
}

--- Check whether the file is a supported 3D model.
--- @param filepath string
--- @return boolean
function M.is_model(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return _model_exts[ext] == true
end

--- Check whether the file is a Markdown document.
--- @param filepath string
--- @return boolean
function M.is_markdown(filepath)
	local ext = (filepath:match('%.([^.]+)$') or ''):lower()
	return ext == 'md' or ext == 'markdown' or ext == 'mdx' or ext == 'mdwn' or ext == 'mdown'
end

--- Check whether the file is a GPG or SSH key.
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

--- Build a human-readable preview buffer name.
--- @param filepath string
--- @param buf? integer  When provided, appended as [buf] to allow multiple buffers for the same file.
--- @return string
function M.preview_buf_name(filepath, buf)
	local name = 'glimpse://preview/' .. vim.fn.fnamemodify(filepath, ':t')
	if buf then
		return name .. '[' .. buf .. ']'
	end
	return name
end

return M
