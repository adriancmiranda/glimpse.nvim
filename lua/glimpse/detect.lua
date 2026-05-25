local M = {}

local term_map = {
	WezTerm = 'wezterm',
	kitty = 'kitty',
	ghostty = 'ghostty',
	iTerm2 = 'iterm',
}

local termname_map = {
	['xterm-kitty'] = 'kitty',
	['xterm-ghostty'] = 'ghostty',
}

local supports_inline = {
	kitty = true,
	ghostty = true,
}

local _cached_terminal = nil
local _detected = false

--- Reset the detection cache (used in tests).
---@private
function M._reset()
	_cached_terminal = nil
	_detected = false
end

--- Detect the current terminal emulator (including inside tmux).
--- The result is cached to avoid repeated vim.fn.system calls.
--- @return string|nil terminal 'wezterm' | 'kitty' | 'ghostty' | 'iterm' | nil
function M.get_terminal()
	if _detected then
		return _cached_terminal
	end
	_detected = true

	local term = os.getenv('TERM_PROGRAM')

	if os.getenv('TMUX') then
		local output = vim.fn.system({ 'tmux', 'display-message', '-p', '#{client_termname}' })
		local termname = vim.trim(output)
		_cached_terminal = termname_map[termname] or 'wezterm'
	else
		_cached_terminal = term_map[term] or termname_map[os.getenv('TERM') or '']
	end

	return _cached_terminal
end

--- Check whether the terminal supports inline rendering (Kitty Graphics Protocol).
--- @return boolean
function M.supports_inline()
	local term = M.get_terminal()
	return supports_inline[term] or false
end

--- Check whether we are inside tmux.
--- @return boolean
function M.in_tmux()
	return os.getenv('TMUX') ~= nil
end

return M
