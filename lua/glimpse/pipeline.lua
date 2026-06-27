--- Document and diagram conversion pipeline.
--- Steps-based abstraction: each step's output feeds the next (like shell pipes).
---
--- A pipeline entry describes one conversion command:
---@class GlimpsePipelineEntry
---@field command string External command name
---@field args string[]|fun(input: string, output: string, extra: integer): string[] Args or factory
---@field type? 'static'|'sequence' Default: 'static'
---@field frames? integer Number of frames to generate when type='sequence' (default: 36)
---@field output_ext? string Extension for the output file when type='static' (default: '.png')
---@field output_pattern? string|fun(output: string, extra: integer): string File path actually produced by the command

---@class GlimpsePipelineRendererConfig
---@field type? 'inline'|'pane' Rendering target (default: 'inline')
---@field fps? number Animation frame rate (default: 12)
---@field progressive? boolean Start playing before all frames are ready (default: true)
---@field auto_play? boolean Start animation automatically; false = manual seek with h/l, CR toggles (default: true)

---@class GlimpsePipelineKeysConfig
---@field toggle? string Keymap to toggle play/pause (default: '<CR>')
---@field seek_forward? string Keymap to advance one frame (default: 'l')
---@field seek_backward? string Keymap to go back one frame (default: 'h')

---@class GlimpsePipelineConfig
---@field steps? GlimpsePipelineEntry[] Sequential chain: each step's output feeds the next
---@field previewers? GlimpsePipelineEntry[] Alternative commands tried in order until one succeeds
---@field renderer? GlimpsePipelineRendererConfig Animation and rendering options
---@field keys? GlimpsePipelineKeysConfig Keymaps for animation playback

---@class GlimpsePipelineResult
---@field path string Final output file path
---@field cleanup fun() Remove the final output and retained intermediate artifacts

---@class GlimpsePipelineFrameResult
---@field frames string[] Frame file paths
---@field tmpdir string Temp directory containing the frames
---@field cleanup fun() Remove the frame directory and retained intermediate artifacts

local M = {}

--- Resolve an extension-specific pipeline before the type-level fallback.
--- @param pipelines table<string, GlimpsePipelineConfig>|nil
--- @param kind string
--- @param filepath string
--- @return GlimpsePipelineConfig|nil
function M.resolve_config(pipelines, kind, filepath)
	if not pipelines then
		return nil
	end
	local ext = filepath:match('(%.[^./]+)$')
	if ext then
		local override = pipelines[ext:lower()]
		if override then
			return override
		end
	end
	return pipelines[kind]
end

local function jobstart_error(job_id)
	if job_id == 0 then
		return 'invalid arguments'
	end
	if job_id == -1 then
		return 'command is not executable'
	end
	return nil
end

--- Resolve args for a pipeline entry.
--- @param entry GlimpsePipelineEntry
--- @param input string
--- @param output string
--- @param extra? integer Frame index (sequence) or fps (assembly); defaults to 0
--- @return string[]
local function resolve_args(entry, input, output, extra)
	if type(entry.args) == 'function' then
		return entry.args(input, output, extra or 0) --[[@as string[] ]]
	end
	local resolved = {}
	for _, arg in
		ipairs(entry.args --[[@as string[] ]])
	do
		if arg == '{input}' then
			resolved[#resolved + 1] = input
		elseif arg == '{output}' then
			resolved[#resolved + 1] = output
		else
			resolved[#resolved + 1] = arg
		end
	end
	return resolved
end

--- Resolve the file path a static command actually produces.
--- @param entry GlimpsePipelineEntry
--- @param output string Requested output path
--- @param extra? integer
--- @return string
local function resolve_output(entry, output, extra)
	if type(entry.output_pattern) == 'function' then
		return entry.output_pattern(output, extra or 0)
	end
	if type(entry.output_pattern) == 'string' then
		return entry.output_pattern:gsub('{output}', function()
			return output
		end)
	end
	return output
end

--- Run one frame of a sequence entry (one jobstart per frame).
--- @param entry GlimpsePipelineEntry
--- @param input string
--- @param output string Frame-specific output path
--- @param frame integer 0-based frame index
--- @param on_done fun(output: string|nil, err: string|nil)
--- @return fun() cancel
local function run_frame(entry, input, output, frame, on_done)
	if vim.fn.executable(entry.command) == 0 then
		vim.schedule(function()
			on_done(nil, entry.command .. ' not found')
		end)
		return function() end
	end

	local args = resolve_args(entry, input, output, frame)
	local cmd = vim.list_extend({ entry.command }, args)
	local cancelled = false

	local job_id = vim.fn.jobstart(cmd, {
		on_exit = function(_, code)
			if cancelled then
				return
			end
			if code ~= 0 then
				vim.schedule(function()
					on_done(nil, entry.command .. ' exited with code ' .. code .. ' on frame ' .. frame)
				end)
				return
			end
			if not vim.uv.fs_stat(output) then
				vim.schedule(function()
					on_done(nil, entry.command .. ' did not produce frame ' .. frame)
				end)
				return
			end
			vim.schedule(function()
				on_done(output, nil)
			end)
		end,
	})
	local start_err = jobstart_error(job_id)
	if start_err then
		vim.schedule(function()
			on_done(nil, entry.command .. ': failed to start job: ' .. start_err)
		end)
		return function() end
	end

	return function()
		cancelled = true
		pcall(vim.fn.jobstop, job_id)
	end
end

--- Run one static entry asynchronously.
--- Calls on_done(output_path, nil) on success or on_done(nil, err) on failure.
--- Returns a cancel function.
--- @param entry GlimpsePipelineEntry
--- @param input string
--- @param output string
--- @param on_done fun(output: string|nil, err: string|nil)
--- @param extra? integer Passed as third arg to args function (e.g. fps for assembly steps)
--- @return fun() cancel
local function run_entry(entry, input, output, on_done, extra)
	if vim.fn.executable(entry.command) == 0 then
		vim.schedule(function()
			on_done(nil, entry.command .. ' not found')
		end)
		return function() end
	end

	local args = resolve_args(entry, input, output, extra)
	local cmd = vim.list_extend({ entry.command }, args)
	local actual_output = resolve_output(entry, output, extra)
	local cancelled = false

	local job_id = vim.fn.jobstart(cmd, {
		on_exit = function(_, code)
			if cancelled then
				return
			end
			if code ~= 0 then
				vim.schedule(function()
					on_done(nil, entry.command .. ' exited with code ' .. code)
				end)
				return
			end
			if not vim.uv.fs_stat(actual_output) then
				vim.schedule(function()
					on_done(nil, entry.command .. ' did not produce output')
				end)
				return
			end
			vim.schedule(function()
				on_done(actual_output, nil)
			end)
		end,
	})
	local start_err = jobstart_error(job_id)
	if start_err then
		vim.schedule(function()
			on_done(nil, entry.command .. ': failed to start job: ' .. start_err)
		end)
		return function() end
	end

	return function()
		cancelled = true
		pcall(vim.fn.jobstop, job_id)
	end
end

--- Run a sequence entry: generate N frames sequentially into tmpdir.
--- Each frame output path is tmpdir/frame_NNNN.png.
--- Calls on_done(frame_paths, nil) on success or on_done(nil, err) on failure.
--- Returns a cancel function.
--- @param entry GlimpsePipelineEntry
--- @param input string Absolute path to the source file
--- @param tmpdir string Directory to write frame files into
--- @param on_done fun(frames: string[]|nil, err: string|nil)
--- @param on_frame? fun(path: string, frame_index: integer) Called after each frame is written (0-based index)
--- @return fun() cancel
function M.run_sequence(entry, input, tmpdir, on_done, on_frame)
	local total = entry.frames or 36
	local frame_paths = {}
	local cancelled = false
	local cancel_current = function() end

	local function run_next(i)
		if cancelled then
			return
		end
		if i > total then
			on_done(frame_paths, nil)
			return
		end
		local output = string.format('%s/frame_%04d.png', tmpdir, i)
		cancel_current = run_frame(entry, input, output, i - 1, function(out, err)
			if cancelled then
				return
			end
			if not out then
				on_done(nil, err)
				return
			end
			frame_paths[#frame_paths + 1] = out
			if on_frame then
				on_frame(out, i - 1)
			end
			run_next(i + 1)
		end)
	end

	run_next(1)

	return function()
		cancelled = true
		cancel_current()
	end
end

--- Run a steps chain: each step's output feeds the next (like shell pipes).
---
--- on_done receives one of:
---   { path = string }                        terminal step produced a single file
---   { frames = string[], tmpdir = string }   terminal step was a sequence
---
--- Returns a cancel function.
--- @param config GlimpsePipelineConfig
--- @param input string Absolute path to the source file
--- @param on_done fun(result: table|nil, err: string|nil)
--- @param on_frame? fun(path: string, frame_index: integer) Forwarded to sequence steps only
--- @return fun() cancel
local function run_chain(config, input, on_done, on_frame)
	local steps = config.steps or {}
	local fps = (config.renderer and config.renderer.fps) or 12

	if #steps == 0 then
		vim.schedule(function()
			on_done(nil, 'no steps configured')
		end)
		return function() end
	end

	local cancelled = false
	local cancel_current = function() end
	local artifacts = {}

	local function track(path, kind)
		artifacts[path] = kind
	end

	local function cleanup_artifacts(keep)
		for path, kind in pairs(artifacts) do
			if path ~= keep then
				if kind == 'dir' then
					vim.fn.delete(path, 'rf')
				else
					os.remove(path)
				end
				artifacts[path] = nil
			end
		end
	end

	local function finish(result, err, keep)
		cleanup_artifacts(keep)
		if result then
			result.cleanup = function()
				cleanup_artifacts()
			end
		end
		on_done(result, err)
	end

	local function run_step(i, current_input)
		if cancelled then
			return
		end

		local step = steps[i]
		local is_last = (i == #steps)

		if step.type == 'sequence' then
			local tmpdir = vim.fn.tempname()
			vim.fn.mkdir(tmpdir, 'p')
			track(tmpdir, 'dir')
			cancel_current = M.run_sequence(step, current_input, tmpdir, function(paths, err)
				if cancelled then
					return
				end
				if not paths then
					finish(nil, err)
					return
				end
				if is_last then
					finish({ frames = paths, tmpdir = tmpdir }, nil, tmpdir)
				else
					run_step(i + 1, tmpdir)
				end
			end, on_frame)
		else
			local ext = step.output_ext or '.png'
			local output = vim.fn.tempname() .. ext
			track(resolve_output(step, output, fps), 'file')
			cancel_current = run_entry(step, current_input, output, function(out, err)
				if cancelled then
					return
				end
				if not out then
					finish(nil, err)
					return
				end
				if is_last then
					finish({ path = out }, nil, out)
				else
					run_step(i + 1, out)
				end
			end, fps)
		end
	end

	run_step(1, input)

	return function()
		cancelled = true
		cancel_current()
		cleanup_artifacts()
	end
end

--- Run a pipeline config.
--- `previewers` are alternatives; `steps` remain a sequential conversion chain.
--- @param config GlimpsePipelineConfig
--- @param input string Absolute path to the source file
--- @param on_done fun(result: table|nil, err: string|nil)
--- @param on_frame? fun(path: string, frame_index: integer)
--- @return fun() cancel
function M.run_steps(config, input, on_done, on_frame)
	local previewers = config.previewers or {}
	if #previewers == 0 then
		return run_chain(config, input, on_done, on_frame)
	end

	local cancelled = false
	local cancel_current = function() end
	local errors = {}

	local function run_previewer(i)
		if cancelled then
			return
		end
		local previewer = previewers[i]
		if not previewer then
			on_done(nil, 'no previewer succeeded: ' .. table.concat(errors, '; '))
			return
		end

		local completed = false
		local cancel = run_chain(
			{
				steps = { previewer },
				renderer = config.renderer,
			},
			input,
			function(result, err)
				completed = true
				if cancelled then
					if result and result.cleanup then
						result.cleanup()
					end
					return
				end
				if result then
					on_done(result, nil)
					return
				end
				errors[#errors + 1] = err or (previewer.command .. ' failed')
				run_previewer(i + 1)
			end,
			on_frame
		)
		if not completed then
			cancel_current = cancel
		end
	end

	run_previewer(1)

	return function()
		cancelled = true
		cancel_current()
	end
end

return M
