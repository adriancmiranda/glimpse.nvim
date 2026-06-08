local M = {}
local dir = require('glimpse.dir')
local follow_cwd = true

local function should_follow_cwd()
	return follow_cwd
end

local function open_image(filepath)
	local config = require('glimpse').get_config()
	local oil_config = config.integrations and config.integrations.oil or {}
	local open_mode = oil_config.open or 'edit'

	if type(open_mode) == 'function' then
		local opened_buf = open_mode(filepath)
		if type(opened_buf) == 'number' and vim.api.nvim_buf_is_valid(opened_buf) then
			return opened_buf
		end
		return vim.api.nvim_get_current_buf()
	end

	if open_mode ~= 'edit' and open_mode ~= 'tabedit' then
		open_mode = 'edit'
	end

	vim.cmd(open_mode .. ' ' .. vim.fn.fnameescape(filepath))
	return vim.api.nvim_get_current_buf()
end

local function focus_existing_image(filepath)
	local renderer = require('glimpse.renderer')
	local buf = renderer.find_by_filepath(filepath)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
			vim.api.nvim_set_current_win(win)
			return buf
		end
	end

	vim.api.nvim_set_current_buf(buf)
	return buf
end

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseOil', { clear = true })
	local util = require('glimpse.util')
	local kitty = require('glimpse.kitty')
	local glimpse = require('glimpse')
	local config = glimpse.get_config()
	local integrations = config.integrations or {}
	local oil_config = integrations.oil or {}
	follow_cwd = oil_config.follow_cwd ~= false
	local keys = config.keys

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
				local fpath = vim.fs.joinpath(current_dir, entry.name)
				if util.is_video(fpath) then
					local thumbnail = require('glimpse.thumbnail')
					thumbnail.extract_async(fpath, function(target)
						if target then
							vim.schedule(function()
								require('glimpse').preview(target)
							end)
						end
					end)
				else
					require('glimpse').preview(fpath)
				end
			end, { buffer = info.buf, silent = true, desc = 'Image/video preview' })

			-- Open image or video with an external player
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
						if settings.video_open then
							if type(settings.video_open) == 'function' then
								settings.video_open(fpath)
							else
								vim.fn.jobstart({ settings.video_open, fpath }, { detach = true })
							end
						end
						return
					end
					if util.is_image(fpath) then
						if glimpse._should_use_inline() then
							oil.close()
							local existing_buf = focus_existing_image(fpath)
							if existing_buf then
								if should_follow_cwd() then
									dir.follow(fpath)
								end
								require('glimpse.renderer').render(existing_buf, fpath, { listed = true })
								return
							end
							if should_follow_cwd() then
								dir.follow(fpath)
							end
							local buf = open_image(fpath)
							vim.schedule(function()
								pcall(vim.api.nvim_buf_set_name, buf, fpath)
							end)
						else
							local pane_config = glimpse.get_config()
							require('glimpse.strategy.pane').show(fpath, {
								position = pane_config.pane_position,
								size = pane_config.pane_size,
							})
						end
						return
					end
					if util.is_font(fpath) then
						require('glimpse').show(fpath)
						return
					end
				end
				oil.select()
			end, { buffer = info.buf, silent = true, desc = 'Open file or image/video' })

			-- Prefetch
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

	-- Clean up the WezTerm pane when leaving Oil or exiting Neovim
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
