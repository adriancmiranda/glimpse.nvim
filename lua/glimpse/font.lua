local M = {}

--- @class FontInfo
--- @field family string
--- @field style string
--- @field weight string
--- @field slant string
--- @field width string
--- @field file string

--- Extrai metadados de uma fonte usando fc-query.
--- @param filepath string
--- @return FontInfo|nil info
--- @return string|nil err
function M.query(filepath)
	if vim.fn.executable('fc-query') == 0 then
		return nil, 'fc-query not found'
	end
	local format = table.concat({
		'Family: %{family}',
		'Style: %{style}',
		'Weight: %{weight}',
		'Slant: %{slant}',
		'Width: %{width}',
	}, '\\n')
	local output = vim.fn.system({ 'fc-query', '--format', format .. '\\n', filepath })
	if vim.v.shell_error ~= 0 then
		return nil, 'fc-query failed'
	end

	local info = {}
	for line in output:gmatch('[^\n]+') do
		local key, value = line:match('^(%S+):%s*(.+)')
		if key then
			info[key:lower()] = value
		end
	end
	info.file = filepath

	if not info.family then
		return nil, 'could not parse font metadata'
	end

	return info
end

--- Formata info da fonte para exibicao.
--- @param info FontInfo
--- @return string[] lines
--- @return table[] highlights
function M.format(info)
	local lines = {}
	local highlights = {}

	local fields = {
		{ 'Family', info.family },
		{ 'Style', info.style },
		{ 'Weight', info.weight },
		{ 'Slant', info.slant == '0' and 'Normal' or 'Italic' },
		{ 'Width', info.width },
	}

	for _, field in ipairs(fields) do
		if field[2] and field[2] ~= '' then
			local line = string.format('  %s: %s', field[1], field[2])
			table.insert(lines, line)
			table.insert(highlights, { #lines - 1, 2, 2 + #field[1] + 1, 'Identifier' })
		end
	end

	table.insert(lines, '')
	table.insert(lines, '  Sample:')
	table.insert(highlights, { #lines - 1, 2, 9, 'Identifier' })
	table.insert(lines, '  ABCDEFGHIJKLMNOPQRSTUVWXYZ')
	table.insert(lines, '  abcdefghijklmnopqrstuvwxyz')
	table.insert(lines, '  0123456789 !@#$%&*()+-=[]{}')
	table.insert(lines, '  The quick brown fox jumps over the lazy dog')

	return lines, highlights
end

return M
