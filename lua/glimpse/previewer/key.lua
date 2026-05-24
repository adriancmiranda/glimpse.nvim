--- Previewer para chaves GPG e SSH.
local M = {}
local float = require('glimpse.float')

local function _render_output(output, prefix)
	local lines = {}
	for line in output:gmatch('[^\n]+') do
		table.insert(lines, (prefix or '') .. line)
	end
	return lines
end

local function _render_packets(output)
	local lines = { '⚠ encrypted GPG file; showing packet metadata only', '' }
	for line in output:gmatch('[^\n]+') do
		if line:match('^gpg:%s+encrypted with') or not line:match('^gpg:') then
			table.insert(lines, '  ' .. line)
		end
	end
	return lines
end

--- Extrai informacoes de uma chave SSH.
--- @param filepath string
--- @return string[]|nil lines
--- @return string|nil err
local function query_ssh(filepath)
	if vim.fn.executable('ssh-keygen') == 0 then
		return nil, 'ssh-keygen not found'
	end
	local output = vim.fn.system({ 'ssh-keygen', '-l', '-f', filepath })
	if vim.v.shell_error ~= 0 then
		return nil, 'ssh-keygen failed'
	end
	local bits, fingerprint, comment, type = output:match('(%d+)%s+(%S+)%s+(.-)%s+%((%S+)%)')
	if not fingerprint then
		return nil, 'could not parse key'
	end
	local lines = {
		'Type: ' .. type,
		'Bits: ' .. bits,
		'Fingerprint: ' .. fingerprint,
		'Comment: ' .. comment,
	}
	local stat = vim.uv.fs_stat(filepath)
	if stat then
		table.insert(lines, 'Created: ' .. os.date('%Y-%m-%d %H:%M', stat.birthtime.sec))
		if stat.mtime.sec ~= stat.birthtime.sec then
			table.insert(lines, '')
			table.insert(lines, '⚠ File modified after creation (mtime != birthtime)')
		end
	end
	return lines
end

--- Extrai informacoes de uma chave GPG.
--- @param filepath string
--- @return string[]|nil lines
--- @return string|nil err
local function query_gpg(filepath)
	if vim.fn.executable('gpg') == 0 then
		return nil, 'gpg not found'
	end
	local output = vim.fn.system({ 'gpg', '--batch', '--no-tty', '--show-keys', '--keyid-format', 'long', filepath })
	if output and output:match('%S') then
		return _render_output(output, '  ')
	end

	local packets = vim.fn.system({ 'gpg', '--batch', '--no-tty', '--list-packets', filepath })
	if packets and packets:match('%S') then
		return _render_packets(packets)
	end

	if vim.v.shell_error ~= 0 then
		return nil, 'gpg failed'
	end

	return nil, 'empty gpg output'
end

--- Detecta se e SSH ou GPG e retorna info.
--- @param filepath string
--- @return string[]|nil lines
--- @return string|nil err
local function query(filepath)
	-- Tenta SSH primeiro (mais rapido)
	local content = vim.fn.readfile(filepath, '', 3)
	if not content or #content == 0 then
		return nil, 'empty file'
	end
	local first_line = content[1] or ''
	if first_line:match('^ssh%-') or first_line:match('^ecdsa%-') or first_line:match('^%-%-%-%-%-BEGIN.*KEY') then
		if first_line:match('PGP') or first_line:match('GPG') then
			return query_gpg(filepath)
		end
		return query_ssh(filepath)
	end
	-- Tenta GPG
	return query_gpg(filepath)
end

--- Exibe info da chave num float.
--- @param filepath string
function M.show(filepath)
	local config = require('glimpse').get_config()
	local lines, err = query(filepath)
	if not lines then
		vim.notify('[glimpse] ' .. (err or 'failed to read key'), vim.log.levels.WARN)
		return
	end

	local header = string.format('\u{f43d} %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_key'

	-- Highlight no warning se existir
	local ns = vim.api.nvim_create_namespace('glimpse_key')
	for i, line in ipairs(lines) do
		if line:match('^⚠') then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				end_col = #line,
				hl_group = 'DiagnosticWarn',
			})
		end
	end

	float.open(buf, {
		title = ' Key Info ',
		max_width = 70,
		max_height = #lines,
	})

	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

M.preview = M.show

return M
