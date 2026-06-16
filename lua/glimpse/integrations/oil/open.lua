local dir = require('glimpse.dir')
local path = require('glimpse.integrations.oil.path')
local preview_state = require('glimpse.preview_state')

local M = {}

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
				and path.buffer_matches_path(candidate, filepath)
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
			and path.buffer_filetype(candidate) == 'image'
			and not preview_state.is_marked(candidate)
			and path.buffer_matches_path(candidate, filepath)
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
				bufname = path.fresh_buffer_name(filepath, opened_buf)
				pcall(vim.api.nvim_buf_set_name, opened_buf, bufname)
			end
			path.set_buffer_filepath(opened_buf, filepath)
			return opened_buf, bufname
		end
		local current_buf = vim.api.nvim_get_current_buf()
		local bufname = filepath
		if not pcall(vim.api.nvim_buf_set_name, current_buf, filepath) then
			bufname = path.fresh_buffer_name(filepath, current_buf)
			pcall(vim.api.nvim_buf_set_name, current_buf, bufname)
		end
		path.set_buffer_filepath(current_buf, filepath)
		return current_buf, bufname
	end

	if open_mode ~= 'edit' and open_mode ~= 'tabedit' then
		open_mode = 'edit'
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local bufname = filepath
	local use_fresh = open_mode ~= 'tabedit'
		and (opts.force_fresh or vim.bo[current_buf].filetype == 'image' or path.should_open_fresh_buffer(filepath))
	if use_fresh then
		local fresh_buf = create_fresh_buffer()
		if not pcall(vim.api.nvim_buf_set_name, fresh_buf, filepath) then
			bufname = path.fresh_buffer_name(filepath, fresh_buf)
			pcall(vim.api.nvim_buf_set_name, fresh_buf, bufname)
		end
		path.set_buffer_filepath(fresh_buf, filepath)
		vim.api.nvim_set_current_buf(fresh_buf)
	else
		vim.cmd({ cmd = open_mode, args = { filepath } })
	end
	local buf = vim.api.nvim_get_current_buf()
	if not pcall(vim.api.nvim_buf_set_name, buf, filepath) then
		bufname = path.fresh_buffer_name(filepath, buf)
		pcall(vim.api.nvim_buf_set_name, buf, bufname)
	end
	path.set_buffer_filepath(buf, filepath)
	return buf, bufname
end

function M.handle_image(filepath, should_follow_cwd)
	local glimpse = require('glimpse')
	local renderer = require('glimpse.renderer')
	local oil = require('oil')

	if glimpse._should_use_inline() then
		local existing_buf = existing_image_buffer(filepath)
		if existing_buf then
			if should_follow_cwd then
				dir.follow(filepath)
			end
			oil.close()
			focus_existing_image(filepath)
			return true
		end

		local pb = renderer.find_by_filepath(filepath)
		local was_preview = pb and preview_state.is_marked(pb)
		oil.close()

		if was_preview then
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
			if should_follow_cwd then
				dir.follow(filepath)
			end
			local leftover = vim.api.nvim_get_current_buf()
			local buf, bufname = open_image(filepath, { force_fresh = true })
			if
				buf ~= leftover
				and vim.api.nvim_buf_is_valid(leftover)
				and vim.api.nvim_buf_get_name(leftover) == ''
				and path.buffer_filetype(leftover) == ''
				and not vim.bo[leftover].modified
				and #vim.fn.win_findbuf(leftover) == 0
			then
				pcall(vim.api.nvim_buf_delete, leftover, { force = true })
			end
			if renderer.render then
				renderer.render(buf, filepath, { listed = true, bufname = bufname })
			end
			return true
		end

		if should_follow_cwd then
			dir.follow(filepath)
		end
		local leftover = vim.api.nvim_get_current_buf()
		local buf, bufname = open_image(filepath, { force_fresh = true })
		if
			buf ~= leftover
			and vim.api.nvim_buf_is_valid(leftover)
			and vim.api.nvim_buf_get_name(leftover) == ''
			and path.buffer_filetype(leftover) == ''
			and not vim.bo[leftover].modified
			and #vim.fn.win_findbuf(leftover) == 0
		then
			pcall(vim.api.nvim_buf_delete, leftover, { force = true })
		end
		if renderer.render then
			renderer.render(buf, filepath, { listed = true, bufname = bufname })
		end
		return true
	end

	local pane_config = glimpse.get_config()
	if should_follow_cwd then
		dir.follow(filepath)
	end
	require('glimpse.strategy.pane').show(filepath, {
		position = pane_config.pane.position,
		size = pane_config.pane.size,
	})
	return true
end

return M
