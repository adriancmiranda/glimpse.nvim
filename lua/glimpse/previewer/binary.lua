--- Previewer para binários (file + hexdump).
local M = {}

local MAX_HEXDUMP_BYTES = 256
local KNOWN_BINARY_EXTENSIONS = {
	bin = true,
	class = true,
	dll = true,
	elf = true,
	exe = true,
	o = true,
	so = true,
	wasm = true,
}

local function _run(args)
	if vim.system then
		local result = vim.system(args, { text = true }):wait()
		local stdout = vim.trim(result.stdout or '')
		local stderr = vim.trim(result.stderr or '')
		if result.code ~= 0 then
			return nil, stderr ~= '' and stderr or stdout
		end
		return stdout, nil
	end

	local output = vim.fn.system(args)
	if vim.v.shell_error ~= 0 then
		return nil, vim.trim(output)
	end
	return vim.trim(output), nil
end

local function _is_text(desc)
	local lower = (desc or ''):lower()
	return lower:find('text', 1, true) ~= nil or lower:find('empty', 1, true) ~= nil
end

local function _is_extensionless(filepath)
	local basename = vim.fn.fnamemodify(filepath, ':t')
	local stripped = basename:gsub('^%.', '')
	return not stripped:find('%.', 1, true)
end

local function _extension(filepath)
	return vim.fn.fnamemodify(filepath, ':e'):lower()
end

local function _buf_lines(filepath, desc, dump)
	local lines = {
		string.format('󰇄 %s', vim.fn.fnamemodify(filepath, ':t')),
		string.rep('─', math.min(vim.o.columns - 4, 80)),
		'file: ' .. desc,
		'',
	}

	for line in dump:gmatch('[^\n]+') do
		table.insert(lines, line)
	end

	return lines
end

function M.is_binary(filepath)
	if not filepath or filepath == '' then
		return false
	end

	local desc, err = _run({ 'file', '-b', filepath })
	if not desc then
		vim.notify('[glimpse] ' .. (err or 'cannot inspect file type'), vim.log.levels.WARN)
		return false
	end

	return not _is_text(desc)
end

function M.is_extensionless(filepath)
	if not filepath or filepath == '' then
		return false
	end
	return _is_extensionless(filepath)
end

function M.should_preview(filepath)
	if not filepath or filepath == '' then
		return false
	end

	if M.is_extensionless(filepath) then
		return true
	end

	if KNOWN_BINARY_EXTENSIONS[_extension(filepath)] then
		return true
	end

	local ok, ft = pcall(vim.filetype.match, { filename = filepath })
	if not ok then
		return false
	end

	return ft == nil or ft == ''
end

function M.can_preview(filepath)
	return M.should_preview(filepath) and M.is_binary(filepath)
end

function M.show(filepath)
	if not M.is_binary(filepath) then
		return false
	end

	if vim.fn.executable('xxd') == 0 then
		vim.notify('[glimpse] xxd not found', vim.log.levels.WARN)
		return false
	end

	local desc, desc_err = _run({ 'file', '-b', filepath })
	if not desc then
		vim.notify('[glimpse] ' .. (desc_err or 'cannot inspect file type'), vim.log.levels.WARN)
		return false
	end

	local dump, dump_err = _run({ 'xxd', '-l', tostring(MAX_HEXDUMP_BYTES), filepath })
	if not dump then
		vim.notify('[glimpse] ' .. (dump_err or 'cannot build hexdump'), vim.log.levels.WARN)
		return false
	end

	local lines = _buf_lines(filepath, desc, dump)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].bufhidden = 'wipe'
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = 'glimpse_binary'

	local width = math.max(40, math.min(100, vim.o.columns - 4))
	local height = math.max(8, math.min(math.max(#lines, 8), vim.o.lines - 4))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = 'minimal',
		border = 'rounded',
		title = ' Binary Preview ',
		title_pos = 'center',
	})

	vim.wo[win].wrap = false
	local config = require('glimpse').get_config()
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
	return true
end

M.preview = M.show

return M
