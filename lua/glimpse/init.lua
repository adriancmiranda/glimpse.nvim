---@brief [[
--- glimpse.nvim - Visualização de imagens inline no Neovim.
---
--- Renderiza imagens diretamente no terminal via Kitty Graphics Protocol,
--- com fallback para Sixel e painéis externos (WezTerm, iTerm, tmux).
---
--- Uso básico:
--- >lua
---   require('glimpse').setup()
--- <
---
--- Keymaps padrão (Oil.nvim):
---   `<leader>p` - Preview da imagem ao lado
---   `;`         - Abre imagem em nova aba
---   `q`         - Fecha buffer de imagem
---
--- Terminais suportados:
---   Kitty, Ghostty (inline), WezTerm (painel), iTerm2 (painel),
---   xterm/foot/mlterm (Sixel via tmux)
---@brief ]]

---@tag glimpse.nvim

--- @see credits https://github.com/folke/snacks.nvim (snacks.image)
--- @see source https://www.reddit.com/r/neovim/comments/1e1txpz/some_fun_with_oilnvim_and_wezterm_for_image/

--- Configuração do glimpse.nvim.
---@class GlimpseConfig
---@field strategy? 'auto'|'inline'|'pane' Método de renderização (default: 'auto')
---@field pane_position? 'right'|'bottom' Posição do painel externo (default: 'right')
---@field pane_size? number Tamanho do painel em percentual (default: 40)
---@field inline? GlimpseInlineConfig Opções para renderização inline
---@field keys? GlimpseKeysConfig Keymaps configuráveis
---@field debounce? GlimpseDebounceConfig Tempos de debounce em ms
---@field cell_size? GlimpseCellSizeConfig Pixels estimados por célula do terminal
---@field cache_dir? string Diretório para cache de imagens convertidas
---@field cache_max_age_days? number Dias para manter arquivos no cache (default: 7)
---@field max_file_size? number Tamanho maximo em bytes para processar (default: 50MB)
---@field loading_text? string Texto exibido durante carregamento
---@field formats? string[] Extensões de imagem suportadas
---@field integrations? GlimpseIntegrationsConfig Integrações com plugins

---@class GlimpseInlineConfig
---@field rerender_on_tab? boolean Re-renderiza ao voltar para aba com imagem (default: true)
---@field close_with_q? boolean Mapeia tecla para fechar buffer de imagem (default: true)

---@class GlimpseKeysConfig
---@field preview? string Keymap para preview no Oil (default: '<leader>p')
---@field open? string Keymap para abrir em aba no Oil (default: ';')
---@field close? string Keymap para fechar buffer de imagem (default: 'q')

---@class GlimpseDebounceConfig
---@field prefetch? number ms antes de pré-converter ao mover cursor (default: 200)
---@field resize? number ms antes de re-renderizar ao redimensionar (default: 100)

---@class GlimpseCellSizeConfig
---@field width? number Pixels estimados por coluna (default: 20)
---@field height? number Pixels estimados por linha (default: 40)

---@class GlimpseIntegrationsConfig
---@field oil? boolean Keymaps no Oil.nvim (default: true)
---@field neotree? boolean|{enable?:boolean, auto_preview?:boolean} NeoTree integration config
---@field telescope? boolean Preview no Telescope (default: true)

local detect = require('glimpse.detect')
local safety = require('glimpse.safety')
local util = require('glimpse.util')
local pane = require('glimpse.strategy.pane')
local inline = require('glimpse.strategy.inline')

---@class Glimpse
local M = {}

---@type GlimpseConfig
local config = {
	strategy = 'auto',
	pane_position = 'right',
	pane_size = 40,
	inline = {
		rerender_on_tab = true,
		close_with_q = true,
	},
	keys = {
		preview = '<leader>p',
		open = ';',
		close = 'q',
	},
	debounce = {
		prefetch = 200,
		resize = 100,
	},
	cell_size = {
		width = 20,
		height = 40,
	},
	cache_dir = vim.fn.stdpath('cache') .. '/glimpse',
	cache_max_age_days = 7,
	max_file_size = 50 * 1024 * 1024,
	loading_text = '  ⏳ Loading...',
	formats = {
		'.png',
		'.jpg',
		'.jpeg',
		'.gif',
		'.bmp',
		'.webp',
		'.avif',
		'.svg',
		'.pdf',
		'.pict',
	},
	integrations = {
		oil = true,
		neotree = {
			enable = false,
			auto_preview = true,
		},
		telescope = true,
	},
	video_formats = {
		'.mp4',
		'.mkv',
		'.avi',
		'.mov',
		'.webm',
		'.flv',
		'.wmv',
		'.m4v',
	},
	video_open = nil,
}

--- Configura o plugin.
---@param opts? GlimpseConfig Opções de configuração (merge com defaults)
function M.setup(opts)
	config = vim.tbl_deep_extend('force', config, opts or {})
	if M._should_use_inline() and config.inline.rerender_on_tab then
		inline.setup_autocmds()
	end
	if config.integrations.oil then
		require('glimpse.integrations.oil').setup()
	end
	local neotree = config.integrations.neotree
	if type(neotree) == 'table' and neotree.enable then
		require('glimpse.integrations.neotree').setup()
	elseif neotree == true then
		require('glimpse.integrations.neotree').setup()
	end
	-- Limpa cache antigo em background
	if config.cache_max_age_days and config.cache_max_age_days > 0 then
		vim.defer_fn(function()
			require('glimpse.cache').cleanup(config.cache_dir, config.cache_max_age_days)
		end, 0)
	end
end

---@private
function M._should_use_inline()
	if config.strategy == 'inline' then
		return true
	end
	if config.strategy == 'pane' then
		return false
	end
	return detect.supports_inline()
end

--- Exibe imagem (escolhe estratégia automaticamente).
---@param filepath string Caminho absoluto do arquivo de imagem
function M.show(filepath)
	if util.is_archive(filepath) then
		local safe, reason = safety.check(filepath, { max_size = 0 })
		if not safe then
			vim.notify('[glimpse] ' .. reason .. ': ' .. filepath, vim.log.levels.WARN)
			return
		end
		-- Abre no buffer atual
		local archive = require('glimpse.archive')
		local entries = archive.list(filepath)
		if entries then
			local lines, highlights = archive.format(entries)
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.bo[buf].modifiable = false
			vim.bo[buf].modified = false
			vim.bo[buf].buftype = 'nofile'
			vim.bo[buf].filetype = 'glimpse_archive'
			-- Aplica highlights
			local ns = vim.api.nvim_create_namespace('glimpse_archive')
			vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
			for _, hl in ipairs(highlights) do
				local row = hl[1]
				local col_end = hl[3]
				if col_end < 0 then
					col_end = #(lines[row + 1] or '')
				end
				vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
					end_col = col_end,
					hl_group = hl[4],
				})
			end
		end
		return
	end
	if util.is_sqlite(filepath) then
		local safe, reason = safety.check(filepath, { max_size = 0 })
		if not safe then
			vim.notify('[glimpse] ' .. reason .. ': ' .. filepath, vim.log.levels.WARN)
			return
		end
		M._show_sqlite(filepath)
		return
	end
	if util.is_font(filepath) then
		M._show_font_render(filepath)
		return
	end
	local safe, reason = safety.check(filepath, { max_size = config.max_file_size })
	if not safe then
		vim.notify('[glimpse] ' .. reason .. ': ' .. filepath, vim.log.levels.WARN)
		return
	end
	if not util.is_image(filepath) then
		vim.notify('[glimpse] not previewable: ' .. filepath, vim.log.levels.WARN)
		return
	end
	if M._should_use_inline() then
		inline.show(filepath)
	else
		pane.show(filepath, { position = config.pane_position, size = config.pane_size })
	end
end

--- Exibe imagem reutilizando janela existente (para navegação em exploradores).
---@param filepath string Caminho absoluto do arquivo
function M.preview(filepath)
	if util.is_archive(filepath) then
		local safe, _ = safety.check(filepath, { max_size = 0 })
		if not safe then
			return
		end
		M._preview_archive(filepath)
		return
	end
	if util.is_sqlite(filepath) then
		local safe, _ = safety.check(filepath, { max_size = 0 })
		if not safe then
			return
		end
		M._show_sqlite(filepath)
		return
	end
	if util.is_font(filepath) then
		M._show_font_metadata(filepath)
		return
	end
	local safe, _ = safety.check(filepath, { max_size = config.max_file_size })
	if not safe then
		return
	end
	if not util.is_image(filepath) then
		return
	end
	if M._should_use_inline() then
		inline.preview(filepath)
	else
		pane.show(filepath, { position = config.pane_position, size = config.pane_size })
	end
end

--- Exibe conteudo de um archive num buffer flutuante.
---@param filepath string
---@private
function M._show_archive(filepath)
	local archive = require('glimpse.archive')
	local entries, err = archive.list(filepath)
	if not entries then
		vim.notify('[glimpse] ' .. (err or 'failed to read archive'), vim.log.levels.WARN)
		return
	end
	local lines, highlights = archive.format(entries)

	-- Header
	local header = string.format('  %s (%d entries)', vim.fn.fnamemodify(filepath, ':t'), #entries)
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	-- Cria buffer flutuante
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_archive'

	-- Aplica highlights (offset +2 pelo header)
	local ns = vim.api.nvim_create_namespace('glimpse_archive')
	for _, hl in ipairs(highlights) do
		local row = hl[1] + 2
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end

	-- Abre float
	local width = math.min(80, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Archive ',
		title_pos = 'center',
	})

	-- Keymap para fechar
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

--- Exibe resumo de um archive num buffer flutuante (preview).
---@param filepath string
---@private
function M._preview_archive(filepath)
	local archive = require('glimpse.archive')
	local entries, err = archive.list(filepath)
	if not entries then
		vim.notify('[glimpse] ' .. (err or 'failed to read archive'), vim.log.levels.WARN)
		return
	end
	local lines, highlights = archive.summary(entries, filepath)

	-- Header
	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	-- Cria buffer flutuante
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_archive'

	-- Aplica highlights (offset +2 pelo header)
	local ns = vim.api.nvim_create_namespace('glimpse_archive_preview')
	for _, hl in ipairs(highlights) do
		local row = hl[1] + 2
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end

	-- Abre float
	local width = math.min(70, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Archive Summary ',
		title_pos = 'center',
	})

	-- Keymap para fechar
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

--- Exibe schema de um banco SQLite num buffer flutuante.
---@param filepath string
---@private
function M._show_sqlite(filepath)
	local sqlite = require('glimpse.sqlite')
	local tables, err = sqlite.list(filepath)
	if not tables then
		vim.notify('[glimpse] ' .. (err or 'failed to read database'), vim.log.levels.WARN)
		return
	end
	local lines, highlights = sqlite.format(tables)

	-- Header
	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	-- Cria buffer flutuante
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_sqlite'

	-- Aplica highlights (offset +2 pelo header)
	local ns = vim.api.nvim_create_namespace('glimpse_sqlite')
	for _, hl in ipairs(highlights) do
		local row = hl[1] + 2
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end

	-- Abre float
	local width = math.min(80, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' SQLite ',
		title_pos = 'center',
	})

	-- Keymap para fechar
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

--- Renderiza uma fonte como imagem inline.
---@param filepath string
---@private
function M._show_font_render(filepath)
	local font = require('glimpse.font')
	local info, err = font.query(filepath)
	if not info then
		vim.notify('[glimpse] ' .. (err or 'failed to read font'), vim.log.levels.WARN)
		return
	end

	if vim.fn.executable('magick') == 0 then
		-- Fallback para metadados se magick nao disponivel
		M._show_font_metadata(filepath)
		return
	end

	local cache_dir = config.cache_dir
	vim.fn.mkdir(cache_dir, 'p')
	local hash = vim.fn.sha256(filepath):sub(1, 12)
	local tmp = cache_dir .. '/font_' .. hash .. '.png'
	local sample = table.concat({
		info.family .. ' - ' .. (info.style or 'Regular'),
		'',
		'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
		'abcdefghijklmnopqrstuvwxyz',
		'0123456789 !@#$%&*()+-=[]{}',
		'',
		'The quick brown fox jumps over the lazy dog',
	}, '\\n')
	vim.fn.system({
		'magick',
		'-background',
		'#1a1b26',
		'-fill',
		'#c0caf5',
		'-font',
		filepath,
		'-pointsize',
		'42',
		'label:' .. sample,
		tmp,
	})
	if vim.v.shell_error == 0 and vim.uv.fs_stat(tmp) then
		if M._should_use_inline() then
			inline.show(tmp)
		else
			pane.show(tmp, { position = config.pane_position, size = config.pane_size })
		end
		return
	end

	-- Fallback
	M._show_font_metadata(filepath)
end

--- Exibe metadados de uma fonte num buffer flutuante.
---@param filepath string
---@private
function M._show_font_metadata(filepath)
	local font = require('glimpse.font')
	local info, err = font.query(filepath)
	if not info then
		vim.notify('[glimpse] ' .. (err or 'failed to read font'), vim.log.levels.WARN)
		return
	end

	local lines, highlights = font.format(info)

	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_font'

	local ns = vim.api.nvim_create_namespace('glimpse_font')
	for _, hl in ipairs(highlights) do
		local row = hl[1] + 2
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end

	local width = math.min(60, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Font ',
		title_pos = 'center',
	})

	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

--- Fecha preview ativo.
function M.close()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].filetype == 'image' then
		inline.close(buf)
	end
end

--- Verifica se o arquivo é uma imagem suportada.
---@param filepath string Caminho do arquivo
---@return boolean
M.is_image = util.is_image

--- Verifica se o arquivo é um vídeo suportado.
---@param filepath string Caminho do arquivo
---@return boolean
M.is_video = util.is_video

--- Verifica se o arquivo é previewable (imagem ou vídeo).
---@param filepath string Caminho do arquivo
---@return boolean
M.is_previewable = util.is_previewable

--- Retorna o terminal detectado.
---@return string|nil terminal 'wezterm'|'kitty'|'ghostty'|'iterm'|nil
M.get_terminal = detect.get_terminal

--- Retorna a configuração atual.
---@return GlimpseConfig
function M.get_config()
	return config
end

return M
