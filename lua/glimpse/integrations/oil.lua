local M = {}
local dir = require('glimpse.dir')
local preview_state = require('glimpse.preview_state')
local util = require('glimpse.util')
local follow_cwd = true

local function should_follow_cwd()
	return follow_cwd
end

local function same_path(lhs, rhs)
	if util.same_path then
		return util.same_path(lhs, rhs)
	end
	return lhs == rhs
end

local function buffer_matches_path(buf, filepath)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end

	if same_path(vim.api.nvim_buf_get_name(buf), filepath) then
		return true
	end

	local ok, marker = pcall(function()
		return vim.b[buf]._glimpse_filepath
	end)
	return ok and marker ~= nil and same_path(marker, filepath)
end

local function set_buffer_filepath(buf, filepath)
	pcall(function()
		vim.b[buf]._glimpse_filepath = filepath
	end)
end

local function buffer_filetype(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end

	local ok, ft = pcall(function()
		return vim.bo[buf].filetype
	end)
	if ok then
		return ft
	end
	return nil
end

local function fresh_buffer_name(filepath, buf)
	return string.format('glimpse://oil/image/%s/%d', vim.fn.sha256(filepath), buf)
end

local function should_open_fresh_buffer(filepath)
	local list_bufs = vim.api.nvim_list_bufs or function()
		return {}
	end

	for _, buf in ipairs(list_bufs()) do
		if buffer_matches_path(buf, filepath) then
			-- Reuse any existing non-preview buffer, even if it is hidden. Only
			-- create a fresh buffer when the file is open exclusively as a marked
			-- preview.
			if not preview_state.is_marked(buf) then
				return false
			end
		end
	end

	return true
end

local function existing_image_buffer(filepath)
	local renderer = require('glimpse.renderer')
	local buf = renderer.find_by_filepath(filepath)
	if buf and vim.api.nvim_buf_is_valid(buf) and not preview_state.is_marked(buf) then
		return buf
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local candidate = vim.api.nvim_win_get_buf(win)
			if
				vim.api.nvim_buf_is_valid(candidate)
				and vim.bo[candidate].filetype == 'image'
				and not preview_state.is_marked(candidate)
				and buffer_matches_path(candidate, filepath)
			then
				return candidate
			end
		end
	end

	local list_bufs = vim.api.nvim_list_bufs or function()
		return {}
	end

	for _, candidate in ipairs(list_bufs()) do
		if
			vim.api.nvim_buf_is_valid(candidate)
			and buffer_filetype(candidate) == 'image'
			and not preview_state.is_marked(candidate)
			and buffer_matches_path(candidate, filepath)
		then
			return candidate
		end
	end
end

local function focus_existing_image(filepath)
	local buf = existing_image_buffer(filepath)
	if not buf then
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

local function open_image(filepath, opts)
	opts = opts or {}
	local config = require('glimpse').get_config()
	local oil_config = config.integrations and config.integrations.oil or {}
	local open_mode = oil_config.open or 'edit'

	local function create_fresh_buffer()
		return vim.api.nvim_create_buf(false, true)
	end

	if type(open_mode) == 'function' then
		local opened_buf = open_mode(filepath)
		if type(opened_buf) == 'number' and vim.api.nvim_buf_is_valid(opened_buf) then
			local bufname = filepath
			if not pcall(vim.api.nvim_buf_set_name, opened_buf, filepath) then
				bufname = fresh_buffer_name(filepath, opened_buf)
				pcall(vim.api.nvim_buf_set_name, opened_buf, bufname)
			end
			set_buffer_filepath(opened_buf, filepath)
			return opened_buf, bufname
		end
		local current_buf = vim.api.nvim_get_current_buf()
		local bufname = filepath
		if not pcall(vim.api.nvim_buf_set_name, current_buf, filepath) then
			bufname = fresh_buffer_name(filepath, current_buf)
			pcall(vim.api.nvim_buf_set_name, current_buf, bufname)
		end
		set_buffer_filepath(current_buf, filepath)
		return current_buf, bufname
	end

	if open_mode ~= 'edit' and open_mode ~= 'tabedit' then
		open_mode = 'edit'
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local bufname = filepath
	local use_fresh = open_mode ~= 'tabedit'
		and (opts.force_fresh or vim.bo[current_buf].filetype == 'image' or should_open_fresh_buffer(filepath))
	if use_fresh then
		local fresh_buf = create_fresh_buffer()
		if not pcall(vim.api.nvim_buf_set_name, fresh_buf, filepath) then
			bufname = fresh_buffer_name(filepath, fresh_buf)
			pcall(vim.api.nvim_buf_set_name, fresh_buf, bufname)
		end
		set_buffer_filepath(fresh_buf, filepath)
		vim.api.nvim_set_current_buf(fresh_buf)
	else
		vim.cmd({ cmd = open_mode, args = { filepath } })
	end
	local buf = vim.api.nvim_get_current_buf()
	if not pcall(vim.api.nvim_buf_set_name, buf, filepath) then
		bufname = fresh_buffer_name(filepath, buf)
		pcall(vim.api.nvim_buf_set_name, buf, bufname)
	end
	set_buffer_filepath(buf, filepath)
	return buf, bufname
end

function M.setup()
	local group = vim.api.nvim_create_augroup('GlimpseOil', { clear = true })
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
						local renderer = require('glimpse.renderer')
						if glimpse._should_use_inline() then
							local existing_buf = existing_image_buffer(fpath)
							if existing_buf then
								if should_follow_cwd() then
									dir.follow(fpath)
								end
								oil.close()
								focus_existing_image(fpath)
								return
							end

							local pb = renderer.find_by_filepath(fpath)
							local was_preview = pb and preview_state.is_marked(pb)
							oil.close()

							if was_preview then
								-- The file is open in a preview window. keys.open (;) must
								-- open in the main workspace instead. Navigate away from the
								-- preview window so 'edit' places it in the right location.
								local cur_win = vim.api.nvim_get_current_win()
								if preview_state.is_marked(vim.api.nvim_win_get_buf(cur_win)) then
									local moved = false
									for _, win in ipairs(vim.api.nvim_list_wins()) do
										if
											win ~= cur_win
											and vim.api.nvim_win_is_valid(win)
											and not preview_state.is_marked(vim.api.nvim_win_get_buf(win))
										then
											vim.api.nvim_set_current_win(win)
											moved = true
											break
										end
									end
									if not moved then
										vim.cmd({ cmd = 'vsplit' })
									end
								end
								if should_follow_cwd() then
									dir.follow(fpath)
								end
								local leftover = vim.api.nvim_get_current_buf()
								local buf, bufname = open_image(fpath, { force_fresh = true })
								-- Clean up empty unnamed buffer left behind by oil.close() or
								-- navigation. Guard on filetype=='' to avoid deleting a buffer
								-- that is already set up as an image render.
								if
									buf ~= leftover
									and vim.api.nvim_buf_is_valid(leftover)
									and vim.api.nvim_buf_get_name(leftover) == ''
									and buffer_filetype(leftover) == ''
									and not vim.bo[leftover].modified
									and #vim.fn.win_findbuf(leftover) == 0
								then
									pcall(vim.api.nvim_buf_delete, leftover, { force = true })
								end
								if renderer.render then
									renderer.render(buf, fpath, { listed = true, bufname = bufname })
								end
								return
							end

							if should_follow_cwd() then
								dir.follow(fpath)
							end
							local leftover = vim.api.nvim_get_current_buf()
							local buf, bufname = open_image(fpath, { force_fresh = true })
							if
								buf ~= leftover
								and vim.api.nvim_buf_is_valid(leftover)
								and vim.api.nvim_buf_get_name(leftover) == ''
								and buffer_filetype(leftover) == ''
								and not vim.bo[leftover].modified
								and #vim.fn.win_findbuf(leftover) == 0
							then
								pcall(vim.api.nvim_buf_delete, leftover, { force = true })
							end
							if renderer.render then
								renderer.render(buf, fpath, { listed = true, bufname = bufname })
							end
							return
						end

						local pane_config = glimpse.get_config()
						if should_follow_cwd() then
							dir.follow(fpath)
						end
						require('glimpse.strategy.pane').show(fpath, {
							position = pane_config.pane.position,
							size = pane_config.pane.size,
						})
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
