--- Previewer for videos via generated thumbnails or inline animation.
local M = {}

local thumbnail = require('glimpse.thumbnail')
local preview_route = require('glimpse.preview_route')
local preview_state = require('glimpse.preview_state')

local _tokens = {}

--- Per-buffer animation state. Keyed by buf number.
--- @type table<number, {source_win: number, toggle: fun(), stop: fun(full_cleanup?: boolean)}>
local _states = {}

-- Tracks all temp PNG paths written during the session so a VimLeavePre
-- autocmd can delete files that survive an abrupt exit.
local _temp_registry = {}
local _leave_registered = false

local function _register_temps(paths)
	for _, p in ipairs(paths) do
		_temp_registry[p] = true
	end
	if not _leave_registered then
		_leave_registered = true
		vim.api.nvim_create_autocmd('VimLeavePre', {
			once = true,
			callback = function()
				for p in pairs(_temp_registry) do
					os.remove(p)
				end
			end,
		})
	end
end

local function _unregister_temps(paths)
	for _, p in ipairs(paths) do
		_temp_registry[p] = nil
	end
end

--- Exposed for tests only.
M._temp_registry = _temp_registry

local function _show_thumbnail(filepath, mode, source_win)
	local winid = source_win or vim.api.nvim_get_current_win()
	local token = {}
	_tokens[winid] = token
	thumbnail.extract_async(filepath, function(thumb)
		if _tokens[winid] ~= token then
			return
		end
		_tokens[winid] = nil
		if not thumb then
			vim.notify('[glimpse] failed to extract video thumbnail', vim.log.levels.WARN)
			return
		end

		local current_win = vim.api.nvim_get_current_win()
		local restore_win = current_win ~= winid and vim.api.nvim_win_is_valid(winid)
		if restore_win then
			vim.api.nvim_set_current_win(winid)
		end
		if mode == 'preview' then
			preview_route.preview(thumb)
		else
			preview_route.show(thumb)
		end
		if restore_win and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
		end
	end)
end

--- Animate: collect all frames via poll strategy and transmit directly via
--- Kitty animation protocol. All frames use the same ffmpeg dimensions so
--- Kitty receives consistent pixel sizes across the full sequence.
local function _show_animated(filepath, mode, source_win)
	local winid = source_win or vim.api.nvim_get_current_win()
	local token = {}

	for _, state in pairs(_states) do
		if state.source_win == winid then
			state.stop(false)
		end
	end

	_tokens[winid] = token

	local glimpse = require('glimpse')
	local kitty = require('glimpse.kitty')
	local renderer = require('glimpse.renderer')
	local frames_mod = require('glimpse.frames')
	local config = glimpse.get_config()
	local fps = (config.video and config.video.frames and config.video.frames.per_second) or 10
	local delay_ms = math.max(1, math.floor(1000 / fps))

	local collected = {}
	local buf, win
	local anim_buf, anim_win, anim_target_buf
	local cur_id = nil
	local cancel_frames = nil
	local frame_files = {}
	local anim_timer, paused, resize_timer, resize_group
	-- Set to true by cleanup_anim; guards ensure_window against reopening a
	-- split that the user intentionally closed, even when the token check is
	-- bypassed by both scheduled callbacks firing in the same idle batch.
	local show_stopped = false
	-- Forward-declared so the _states[winid] stop closure below can reference it
	-- before the full assignment at the end of this block.
	local cleanup_anim

	-- Register a stop handle immediately so callers can cancel the extraction
	-- before the first frame arrives (mirrors pipeline_previewer pattern).
	-- cleanup_anim will be assigned before stop() is ever called.
	_states[winid] = {
		source_win = winid,
		stop = function(final)
			if cleanup_anim then
				cleanup_anim(final)
			end
		end,
	}

	-- Watch any currently-open preview windows. If the user closes one before
	-- our deferred_on_done installs its own WinClosed handler, cancel this
	-- extraction so the deferred callback cannot reopen the split.
	-- Two events needed: BufDelete (force-wipe) and WinClosed (q with
	-- bufhidden=hide — buffer stays alive so BufDelete never fires).
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if w ~= winid then
			local b = vim.api.nvim_win_get_buf(w)
			if preview_state.is_marked(b) then
				vim.api.nvim_create_autocmd('BufDelete', {
					buffer = b,
					once = true,
					callback = function()
						if _tokens[winid] == token then
							cleanup_anim(true)
						end
					end,
				})
				vim.api.nvim_create_autocmd('WinClosed', {
					pattern = tostring(w),
					once = true,
					callback = function()
						if _tokens[winid] == token then
							cleanup_anim(true)
						end
					end,
				})
			end
		end
	end

	-- Find or create the image window; memoized so preview and full animation
	-- share the same buf/win without opening a second split.
	local function ensure_window()
		if show_stopped then
			return nil, nil
		end
		if anim_buf and vim.api.nvim_buf_is_valid(anim_buf) then
			if anim_win and vim.api.nvim_win_is_valid(anim_win) and vim.api.nvim_win_get_buf(anim_win) == anim_buf then
				return anim_buf, anim_win
			end
			anim_buf, anim_win, anim_target_buf = nil, nil, nil
		end
		if mode ~= 'preview' then
			anim_win = winid
			if not vim.api.nvim_win_is_valid(anim_win) then
				return nil, nil
			end
			anim_buf = vim.api.nvim_win_get_buf(winid)
			anim_target_buf = anim_buf
			return anim_buf, anim_win
		end
		local oil_win = winid
		local target_win, target_buf = nil, nil
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			local candidate_buf = vim.api.nvim_win_get_buf(w)
			if w ~= oil_win and vim.bo[candidate_buf].filetype == 'image' and preview_state.is_marked(candidate_buf) then
				target_win = w
				target_buf = candidate_buf
				break
			end
		end
		local current_win = vim.api.nvim_get_current_win()
		local restore_win = current_win ~= winid and vim.api.nvim_win_is_valid(winid)
		if restore_win then
			vim.api.nvim_set_current_win(winid)
		end
		if target_win then
			anim_win = target_win
			anim_buf = target_buf
		else
			if mode == 'preview' then
				vim.cmd('vsplit')
			end
			anim_buf = vim.api.nvim_create_buf(false, true)
			anim_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(anim_win, anim_buf)
		end
		if restore_win and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
		end
		anim_target_buf = anim_buf
		return anim_buf, anim_win
	end

	local function show_frame_immediately(data)
		-- Bail if the source window is gone (user closed oil before first frame).
		if not vim.api.nvim_win_is_valid(winid) then
			cleanup_anim(true)
			return
		end
		local b, w = ensure_window()
		if not b or not w then
			return
		end
		preview_state.mark(b)
		anim_target_buf = b
		local w_px, h_px = kitty.png_dimensions_from_data(data)
		if not w_px or not h_px then
			return
		end
		local cell_w = (config.cell_size and config.cell_size.width) or 20
		local cell_h = (config.cell_size and config.cell_size.height) or 40
		local wc = vim.api.nvim_win_get_width(w)
		local wr = vim.api.nvim_win_get_height(w)
		local gc = math.min(wc, math.ceil(w_px / cell_w))
		local gr = math.min(wr, math.ceil(h_px / cell_h))
		local tmp = vim.fn.tempname() .. '.png'
		_register_temps({ tmp })
		local fh = io.open(tmp, 'wb')
		if fh then
			fh:write(data)
			fh:close()
		end
		local id = kitty.new_id()
		kitty.retransmit_frame(id, tmp)
		renderer.setup_animation_buf(b, w, id, gc, gr, wc, wr, filepath)
		vim.cmd('redraw')
		-- Keep the file alive until cleanup_anim — the terminal reads it
		-- asynchronously (especially through tmux buffering) and may open it
		-- after the redraw call returns.
		frame_files[#frame_files + 1] = tmp
		-- Guard against the user closing the preview split before on_done
		-- installs the full BufDelete + _states cleanup. Without this, the
		-- token stays valid and on_done would re-open the split after close.
		vim.api.nvim_create_autocmd('BufDelete', {
			buffer = b,
			once = true,
			callback = function()
				cleanup_anim(false)
			end,
		})
	end

	cleanup_anim = function(full_cleanup)
		show_stopped = true
		full_cleanup = full_cleanup ~= false
		if cancel_frames then
			pcall(cancel_frames)
			cancel_frames = nil
		end
		if anim_timer then
			anim_timer:stop()
			if not anim_timer:is_closing() then
				anim_timer:close()
			end
			anim_timer = nil
		end
		if resize_timer then
			resize_timer:stop()
			if not resize_timer:is_closing() then
				resize_timer:close()
			end
			resize_timer = nil
		end
		if resize_group then
			pcall(vim.api.nvim_del_augroup_by_id, resize_group)
			resize_group = nil
		end
		-- Only touch shared state when this animation still owns the window
		-- token. A newer _show_animated call may have already replaced it, and
		-- its cleanup_anim would otherwise clobber the new token and close the
		-- reused preview buffer.
		local is_owner = _tokens[winid] == token
		if full_cleanup then
			if cur_id then
				kitty.delete(cur_id)
				cur_id = nil
			end
			if is_owner and anim_target_buf and vim.api.nvim_buf_is_valid(anim_target_buf) then
				renderer.close(anim_target_buf)
				anim_target_buf = nil
			end
		end
		for _, fp in ipairs(frame_files) do
			os.remove(fp)
		end
		_unregister_temps(frame_files)
		frame_files = {}
		if is_owner then
			_tokens[winid] = nil
			_states[winid] = nil
			if buf then
				_states[buf] = nil
			end
		end
	end

	local frames_cfg = (config.video and config.video.frames) or {}
	local frame_width
	if frames_cfg.width == 'auto' then
		local src_win = vim.fn.bufwinid(vim.api.nvim_get_current_buf())
		local cell_w = (config.cell_size and config.cell_size.width) or 20
		frame_width = (src_win ~= -1 and vim.api.nvim_win_get_width(src_win) or 80) * cell_w
	else
		frame_width = frames_cfg.width or 640
	end

	cancel_frames = frames_mod.extract_frames_async(filepath, { width = frame_width }, function(data, _index, is_preview)
		if _tokens[winid] ~= token then
			return
		end
		if is_preview then
			show_frame_immediately(data)
		else
			collected[#collected + 1] = data
		end
	end, function(_count, err)
		if _tokens[winid] ~= token then
			return
		end

		if err or #collected == 0 then
			cleanup_anim()
			_show_thumbnail(filepath, mode, winid)
			vim.notify('[glimpse] ' .. (err or 'no frames extracted'), vim.log.levels.WARN)
			return
		end

		-- Read dimensions from first frame PNG header
		local w_px, h_px = kitty.png_dimensions_from_data(collected[1])
		if not w_px or not h_px then
			vim.notify('[glimpse] could not read frame dimensions', vim.log.levels.WARN)
			return
		end

		buf, win = ensure_window()
		if not buf or not win then
			return
		end

		-- Trigger full cleanup when the animation window is closed directly
		-- (bufhidden=hide means BufDelete never fires in that path).
		vim.api.nvim_create_autocmd('WinClosed', {
			pattern = tostring(win),
			once = true,
			callback = function()
				cleanup_anim(true)
			end,
		})

		local animation_files = {}
		local cell_w = (config.cell_size and config.cell_size.width) or 20
		local cell_h = (config.cell_size and config.cell_size.height) or 40
		local win_cols = vim.api.nvim_win_get_width(win)
		local win_rows = vim.api.nvim_win_get_height(win)
		local grid_cols = math.min(win_cols, math.ceil(w_px / cell_w))
		local grid_rows = math.min(win_rows, math.ceil(h_px / cell_h))

		-- Pre-write all frames to temp files
		for _, data in ipairs(collected) do
			local tmp = vim.fn.tempname() .. '.png'
			local fh = io.open(tmp, 'wb')
			if fh then
				fh:write(data)
				fh:close()
				animation_files[#animation_files + 1] = tmp
				frame_files[#frame_files + 1] = tmp
			end
		end
		_register_temps(frame_files)

		-- Send only frame 1 to establish the image ID and placeholder
		local image_id = kitty.new_id()
		if animation_files[1] then
			kitty.retransmit_frame(image_id, animation_files[1])
		end

		-- Set up buffer with placeholder grid
		renderer.setup_animation_buf(buf, win, image_id, grid_cols, grid_rows, win_cols, win_rows, filepath)
		preview_state.mark(buf)
		vim.cmd('redraw')

		-- Retransmit each frame on a timer (uses same a=T,t=f path as frame 1)
		local frame = 1
		cur_id = image_id
		anim_timer = vim.uv.new_timer()
		paused = false
		resize_timer = vim.uv.new_timer()
		resize_group = nil

		local function advance()
			if _tokens[winid] ~= token or not vim.api.nvim_buf_is_valid(buf) then
				cleanup_anim()
				return
			end
			if paused then
				return
			end
			frame = (frame % #animation_files) + 1
			if animation_files[frame] then
				local new_id = kitty.new_id()
				kitty.retransmit_frame(new_id, animation_files[frame])
				local old_id = cur_id
				kitty.delete(old_id)
				cur_id = new_id
				renderer.update_animation_highlight(buf, new_id)
				vim.cmd('redraw')
			end
			anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
		end
		anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))

		local function jump_to_frame(target)
			frame = math.max(1, math.min(#animation_files, target))
			if animation_files[frame] then
				local new_id = kitty.new_id()
				kitty.retransmit_frame(new_id, animation_files[frame])
				local old_id = cur_id
				kitty.delete(old_id)
				cur_id = new_id
				renderer.update_animation_highlight(buf, new_id)
				vim.cmd('redraw')
			end
		end

		-- The buf-keyed entry takes over from the early winid-keyed registration.
		_states[winid] = nil
		_states[buf] = {
			source_win = winid,
			toggle = function()
				paused = not paused
				if not paused then
					anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
				end
			end,
			seek = function(delta_seconds)
				jump_to_frame(frame + math.floor(fps * delta_seconds))
			end,
			stop = function(final)
				cleanup_anim(final)
			end,
		}

		local keys = (config.video and config.video.keys) or {}
		local toggle_key = keys.toggle or '<CR>'
		local seek_fwd_key = keys.seek_forward or 'l'
		local seek_bwd_key = keys.seek_backward or 'h'
		vim.keymap.set('n', toggle_key, function()
			local s = _states[vim.api.nvim_get_current_buf()]
			if s then
				s.toggle()
			end
		end, { buffer = buf, silent = true, desc = 'Toggle video play/pause' })
		vim.keymap.set('n', seek_fwd_key, function()
			local s = _states[vim.api.nvim_get_current_buf()]
			if s then
				s.seek(5)
			end
		end, { buffer = buf, silent = true, desc = 'Seek video forward 5s' })
		vim.keymap.set('n', seek_bwd_key, function()
			local s = _states[vim.api.nvim_get_current_buf()]
			if s then
				s.seek(-5)
			end
		end, { buffer = buf, silent = true, desc = 'Seek video backward 5s' })

		-- Re-extract and restart when the preview window is resized
		resize_group = vim.api.nvim_create_augroup('GlimpseVideoResize_' .. buf, { clear = true })
		vim.api.nvim_create_autocmd('WinResized', {
			group = resize_group,
			callback = function()
				if not vim.api.nvim_buf_is_valid(buf) then
					return
				end
				local changed = (vim.v.event and vim.v.event.windows) or {}
				local relevant = false
				for _, w in ipairs(changed) do
					if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == buf then
						relevant = true
						break
					end
				end
				if not relevant then
					return
				end
				resize_timer:stop()
				local ms = (config.debounce and config.debounce.resize) or 100
				resize_timer:start(
					ms,
					0,
					vim.schedule_wrap(function()
						if _tokens[winid] ~= token or not vim.api.nvim_buf_is_valid(buf) then
							return
						end
						local s = _states[buf]
						if s then
							s.stop(false)
						end
						_show_animated(filepath, mode, winid)
					end)
				)
			end,
		})

		-- Clean up state when the buffer is deleted
		vim.api.nvim_create_autocmd('BufDelete', {
			buffer = buf,
			once = true,
			callback = function()
				local s = _states[buf]
				if s then
					s.stop()
				end
			end,
		})
	end)
end

--- Stop an active video preview tracked by buffer.
--- @param buf number
--- @param full_cleanup? boolean
function M.stop(buf, full_cleanup)
	local s = _states[buf]
	if s then
		s.stop(full_cleanup ~= false)
	end
end

--- Cancel any in-flight video extraction or animation for the given window.
--- Keeps the preview window alive so the next call can reuse it.
--- @param winid? number Defaults to current window
function M.cancel(winid)
	local w = winid or vim.api.nvim_get_current_win()
	local state = _states[w]
	if state then
		state.stop(false)
		return
	end
	for _, s in pairs(_states) do
		if s.source_win == w then
			s.stop(false)
			break
		end
	end
end

--- Show a video using inline animation when supported, thumbnail otherwise.
--- @param filepath string
function M.show(filepath)
	local glimpse = require('glimpse')
	local use_anim = glimpse._should_use_inline()
		and require('glimpse.detect').supports_animation()
		and vim.fn.has('ttyin') == 1
	if use_anim then
		_show_animated(filepath, 'show')
	else
		_show_thumbnail(filepath, 'show')
	end
end

--- Quick preview of a video using inline animation when supported, thumbnail otherwise.
--- @param filepath string
function M.preview(filepath)
	local glimpse = require('glimpse')
	local use_anim = glimpse._should_use_inline()
		and require('glimpse.detect').supports_animation()
		and vim.fn.has('ttyin') == 1
	if use_anim then
		_show_animated(filepath, 'preview')
	else
		_show_thumbnail(filepath, 'preview')
	end
end

return M
