--- Generic pipeline-to-image previewer runtime.
--- Handles token ownership, animation loops, static renders, and temp-file
--- cleanup for any previewer built on top of pipeline.lua.
---
--- All previewers that convert a file to a PNG/GIF/sequence via an external
--- pipeline (model, plantuml, …) delegate here instead of reimplementing the
--- same animation machinery.
local M = {}

local preview_route = require('glimpse.preview_route')
local pipeline = require('glimpse.pipeline')

-- Token ownership: each _run call stamps a unique table into _tokens[winid].
-- Stale callbacks self-cancel by checking _tokens[winid] == token.
local _tokens = {}

-- Per-source-window stop handle: { stop(full_cleanup?) }.
-- stop(false): cancel pipeline+timer, free temps, keep preview window alive.
-- stop(true):  also close the preview buffer (called from BufDelete autocmd).
local _states = {}

-- Static pipeline results (single-file output) retained until the preview
-- buffer is deleted or the window changes.
local _static_results = {}
local _static_leave_registered = false

-- Temp frame files written during the session; deleted on VimLeavePre.
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

--- Run a pipeline config and render the result inline or in a preview split.
--- @param pipeline_cfg GlimpsePipelineConfig
--- @param filepath string Source file path
--- @param mode 'show'|'preview'
--- @param source_win? number Defaults to current window
--- @param opts? { label?: string } label used in error notifications
function M.run(pipeline_cfg, filepath, mode, source_win, opts)
	local label = (opts and opts.label) or 'pipeline'
	local winid = source_win or vim.api.nvim_get_current_win()

	if _states[winid] then
		_states[winid].stop(false)
	end

	local token = {}
	_tokens[winid] = token

	local anim_buf = nil
	local anim_win = nil
	local anim_timer = nil
	local cur_id = nil
	local frame_paths = nil
	local frame_tmpdir = nil
	local result_cleanup = nil
	local cancel_pipeline = nil

	local anim_frames = {}
	local anim_started = false
	local anim_frame_idx = 1
	local paused = false

	local fps = (pipeline_cfg.renderer and pipeline_cfg.renderer.fps) or 12
	local delay_ms = math.max(1, math.floor(1000 / fps))
	local progressive = not (pipeline_cfg.renderer and pipeline_cfg.renderer.progressive == false)

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
		require('glimpse.renderer').setup_animation_buf(b, w, id, gc, gr, wc, wr, filepath)
		require('glimpse.preview_state').mark(b)
		vim.cmd('redraw')
		cur_id = id
		vim.api.nvim_create_autocmd('BufDelete', {
			buffer = b,
			once = true,
			callback = function()
				cleanup(true)
			end,
		})
	end

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
			vim.notify('[glimpse] ' .. label .. ' pipeline failed: ' .. (err or 'unknown'), vim.log.levels.WARN)
			_states[winid] = nil
			_tokens[winid] = nil
			return
		end

		if result.path then
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

		local paths = result.frames
		local tmpdir = result.tmpdir

		if not paths or #paths == 0 then
			vim.notify('[glimpse] ' .. label .. ' pipeline: sequence produced no frames', vim.log.levels.WARN)
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
			if #anim_frames >= 2 then
				anim_started = true
				anim_timer = vim.uv.new_timer()
				anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
			else
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
				end, { buffer = anim_buf, silent = true, desc = 'Toggle animation' })
				vim.keymap.set('n', seek_fwd_key, function()
					jump_to_frame(anim_frame_idx + 1)
				end, { buffer = anim_buf, silent = true, desc = 'Seek forward 1 frame' })
				vim.keymap.set('n', seek_bwd_key, function()
					jump_to_frame(anim_frame_idx - 1)
				end, { buffer = anim_buf, silent = true, desc = 'Seek backward 1 frame' })
			end
		end
		if progressive and #anim_frames == 2 and not anim_started then
			anim_started = true
			anim_timer = vim.uv.new_timer()
			anim_timer:start(delay_ms, 0, vim.schedule_wrap(advance))
		end
	end)
end

--- Shorthand for M.run with mode='show'.
--- @param pipeline_cfg GlimpsePipelineConfig
--- @param filepath string
--- @param source_win? number
--- @param opts? { label?: string }
function M.show(pipeline_cfg, filepath, source_win, opts)
	M.run(pipeline_cfg, filepath, 'show', source_win, opts)
end

--- Shorthand for M.run with mode='preview'.
--- @param pipeline_cfg GlimpsePipelineConfig
--- @param filepath string
--- @param source_win? number
--- @param opts? { label?: string }
function M.preview(pipeline_cfg, filepath, source_win, opts)
	M.run(pipeline_cfg, filepath, 'preview', source_win, opts)
end

--- Cancel any in-flight pipeline render for the given window.
--- Keeps the preview window alive so the next call can reuse it.
--- @param winid? number Defaults to current window
function M.cancel(winid)
	local w = winid or vim.api.nvim_get_current_win()
	if _states[w] then
		_states[w].stop(false)
	end
	_release_static_result(w)
end

return M
