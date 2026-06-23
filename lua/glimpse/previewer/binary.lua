--- Previewer for binaries (file + hexdump).
--- Requires `file(1)` and `xxd(1)` on PATH; if either is missing, it fails safely.
local M = {}
local float = require('glimpse.float')
local preview_cache = require('glimpse.preview_cache')

local MAX_HEXDUMP_BYTES = 256

local inspect_cache = {}

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

local function _cache_key(filepath, stat)
	if not stat then
		return filepath .. ':missing'
	end
	local mtime = stat.mtime or {}
	return table.concat({ filepath, stat.size or 0, mtime.sec or 0, mtime.nsec or 0 }, ':')
end

local function _inspect(filepath)
	local stat = vim.uv.fs_stat(filepath)
	if not stat then
		return nil, 'file not found'
	end

	local key = _cache_key(filepath, stat)
	local cached = inspect_cache[key]
	if cached then
		return cached
	end

	local desc, err = _run({ 'file', '-b', filepath })
	if not desc then
		return nil, err or 'cannot inspect file type'
	end

	local encoding, encoding_err = _run({ 'file', '-b', '--mime-encoding', filepath })
	if not encoding then
		return nil, encoding_err or 'cannot inspect file encoding'
	end

	local info = {
		desc = desc,
		encoding = encoding,
		is_binary = encoding == 'binary',
	}
	inspect_cache[key] = info
	return info
end

local function _missing_tools()
	return vim.fn.executable('file') == 0 or vim.fn.executable('xxd') == 0
end

local function _is_extensionless(filepath)
	local basename = vim.fn.fnamemodify(filepath, ':t')
	local stripped = basename:gsub('^%.', '')
	return not stripped:find('.', 1, true)
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

local function _preview_data(filepath)
	return preview_cache.memoize(filepath, 'binary', function()
		if vim.fn.executable('file') == 0 then
			return nil, nil, 'file not found'
		end

		local info, err = _inspect(filepath)
		if not info then
			return nil, nil, err
		end

		if not info.is_binary then
			return nil, nil, 'not a binary file'
		end

		if vim.fn.executable('xxd') == 0 then
			return nil, nil, 'xxd not found'
		end

		local dump, dump_err = _run({ 'xxd', '-l', tostring(MAX_HEXDUMP_BYTES), filepath })
		if not dump then
			return nil, nil, dump_err or 'cannot build hexdump'
		end

		local lines = _buf_lines(filepath, info.desc, dump)
		return lines, nil
	end)
end

function M.is_binary(filepath)
	if not filepath or filepath == '' then
		return false
	end

	local info, err = _inspect(filepath)
	if not info then
		vim.notify('[glimpse] ' .. (err or 'cannot inspect file type'), vim.log.levels.WARN)
		return false
	end

	return info.is_binary
end

function M.is_extensionless(filepath)
	if not filepath or filepath == '' then
		return false
	end
	return _is_extensionless(filepath)
end

function M.should_preview(filepath)
	return M.is_binary(filepath)
end

function M.can_preview(filepath)
	if _missing_tools() then
		return false
	end

	local info = _inspect(filepath)
	if not info then
		return false
	end

	return info.is_binary
end

function M.show(filepath, opts)
	local lines, _, err = _preview_data(filepath)
	if not lines then
		vim.notify('[glimpse] ' .. (err or 'cannot inspect file type'), vim.log.levels.WARN)
		return false
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].bufhidden = 'wipe'
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = 'glimpse_binary'

	local win = float.open(buf, {
		kind = 'binary',
		title = ' Binary Preview ',
		max_width = 100,
		max_height = math.max(#lines, 8),
		min_width = 40,
		min_height = 8,
		window = opts and opts.window,
	})

	vim.wo[win].wrap = false
	local config = require('glimpse').get_config()
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
	return true
end

M.preview = M.show
M.preview_data = _preview_data

return M
