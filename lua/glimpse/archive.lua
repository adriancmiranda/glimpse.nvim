local M = {}

--- @class ArchiveEntry
--- @field path string
--- @field size number|nil
--- @field date string|nil
--- @field type 'file'|'directory'|'symlink'
--- @field suspicious boolean

--- Detecta paths suspeitos (traversal, absolutos, symlinks).
--- @param path string
--- @return boolean
local function is_suspicious(path)
	if path:match('^/') then
		return true
	end
	if path:match('%.%./') or path:match('/%.%.') then
		return true
	end
	return false
end

--- Parseia output de `zipinfo` com detalhes.
--- @param filepath string
--- @return ArchiveEntry[]|nil entries
--- @return string|nil err
function M.list_zip(filepath)
	if vim.fn.executable('zipinfo') == 0 then
		return nil, 'zipinfo not found'
	end
	local output = vim.fn.system({ 'zipinfo', filepath })
	if vim.v.shell_error ~= 0 then
		return nil, 'zipinfo failed'
	end
	-- O zipinfo do macOS usa '+' como escape para bytes nao-ASCII (Latin-1).
	-- Remove o '+' e converte o byte seguinte de Latin-1 para UTF-8.
	output = output:gsub('%+(.)', function(byte)
		local b = byte:byte()
		if b >= 0x80 then
			-- Converte Latin-1 byte para UTF-8 (2 bytes)
			if b < 0xC0 then
				return string.char(0xC2, b)
			else
				return string.char(0xC3, b - 0x40)
			end
		end
		return '+' .. byte
	end)
	local entries = {}
	for line in output:gmatch('[^\n]+') do
		if line:match('^[%-dl?]') then
			local perms, size, date, time, path = line:match('^(%S+)%s+%S+%s+%S+%s+(%d+)%s+%S+%s+%S+%s+(%S+)%s+(%S+)%s+(.+)')
			if perms and path then
				local entry_type = 'file'
				if perms:match('^d') then
					entry_type = 'directory'
				elseif perms:match('^l') then
					entry_type = 'symlink'
				end
				table.insert(entries, {
					path = path,
					size = tonumber(size),
					date = date .. ' ' .. time,
					type = entry_type,
					suspicious = is_suspicious(path) or entry_type == 'symlink',
				})
			end
		end
	end
	return entries
end

--- Parseia output de `tar tf`.
--- @param filepath string
--- @return ArchiveEntry[]|nil entries
--- @return string|nil err
function M.list_tar(filepath)
	if vim.fn.executable('tar') == 0 then
		return nil, 'tar not found'
	end
	local output = vim.fn.system({ 'tar', 'tvf', filepath })
	if vim.v.shell_error ~= 0 then
		return nil, 'tar failed'
	end
	local entries = {}
	for line in output:gmatch('[^\n]+') do
		local perms, size, date, time, path = line:match('^(%S+)%s+%S+%s+(%d+)%s+(%S+)%s+(%S+)%s+(.+)')
		if path then
			local entry_type = 'file'
			if perms:match('^d') then
				entry_type = 'directory'
			elseif perms:match('^l') then
				entry_type = 'symlink'
			end
			table.insert(entries, {
				path = path,
				size = tonumber(size),
				date = date .. ' ' .. time,
				type = entry_type,
				suspicious = is_suspicious(path),
			})
		end
	end
	return entries
end

--- Lista conteudo de um archive (detecta formato pela extensao).
--- @param filepath string
--- @return ArchiveEntry[]|nil entries
--- @return string|nil err
function M.list(filepath)
	local ext = filepath:match('%.([^.]+)$')
	if not ext then
		return nil, 'unknown format'
	end
	ext = ext:lower()
	if ext == 'zip' or ext == 'jar' or ext == 'war' or ext == 'apk' then
		return M.list_zip(filepath)
	elseif ext == 'tar' or filepath:match('%.tar%.%w+$') or ext == 'tgz' or ext == 'txz' then
		return M.list_tar(filepath)
	elseif ext == 'gz' and filepath:match('%.tar%.gz$') then
		return M.list_tar(filepath)
	elseif ext == 'bz2' and filepath:match('%.tar%.bz2$') then
		return M.list_tar(filepath)
	elseif ext == 'xz' and filepath:match('%.tar%.xz$') then
		return M.list_tar(filepath)
	end
	return nil, 'unsupported format: ' .. ext
end

--- Formata entries para exibicao em buffer.
--- @param entries ArchiveEntry[]
--- @return string[] lines
--- @return table[] highlights {line, col_start, col_end, hl_group}
function M.format(entries)
	local lines = {}
	local highlights = {}
	local suspicious_count = 0

	for _, entry in ipairs(entries) do
		if entry.suspicious then
			suspicious_count = suspicious_count + 1
		end
	end

	if suspicious_count > 0 then
		table.insert(lines, string.format('  ⚠ %d suspicious path(s) detected', suspicious_count))
		table.insert(highlights, { #lines - 1, 0, -1, 'DiagnosticWarn' })
		table.insert(lines, '')
	end

	for _, entry in ipairs(entries) do
		local icon = '  '
		if entry.type == 'directory' then
			icon = '  '
		elseif entry.type == 'symlink' then
			icon = '  '
		end

		local size_str = ''
		if entry.size then
			if entry.size >= 1048576 then
				size_str = string.format('%.1fM', entry.size / 1048576)
			elseif entry.size >= 1024 then
				size_str = string.format('%.1fK', entry.size / 1024)
			else
				size_str = tostring(entry.size) .. 'B'
			end
		end

		local line = string.format('%s %s  %6s  %s', icon, entry.path, size_str, entry.date or '')
		table.insert(lines, line)

		if entry.suspicious then
			table.insert(highlights, { #lines - 1, 0, -1, 'DiagnosticError' })
		elseif entry.type == 'directory' then
			table.insert(highlights, { #lines - 1, 0, #icon + #entry.path + 1, 'Directory' })
		end
	end

	return lines, highlights
end

return M
