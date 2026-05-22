--- Integração com Telescope: injeta buffer_previewer_maker para preview de imagens e vídeos.

local M = {}

local _timer = nil

--- Substituto de buffer_previewer_maker do Telescope com suporte a imagens e vídeos.
--- Inclui debounce de 100ms para evitar conversões durante navegação rápida.
M.buffer_previewer_maker = function(filepath, bufnr, opts)
	opts = opts or {}
	local util = require('glimpse.util')
	local is_img = util.is_image(filepath)
	local is_vid = util.is_video(filepath)
	if not is_img and not is_vid then
		require('telescope.previewers').buffer_previewer_maker(filepath, bufnr, opts)
		return
	end
	-- Captura winid agora: o Telescope passa opts.winid (self.state.winid) que é mais
	-- confiável do que bufwinid() chamado no interior do schedule_wrap, pois o buffer
	-- pode não ter janela associada naquele momento.
	local winid = (opts.winid and opts.winid ~= -1) and opts.winid or vim.fn.bufwinid(bufnr)
	-- Debounce: cancela conversão anterior se o usuário navegar rápido
	if _timer then
		_timer:stop()
		_timer:close()
		_timer = nil
	end
	local timer = vim.uv.new_timer()
	if not timer then
		return
	end
	_timer = timer
	timer:start(
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
			-- Resolve winid final: prefere o capturado em cima, cai de volta para bufwinid
			local win = (winid and winid ~= -1) and winid or vim.fn.bufwinid(bufnr)
			if is_img then
				require('glimpse.renderer').render(bufnr, filepath, { winid = win })
			else
				require('glimpse.thumbnail').extract_async(filepath, function(thumb)
					if not thumb or not vim.api.nvim_buf_is_valid(bufnr) then
						return
					end
					require('glimpse.renderer').render(bufnr, thumb, { winid = win })
				end)
			end
		end)
	)
end

--- Injeta buffer_previewer_maker nas configurações do Telescope.
local function inject()
	local ok, conf = pcall(require, 'telescope.config')
	if not ok then
		return
	end
	conf.values.buffer_previewer_maker = M.buffer_previewer_maker
end

--- Configura a integração com Telescope.
--- Injeta buffer_previewer_maker imediatamente se o Telescope já estiver carregado,
--- ou aguarda o evento LazyLoad para injetar após o carregamento.
function M.setup()
	if package.loaded['telescope.config'] then
		inject()
		return
	end
	-- Telescope ainda não carregou — aguarda via lazy.nvim
	vim.api.nvim_create_autocmd('User', {
		pattern = 'LazyLoad',
		callback = function(ev)
			if ev.data == 'telescope.nvim' then
				inject()
				return true -- remove este autocmd
			end
		end,
	})
end

return M
