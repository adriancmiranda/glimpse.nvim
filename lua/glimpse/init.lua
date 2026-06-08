---@brief [[
--- glimpse.nvim - Inline image preview for Neovim.
---
--- Renders images directly in the terminal via Kitty Graphics Protocol,
--- with fallback to Sixel and external panes (WezTerm, iTerm, tmux).
---
--- Basic usage:
--- >lua
---   require('glimpse').setup()
--- <
---
--- Default keymaps (Oil.nvim):
---   `<leader>p` - Preview image side by side (does not change cwd)
---   `;`         - Open image (may change cwd when configured)
---   `q`         - Close image buffer
---
--- Supported terminals:
---   Kitty, Ghostty (inline), WezTerm (pane), iTerm2 (pane),
---   xterm/foot/mlterm (Sixel via tmux)
---@brief ]]

---@tag glimpse.nvim

--- @see credits https://github.com/folke/snacks.nvim (snacks.image)
--- @see source https://www.reddit.com/r/neovim/comments/1e1txpz/some_fun_with_oilnvim_and_wezterm_for_image/

--- glimpse.nvim configuration.
---@class GlimpseConfig
---@field strategy? 'auto'|'inline'|'pane' Rendering method (default: 'auto')
---@field pane_position? 'right'|'bottom' External pane position (default: 'right')
---@field pane_size? number External pane size in percent (default: 40)
---@field inline? GlimpseInlineConfig Inline rendering options
---@field keys? GlimpseKeysConfig Configurable keymaps
---@field debounce? GlimpseDebounceConfig Debounce timings in ms
---@field cell_size? GlimpseCellSizeConfig Estimated terminal cell pixel size
---@field cache_dir? string Cache directory for converted images
---@field cache_max_age_days? number Days to keep cached files (default: 7)
---@field max_file_size? number Maximum bytes to process (default: 50MB)
---@field loading_text? string Text shown while loading
---@field formats? string[] Supported image extensions
---@field integrations? GlimpseIntegrationsConfig Plugin integrations

---@class GlimpseInlineConfig
---@field rerender_on_tab? boolean Re-render when returning to an image tab (default: true)
---@field close_with_q? boolean Map a key to close the image buffer (default: true)

---@class GlimpseOilConfig
---@field enable? boolean Keymaps in Oil.nvim (default: enabled)
---@field follow_cwd? boolean Follow image directories when opening with `;` in Oil (default: true)
---@field open? string|fun(filepath:string):integer? Open images in the current tab, a new tab,
---or custom logic returning the opened buffer (default: 'edit')

---@class GlimpseTelescopeConfig
---@field enable? boolean Preview in Telescope (default: enabled)
---@field pickers? string|string[]|table Telescope pickers that receive Glimpse previews
---@field follow_cwd? boolean Follow image directories when previewing in Telescope (default: false)
---@field previewer? table Custom Telescope previewer instance
---@field previewer_opts? table Options passed to the Glimpse previewer factory
---@field image? boolean Enable image previews (default: true)
---@field video? boolean Enable video previews (default: true)
---@field archive? boolean Enable archive previews (default: true)
---@field sqlite? boolean Enable SQLite previews (default: true)
---@field font? boolean Enable font previews (default: true)
---@field cert? boolean Enable certificate previews (default: true)
---@field key? boolean Enable key previews (default: true)
---@field binary? boolean Enable binary previews (default: true)

---@class GlimpseKeysConfig
---@field preview? string Keymap for preview in Oil (default: '<leader>p')
---@field open? string Keymap for opening an image in Oil (default: ';')
---@field close? string Keymap for closing the image buffer (default: 'q')

---@class GlimpseDebounceConfig
---@field prefetch? number ms before pre-converting on cursor move (default: 200)
---@field resize? number ms before re-rendering on resize (default: 100)

---@class GlimpseCellSizeConfig
---@field width? number Estimated pixels per column (default: 20)
---@field height? number Estimated pixels per row (default: 40)

---@class GlimpseIntegrationsConfig
---@field oil? boolean|GlimpseOilConfig Keymaps in Oil.nvim (default: true)
---@field neotree? boolean|{enable?:boolean, auto_preview?:boolean} NeoTree integration config
---@field telescope? boolean|GlimpseTelescopeConfig Preview in Telescope (default: true)

local detect = require('glimpse.detect')
local safety = require('glimpse.safety')
local util = require('glimpse.util')
local binary = require('glimpse.previewer.binary')
local inline = require('glimpse.strategy.inline')

---@class Glimpse
local M = {}

local function normalize_oil_config(oil)
	if oil == false then
		return { enable = false, follow_cwd = false }
	end
	if oil == true or oil == nil then
		return { enable = true, follow_cwd = true }
	end
	if type(oil) == 'table' then
		return vim.tbl_deep_extend('force', { enable = true, follow_cwd = true }, oil)
	end
	return { enable = true, follow_cwd = true }
end

local function normalize_telescope_config(telescope)
	if telescope == false then
		return { enable = false, follow_cwd = false }
	end
	if telescope == true or telescope == nil then
		return { enable = true, follow_cwd = false }
	end
	if type(telescope) == 'table' then
		return vim.tbl_deep_extend('force', { enable = true, follow_cwd = false }, telescope)
	end
	return { enable = true, follow_cwd = false }
end

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

--- Configure the plugin.
---@param opts? GlimpseConfig Configuration options (merged with defaults)
function M.setup(opts)
	config = vim.tbl_deep_extend('force', config, opts or {})
	config.integrations.oil = normalize_oil_config(config.integrations.oil)
	config.integrations.telescope = normalize_telescope_config(config.integrations.telescope)
	if M._should_use_inline() and config.inline.rerender_on_tab then
		inline.setup_autocmds()
	end
	if config.integrations.oil.enable ~= false then
		require('glimpse.integrations.oil').setup()
	end
	local neotree = config.integrations.neotree
	if type(neotree) == 'table' and neotree.enable then
		require('glimpse.integrations.neotree').setup()
	elseif neotree == true then
		require('glimpse.integrations.neotree').setup()
	end
	if config.integrations.telescope.enable ~= false then
		require('glimpse.integrations.telescope').setup(config.integrations.telescope)
	end
	-- Clean up old cache entries in the background
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

--- Show an image (selects the strategy automatically).
--- Resolve the appropriate previewer for the file type.
--- @param filepath string
--- @return table|nil previewer
--- @return table|nil safety_opts
--- @return string|nil kind
local function resolve_previewer(filepath)
	if util.is_image(filepath) and util.is_git_lfs_pointer(filepath) then
		return nil
	end
	if util.is_archive(filepath) then
		return require('glimpse.previewer.archive'), { max_size = 0 }, 'archive'
	end
	if util.is_sqlite(filepath) then
		return require('glimpse.previewer.sqlite'), { max_size = 0 }, 'sqlite'
	end
	if util.is_cert(filepath) then
		return require('glimpse.previewer.cert'), { max_size = config.max_file_size }, 'cert'
	end
	if util.is_key(filepath) then
		return require('glimpse.previewer.key'), { max_size = config.max_file_size }, 'key'
	end
	if util.is_font(filepath) then
		return require('glimpse.previewer.font'), { max_size = config.max_file_size }, 'font'
	end
	if util.is_video(filepath) then
		return require('glimpse.previewer.video'), { max_size = config.max_file_size }, 'video'
	end
	if util.is_image(filepath) then
		return require('glimpse.previewer.image'), { max_size = config.max_file_size }, 'image'
	end
	if binary.can_preview(filepath) then
		return binary, { max_size = 0 }, 'binary'
	end
	return nil
end

--- Return whether the file has a known previewer.
---@param filepath string Absolute file path
---@return boolean
function M.can_preview(filepath)
	return resolve_previewer(filepath) ~= nil
end

--- Return the preview kind that would be used for the file.
---@param filepath string Absolute file path
---@return string|nil kind
function M.get_preview_kind(filepath)
	local _, _, kind = resolve_previewer(filepath)
	return kind
end

--- Show a file (selects the previewer automatically).
---@param filepath string Absolute file path
function M.show(filepath)
	if util.is_image(filepath) and util.is_git_lfs_pointer(filepath) then
		return
	end

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

--- Quick preview (reuses an existing window or opens a float).
---@param filepath string Absolute file path
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

--- Show archive contents in a floating buffer.
---@param filepath string
---@private
--- Close the active preview.
function M.close()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].filetype == 'image' then
		inline.close(buf, true)
	end
end

--- Check whether the file is a supported image.
---@param filepath string File path
---@return boolean
M.is_image = util.is_image

--- Check whether the file is a supported video.
---@param filepath string File path
---@return boolean
M.is_video = util.is_video
M.is_archive = util.is_archive
M.is_sqlite = util.is_sqlite

--- Check whether the file is previewable (image, video, certificate, etc.).
---@param filepath string File path
---@return boolean
M.is_previewable = util.is_previewable

--- Check whether the file is an X.509 certificate.
---@param filepath string File path
---@return boolean
M.is_cert = util.is_cert
M.is_font = util.is_font
M.is_key = util.is_key
M.is_git_lfs_pointer = util.is_git_lfs_pointer

--- Return the detected terminal.
---@return string|nil terminal 'wezterm'|'kitty'|'ghostty'|'iterm'|nil
M.get_terminal = detect.get_terminal
M.supports_inline = detect.supports_inline
M.in_tmux = detect.in_tmux

--- Return the current configuration.
---@return GlimpseConfig
function M.get_config()
	return config
end

return M
