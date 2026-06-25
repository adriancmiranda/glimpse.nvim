--- Image placement management for Neovim buffers.
--- Uses Unicode placeholders via Kitty Graphics Protocol.

local kitty = require('glimpse.kitty')
local placement_state = require('glimpse.placement_state')
local preview_state = require('glimpse.preview_state')
local util = require('glimpse.util')

local M = {}

local ns = vim.api.nvim_create_namespace('glimpse')
local PLACEHOLDER = vim.fn.nr2char(0x10EEEE)

-- Diacritics used to encode row/col
-- luacheck: push ignore 631
local diacritics_hex = vim.split(
	'0305,030D,030E,0310,0312,033D,033E,033F,0346,034A,034B,034C,0350,0351,0352,0357,035B,0363,0364,0365,0366,0367,0368,0369,036A,036B,036C,036D,036E,036F,0483,0484,0485,0486,0487,0592,0593,0594,0595,0597,0598,0599,059C,059D,059E,059F,05A0,05A1,05A8,05A9,05AB,05AC,05AF,05C4,0610,0611,0612,0613,0614,0615,0616,0617,0657,0658,0659,065A,065B,065D,065E,06D6,06D7,06D8,06D9,06DA,06DB,06DC,06DF,06E0,06E1,06E2,06E4,06E7,06E8,06EB,06EC,0730,0732,0733,0735,0736,073A,073D,073F,0740,0741,0743,0745,0747,0749,074A,07EB,07EC,07ED,07EE,07EF,07F0,07F1,07F3,0816,0817,0818,0819,081B,081C,081D,081E,081F,0820,0821,0822,0823,0825,0826,0827,0829,082A,082B,082C,082D,0951,0953,0954,0F82,0F83,0F86,0F87,135D,135E,135F,17DD,193A,1A17,1A75,1A76,1A77,1A78,1A79,1A7A,1A7B,1A7C,1B6B,1B6D,1B6E,1B6F,1B70,1B71,1B72,1B73,1CD0,1CD1,1CD2,1CDA,1CDB,1CE0,1DC0,1DC1,1DC3,1DC4,1DC5,1DC6,1DC7,1DC8,1DC9,1DCB,1DCC,1DD1,1DD2,1DD3,1DD4,1DD5,1DD6,1DD7,1DD8,1DD9,1DDA,1DDB,1DDC,1DDD,1DDE,1DDF,1DE0,1DE1,1DE2,1DE3,1DE4,1DE5,1DE6,1DFE,20D0,20D1,20D4,20D5,20D6,20D7,20DB,20DC,20E1,20E7,20E9,20F0,2CEF,2CF0,2CF1,2DE0,2DE1,2DE2,2DE3,2DE4,2DE5,2DE6,2DE7,2DE8,2DE9,2DEA,2DEB,2DEC,2DED,2DEE,2DEF,2DF0,2DF1,2DF2,2DF3,2DF4,2DF5,2DF6,2DF7,2DF8,2DF9,2DFA,2DFB,2DFC,2DFD,2DFE,2DFF,A66F,A67C,A67D,A6F0,A6F1,A8E0,A8E1,A8E2,A8E3,A8E4,A8E5,A8E6,A8E7,A8E8,A8E9,A8EA,A8EB,A8EC,A8ED,A8EE,A8EF,A8F0,A8F1,AAB0,AAB2,AAB3,AAB7,AAB8,AABE,AABF,AAC1,FE20,FE21,FE22,FE23,FE24,FE25,FE26,10A0F,10A38,1D185,1D186,1D187,1D188,1D189,1D1AA,1D1AB,1D1AC,1D1AD,1D242,1D243,1D244',
	','
)
-- luacheck: pop

local positions = {}
for k, hex in ipairs(diacritics_hex) do
	positions[k] = vim.fn.nr2char(tonumber(hex, 16))
end

local request_counter = 0

-- One-deep pending slot: when a conversion is already in-flight for a buf,
-- subsequent rerender calls store a flag here instead of killing + respawning.
-- The completion callback dispatches exactly one follow-up if the flag is set,
-- capping N rapid resize events at 2 spawns regardless of N.
local _pending_rerender = {}

local function file_signature(path)
	local stat = vim.uv.fs_stat(path)
	if not stat then
		return nil
	end
	return {
		size = stat.size,
		mtime_sec = stat.mtime.sec,
		mtime_nsec = stat.mtime.nsec,
		ctime_sec = stat.ctime and stat.ctime.sec or nil,
		ctime_nsec = stat.ctime and stat.ctime.nsec or nil,
		ino = stat.ino,
	}
end

local function same_signature(left, right)
	if left == nil or right == nil then
		return false
	end
	return left.size == right.size
		and left.mtime_sec == right.mtime_sec
		and left.mtime_nsec == right.mtime_nsec
		and left.ctime_sec == right.ctime_sec
		and left.ctime_nsec == right.ctime_nsec
		and left.ino == right.ino
end

local function window_signature(win)
	if win == nil or win == -1 or not vim.api.nvim_win_is_valid(win) then
		return nil, nil
	end
	return vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
end

--- Generate a placeholder grid as real lines in the buffer.
--- @param buf number
--- @param image_id number
--- @param cols number
--- @param rows number
local function render_grid(buf, image_id, cols, rows)
	local height = math.min(#positions, rows)
	local width = math.min(#positions, cols)

	local hl_name = 'ImagePreview' .. image_id
	vim.api.nvim_set_hl(0, hl_name, { fg = image_id, nocombine = true })

	-- Generate placeholder lines
	local lines = {}
	for r = 1, height do
		local line = {}
		for c = 1, width do
			line[#line + 1] = PLACEHOLDER .. positions[r] .. positions[c]
		end
		lines[#lines + 1] = table.concat(line)
	end

	-- Write real lines into the buffer
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false

	-- Apply highlighting via extmarks
	for i = 0, #lines - 1 do
		vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
			end_col = #lines[i + 1],
			hl_group = hl_name,
		})
	end
end

--- Render an image in the buffer.
--- @param buf number
--- @param filepath string
--- @param opts? { listed?: boolean, bufname?: string, winid?: integer }
--- @param on_done? fun()
--- @return ImagePlacement
function M.render(buf, filepath, opts, on_done)
	opts = opts or {}
	local existing = placement_state.get(buf)
	local signature = file_signature(filepath)
	local buffer_name = opts.bufname or filepath
	local win = opts.winid or vim.fn.bufwinid(buf)
	local cols, rows = window_signature(win)
	if
		existing
		and util.same_path(existing.filepath, filepath)
		and same_signature(existing.signature, signature)
		and (cols == nil or rows == nil or (existing.win_cols == cols and existing.win_rows == rows))
	then
		pcall(vim.api.nvim_buf_set_name, buf, buffer_name)
		vim.bo[buf].buflisted = opts.listed or false
		if opts.listed then
			vim.bo[buf].bufhidden = 'hide'
		end
		if on_done then
			on_done()
		end
		return existing
	end
	if existing then
		M.close(buf)
	end

	request_counter = request_counter + 1
	local req_id = request_counter

	local placement = {
		buf = buf,
		filepath = filepath,
		signature = signature,
		image_id = nil,
		closed = false,
		created_at = vim.uv.hrtime(),
		request_id = req_id,
		win_cols = cols,
		win_rows = rows,
	}
	placement_state.set(buf, placement)

	pcall(vim.api.nvim_buf_set_name, buf, buffer_name)
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = 'image'
	vim.bo[buf].buflisted = opts.listed or false
	if opts.listed then
		vim.bo[buf].bufhidden = 'hide'
	end

	if win == -1 then
		return placement
	end
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = 'no'
	vim.wo[win].foldcolumn = '0'
	vim.wo[win].wrap = false
	vim.wo[win].statuscolumn = ''
	vim.wo[win].list = false
	vim.wo[win].spell = false

	-- Show loading indicator
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', require('glimpse').get_config().loading.text })
	vim.bo[buf].modifiable = false

	local win_cols = vim.api.nvim_win_get_width(win)
	local win_rows = vim.api.nvim_win_get_height(win)

	-- Cancel the previous conversion job if it is still running
	if placement.job_id then
		pcall(vim.fn.jobstop, placement.job_id)
		placement.job_id = nil
	end

	placement.job_id = kitty.transmit_async(
		filepath,
		{ width = win_cols, height = win_rows },
		function(id, err, w_px, h_px)
			placement.job_id = nil
			if err or not id then
				if placement.closed or placement.request_id ~= req_id or not vim.api.nvim_buf_is_valid(buf) then
					return
				end
				vim.notify('[glimpse] ' .. (err or 'render failed'), vim.log.levels.WARN)
				return
			end
			-- Discard if the placement changed (race condition)
			if placement.closed or placement.request_id ~= req_id then
				kitty.delete(id)
				return
			end
			if not vim.api.nvim_buf_is_valid(buf) then
				kitty.delete(id)
				return
			end
			if not w_px or not h_px then
				return
			end
			placement.image_id = id
			placement.win_cols = win_cols
			placement.win_rows = win_rows
			local grid_cols = math.min(win_cols, math.ceil(w_px / require('glimpse').get_config().cell_size.width))
			local grid_rows = math.min(win_rows, math.ceil(h_px / require('glimpse').get_config().cell_size.height))
			render_grid(buf, id, grid_cols, grid_rows)
			if on_done then
				on_done()
			end
		end
	)

	return placement
end

--- Find the buffer currently tracking a filepath.
--- @param filepath string
--- @return number|nil
function M.find_by_filepath(filepath)
	return placement_state.find_by_filepath(filepath)
end

--- Suppress an image: hide it and block all rerenders until unsuppressed.
--- Used when a float (e.g. Oil) opens over the image window so neither the
--- original placement nor any in-flight async callback bleeds through the float.
--- @param buf number
function M.suppress(buf)
	local placement = placement_state.get(buf)
	if not placement then
		return
	end
	-- Cancel any in-flight transmit job and invalidate request_id so its
	-- callback is discarded even if the job already completed.
	if placement.job_id then
		pcall(vim.fn.jobstop, placement.job_id)
		placement.job_id = nil
	end
	_pending_rerender[buf] = nil
	request_counter = request_counter + 1
	placement.request_id = request_counter
	if placement.image_id then
		kitty.delete(placement.image_id)
		placement.image_id = nil
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	placement.suppressed = true
end

--- Lift suppression so rerenders are allowed again.
--- @param buf number
function M.unsuppress(buf)
	local placement = placement_state.get(buf)
	if placement then
		placement.suppressed = false
	end
end

--- Close and clean up a placement.
--- @param buf number
function M.close(buf)
	_pending_rerender[buf] = nil
	local placement = placement_state.get(buf)
	if not placement then
		preview_state.unmark(buf)
		return
	end
	placement.closed = true
	if placement.image_id then
		kitty.delete(placement.image_id)
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	placement_state.remove(buf)
	preview_state.unmark(buf)
end

--- Register an existing placement for tracking.
--- @param buf number
--- @param filepath string
function M.register(buf, filepath)
	if placement_state.get(buf) then
		return
	end
	placement_state.set(buf, {
		buf = buf,
		filepath = filepath,
		signature = file_signature(filepath),
		image_id = nil,
		closed = false,
		created_at = vim.uv.hrtime(),
	})
end

--- Re-render an existing placement (keep the old one until the new one is ready).
--- @param buf number
--- @param opts? { force?: boolean }
function M.rerender(buf, opts)
	opts = opts or {}
	local placement = placement_state.get(buf)
	if not placement then
		return
	end
	if placement.suppressed then
		return
	end
	-- Skip if it was created less than 500ms ago
	local created_at = placement.created_at or 0
	if not opts.force and created_at > 0 and (vim.uv.hrtime() - created_at) < 500e6 then
		return
	end
	local filepath = placement.filepath

	-- Animation buffers use virtual paths; rerender is not supported yet
	if filepath and filepath:match('^glimpse://preview/') then
		return
	end

	local old_id = placement.image_id

	-- If a conversion is already in-flight, invalidate it and store a pending
	-- flag instead of kill+respawn. The completion callback will fire exactly
	-- one follow-up render with the latest window dimensions.
	if placement.job_id then
		request_counter = request_counter + 1
		placement.request_id = request_counter
		_pending_rerender[buf] = true
		return
	end

	request_counter = request_counter + 1
	local req_id = request_counter
	placement.request_id = req_id

	local win = vim.fn.bufwinid(buf)
	if win == -1 then
		return
	end
	local cols = vim.api.nvim_win_get_width(win)
	local rows = vim.api.nvim_win_get_height(win)

	local function dispatch_pending()
		if _pending_rerender[buf] and not placement.closed and vim.api.nvim_buf_is_valid(buf) then
			_pending_rerender[buf] = nil
			vim.schedule(function()
				M.rerender(buf, { force = true })
			end)
		end
	end

	placement.job_id = kitty.transmit_async(filepath, { width = cols, height = rows }, function(id, err, w_px, h_px)
		placement.job_id = nil
		if err or not id then
			if placement.closed or placement.request_id ~= req_id or not vim.api.nvim_buf_is_valid(buf) then
				dispatch_pending()
				return
			end
			dispatch_pending()
			return
		end
		if placement.closed or placement.request_id ~= req_id then
			kitty.delete(id)
			dispatch_pending()
			return
		end
		if not vim.api.nvim_buf_is_valid(buf) then
			kitty.delete(id)
			return
		end
		-- Remove the old one
		if old_id then
			kitty.delete(old_id)
		end
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		-- Apply the new one
		if not w_px or not h_px then
			dispatch_pending()
			return
		end
		placement.image_id = id
		placement.win_cols = cols
		placement.win_rows = rows
		local grid_cols = math.min(cols, math.ceil(w_px / require('glimpse').get_config().cell_size.width))
		local grid_rows = math.min(rows, math.ceil(h_px / require('glimpse').get_config().cell_size.height))
		render_grid(buf, id, grid_cols, grid_rows)
		dispatch_pending()
	end)
end

--- Check whether a buffer has an active placement.
--- @param buf number
--- @return boolean
function M.has_placement(buf)
	return placement_state.has(buf)
end

--- Check whether the placement needs a re-render (the image may have been lost).
--- @param buf number
--- @return boolean
function M.needs_rerender(buf)
	return placement_state.needs_rerender(buf)
end

--- Set up a buffer for animation: apply window options and write placeholder grid.
--- Used by callers that manage frame transmission directly (e.g. video animation).
--- @param buf number
--- @param win number
--- @param image_id number
--- @param grid_cols number
--- @param grid_rows number
--- @param win_cols number
--- @param win_rows number
--- @param filepath? string Source file path; its basename is used as the buffer name
function M.setup_animation_buf(buf, win, image_id, grid_cols, grid_rows, win_cols, win_rows, filepath)
	local existing = placement_state.get(buf)
	local old_image_id = existing and existing.image_id or nil
	local name = filepath and util.preview_buf_name(filepath) or ('glimpse://preview/' .. tostring(image_id))
	pcall(vim.api.nvim_buf_set_name, buf, name)
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = 'image'
	vim.bo[buf].buflisted = false
	if vim.api.nvim_win_is_valid(win) then
		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = 'no'
		vim.wo[win].foldcolumn = '0'
		vim.wo[win].wrap = false
		vim.wo[win].statuscolumn = ''
		vim.wo[win].list = false
		vim.wo[win].spell = false
	end
	request_counter = request_counter + 1
	placement_state.set(buf, {
		buf = buf,
		filepath = name,
		signature = nil,
		image_id = image_id,
		closed = false,
		created_at = vim.uv.hrtime(),
		request_id = request_counter,
		win_cols = win_cols,
		win_rows = win_rows,
	})
	-- Plain grid; reuse a single per-buffer group to avoid highlight exhaustion
	local hl_name = 'GlimpseAnim' .. tostring(buf)
	vim.api.nvim_set_hl(0, hl_name, { fg = image_id, nocombine = true })
	local height = math.min(#positions, grid_rows)
	local width = math.min(#positions, grid_cols)
	local lines = {}
	for r = 1, height do
		local line = {}
		for c = 1, width do
			line[#line + 1] = PLACEHOLDER .. positions[r] .. positions[c]
		end
		lines[r] = table.concat(line)
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	for i = 0, #lines - 1 do
		vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
			end_col = #lines[i + 1],
			hl_group = hl_name,
		})
	end
	if old_image_id and old_image_id ~= image_id then
		vim.schedule(function()
			pcall(kitty.delete, old_image_id)
		end)
	end
end

--- Update the fg color of the animation highlight group for this buffer.
--- Reuses the same group (GlimpseAnim<buf>) to avoid the "too many highlight
--- groups" error. Neovim sends updated fg codes on the next redraw, which
--- triggers Kitty to re-render the image at the placeholder positions.
--- @param buf number
--- @param new_id number New image ID to display
function M.update_animation_highlight(buf, new_id)
	local hl_name = 'GlimpseAnim' .. tostring(buf)
	vim.api.nvim_set_hl(0, hl_name, { fg = new_id, nocombine = true })
	local placement = placement_state.get(buf)
	if placement then
		placement.image_id = new_id
	end
end

--- Return the active placement for a buffer, or nil.
--- Exposes image_id so callers can add animation frames to an existing render.
--- @param buf number
--- @return ImagePlacement|nil
function M.get_placement(buf)
	return placement_state.get(buf)
end

return M
