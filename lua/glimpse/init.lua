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
	if config.integrations.telescope then
		require('glimpse.integrations.telescope').setup()
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
--- Resolve o previewer adequado para o tipo de arquivo.
--- @param filepath string
--- @return table|nil previewer
--- @return table|nil safety_opts
local function resolve_previewer(filepath)
	if util.is_archive(filepath) then
		return require('glimpse.previewer.archive'), { max_size = 0 }
	end
	if util.is_sqlite(filepath) then
		return require('glimpse.previewer.sqlite'), { max_size = 0 }
	end
	if util.is_key(filepath) then
		return require('glimpse.previewer.key'), { max_size = config.max_file_size }
	end
	if util.is_font(filepath) then
		return require('glimpse.previewer.font'), { max_size = config.max_file_size }
	end
	if util.is_image(filepath) then
		return require('glimpse.previewer.image'), { max_size = config.max_file_size }
	end
	return nil
end

--- Exibe arquivo (escolhe previewer automaticamente).
---@param filepath string Caminho absoluto do arquivo
function M.show(filepath)
	local previewer, safety_opts = resolve_previewer(filepath)
	if not previewer then
		vim.notify('[glimpse] not previewable: ' .. filepath, vim.log.levels.WARN)
		return
	end
	local safe, reason = safety.check(filepath, safety_opts)
	if not safe then
		vim.notify('[glimpse] ' .. reason .. ': ' .. filepath, vim.log.levels.WARN)
		return
	end
	previewer.show(filepath)
end

--- Preview rapido (reutiliza janela existente ou abre float).
---@param filepath string Caminho absoluto do arquivo
function M.preview(filepath)
	local previewer, safety_opts = resolve_previewer(filepath)
	if not previewer then
		return
	end
	local safe, _ = safety.check(filepath, safety_opts)
	if not safe then
		return
	end
	previewer.preview(filepath)
end

--- Exibe conteudo de um archive num buffer flutuante.
---@param filepath string
---@private
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
