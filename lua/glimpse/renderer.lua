--- Image placement management for Neovim buffers.
--- Uses Unicode placeholders via Kitty Graphics Protocol.

local kitty = require('glimpse.kitty')

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

--- @class ImagePlacement
--- @field buf number
--- @field image_id number|nil
--- @field filepath string
--- @field closed boolean
--- @field request_id number

--- @type table<number, ImagePlacement>
local placements = {}

-- Bounded pool of highlight group names to avoid E849 "too many highlight groups".
-- Each active buffer leases one slot; the slot is released when the buffer closes.
local POOL_SIZE = 64
local _pool_owner = {} -- slot_index (0-based) -> buf or nil
local _buf_slot = {} -- buf -> slot_index
local _wipeout_autocmd_id = {} -- buf -> autocmd id, so stale autocmds can be deleted
local _pool_exhausted_count = 0 -- number of placements currently marked pool_exhausted

-- Clears pool_exhausted on a placement and decrements the counter.
-- Centralised here so all three recovery sites (immediate, deferred, M.close)
-- stay in sync and a future refactor cannot forget one.
local function _decrement_exhausted(p)
	if p.pool_exhausted then
		_pool_exhausted_count = math.max(0, _pool_exhausted_count - 1)
		p.pool_exhausted = nil
	end
end

-- Register a one-shot BufWipeout autocmd so the pool slot is released even
-- when a buffer is destroyed outside M.close() (:bwipeout, another plugin).
-- Defined before _acquire_slot (which calls it) so no forward declaration is
-- needed. The autocmd ID is stored so _release_slot can delete it explicitly
-- when the buffer is reused before wipeout, preventing accumulation.
local function _ensure_wipeout_guard(buf)
	if _wipeout_autocmd_id[buf] then
		return
	end
	local id = vim.api.nvim_create_autocmd('BufWipeout', {
		buffer = buf,
		once = true,
		callback = function()
			_wipeout_autocmd_id[buf] = nil
			M.close(buf)
		end,
	})
	_wipeout_autocmd_id[buf] = id
end

local function _evict_invalid_owner(i, owner, buf)
	local p = placements[owner]
	if p then
		-- Mark closed BEFORE clearing placements[owner]. In-flight
		-- kitty.transmit_async callbacks for this owner still hold a reference
		-- to the old placement table. Setting closed=true ensures they bail out
		-- at the `placement.closed` guard rather than rendering into a buffer
		-- number that Neovim may have recycled for an unrelated buffer.
		p.closed = true
		if p.image_id then
			kitty.delete(p.image_id)
		end
		-- Pool-exhausted buffers never received a BufWipeout guard (the guard is
		-- only registered after a slot is successfully acquired). If such a buffer
		-- becomes invalid without M.close being called, the counter would
		-- permanently over-count without this decrement.
		_decrement_exhausted(p)
	end
	placements[owner] = nil
	local aid = _wipeout_autocmd_id[owner]
	if aid then
		pcall(vim.api.nvim_del_autocmd, aid)
		_wipeout_autocmd_id[owner] = nil
	end
	_buf_slot[owner] = nil
	_pool_owner[i] = buf
	_buf_slot[buf] = i
end

local function _acquire_slot(buf)
	local existing = _buf_slot[buf]
	if existing ~= nil then
		return existing
	end
	-- Single pass: take the first free slot; remember the first invalid-owner
	-- slot as a fallback so we avoid a second full scan.
	local fallback_slot, fallback_owner
	for i = 0, POOL_SIZE - 1 do
		local owner = _pool_owner[i]
		if owner == nil then
			_pool_owner[i] = buf
			_buf_slot[buf] = i
			_ensure_wipeout_guard(buf)
			return i
		end
		if fallback_slot == nil and not vim.api.nvim_buf_is_valid(owner) then
			fallback_slot = i
			fallback_owner = owner
		end
	end
	if fallback_slot ~= nil then
		-- Clear stale placement so a recycled buf number does not inherit old
		-- state (has_placement() and M.render's fast-path both read placements[]).
		-- M.close() cannot be called here: nvim_buf_clear_namespace raises on
		-- an invalid buffer.
		_evict_invalid_owner(fallback_slot, fallback_owner, buf)
		_ensure_wipeout_guard(buf)
		return fallback_slot
	end
	-- Pool exhausted: all 64 slots are owned by live buffers and none could be
	-- reclaimed. Return nil so the caller can abort the render cleanly rather
	-- than forcibly tearing down an unrelated, still-visible preview.
	return nil
end

local function _release_slot(buf)
	local slot = _buf_slot[buf]
	if slot ~= nil then
		_pool_owner[slot] = nil
		_buf_slot[buf] = nil
		-- Delete the pending BufWipeout autocmd so it does not accumulate when
		-- the buffer is reused (re-rendered) before it is actually wiped out.
		local aid = _wipeout_autocmd_id[buf]
		if aid then
			pcall(vim.api.nvim_del_autocmd, aid)
			_wipeout_autocmd_id[buf] = nil
		end
		-- A slot was freed: give the first pool-exhausted placement a chance to
		-- render. Guard on the counter so rapid close loops do not flood the event
		-- queue with empty scans when the pool was never exhausted.
		if _pool_exhausted_count > 0 then
			vim.schedule(function()
				-- Pre-pass: clear pool_exhausted on hidden buffers unconditionally.
				-- This must run even when a visible placement is immediately recovered
				-- below (which returns early). Without this, the first-pass return would
				-- skip the hidden-buffer clearing, leaving those placements flagged
				-- forever and making M.rerender() short-circuit when the user shows them.
				-- For each hidden buffer we also register a one-shot BufWinEnter autocmd
				-- so recovery fires immediately when the user brings it back into view
				-- via :buffer, vsplit, etc. (paths that do not trigger TabEnter/WinResized).
				for pb, p in pairs(placements) do
					if
						p
						and p.pool_exhausted
						and not p.closed
						and vim.api.nvim_buf_is_valid(pb)
						and vim.fn.bufwinid(pb) == -1
					then
						_decrement_exhausted(p)
						local lpb, lp = pb, p
						vim.api.nvim_create_autocmd('BufWinEnter', {
							buffer = lpb,
							once = true,
							callback = function()
								if
									placements[lpb] == lp
									and not lp.pool_exhausted
									and not lp.closed
									and not lp.image_id
									and vim.api.nvim_buf_is_valid(lpb)
								then
									local age_ns = vim.uv.hrtime() - (lp.created_at or 0)
									if age_ns >= 500e6 then
										-- Set the recovery marker so that if this retry fails
										-- the error-path can restore pool_exhausted and keep
										-- the placement in the retry queue.
										lp._recovering = true
										M.rerender(lpb)
									else
										-- Too young for M.rerender's debounce; schedule a
										-- deferred retry just after the window expires.
										local delay_ms = math.ceil((500e6 - age_ns) / 1e6) + 10
										vim.defer_fn(function()
											if
												placements[lpb] == lp
												and not lp.pool_exhausted
												and not lp.closed
												and not lp.image_id
												and vim.api.nvim_buf_is_valid(lpb)
											then
												lp._recovering = true
												M.rerender(lpb)
											end
										end, delay_ms)
									end
								end
							end,
						})
					end
				end
				-- First pass: find and use the first immediately-eligible visible
				-- placement (windowed + past the rerender debounce). If found, consume
				-- the freed slot for it and return without scheduling deferred retries,
				-- which would cause wasted transmit+delete cycles if the slot is taken.
				for pb, p in pairs(placements) do
					if
						p
						and p.pool_exhausted
						and not p.closed
						and vim.api.nvim_buf_is_valid(pb)
						and vim.fn.bufwinid(pb) ~= -1
					then
						local age_ns = vim.uv.hrtime() - (p.created_at or 0)
						if age_ns >= 500e6 then
							p._recovering = true
							_decrement_exhausted(p)
							M.rerender(pb)
							return
						end
					end
				end
				-- Second pass: no immediately-eligible visible placement found.
				-- Schedule a deferred retry for each young windowed placement so
				-- recovery is not permanently lost while the debounce window expires.
				for pb, p in pairs(placements) do
					if p and p.pool_exhausted and not p.closed and vim.api.nvim_buf_is_valid(pb) then
						local winid = vim.fn.bufwinid(pb)
						if winid ~= -1 then
							local age_ns = vim.uv.hrtime() - (p.created_at or 0)
							if age_ns < 500e6 then
								local delay_ms = math.ceil((500e6 - age_ns) / 1e6) + 10
								-- Copy loop locals explicitly so each closure captures its own
								-- pb/p even though Lua generics-for already does this correctly.
								local lpb, lp = pb, p
								vim.defer_fn(function()
									if
										placements[lpb] == lp
										and lp.pool_exhausted
										and not lp.closed
										and vim.api.nvim_buf_is_valid(lpb)
										and vim.fn.bufwinid(lpb) ~= -1
									then
										lp._recovering = true
										_decrement_exhausted(lp)
										M.rerender(lpb)
									end
								end, delay_ms)
							end
						end
					end
				end
			end)
		end
	end
end

-- Re-apply pool slot fg values after a colorscheme change.
-- Colorschemes may reset or redefine highlight groups, wiping the image_id
-- stored in each GlimpseImage<slot> group and causing placeholders to render
-- the wrong image (fg=0 means image ID 0, which is undefined in Kitty).
local _pool_augroup = vim.api.nvim_create_augroup('GlimpsePool', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', {
	group = _pool_augroup,
	callback = function()
		for i = 0, POOL_SIZE - 1 do
			local owned_buf = _pool_owner[i]
			if owned_buf then
				local p = placements[owned_buf]
				if p and p.image_id then
					vim.api.nvim_set_hl(0, 'GlimpseImage' .. i, { fg = p.image_id, nocombine = true })
				end
			end
		end
	end,
})

local request_counter = 0

local function normalize_path(path)
	return vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

local function same_path(left, right)
	if left == right then
		return true
	end
	if left == nil or right == nil then
		return false
	end
	return normalize_path(left) == normalize_path(right)
end

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
-- Returns true on success, false when the image was not rendered (caller
-- should preserve old state rather than clearing it).
local function render_grid(buf, image_id, cols, rows)
	if not vim.api.nvim_buf_is_valid(buf) then
		-- The image was already transmitted; delete it so it does not leak
		-- in the terminal. (The pool-exhausted branch below also calls delete.)
		kitty.delete(image_id)
		return false
	end
	local height = math.min(#positions, rows)
	local width = math.min(#positions, cols)

	local slot = _acquire_slot(buf)
	if slot == nil then
		-- All 64 pool slots are occupied by live buffers. Delete the already-
		-- transmitted image so it does not leak in the terminal, and mark the
		-- placement as pool_exhausted so M.rerender skips it (no churn) while
		-- still allowing recovery when another buffer frees a slot.
		kitty.delete(image_id)
		local p = placements[buf]
		if p then
			p.image_id = nil
			p.pool_exhausted = true
			_pool_exhausted_count = _pool_exhausted_count + 1
			-- Register a BufWipeout guard even though no slot was acquired.
			-- Without this, :bd or a plugin can destroy the buffer and leave
			-- placements[buf] behind; has_placement() then returns true for a
			-- later buffer that reuses the same number, causing the inline
			-- auto-render path to skip it.
			_ensure_wipeout_guard(buf)
		end
		vim.notify('[glimpse] highlight group pool exhausted (>64 simultaneous previews)', vim.log.levels.WARN)
		return false
	end
	local hl_name = 'GlimpseImage' .. slot
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

	-- Clear old extmarks before writing new ones. Done here (not in the caller)
	-- so that a failed render_grid (pool exhausted, invalid buf) does not leave
	-- the buffer without extmarks and with its previous image already deleted.
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	-- Apply highlighting via extmarks
	for i = 0, #lines - 1 do
		vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
			end_col = #lines[i + 1],
			hl_group = hl_name,
		})
	end
	return true
end

--- Render an image in the buffer.
--- @param buf number
--- @param filepath string
--- @param opts? { listed?: boolean }
--- @param on_done? fun()
--- @return ImagePlacement
function M.render(buf, filepath, opts, on_done)
	opts = opts or {}
	local existing = placements[buf]
	local signature = file_signature(filepath)
	local buffer_name = opts.bufname or filepath
	local win = opts.winid or vim.fn.bufwinid(buf)
	local cols, rows = window_signature(win)
	if
		existing
		and existing.image_id
		and not existing.pool_exhausted
		and same_path(existing.filepath, filepath)
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
	placements[buf] = placement

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
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			local placement = placements[buf]
			if
				placement
				and placement.filepath
				and same_path(placement.filepath, filepath)
				and vim.api.nvim_buf_is_valid(buf)
			then
				return buf
			end
		end
	end

	for buf, placement in pairs(placements) do
		if placement.filepath and same_path(placement.filepath, filepath) and vim.api.nvim_buf_is_valid(buf) then
			return buf
		end
	end
end

--- Close and clean up a placement.
--- @param buf number
function M.close(buf)
	local placement = placements[buf]
	if not placement then
		return
	end
	placement.closed = true
	_decrement_exhausted(placement)
	if placement.image_id then
		kitty.delete(placement.image_id)
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	_release_slot(buf)
	placements[buf] = nil
end

--- Register an existing placement for tracking.
--- @param buf number
--- @param filepath string
function M.register(buf, filepath)
	if placements[buf] then
		return
	end
	placements[buf] = {
		buf = buf,
		filepath = filepath,
		signature = file_signature(filepath),
		image_id = nil,
		closed = false,
		created_at = vim.uv.hrtime(),
	}
end

--- Re-render an existing placement (keep the old one until the new one is ready).
--- @param buf number
function M.rerender(buf)
	local placement = placements[buf]
	if not placement then
		return
	end
	-- Skip if it was created less than 500ms ago
	if (vim.uv.hrtime() - (placement.created_at or 0)) < 500e6 then
		return
	end
	-- Skip if the pool was exhausted for this buffer; M.render and _release_slot
	-- handle recovery once a slot becomes available.
	if placement.pool_exhausted then
		return
	end
	local filepath = placement.filepath
	local old_id = placement.image_id

	request_counter = request_counter + 1
	local req_id = request_counter
	placement.request_id = req_id

	local win = vim.fn.bufwinid(buf)
	if win == -1 then
		-- Clear the recovery marker so it does not leak into future calls.
		placement._recovering = nil
		return
	end
	local cols = vim.api.nvim_win_get_width(win)
	local rows = vim.api.nvim_win_get_height(win)

	-- Cancel the previous conversion job if it is still running
	if placement.job_id then
		pcall(vim.fn.jobstop, placement.job_id)
		placement.job_id = nil
	end

	placement.job_id = kitty.transmit_async(filepath, { width = cols, height = rows }, function(id, err, w_px, h_px)
		placement.job_id = nil
		-- Capture and clear the recovery marker before any early return so it
		-- does not leak across retries regardless of which path is taken.
		local was_recovering = placement._recovering
		placement._recovering = nil
		if err or not id then
			-- If this was a recovery attempt (pool_exhausted was cleared to let
			-- M.rerender proceed), restore the exhaustion state on failure so the
			-- placement is retried on the next slot release.
			-- Use was_recovering rather than `not placement.image_id` to avoid
			-- falsely stamping normal first-render or re-render failures that happen
			-- to have image_id=nil (e.g. registered placements, corrupt files).
			if was_recovering and not placement.closed and placement.request_id == req_id then
				placement.pool_exhausted = true
				_pool_exhausted_count = _pool_exhausted_count + 1
				-- The counter was 0 while the transmit was in flight; if a slot was
				-- freed during that window, _release_slot saw count=0 and skipped its
				-- scan. Schedule a new scan now to catch that case.
				vim.schedule(function()
					if _pool_exhausted_count > 0 then
						-- Reuse the standard recovery logic: try to find an eligible
						-- exhausted placement and rerender it.
						for pb, p in pairs(placements) do
							if
								p
								and p.pool_exhausted
								and not p.closed
								and vim.api.nvim_buf_is_valid(pb)
								and vim.fn.bufwinid(pb) ~= -1
							then
								local age_ns = vim.uv.hrtime() - (p.created_at or 0)
								if age_ns >= 500e6 then
									p._recovering = true
									_decrement_exhausted(p)
									M.rerender(pb)
									return
								end
							end
						end
					end
				end)
			end
			return
		end
		if placement.closed or placement.request_id ~= req_id then
			kitty.delete(id)
			return
		end
		if not vim.api.nvim_buf_is_valid(buf) then
			kitty.delete(id)
			return
		end
		if not w_px or not h_px then
			kitty.delete(id)
			return
		end
		placement.image_id = id
		placement.win_cols = cols
		placement.win_rows = rows
		local grid_cols = math.min(cols, math.ceil(w_px / require('glimpse').get_config().cell_size.width))
		local grid_rows = math.min(rows, math.ceil(h_px / require('glimpse').get_config().cell_size.height))
		-- render_grid clears the namespace and writes new extmarks only on
		-- success. Old state (old_id + extmarks) is preserved on failure so
		-- the buffer does not go blank if the slot race is lost mid-rerender.
		if render_grid(buf, id, grid_cols, grid_rows) then
			if old_id then
				kitty.delete(old_id)
			end
		end
	end)
end

--- Check whether a buffer has an active placement.
--- @param buf number
--- @return boolean
function M.has_placement(buf)
	return placements[buf] ~= nil and not placements[buf].closed
end

--- Check whether the placement needs a re-render (the image may have been lost).
--- @param buf number
--- @return boolean
function M.needs_rerender(buf)
	local placement = placements[buf]
	if not placement or placement.closed then
		return false
	end
	-- If there is no image_id, it is still loading - do not re-render
	if not placement.image_id then
		return false
	end
	return true
end

return M
