--- Telescope integration for all Glimpse previews.

local M = {}

local _timer = nil
local _request_ids = {}
local _config = {}

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

local function _lfs_preview_lines(filepath)
	local util = require('glimpse.util')
	local pointer = util.parse_git_lfs_pointer(filepath)
	if not pointer then
		return {
			'[glimpse] Git LFS pointer detected',
			'tip: run git lfs pull in the repository that owns this file',
		},
			'glimpse_warning'
	end

	return {
		'[glimpse] Git LFS pointer',
		'oid sha256:' .. pointer.oid,
		'size ' .. tostring(pointer.size) .. ' bytes',
		'tip: run git lfs pull in the repository that owns this file',
	},
		'glimpse_warning'
end

local function _set_text_preview(bufnr, lines, highlights, filetype)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

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

local function _show_lfs_warning(bufnr, filepath)
	local lines, filetype = _lfs_preview_lines(filepath)
	_set_text_preview(bufnr, lines, nil, filetype)
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
		if glimpse.is_git_lfs_pointer and glimpse.is_git_lfs_pointer(filepath) then
			_show_lfs_warning(bufnr, filepath)
			return
		end
		require('glimpse.renderer').render(bufnr, filepath, { winid = win })
		return
	end

	if kind == 'video' then
		require('glimpse.thumbnail').extract_async(filepath, function(thumb)
			if thumb and vim.api.nvim_buf_is_valid(bufnr) and _request_ids[bufnr] == request_id then
				require('glimpse.renderer').render(bufnr, thumb, { winid = win })
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

	if _timer then
		_timer:stop()
		_timer:close()
		_timer = nil
	end

	local request_id = tostring(vim.uv.hrtime()) .. ':' .. tostring(bufnr)
	_request_ids[bufnr] = request_id

	_timer = vim.uv.new_timer()
	if not _timer then
		return
	end

	_timer:start(
		100,
		0,
		vim.schedule_wrap(function()
			if _timer then
				_timer:close()
				_timer = nil
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
			return from_entry.path(entry, false, false)
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
		_config = {}
		return
	end
	if opts == true or opts == nil then
		opts = {}
	end
	if opts.enable == false then
		_config = {}
		return
	end
	_config = vim.deepcopy(opts)
	opts.pickers = opts.pickers or { 'find_files' }

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
