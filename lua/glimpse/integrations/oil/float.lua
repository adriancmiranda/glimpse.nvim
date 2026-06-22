local path = require('glimpse.integrations.oil.path')

local M = {}

local function refresh_source_image(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= 'image' then
		return
	end

	local renderer = require('glimpse.renderer')
	if renderer.has_placement(buf) then
		renderer.rerender(buf, { force = true })
	end
end

local function get_process_cwd()
	return vim.uv.cwd() or vim.fn.getcwd()
end

local function is_abs_path(pathname)
	return pathname:sub(1, 1) == '/' or pathname:match('^%a:[/\\]') ~= nil
end

local function startup_target()
	local argc = vim.fn.argc and vim.fn.argc() or 0
	if argc <= 0 then
		return nil
	end

	local ok, arg = pcall(vim.fn.argv, 0)
	if not ok or type(arg) ~= 'string' or arg == '' or arg == '.' then
		return nil
	end

	local cwd = get_process_cwd()
	if not is_abs_path(arg) then
		arg = vim.fs.joinpath(cwd, arg)
	end

	return vim.fs.normalize(arg)
end

local function current_buffer_selection()
	local current_buf = vim.api.nvim_get_current_buf()

	if vim.bo[current_buf].filetype == 'oil' then
		local ok, oil = pcall(require, 'oil')
		if ok then
			local oil_dir = oil.get_current_dir(current_buf)
			if oil_dir then
				return oil_dir, nil
			end
		end
	end

	local filepath = path.buffer_filepath(current_buf)
	if not filepath then
		return nil, nil
	end

	return vim.fs.dirname(filepath), vim.fs.basename(filepath)
end

local function set_cursor_to_entry(name)
	local oil = require('oil')
	local bufnr = vim.api.nvim_get_current_buf()
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	for lnum = 1, line_count do
		local entry = oil.get_entry_on_line and oil.get_entry_on_line(bufnr, lnum) or nil
		if entry and entry.name == name then
			local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ''
			local col = line:find(name, 1, true) or 1
			vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
			return
		end
	end
end

function M.resolve_float_dir()
	local current_dir, current_name = current_buffer_selection()
	if current_dir then
		return current_dir, current_name
	end

	local cwd = get_process_cwd()
	local target = startup_target()
	if not target then
		return cwd, nil
	end

	local stat = vim.uv.fs_stat(target)
	if stat and stat.type == 'directory' then
		return target, nil
	end

	return vim.fs.dirname(target) or cwd, nil
end

function M.open_float(opts)
	opts = opts or {}
	local oil = require('oil')
	local source_buf = vim.api.nvim_get_current_buf()
	local dirpath, cursor_name = M.resolve_float_dir()
	oil.open_float(dirpath, opts.oil_opts, function()
		if cursor_name then
			set_cursor_to_entry(cursor_name)
		end
		if opts.cb then
			opts.cb(dirpath, cursor_name)
		end
		refresh_source_image(source_buf)
	end)
end

function M.toggle_float(opts)
	opts = opts or {}
	local oil = require('oil')
	local source_buf = vim.api.nvim_get_current_buf()
	local dirpath, cursor_name = M.resolve_float_dir()
	oil.toggle_float(dirpath, opts.oil_opts, function()
		if cursor_name and vim.bo[vim.api.nvim_get_current_buf()].filetype == 'oil' then
			set_cursor_to_entry(cursor_name)
		end
		if opts.cb then
			opts.cb(dirpath, cursor_name)
		end
		refresh_source_image(source_buf)
	end)
end

return M
