--- Telescope integration for all Glimpse previews.

local M = {}
local dir = require('glimpse.dir')

local _timers = {}
local _request_ids = {}
local _cleanup_windows = {}
local _cleanup_autocmds = {}
local _media_buffer_refs = {}
local _config = { follow_cwd = false }

local function _as_list(value)
	if value == nil or value == true then
		return { 'find_files' }
	end
	if type(value) == 'string' then
		return { value }
	end
	local islist = vim.islist or vim.tbl_islist
	if islist(value) then
		return value
	end

	local pickers = {}
	for picker, enabled in pairs(value) do
		if enabled then
			table.insert(pickers, picker)
		end
	end
	return pickers
end

local function _fallback_buffer_previewer(filepath, bufnr, opts)
	require('telescope.previewers').buffer_previewer_maker(filepath, bufnr, opts)
end

local function _kind_enabled(kind)
	return _config[kind] ~= false
end

local function _should_follow_cwd()
	return _config.follow_cwd == true
end

local function _buffer_name_for_entry(kind, filepath)
	local normalized = vim.uv.fs_realpath(filepath) or vim.fn.fnamemodify(filepath, ':p')
	return string.format('glimpse://telescope/media/%s/%s', kind, vim.fn.sha256(normalized))
end

local function _release_media_buffer(bufnr)
	local refs = _media_buffer_refs[bufnr]
	if refs == nil then
		return
	end

	refs = refs - 1
	if refs <= 0 then
		_media_buffer_refs[bufnr] = nil
		_request_ids[bufnr] = nil
		if _timers[bufnr] then
			_timers[bufnr]:stop()
			_timers[bufnr]:close()
			_timers[bufnr] = nil
		end
		pcall(require('glimpse.renderer').close, bufnr)
		return
	end

	_media_buffer_refs[bufnr] = refs
end

local function _normalize_lines(lines)
	local normalized = {}
	for _, line in ipairs(lines or {}) do
		if type(line) ~= 'string' then
			line = tostring(line)
		end
		local chunks = vim.split(line, '\n', { plain = true, trimempty = false })
		for _, chunk in ipairs(chunks) do
			table.insert(normalized, chunk)
		end
	end
	return normalized
end

local function _set_text_preview(bufnr, lines, highlights, filetype)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	pcall(require('glimpse.renderer').close, bufnr)
	lines = _normalize_lines(lines)

	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].modified = false
	vim.bo[bufnr].buftype = 'nofile'
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = filetype or 'glimpse_preview'

	if not highlights then
		return
	end

	local ns = vim.api.nvim_create_namespace('glimpse_telescope')
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	for _, hl in ipairs(highlights) do
		local row = hl[1]
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end
end

local function _attach_preview_cleanup(winid, bufnr)
	if not vim.api.nvim_win_is_valid(winid) or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local previous = _cleanup_windows[winid]
	if previous == bufnr then
		return
	end

	if previous and previous ~= bufnr then
		_release_media_buffer(previous)
	end

	_cleanup_windows[winid] = bufnr
	_media_buffer_refs[bufnr] = (_media_buffer_refs[bufnr] or 0) + 1

	if _cleanup_autocmds[winid] then
		return
	end

	_cleanup_autocmds[winid] = vim.api.nvim_create_autocmd('WinClosed', {
		pattern = tostring(winid),
		once = true,
		callback = function()
			local tracked_buf = _cleanup_windows[winid]
			_cleanup_windows[winid] = nil
			_cleanup_autocmds[winid] = nil
			if tracked_buf then
				_release_media_buffer(tracked_buf)
			end
		end,
	})
end
local function _render_preview(filepath, bufnr, opts, request_id)
	local glimpse = require('glimpse')
	local kind = glimpse.get_preview_kind(filepath)
	local win = (opts.winid and opts.winid ~= -1) and opts.winid or vim.fn.bufwinid(bufnr)

	if kind and not _kind_enabled(kind) then
		_fallback_buffer_previewer(filepath, bufnr, opts)
		return
	end

	if kind == 'image' then
		_attach_preview_cleanup(win, bufnr)
		require('glimpse.renderer').render(bufnr, filepath, {
			bufname = opts.bufname,
			winid = win,
		})
		if _should_follow_cwd() then
			dir.follow(filepath)
		end
		return
	end

	if kind == 'video' then
		if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		local tabnr = vim.api.nvim_win_get_tabpage(win)
		_attach_preview_cleanup(win, bufnr)
		require('glimpse.thumbnail').extract_async(filepath, function(thumb)
			if
				thumb
				and vim.api.nvim_win_is_valid(win)
				and vim.api.nvim_buf_is_valid(bufnr)
				and _request_ids[bufnr] == request_id
			then
				require('glimpse.renderer').render(bufnr, thumb, {
					bufname = opts.bufname,
					winid = win,
				})
				if
					_should_follow_cwd()
					and vim.api.nvim_tabpage_is_valid(tabnr)
					and vim.api.nvim_get_current_tabpage() == tabnr
				then
					dir.follow(filepath)
				end
			end
		end)
		return
	end

	local previewers = {
		archive = require('glimpse.previewer.archive'),
		sqlite = require('glimpse.previewer.sqlite'),
		font = require('glimpse.previewer.font'),
		cert = require('glimpse.previewer.cert'),
		key = require('glimpse.previewer.key'),
		binary = require('glimpse.previewer.binary'),
	}

	local previewer = kind and previewers[kind] or nil
	if not previewer or not previewer.preview_data then
		_fallback_buffer_previewer(filepath, bufnr, opts)
		return
	end

	local lines, highlights, err = previewer.preview_data(filepath)
	if not lines then
		_set_text_preview(bufnr, { '[glimpse] ' .. (err or 'failed to render preview') }, nil, 'glimpse_preview')
		return
	end

	_set_text_preview(bufnr, lines, highlights, 'glimpse_' .. kind)
end

--- Telescope's buffer_previewer_maker replacement with support for every Glimpse preview kind.
---@param filepath string
---@param bufnr integer
---@param opts? table
function M.buffer_previewer_maker(filepath, bufnr, opts)
	opts = opts or {}

	if not _timers[bufnr] then
		_timers[bufnr] = vim.uv.new_timer()
		if not _timers[bufnr] then
			return
		end
	else
		_timers[bufnr]:stop()
	end

	local request_id = tostring(vim.uv.hrtime()) .. ':' .. tostring(bufnr)
	_request_ids[bufnr] = request_id

	_timers[bufnr]:start(
		100,
		0,
		vim.schedule_wrap(function()
			local t = _timers[bufnr]
			if t then
				t:stop()
				t:close()
				_timers[bufnr] = nil
			end
			if not vim.api.nvim_buf_is_valid(bufnr) or _request_ids[bufnr] ~= request_id then
				return
			end
			_render_preview(filepath, bufnr, opts, request_id)
		end)
	)
end

--- Create a Telescope previewer with Glimpse support.
---@param opts? table
---@return table
function M.previewer(opts)
	opts = opts or {}
	local from_entry = require('telescope.from_entry')
	local previewers = require('telescope.previewers')

	return previewers.new_buffer_previewer({
		title = opts.title or 'File Preview',

		get_buffer_by_name = function(_, entry)
			local filepath = from_entry.path(entry, false, false)
			if not filepath or filepath == '' then
				return nil
			end
			local glimpse = require('glimpse')
			local kind = glimpse.get_preview_kind(filepath)
			if kind == 'image' or kind == 'video' then
				return _buffer_name_for_entry(kind, filepath)
			end
			return filepath
		end,

		define_preview = function(self, entry)
			local filepath = from_entry.path(entry, true, false)
			if not filepath or filepath == '' then
				return
			end

			M.buffer_previewer_maker(filepath, self.state.bufnr, {
				bufname = self.state.bufname,
				winid = self.state.winid,
				preview = opts.preview,
				file_encoding = opts.file_encoding,
			})
		end,
	})
end

local function _apply_to_pickers(config)
	local ok, telescope_config = pcall(require, 'telescope.config')
	if not ok then
		return
	end

	local pickers = _as_list(config.pickers)
	local picker_opts = {}
	for _, picker in ipairs(pickers) do
		local current = vim.deepcopy(telescope_config.pickers[picker] or {})
		current.previewer = config.previewer or M.previewer(config.previewer_opts)
		picker_opts[picker] = current
	end

	telescope_config.set_pickers(picker_opts)
end

--- Configure the Telescope integration.
--- By default, applies the previewer only to the `find_files` picker.
---@param opts? boolean|GlimpseTelescopeConfig
function M.setup(opts)
	if opts == false then
		_config = { follow_cwd = false }
		return
	end
	if opts == true or opts == nil then
		opts = {}
	end
	if opts.enable == false then
		_config = { follow_cwd = false }
		return
	end
	opts.pickers = opts.pickers or { 'find_files' }
	_config = vim.tbl_deep_extend('force', { follow_cwd = false }, opts)

	if package.loaded['telescope.config'] then
		_apply_to_pickers(opts)
		return
	end

	vim.api.nvim_create_autocmd('User', {
		pattern = 'LazyLoad',
		callback = function(ev)
			if ev.data == 'telescope.nvim' then
				_apply_to_pickers(opts)
				return true
			end
		end,
	})
end

return M
