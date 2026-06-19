--- Previewer for 3D model files via user-configured pipeline.
--- Requires a `pipelines.model` entry in the glimpse config with at least one step.
---
--- Static thumbnail example (f3d):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       model = {
---       steps = {
---         {
---           command = 'f3d',
---           args = function(input, output)
---             return { input, '--output', output, '--config=thumbnail' }
---           end,
---         },
---       },
---       },
---     },
---   })
--- <
---
--- Turntable animation example (f3d sequence, no assembler):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       model = {
---       steps = {
---         {
---           command = 'f3d',
---           type = 'sequence',
---           frames = 36,
---           args = function(input, output, frame)
---             return { input, '--output', output, '--config=thumbnail',
---                      '--camera-azimuth-angle=' .. (frame * 10) }
---           end,
---         },
---       },
---       renderer = { fps = 12 },
---       },
---     },
---   })
--- <
---
--- Turntable-to-GIF example (f3d + ffmpeg assembly):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       model = {
---       steps = {
---         {
---           command = 'f3d',
---           type = 'sequence',
---           frames = 36,
---           args = function(input, output, frame)
---             return { input, '--output', output, '--config=thumbnail',
---                      '--camera-azimuth-angle=' .. (frame * 10) }
---           end,
---         },
---         {
---           command = 'ffmpeg',
---           output_ext = '.gif',
---           args = function(frames_dir, output, fps)
---             return { '-y', '-framerate', tostring(fps),
---                      '-i', frames_dir .. '/frame_%04d.png',
---                      output }
---           end,
---         },
---       },
---       renderer = { fps = 12 },
---       },
---     },
---   })
--- <
local M = {}

local preview_route = require('glimpse.preview_route')
local pipeline = require('glimpse.pipeline')

local _tokens = {}
-- Per-source-window state: { stop(full_cleanup?) }. Mirrors video.lua's _states pattern.
-- stop(false): cancels pipeline + timer, frees temp files, keeps preview window alive for reuse.
-- stop(true):  also closes/deletes the preview buffer (called from BufDelete autocmd).
local _states = {}
local _static_results = {}
local _static_leave_registered = false

-- Temp files written during the session; cleaned up on VimLeavePre.
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

local function _release_static_result(winid)
	local result = _static_results[winid]
	if not result then
		return
	end
	_static_results[winid] = nil
	result.cleanup()
end

local function _retain_static_result(winid, result)
	local previous = _static_results[winid]
	_static_results[winid] = result
	if previous then
		previous.cleanup()
	end

	if not _static_leave_registered then
		_static_leave_registered = true
		vim.api.nvim_create_autocmd('VimLeavePre', {
			once = true,
			callback = function()
				for source_win in pairs(_static_results) do
					_release_static_result(source_win)
				end
			end,
		})
	end

	local buf = require('glimpse.renderer').find_by_filepath(result.path)
	if buf then
		vim.api.nvim_create_autocmd('BufDelete', {
			buffer = buf,
			once = true,
			callback = function()
				if _static_results[winid] == result then
					_release_static_result(winid)
				end
			end,
		})
	end
end

local function _get_pipeline_config()
	local cfg = require('glimpse').get_config()
	return cfg.pipelines and cfg.pipelines.model
end

--- Run the configured pipeline and display the result.
--- Handles both { path } (static/GIF) and { frames, tmpdir } (sequence animation).
--- @param filepath string
--- @param mode 'show'|'preview'
--- @param source_win? number
local function _run_pipeline(filepath, mode, source_win)
	local pipeline_cfg = _get_pipeline_config()
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for model preview', vim.log.levels.WARN)
		return
	end

	local winid = source_win or vim.api.nvim_get_current_win()

	-- Stop the existing animation without closing the preview window so that
	-- ensure_window() can reuse it. Mirrors video.lua's _show_animated pattern:
	-- stop(false) keeps the window alive for the incoming inline.preview or new model.preview.
	if _states[winid] then
		_states[winid].stop(false)
	end

	local token = {}
	_tokens[winid] = token

	-- All animation state lives in the closure so cleanup() has access regardless of phase.
	local anim_buf = nil
	local anim_win = nil
	local anim_timer = nil
	local cur_id = nil
	local frame_paths = nil
	local frame_tmpdir = nil
	local result_cleanup = nil
	local cancel_pipeline = nil

	-- Progressive sequence state: grows in on_frame, consumed by advance().
	local anim_frames = {}
	local anim_started = false
	local anim_frame_idx = 1
	local paused = false

	local fps = (pipeline_cfg.renderer and pipeline_cfg.renderer.fps) or 12
	local delay_ms = math.max(1, math.floor(1000 / fps))
	local progressive = not (pipeline_cfg.renderer and pipeline_cfg.renderer.progressive == false)

	-- Lazy search: find or create the preview window at callback time (not upfront).
	-- Searching lazily ensures we find whatever window is alive at frame-0 time,
	-- rather than a stale snapshot captured before async cleanup runs.
	local function ensure_window()
		if anim_buf and vim.api.nvim_buf_is_valid(anim_buf) then
			if anim_win and vim.api.nvim_win_is_valid(anim_win) and vim.api.nvim_win_get_buf(anim_win) == anim_buf then
				return anim_buf, anim_win
			end
			anim_buf, anim_win = nil, nil
		end

		if mode ~= 'preview' then
			anim_win = winid
			if not vim.api.nvim_win_is_valid(anim_win) then
				return nil, nil
			end
			anim_buf = vim.api.nvim_win_get_buf(anim_win)
			if not vim.api.nvim_buf_is_valid(anim_buf) then
				return nil, nil
			end
			return anim_buf, anim_win
		end

		if not vim.api.nvim_win_is_valid(winid) then
			return nil, nil
		end

		-- Find an existing marked preview window — same criteria as inline.preview.
		local ps = require('glimpse.preview_state')
		local target_win = nil
		local target_buf = nil
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			local cbuf = vim.api.nvim_win_get_buf(w)
			if w ~= winid and ps.is_marked(cbuf) then
				target_win = w
				target_buf = cbuf
				break
			end
		end

		local current_win = vim.api.nvim_get_current_win()
		local restore_win = current_win ~= winid and vim.api.nvim_win_is_valid(winid)
		if restore_win then
			vim.api.nvim_set_current_win(winid)
		end

		if target_win then
			-- Reuse the existing window and its buffer (same as video.lua).
			anim_win = target_win
			anim_buf = target_buf
		else
			vim.cmd('vsplit')
			anim_buf = vim.api.nvim_create_buf(false, true)
			anim_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(anim_win, anim_buf)
		end

		if restore_win and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
		end

		return anim_buf, anim_win
	end

	local cleanup

	local function show_frame_immediately(path)
		local b, w = ensure_window()
		if not b or not w then
			return
		end
		local fh = io.open(path, 'rb')
		if not fh then
			return
		end
		local header = fh:read(24)
		fh:close()
		local kitty = require('glimpse.kitty')
		local w_px, h_px = kitty.png_dimensions_from_data(header)
		if not w_px or not h_px then
			return
		end
		local cfg = require('glimpse').get_config()
		local cell_w = (cfg.cell_size and cfg.cell_size.width) or 20
		local cell_h = (cfg.cell_size and cfg.cell_size.height) or 40
		local wc = vim.api.nvim_win_get_width(w)
		local wr = vim.api.nvim_win_get_height(w)
		local gc = math.min(wc, math.ceil(w_px / cell_w))
		local gr = math.min(wr, math.ceil(h_px / cell_h))
		local id = kitty.new_id()
		kitty.retransmit_frame(id, path)
		require('glimpse.renderer').setup_animation_buf(b, w, id, gc, gr, wc, wr)
		require('glimpse.preview_state').mark(b)
		vim.cmd('redraw')
		cur_id = id
		-- Register BufDelete as early as possible so closing the buffer before
		-- on_done fires still cancels the pipeline and frees resources.
		vim.api.nvim_create_autocmd('BufDelete', {
			buffer = b,
			once = true,
			callback = function()
				cleanup(true)
			end,
		})
	end

	-- Render an arbitrary frame index (cyclic wrap) without touching the timer.
	local function jump_to_frame(target)
		if #anim_frames == 0 then
			return
		end
		anim_frame_idx = ((target - 1) % #anim_frames) + 1
		local b = anim_buf
		if not b or not vim.api.nvim_buf_is_valid(b) then
			return
		end
		local kitty = require('glimpse.kitty')
		local new_id = kitty.new_id()
		kitty.retransmit_frame(new_id, anim_frames[anim_frame_idx])
		kitty.delete(cur_id)
		cur_id = new_id
		require('glimpse.renderer').update_animation_highlight(b, new_id)
		vim.cmd('redraw')
	end

	-- advance() uses anim_frames by reference: naturally picks up frames as they arrive.
	local function advance()
		local b = anim_buf
		if _tokens[winid] ~= token or not b or not vim.api.nvim_buf_is_valid(b) then
			cleanup(false)
			return
		end
		if paused then
			return
		end
		anim_frame_idx = (anim_frame_idx % #anim_frames) + 1
		local kitty = require('glimpse.kitty')
		local new_id = kitty.new_id()
		kitty.retransmit_frame(new_id, anim_frames[anim_frame_idx])
		kitty.delete(cur_id)
		cur_id = new_id
		require('glimpse.renderer').update_animation_highlight(b, new_id)
		vim.cmd('redraw')
		anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
	end

	-- full_cleanup=true:  stop timer + pipeline, delete kitty image, close buffer.
	-- full_cleanup=false: stop timer + pipeline, free temp files, keep window alive.
	cleanup = function(full_cleanup)
		full_cleanup = full_cleanup ~= false

		if anim_timer then
			anim_timer:stop()
			if not anim_timer:is_closing() then
				anim_timer:close()
			end
			anim_timer = nil
		end

		if cancel_pipeline then
			cancel_pipeline()
			cancel_pipeline = nil
		end

		local is_owner = _tokens[winid] == token

		if full_cleanup then
			if cur_id then
				require('glimpse.kitty').delete(cur_id)
				cur_id = nil
			end
			if is_owner and anim_buf and vim.api.nvim_buf_is_valid(anim_buf) then
				require('glimpse.renderer').close(anim_buf)
			end
		end

		if result_cleanup then
			if frame_paths then
				_unregister_temps(frame_paths)
			end
			result_cleanup()
			result_cleanup = nil
			frame_paths = nil
			frame_tmpdir = nil
		elseif frame_paths then
			_unregister_temps(frame_paths)
			for _, p in ipairs(frame_paths) do
				os.remove(p)
			end
			frame_paths = nil
		end
		-- frame_tmpdir may be set before on_done fires (captured in on_frame frame 0)
		-- so always check it independently of frame_paths.
		if frame_tmpdir then
			vim.fn.delete(frame_tmpdir, 'rf')
			frame_tmpdir = nil
		end

		if is_owner then
			_tokens[winid] = nil
			_states[winid] = nil
		end
	end

	_states[winid] = { stop = cleanup }

	cancel_pipeline = pipeline.run_steps(pipeline_cfg, filepath, function(result, err)
		cancel_pipeline = nil
		if _tokens[winid] ~= token then
			-- stale: clean up any temp output produced by this now-discarded run
			if result then
				if result.cleanup then
					result.cleanup()
				elseif result.path then
					os.remove(result.path)
				elseif result.frames then
					for _, p in ipairs(result.frames) do
						os.remove(p)
					end
					vim.fn.delete(result.tmpdir, 'rf')
				end
			end
			return
		end

		if not result then
			vim.notify('[glimpse] model pipeline failed: ' .. (err or 'unknown'), vim.log.levels.WARN)
			_states[winid] = nil
			_tokens[winid] = nil
			return
		end

		if result.path then
			-- Static or assembled output (PNG, GIF, etc.) — route through image pipeline.
			local current_win = vim.api.nvim_get_current_win()
			local restore_win = current_win ~= winid and vim.api.nvim_win_is_valid(winid)
			if restore_win then
				vim.api.nvim_set_current_win(winid)
			end
			if mode == 'preview' then
				preview_route.preview(result.path)
			else
				preview_route.show(result.path)
			end
			if result.cleanup then
				_retain_static_result(winid, result)
			end
			if restore_win and vim.api.nvim_win_is_valid(current_win) then
				vim.api.nvim_set_current_win(current_win)
			end
			_states[winid] = nil
			_tokens[winid] = nil
			return
		end

		-- Sequence output: animation is already running progressively via on_frame.
		-- Register temps for cleanup; the timer keeps running until cleanup() is called.
		local paths = result.frames
		local tmpdir = result.tmpdir

		if not paths or #paths == 0 then
			vim.notify('[glimpse] model pipeline: sequence produced no frames', vim.log.levels.WARN)
			vim.fn.delete(tmpdir, 'rf')
			_states[winid] = nil
			_tokens[winid] = nil
			return
		end

		_register_temps(paths)
		frame_paths = paths
		frame_tmpdir = tmpdir
		result_cleanup = result.cleanup

		if not anim_started then
			-- Non-progressive or < 2 frames: start animation now that all frames are ready.
			-- anim_frames is already populated by on_frame callbacks.
			if #anim_frames >= 2 then
				anim_started = true
				anim_timer = vim.uv.new_timer()
				anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
			else
				-- 0 or 1 frame: frame 0 shown statically by show_frame_immediately; done.
				_states[winid] = nil
				_tokens[winid] = nil
			end
		end
	end, function(path, frame_index)
		if _tokens[winid] ~= token then
			return
		end
		anim_frames[#anim_frames + 1] = path
		if frame_index == 0 then
			-- Capture tmpdir for early cleanup (before on_done fires).
			frame_tmpdir = vim.fn.fnamemodify(path, ':h')
			show_frame_immediately(path)
			if anim_buf and vim.api.nvim_buf_is_valid(anim_buf) then
				local pkeys = pipeline_cfg.keys or {}
				local toggle_key = pkeys.toggle or '<CR>'
				local seek_fwd_key = pkeys.seek_forward or 'l'
				local seek_bwd_key = pkeys.seek_backward or 'h'
				vim.keymap.set('n', toggle_key, function()
					paused = not paused
					if not paused and anim_timer then
						anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
					end
				end, { buffer = anim_buf, silent = true, desc = 'Toggle model animation' })
				vim.keymap.set('n', seek_fwd_key, function()
					jump_to_frame(anim_frame_idx + 1)
				end, { buffer = anim_buf, silent = true, desc = 'Seek model forward 1 frame' })
				vim.keymap.set('n', seek_bwd_key, function()
					jump_to_frame(anim_frame_idx - 1)
				end, { buffer = anim_buf, silent = true, desc = 'Seek model backward 1 frame' })
			end
		end
		-- Start animating as soon as we have 2 frames (progressive mode only).
		if progressive and #anim_frames == 2 and not anim_started then
			anim_started = true
			anim_timer = vim.uv.new_timer()
			anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
		end
	end)
end

--- Show the model (full view).
--- @param filepath string
--- @param source_win? number
function M.show(filepath, source_win)
	_run_pipeline(filepath, 'show', source_win)
end

--- Preview the model in the current preview target.
--- @param filepath string
--- @param source_win? number
function M.preview(filepath, source_win)
	_run_pipeline(filepath, 'preview', source_win)
end

--- Cancel any in-flight render for the given window.
--- Keeps the preview window alive so the next inline.preview or model.preview
--- can reuse it — mirrors video.lua's stop(false) pattern.
--- @param winid? number Defaults to current window
function M.cancel(winid)
	local w = winid or vim.api.nvim_get_current_win()
	if _states[w] then
		_states[w].stop(false)
	end
	_release_static_result(w)
end

return M
