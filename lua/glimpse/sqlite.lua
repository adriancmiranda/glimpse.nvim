local M = {}

--- @class SqliteTable
--- @field name string
--- @field sql string
--- @field columns string[]

--- Lista tabelas e schema de um arquivo SQLite.
--- @param filepath string
--- @return SqliteTable[]|nil tables
--- @return string|nil err
function M.list(filepath)
	if vim.fn.executable('sqlite3') == 0 then
		return nil, 'sqlite3 not found'
	end

	-- Lista tabelas
	local output = vim.fn.system({ 'sqlite3', filepath, '.tables' })
	if vim.v.shell_error ~= 0 then
		return nil, 'sqlite3 failed: ' .. (output or '')
	end

	local table_names = {}
	for name in output:gmatch('%S+') do
		table.insert(table_names, name)
	end

	if #table_names == 0 then
		return nil, 'no tables found'
	end

	-- Obtem colunas de cada tabela via PRAGMA
	local tables = {}
	for _, name in ipairs(table_names) do
		local info = vim.fn.system({ 'sqlite3', filepath, 'PRAGMA table_info(' .. name .. ');' })
		local columns = {}
		if vim.v.shell_error == 0 and info then
			for col_name in info:gmatch('[^\n]+') do
				local col = col_name:match('^%d+|([^|]+)|')
				if col then
					table.insert(columns, col)
				end
			end
		end
		table.insert(tables, {
			name = name,
			sql = '',
			columns = columns,
		})
	end

	return tables
end

--- Formata tabelas para exibicao em buffer.
--- @param tables SqliteTable[]
--- @return string[] lines
--- @return table[] highlights {line, col_start, col_end, hl_group}
function M.format(tables)
	local lines = {}
	local highlights = {}

	table.insert(lines, string.format('  %d table(s)', #tables))
	table.insert(highlights, { #lines - 1, 0, -1, 'Title' })
	table.insert(lines, '')

	for _, tbl in ipairs(tables) do
		local header = '  ' .. tbl.name
		table.insert(lines, header)
		table.insert(highlights, { #lines - 1, 0, #header, 'Function' })

		if #tbl.columns > 0 then
			table.insert(lines, '    (' .. table.concat(tbl.columns, ', ') .. ')')
		elseif tbl.sql ~= '' then
			-- Mostra o CREATE statement indentado
			for sql_line in tbl.sql:gmatch('[^\n]+') do
				table.insert(lines, '    ' .. sql_line)
			end
		end
		table.insert(lines, '')
	end

	return lines, highlights
end

return M
