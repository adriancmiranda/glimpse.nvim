local M = {}

--- Try to convert a string to valid UTF-8 using an encoding heuristic.
--- Tries, in order: UTF-8 (already valid), CP1252, Latin-1.
--- @param str string
--- @return string
local function ensure_utf8(str)
	if not str:match('[\128-\255]') then
		return str
	end
	-- Check whether it is already valid UTF-8
	local i = 1
	while i <= #str do
		local b = str:byte(i)
		if b < 0x80 then
			i = i + 1
		elseif b >= 0xC2 and b <= 0xDF and i + 1 <= #str and str:byte(i + 1) >= 0x80 and str:byte(i + 1) <= 0xBF then
			i = i + 2
		elseif b >= 0xE0 and b <= 0xEF and i + 2 <= #str and str:byte(i + 1) >= 0x80 and str:byte(i + 2) >= 0x80 then
			i = i + 3
		else
			break
		end
	end
	if i > #str then
		return str
	end
	-- Tenta CP1252
	local cp1252 = vim.iconv(str, 'CP1252', 'UTF-8')
	if cp1252 and #cp1252 > 0 and not cp1252:match('\239\191\189') then
		return cp1252
	end
	-- Fallback: Latin-1
	local latin1 = vim.iconv(str, 'ISO-8859-1', 'UTF-8')
	if latin1 and #latin1 > 0 then
		return latin1
	end
	return str
end

--- @class ArchiveEntry
--- @field path string
--- @field size number|nil
--- @field date string|nil
--- @field type 'file'|'directory'|'symlink'
--- @field suspicious boolean

--- Detect suspicious paths (traversal, absolute paths, symlinks).
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

--- Parse `zipinfo` output with details.
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
	-- macOS zipinfo uses '+' as an escape for non-ASCII bytes (Latin-1).
	-- Remove '+' and convert the following byte from Latin-1 to UTF-8.
	if vim.fn.has('mac') == 1 then
		output = output:gsub('%+(.)', function(byte)
			local b = byte:byte()
			if b >= 0x80 then
				-- Convert a Latin-1 byte to UTF-8 (2 bytes)
				if b < 0xC0 then
					return string.char(0xC2, b)
				else
					return string.char(0xC3, b - 0x40)
				end
			end
			return '+' .. byte
		end)
	end
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
					path = ensure_utf8(path),
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

--- Parse `tar tf` output.
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
				path = ensure_utf8(path),
				size = tonumber(size),
				date = date .. ' ' .. time,
				type = entry_type,
				suspicious = is_suspicious(path),
			})
		end
	end
	return entries
end

--- List archive contents (detect format by extension).
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

--- Format entries for display in a buffer.
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
		table.insert(lines, string.format('⚠ %d suspicious path(s) detected', suspicious_count))
		table.insert(highlights, { #lines - 1, 0, -1, 'DiagnosticWarn' })
		table.insert(lines, '')
	end

	-- First pass: compute widths
	local max_path_width = 0
	local max_size_width = 0
	local prepared = {}
	for _, entry in ipairs(entries) do
		local icon
		local ok, devicons = pcall(require, 'nvim-web-devicons')
		if ok then
			local ext = entry.path:match('%.([^./]+)$')
			if entry.type == 'directory' then
				icon = devicons.get_icon(entry.path, nil, { default = true }) or ''
			else
				icon = devicons.get_icon(entry.path, ext, { default = true }) or ''
			end
		else
			if entry.type == 'directory' then
				icon = '\u{f4d3}'
			elseif entry.type == 'symlink' then
				icon = '\u{f0c1}'
			else
				icon = '\u{f4a5}'
			end
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

		local display = icon .. ' ' .. entry.path
		local w = vim.api.nvim_strwidth(display)
		if w > max_path_width then
			max_path_width = w
		end
		if #size_str > max_size_width then
			max_size_width = #size_str
		end
		table.insert(prepared, { entry = entry, display = display, width = w, size = size_str })
	end

	-- Second pass: generate aligned lines
	for _, p in ipairs(prepared) do
		local pad = string.rep(' ', max_path_width - p.width)
		local size_pad = string.rep(' ', max_size_width - #p.size)
		local line = p.display .. pad .. '  ' .. size_pad .. p.size .. '  ' .. (p.entry.date or '')
		table.insert(lines, line)

		if p.entry.suspicious then
			table.insert(highlights, { #lines - 1, 0, -1, 'DiagnosticError' })
		elseif p.entry.type == 'directory' then
			table.insert(highlights, { #lines - 1, 0, #p.display, 'Directory' })
		end
	end

	return lines, highlights
end

--- Build an archive summary for quick preview.
--- @param entries ArchiveEntry[]
--- @param filepath string
--- @return string[] lines
--- @return table[] highlights
function M.summary(entries, filepath)
	local lines = {}
	local highlights = {}

	-- Counters
	local total_size = 0
	local file_count = 0
	local dir_count = 0
	local suspicious_count = 0
	local extensions = {}
	local oldest, newest = nil, nil

	for _, entry in ipairs(entries) do
		if entry.type == 'file' then
			file_count = file_count + 1
		elseif entry.type == 'directory' then
			dir_count = dir_count + 1
		end
		if entry.size then
			total_size = total_size + entry.size
		end
		if entry.suspicious then
			suspicious_count = suspicious_count + 1
		end
		if entry.date then
			if not oldest or entry.date < oldest then
				oldest = entry.date
			end
			if not newest or entry.date > newest then
				newest = entry.date
			end
		end
		local ext = (entry.path:match('%.([^./]+)$') or ''):lower()
		if ext ~= '' and entry.type == 'file' then
			extensions[ext] = (extensions[ext] or 0) + 1
		end
	end

	-- Warnings
	if suspicious_count > 0 then
		table.insert(lines, string.format('⚠ %d suspicious path(s) detected', suspicious_count))
		table.insert(highlights, { #lines - 1, 0, -1, 'DiagnosticWarn' })
		table.insert(lines, '')
	end

	-- General info
	local size_str
	if total_size >= 1048576 then
		size_str = string.format('%.1f MB', total_size / 1048576)
	elseif total_size >= 1024 then
		size_str = string.format('%.1f KB', total_size / 1024)
	else
		size_str = total_size .. ' B'
	end

	table.insert(lines, string.format('  Files: %d', file_count))
	table.insert(lines, string.format('  Directories: %d', dir_count))
	table.insert(lines, string.format('  Total size: %s (uncompressed)', size_str))
	if oldest then
		table.insert(lines, string.format('  Oldest: %s', oldest))
	end
	if newest then
		table.insert(lines, string.format('  Newest: %s', newest))
	end

	-- File stats on disk
	local stat = vim.uv.fs_stat(filepath)
	if stat then
		local disk_size
		if stat.size >= 1048576 then
			disk_size = string.format('%.1f MB', stat.size / 1048576)
		elseif stat.size >= 1024 then
			disk_size = string.format('%.1f KB', stat.size / 1024)
		else
			disk_size = stat.size .. ' B'
		end
		table.insert(lines, string.format('  Archive size: %s', disk_size))
		table.insert(lines, string.format('  Modified: %s', os.date('%Y-%m-%d %H:%M', stat.mtime.sec)))
	end

	-- Top extensions
	local sorted_ext = {}
	for ext, count in pairs(extensions) do
		table.insert(sorted_ext, { ext = ext, count = count })
	end
	table.sort(sorted_ext, function(a, b)
		return a.count > b.count
	end)
	if #sorted_ext > 0 then
		table.insert(lines, '')
		table.insert(lines, '  Extensions:')
		table.insert(highlights, { #lines - 1, 2, 13, 'Identifier' })
		for i = 1, math.min(5, #sorted_ext) do
			table.insert(lines, string.format('    .%s (%d)', sorted_ext[i].ext, sorted_ext[i].count))
		end
	end

	-- Top 5 largest files
	local by_size = {}
	for _, entry in ipairs(entries) do
		if entry.type == 'file' and entry.size and entry.size > 0 then
			table.insert(by_size, entry)
		end
	end
	table.sort(by_size, function(a, b)
		return (a.size or 0) > (b.size or 0)
	end)
	if #by_size > 0 then
		table.insert(lines, '')
		table.insert(lines, '  Largest files:')
		table.insert(highlights, { #lines - 1, 2, 16, 'Identifier' })
		for i = 1, math.min(5, #by_size) do
			local e = by_size[i]
			local s
			if e.size >= 1048576 then
				s = string.format('%.1fM', e.size / 1048576)
			elseif e.size >= 1024 then
				s = string.format('%.1fK', e.size / 1024)
			else
				s = e.size .. 'B'
			end
			table.insert(lines, string.format('    %s  %s', s, e.path))
		end
	end

	return lines, highlights
end

return M
