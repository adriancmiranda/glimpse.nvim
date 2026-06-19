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
---   `<leader>p` - Preview image side by side
---   `;`         - Open image (configurable: current tab or new tab)
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
---@field pane? GlimpsePaneConfig External pane settings
---@field inline? GlimpseInlineConfig Inline rendering options
---@field keys? GlimpseKeysConfig Configurable keymaps
---@field debounce? GlimpseDebounceConfig Debounce timings in ms
---@field cell_size? GlimpseCellSizeConfig Estimated terminal cell pixel size
---@field cache? GlimpseCacheConfig Cache settings
---@field safety? GlimpseSafetyConfig Safety settings
---@field loading? GlimpseLoadingConfig Loading text
---@field image? GlimpseImageConfig Image preview settings
---@field video? GlimpseVideoConfig Video preview settings
---@field archive? GlimpseArchiveConfig Archive preview settings
---@field pipelines? { model?: GlimpsePipelineConfig } Conversion pipelines by preview type
---@field integrations? GlimpseIntegrationsConfig Plugin integrations

---@class GlimpseInlineConfig
---@field rerender_on_tab? boolean Re-render when returning to an image tab (default: true)
---@field close_with_q? boolean Map a key to close the image buffer (default: true)

---@class GlimpseOilConfig
---@field enable? boolean Keymaps in Oil.nvim (default: enabled)
---@field open? 'edit'|'tabedit'|fun(filepath: string)
--- Open images in the current tab, a new tab, or custom logic (default: 'edit')
---@field follow_cwd? boolean Keep the tab cwd in sync with the opened image (default: true)

---@class GlimpsePaneConfig
---@field position? 'right'|'bottom' External pane position (default: 'right')
---@field size? number External pane size in percent (default: 40)

---@class GlimpseCacheConfig
---@field dir? string Cache directory for converted images
---@field max_age_days? number Days to keep cached files (default: 7)

---@class GlimpseSafetyConfig
---@field max_file_size? number Maximum bytes to process (default: 50MB)

---@class GlimpseLoadingConfig
---@field text? string Text shown while loading

---@class GlimpseImageConfig
---@field formats? string[] Supported image extensions

---@class GlimpseVideoFramesConfig
---@field strategy? 'auto'|'batch'|'poll' Frame extraction strategy for inline playback (default: 'auto')
---@field per_second? number Frames per second to extract (default: 10)
---@field limit? integer Maximum frames to extract (default: 120)
---@field width? integer|'auto' Frame width in pixels for ffmpeg (default: 640). Use 'auto' to match window width.

---@class GlimpseVideoKeysConfig
---@field toggle? string Keymap to toggle play/pause in an animation buffer (default: '<CR>')
---@field seek_forward? string Keymap to seek forward 5 seconds (default: 'l')
---@field seek_backward? string Keymap to seek backward 5 seconds (default: 'h')

---@class GlimpseVideoConfig
---@field formats? string[] Supported video extensions
---@field open? string|fun(filepath: string) Command or callback for opening videos externally
---@field keys? GlimpseVideoKeysConfig Keymaps for inline video playback
---@field frames? GlimpseVideoFramesConfig Inline video playback settings

---@class GlimpseArchiveConfig
---@field formats? string[] Supported archive extensions

---@class GlimpseKeysConfig
---@field preview? string Keymap for preview in Oil (default: '<leader>p')
---@field open? string Keymap for opening in a tab in Oil (default: ';')
---@field close? string Keymap for closing the image buffer (default: 'q')

---@class GlimpseDebounceConfig
---@field prefetch? number ms before pre-converting on cursor move (default: 200)
---@field resize? number ms before re-rendering on resize (default: 100)

---@class GlimpseCellSizeConfig
---@field width? number Estimated pixels per column (default: 20)
---@field height? number Estimated pixels per row (default: 40)

---@class GlimpseTelescopeConfig
---@field enable? boolean
---@field pickers? string|string[]|table
---@field previewer? table
---@field previewer_opts? table
---@field follow_cwd? boolean Keep the tab cwd in sync with the previewed file (default: false)
---@field image? boolean
---@field video? boolean
---@field archive? boolean
---@field sqlite? boolean
---@field font? boolean
---@field cert? boolean
---@field key? boolean
---@field binary? boolean

---@class GlimpseIntegrationsConfig
---@field oil? GlimpseOilConfig Keymaps in Oil.nvim (default: enabled)
---@field neotree? {enable?:boolean, auto_preview?:boolean} NeoTree integration config
---@field telescope? GlimpseTelescopeConfig Preview in Telescope (default: enabled)

local detect = require('glimpse.detect')
local safety = require('glimpse.safety')
local util = require('glimpse.util')
local binary = require('glimpse.previewer.binary')
local inline = require('glimpse.strategy.inline')

---@class Glimpse
local M = {}

---@type GlimpseConfig
local config = {
	strategy = 'auto',
	pane = {
		position = 'right',
		size = 40,
	},
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
	cache = {
		dir = vim.fn.stdpath('cache') .. '/glimpse',
		max_age_days = 7,
	},
	safety = {
		max_file_size = 50 * 1024 * 1024,
	},
	loading = {
		text = '  ⏳ Loading...',
	},
	image = {
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
	},
	video = {
		formats = {
			'.mp4',
			'.mkv',
			'.avi',
			'.mov',
			'.webm',
			'.flv',
			'.wmv',
			'.m4v',
		},
		open = nil,
		keys = {
			toggle = '<CR>',
			seek_forward = 'l',
			seek_backward = 'h',
		},
	},
	pipelines = {
		model = {
			steps = {
				{
					command = 'f3d',
					output_ext = '.png',
					args = function(input, output)
						return { input, '--output', output, '--config=thumbnail' }
					end,
				},
			},
			renderer = {
				fps = 12,
				progressive = true,
			},
			keys = {
				toggle = '<CR>',
				seek_forward = 'l',
				seek_backward = 'h',
			},
		},
	},
	archive = {
		formats = {
			'.zip',
			'.tar',
			'.tar.gz',
			'.tgz',
			'.tar.bz2',
			'.tar.xz',
			'.txz',
			'.jar',
			'.war',
			'.apk',
		},
	},
	integrations = {
		oil = {
			enable = true,
		},
		neotree = {
			enable = false,
			auto_preview = true,
		},
		telescope = {
			enable = true,
		},
	},
}

local kind_cache = {}
local kind_cache_revision = 0

local function normalize_telescope_config(telescope)
	if telescope == false then
		return { enable = false }
	end
	if telescope == true or telescope == nil then
		return { enable = true }
	end
	if type(telescope) == 'table' then
		return vim.tbl_deep_extend('force', { enable = true }, telescope)
	end
	return { enable = true }
end

local function normalize_oil_config(oil)
	if oil == false then
		return {
			enable = false,
			open = 'edit',
		}
	end

	if oil == true or oil == nil then
		return {
			enable = true,
			open = 'edit',
		}
	end

	if type(oil) == 'table' then
		return vim.tbl_deep_extend('force', {
			enable = true,
			open = 'edit',
		}, oil)
	end

	return {
		enable = true,
		open = 'edit',
	}
end

--- Configure the plugin.
---@param opts? GlimpseConfig Configuration options (merged with defaults)
function M.setup(opts)
	config = vim.tbl_deep_extend('force', config, opts or {})
	config.integrations.oil = normalize_oil_config(config.integrations.oil)
	config.integrations.telescope = normalize_telescope_config(config.integrations.telescope)
	kind_cache = {}
	kind_cache_revision = kind_cache_revision + 1
	if M._should_use_inline() and config.inline.rerender_on_tab then
		inline.setup_autocmds()
	end
	if config.integrations.oil and config.integrations.oil.enable ~= false then
		require('glimpse.integrations.oil').setup()
	end
	local neotree = config.integrations.neotree
	if type(neotree) == 'table' and neotree.enable then
		require('glimpse.integrations.neotree').setup()
	end
	if config.integrations.telescope.enable ~= false then
		require('glimpse.integrations.telescope').setup(config.integrations.telescope)
	end
	-- Auto-detect terminal cell pixel dimensions (skip in headless/non-tty mode)
	if not (opts and opts.cell_size) and vim.fn.has('ttyin') == 1 then
		require('glimpse.kitty').detect_cell_size(function(w, h)
			config.cell_size.width = w
			config.cell_size.height = h
			-- Re-render any image buffers that were opened before detection completed
			local renderer = require('glimpse.renderer')
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(win) then
					local buf = vim.api.nvim_win_get_buf(win)
					if vim.bo[buf].filetype == 'image' and renderer.has_placement(buf) then
						renderer.rerender(buf)
					end
				end
			end
		end)
	end
	-- Clean up old cache entries in the background
	if config.cache.max_age_days and config.cache.max_age_days > 0 then
		vim.defer_fn(function()
			require('glimpse.cache').cleanup(config.cache.dir, config.cache.max_age_days)
		end, 0)
	end
end

local function _kind_cache_key(filepath)
	local stat = vim.uv.fs_stat(filepath)
	if not stat then
		return nil
	end

	local mtime = stat.mtime or {}
	return table.concat({
		tostring(kind_cache_revision),
		filepath,
		tostring(stat.size or 0),
		tostring(mtime.sec or 0),
		tostring(mtime.nsec or 0),
	}, ':')
end

local function resolve_kind(filepath)
	local cache_key = _kind_cache_key(filepath)
	if cache_key then
		local cached = kind_cache[cache_key]
		if cached ~= nil then
			return cached or nil
		end
	end

	local kind
	if util.is_archive(filepath) then
		kind = 'archive'
	elseif util.is_sqlite(filepath) then
		kind = 'sqlite'
	elseif util.is_cert(filepath) then
		kind = 'cert'
	elseif util.is_key(filepath) then
		kind = 'key'
	elseif util.is_font(filepath) then
		kind = 'font'
	elseif util.is_model(filepath) then
		kind = 'model'
	elseif util.is_video(filepath) then
		kind = 'video'
	elseif util.is_image(filepath) and util.is_git_lfs_pointer(filepath) then
		kind = nil
	elseif util.is_image(filepath) then
		kind = 'image'
	elseif binary.can_preview(filepath) then
		kind = 'binary'
	end

	if cache_key then
		kind_cache[cache_key] = kind or false
	end
	return kind
end

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
	local kind = resolve_kind(filepath)
	if kind == 'archive' then
		return require('glimpse.previewer.archive'), { max_size = 0 }, 'archive'
	end
	if kind == 'sqlite' then
		return require('glimpse.previewer.sqlite'), { max_size = 0 }, 'sqlite'
	end
	if kind == 'cert' then
		return require('glimpse.previewer.cert'), { max_size = config.safety.max_file_size }, 'cert'
	end
	if kind == 'key' then
		return require('glimpse.previewer.key'), { max_size = config.safety.max_file_size }, 'key'
	end
	if kind == 'font' then
		return require('glimpse.previewer.font'), { max_size = config.safety.max_file_size }, 'font'
	end
	if kind == 'model' then
		return require('glimpse.previewer.model'), { max_size = config.safety.max_file_size }, 'model'
	end
	if kind == 'video' then
		return require('glimpse.previewer.video'), { max_size = config.safety.max_file_size }, 'video'
	end
	if kind == 'image' then
		return require('glimpse.previewer.image'), { max_size = config.safety.max_file_size }, 'image'
	end
	if kind == 'binary' then
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
	return resolve_kind(filepath)
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
	if util.is_image(filepath) then
		require('glimpse.dir').follow(filepath)
	end
	previewer.show(filepath)
end

--- Quick preview (reuses an existing window or opens a float).
---@param filepath string Absolute file path
function M.preview(filepath)
	if util.is_image(filepath) and util.is_git_lfs_pointer(filepath) then
		return
	end

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

--- Close the active preview.
function M.close()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].filetype == 'image' then
		inline.close(buf, true)
	end
end

---@type fun(filepath: string): boolean Check whether the file is a supported image.
M.is_image = util.is_image
---@type fun(filepath: string): boolean|nil Check whether the file is a Git LFS pointer.
M.is_git_lfs_pointer = util.is_git_lfs_pointer

---@type fun(filepath: string): boolean Check whether the file is a supported video.
M.is_video = util.is_video
---@type fun(filepath: string): boolean
M.is_archive = util.is_archive
---@type fun(filepath: string): boolean
M.is_sqlite = util.is_sqlite

---@type fun(filepath: string): boolean Check whether the file is previewable.
M.is_previewable = util.is_previewable

---@type fun(filepath: string): boolean Check whether the file is an X.509 certificate.
M.is_cert = util.is_cert
---@type fun(filepath: string): boolean
M.is_font = util.is_font
---@type fun(filepath: string): boolean
M.is_key = util.is_key
---@type fun(filepath: string): boolean Check whether the file is a supported 3D model.
M.is_model = util.is_model

--- Return the detected terminal.
---@return string|nil terminal 'wezterm'|'kitty'|'ghostty'|'iterm'|nil
M.get_terminal = detect.get_terminal
M.supports_inline = detect.supports_inline
M.supports_animation = detect.supports_animation
M.in_tmux = detect.in_tmux

--- Return the current configuration.
---@return GlimpseConfig
function M.get_config()
	return config
end

return M
