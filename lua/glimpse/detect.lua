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

--- Reseta o cache de detecção (usado em testes).
---@private
function M._reset()
	_cached_terminal = nil
	_detected = false
end

--- Detecta o terminal emulador atual (inclusive dentro do tmux).
--- Resultado é cacheado para evitar chamadas repetidas a vim.fn.system.
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

--- Verifica se o terminal suporta renderização inline (Kitty Graphics Protocol).
--- @return boolean
function M.supports_inline()
	local term = M.get_terminal()
	return supports_inline[term] or false
end

--- Verifica se estamos dentro do tmux.
--- @return boolean
function M.in_tmux()
	return os.getenv('TMUX') ~= nil
end

return M
