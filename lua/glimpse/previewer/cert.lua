--- Previewer para certificados X.509 (.pem, .crt).
local M = {}

local MONTHS = {
	Jan = 1,
	Feb = 2,
	Mar = 3,
	Apr = 4,
	May = 5,
	Jun = 6,
	Jul = 7,
	Aug = 8,
	Sep = 9,
	Oct = 10,
	Nov = 11,
	Dec = 12,
}

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

local function _parse_openssl_date(date_str)
	local mon, day, hour, min, sec, year = date_str:match('^(%a+)%s+(%d%d?)%s+(%d%d):(%d%d):(%d%d)%s+(%d%d%d%d)%s+GMT$')
	if not mon then
		return nil
	end
	local local_ts = os.time({
		year = tonumber(year),
		month = MONTHS[mon],
		day = tonumber(day),
		hour = tonumber(hour),
		min = tonumber(min),
		sec = tonumber(sec),
	})
	if not local_ts then
		return nil
	end
	return local_ts + (local_ts - os.time(os.date('!*t', local_ts)))
end

local function _parse_output(output)
	local lines = {}
	local meta = {
		subject = nil,
		issuer = nil,
		not_before = nil,
		not_after = nil,
		signature_algorithm = nil,
		is_ca = false,
	}
	local in_subject_public_key = false
	local in_basic_constraints = false

	for line in output:gmatch('[^\n]+') do
		local subject = line:match('^%s*Subject:%s*(.+)$')
		if subject then
			meta.subject = vim.trim(subject)
			table.insert(lines, 'Subject: ' .. subject)
		else
			local issuer = line:match('^%s*Issuer:%s*(.+)$')
			if issuer then
				meta.issuer = vim.trim(issuer)
				table.insert(lines, 'Issuer: ' .. issuer)
			else
				local not_before = line:match('^%s*Not Before:%s*(.+)$')
				if not_before then
					meta.not_before = not_before
					table.insert(lines, 'Valid From: ' .. not_before)
				else
					local not_after = line:match('^%s*Not After :%s*(.+)$')
					if not_after then
						meta.not_after = not_after
						table.insert(lines, 'Valid Until: ' .. not_after)
					else
						local fingerprint = line:match('^%s*SHA256 Fingerprint%s*=%s*(.+)$')
						if fingerprint then
							table.insert(lines, 'SHA256 Fingerprint: ' .. fingerprint)
						else
							local signature_algorithm = line:match('^%s*Signature Algorithm:%s*(.+)$')
							if signature_algorithm and not meta.signature_algorithm then
								meta.signature_algorithm = signature_algorithm
								table.insert(lines, 'Signature Algorithm: ' .. signature_algorithm)
							elseif line:match('^%s*X509v3 Basic Constraints:') then
								in_basic_constraints = true
							elseif in_basic_constraints then
								if line:match('CA:%s*TRUE') then
									meta.is_ca = true
									table.insert(lines, 'Basic Constraints: CA:TRUE')
									in_basic_constraints = false
								elseif line:match('^%s*%S') then
									in_basic_constraints = false
								end
							end
							if line:match('^%s*X509v3 Subject Alternative Name:') then
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
	end

	local warnings = {}
	local now = os.time()
	local not_before_ts = meta.not_before and _parse_openssl_date(meta.not_before) or nil
	local not_after_ts = meta.not_after and _parse_openssl_date(meta.not_after) or nil

	if not_before_ts and now < not_before_ts then
		table.insert(warnings, 'certificate is not yet valid')
	end
	if not_after_ts and now > not_after_ts then
		table.insert(warnings, 'certificate is expired')
	end
	if meta.subject and meta.issuer and meta.subject == meta.issuer and not meta.is_ca then
		table.insert(warnings, 'certificate is self-signed')
	end
	if meta.signature_algorithm then
		local algo = meta.signature_algorithm:lower()
		if algo:find('sha1', 1, true) or algo:find('md5', 1, true) then
			table.insert(warnings, 'certificate uses a weak signature algorithm: ' .. meta.signature_algorithm)
		end
	end

	return lines, warnings
end

--- Exibe info do certificado num float.
--- @param filepath string
function M.show(filepath)
	local output, err = _run_openssl(filepath)
	if not output then
		vim.notify('[glimpse] ' .. (err or 'failed to read certificate'), vim.log.levels.WARN)
		return
	end

	local lines, warnings = _parse_output(output)
	if #lines == 0 then
		vim.notify('[glimpse] could not parse certificate metadata: ' .. filepath, vim.log.levels.WARN)
		return
	end

	if #warnings > 0 then
		for i = #warnings, 1, -1 do
			table.insert(lines, 1, '⚠ ' .. warnings[i])
		end
		table.insert(lines, 1 + #warnings, '')
	end

	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_cert'

	if #warnings > 0 then
		local ns = vim.api.nvim_create_namespace('glimpse_cert')
		for i, line in ipairs(lines) do
			if line:match('^⚠ ') then
				vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
					end_col = #line,
					hl_group = 'DiagnosticWarn',
				})
			end
		end
	end

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
