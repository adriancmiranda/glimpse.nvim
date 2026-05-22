--- Previewer para certificados X.509 (.pem, .crt).
local M = {}

local function _run_openssl(filepath)
	if vim.fn.executable('openssl') == 0 then
		return nil, 'openssl not found'
	end

	local output = vim.fn.system({
		'openssl',
		'x509',
		'-noout',
		'-text',
		'-fingerprint',
		'-sha256',
		'-in',
		filepath,
	})
	if vim.v.shell_error ~= 0 then
		return nil, 'openssl x509 failed'
	end

	return output
end

local function _parse_output(output)
	local lines = {}
	local in_subject_public_key = false

	for line in output:gmatch('[^\n]+') do
		local subject = line:match('^%s*Subject:%s*(.+)$')
		if subject then
			table.insert(lines, 'Subject: ' .. subject)
		else
			local issuer = line:match('^%s*Issuer:%s*(.+)$')
			if issuer then
				table.insert(lines, 'Issuer: ' .. issuer)
			else
				local not_before = line:match('^%s*Not Before:%s*(.+)$')
				if not_before then
					table.insert(lines, 'Valid From: ' .. not_before)
				else
					local not_after = line:match('^%s*Not After :%s*(.+)$')
					if not_after then
						table.insert(lines, 'Valid Until: ' .. not_after)
					else
						local fingerprint = line:match('^%s*SHA256 Fingerprint%s*=%s*(.+)$')
						if fingerprint then
							table.insert(lines, 'SHA256 Fingerprint: ' .. fingerprint)
						elseif line:match('^%s*X509v3 Subject Alternative Name:') then
							table.insert(lines, '')
							table.insert(lines, 'Subject Alternative Name:')
						elseif line:match('^%s*Subject Public Key Info:') then
							in_subject_public_key = true
						elseif in_subject_public_key then
							local algorithm = line:match('^%s*Public Key Algorithm:%s*(.+)$')
							if algorithm then
								table.insert(lines, 'Public Key Algorithm: ' .. algorithm)
							end
						end
					end
				end
			end
		end
	end

	return lines
end

--- Exibe info do certificado num float.
--- @param filepath string
function M.show(filepath)
	local output, err = _run_openssl(filepath)
	if not output then
		vim.notify('[glimpse] ' .. (err or 'failed to read certificate'), vim.log.levels.WARN)
		return
	end

	local lines = _parse_output(output)
	if #lines == 0 then
		vim.notify('[glimpse] could not parse certificate metadata: ' .. filepath, vim.log.levels.WARN)
		return
	end

	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_cert'

	local width = math.min(90, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Certificate ',
		title_pos = 'center',
	})

	local config = require('glimpse').get_config()
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

M.preview = M.show

return M
