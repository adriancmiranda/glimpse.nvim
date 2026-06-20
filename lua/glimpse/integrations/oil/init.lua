local M = {}

local float = require('glimpse.integrations.oil.float')
local open = require('glimpse.integrations.oil.open')
local util = require('glimpse.util')

local follow_cwd = true

local function should_follow_cwd()
	return follow_cwd
end

function M.resolve_float_dir()
	return float.resolve_float_dir()
end

function M.open_float(opts)
	return float.open_float(opts)
end

function M.toggle_float(opts)
	return float.toggle_float(opts)
end

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseOil', { clear = true })
	local kitty = require('glimpse.kitty')
	local glimpse = require('glimpse')
	local config = glimpse.get_config()
	local integrations = config.integrations or {}
	---@type GlimpseOilConfig
	local oil_config = integrations.oil or {}
	follow_cwd = oil_config.follow_cwd ~= false
	local keys = config.keys or {}

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'oil',
		group = group,
		callback = function(info)
			vim.keymap.set('n', keys.preview, function()
				local oil = require('oil')
				local entry = oil.get_cursor_entry()
				if not entry or entry.type ~= 'file' then
					return
				end
				local current_dir = oil.get_current_dir()
				if not current_dir then
					return
				end
				-- Cancel any in-flight model pipeline so its callback is discarded
				-- if the user switches to a different file before it finishes.
				require('glimpse.previewer.model').cancel()
				local fpath = vim.fs.joinpath(current_dir, entry.name)
				if util.is_video(fpath) then
					require('glimpse.previewer.video').preview(fpath)
				else
					require('glimpse').preview(fpath)
				end
			end, { buffer = info.buf, silent = true, desc = 'Image/video preview' })

			vim.keymap.set('n', keys.open, function()
				local oil = require('oil')
				local entry = oil.get_cursor_entry()
				if entry and entry.type == 'file' then
					local current_dir = oil.get_current_dir()
					if not current_dir then
						return
					end
					local fpath = vim.fs.joinpath(current_dir, entry.name)
					if util.is_video(fpath) then
						local settings = require('glimpse').get_config()
						local video_config = settings.video
						if video_config and video_config.open then
							if type(video_config.open) == 'function' then
								video_config.open(fpath)
							else
								vim.fn.jobstart({ video_config.open, fpath }, { detach = true })
							end
						end
						return
					end
					if util.is_image(fpath) then
						open.handle_image(fpath, should_follow_cwd())
						return
					end
					if util.is_font(fpath) then
						require('glimpse').show(fpath)
						return
					end
				end
				oil.select()
			end, { buffer = info.buf, silent = true, desc = 'Open file or image/video' })

			local prefetch_timer = nil
			vim.api.nvim_create_autocmd('CursorMoved', {
				buffer = info.buf,
				group = group,
				callback = function()
					if prefetch_timer then
						prefetch_timer:stop()
					end
					prefetch_timer = vim.defer_fn(function()
						prefetch_timer = nil
						local oil = require('oil')
						local entry = oil.get_cursor_entry()
						if not entry or entry.type ~= 'file' then
							return
						end
						local current_dir = oil.get_current_dir()
						if not current_dir then
							return
						end
						local fpath = vim.fs.joinpath(current_dir, entry.name)
						if util.is_image(fpath) then
							local cols = math.floor(vim.api.nvim_win_get_width(0) / 2)
							local rows = vim.api.nvim_win_get_height(0)
							kitty.prefetch(fpath, { width = cols, height = rows })
						end
					end, require('glimpse').get_config().debounce.prefetch)
				end,
			})
		end,
	})

	vim.api.nvim_create_autocmd({ 'BufLeave' }, {
		group = group,
		pattern = 'oil://*',
		callback = function()
			local pane = require('glimpse.strategy.pane')
			if pane._wezterm_preview_pane then
				vim.fn.jobstart(
					{ 'wezterm', 'cli', 'kill-pane', '--pane-id', pane._wezterm_preview_pane },
					{ on_exit = function() end }
				)
				pane._wezterm_preview_pane = nil
			end
		end,
	})

	vim.api.nvim_create_autocmd('VimLeavePre', {
		group = group,
		callback = function()
			local pane = require('glimpse.strategy.pane')
			if pane._wezterm_preview_pane then
				vim.fn.system({ 'wezterm', 'cli', 'kill-pane', '--pane-id', pane._wezterm_preview_pane })
				pane._wezterm_preview_pane = nil
			end
		end,
	})
end

return M
