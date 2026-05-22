--- Integração com Telescope para previews de imagens e vídeos.

local M = {}

local _timer = nil

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

--- Substituto de buffer_previewer_maker do Telescope com suporte a imagens e vídeos.
--- Arquivos que não são mídia usam o previewer padrão do Telescope.
---@param filepath string
---@param bufnr integer
---@param opts? table
function M.buffer_previewer_maker(filepath, bufnr, opts)
	opts = opts or {}

	local util = require('glimpse.util')
	local is_image = util.is_image(filepath)
	local is_video = util.is_video(filepath)
	if not is_image and not is_video then
		_fallback_buffer_previewer(filepath, bufnr, opts)
		return
	end

	if _timer then
		_timer:stop()
		_timer:close()
		_timer = nil
	end

	_timer = vim.uv.new_timer()
	if not _timer then
		return
	end

	local winid = (opts.winid and opts.winid ~= -1) and opts.winid or vim.fn.bufwinid(bufnr)
	_timer:start(
		100,
		0,
		vim.schedule_wrap(function()
			if _timer then
				_timer:close()
				_timer = nil
			end
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local win = (winid and winid ~= -1) and winid or vim.fn.bufwinid(bufnr)
			if is_image then
				require('glimpse.renderer').render(bufnr, filepath, { winid = win })
				return
			end

			require('glimpse.thumbnail').extract_async(filepath, function(thumb)
				if thumb and vim.api.nvim_buf_is_valid(bufnr) then
					require('glimpse.renderer').render(bufnr, thumb, { winid = win })
				end
			end)
		end)
	)
end

--- Cria um previewer do Telescope com suporte a imagens e vídeos.
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

--- Configura a integração com Telescope.
--- Por padrão, aplica o previewer apenas ao picker `find_files`.
---@param opts? boolean|{ enable?: boolean, pickers?: string|string[]|table, previewer?: table, previewer_opts?: table }
function M.setup(opts)
	if opts == false then
		return
	end
	if opts == true or opts == nil then
		opts = {}
	end
	if opts.enable == false then
		return
	end
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
