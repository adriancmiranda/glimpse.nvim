local detect = require('glimpse.detect')
local sixel = require('glimpse.sixel')

local M = {}

--- @param filepath string
--- @param opts { position: string, size: number }
function M.show(filepath, opts)
	local term = detect.get_terminal()
	local position = opts.position or 'right'
	local size = opts.size or 40

	if term == 'wezterm' then
		M._show_wezterm(filepath, position, size)
	elseif term == 'kitty' or term == 'ghostty' then
		M._show_kitty(filepath, position, size)
	elseif term == 'iterm' then
		M._show_iterm(filepath, position, size)
	elseif sixel.supported() and detect.in_tmux() then
		sixel.show_pane(filepath, { width = size, height = 30 })
	else
		vim.notify('[glimpse] Terminal não suportado.', vim.log.levels.WARN)
	end
end

--- @param filepath string
--- @param position string
--- @param size number
function M._show_wezterm(filepath, position, size)
	local socket = M._find_wezterm_socket()
	if not socket then
		vim.notify('[glimpse] WezTerm socket not found', vim.log.levels.WARN)
		return
	end
	vim.env.WEZTERM_UNIX_SOCKET = socket

	if M._wezterm_preview_pane then
		-- Reuse existing pane: send clear + imgcat
		local text = 'clear && wezterm imgcat "' .. filepath .. '"\n'
		vim.fn.jobstart({
			'wezterm',
			'cli',
			'send-text',
			'--pane-id',
			M._wezterm_preview_pane,
			'--no-paste',
			text,
		}, { on_exit = function() end })
	else
		-- First time: create pane running a read-eval loop (no echo)
		local direction = position == 'bottom' and '--bottom' or '--right'
		vim.fn.jobstart({
			'wezterm',
			'cli',
			'split-pane',
			direction,
			'--percent',
			tostring(size),
			'--',
			'bash',
			'-c',
			'trap "exit 0" INT TERM; stty -echo 2>/dev/null; while IFS= read -r cmd; do eval "$cmd"; done',
		}, {
			stdout_buffered = true,
			on_stdout = function(_, d)
				local pane_id = vim.trim(table.concat(d or {}, ''))
				if pane_id ~= '' then
					M._wezterm_preview_pane = pane_id
					-- Send first imgcat
					vim.defer_fn(function()
						local text = 'clear && wezterm imgcat "' .. filepath .. '"\n'
						vim.fn.jobstart({
							'wezterm',
							'cli',
							'send-text',
							'--pane-id',
							pane_id,
							'--no-paste',
							text,
						}, { on_exit = function() end })
					end, 200)
				end
			end,
			on_exit = function()
				local focus_dir = position == 'bottom' and 'Up' or 'Left'
				vim.fn.jobstart({ 'wezterm', 'cli', 'activate-pane-direction', focus_dir }, {
					on_exit = function() end,
				})
			end,
		})
	end
end

--- Encontra o socket ativo do WezTerm.
--- @return string|nil
function M._find_wezterm_socket()
	local env_socket = os.getenv('WEZTERM_UNIX_SOCKET')
	if env_socket and vim.uv.fs_stat(env_socket) then
		local pid = tonumber(env_socket:match('gui%-sock%-(%d+)'))
		if pid and vim.uv.kill(pid, 0) == 0 then
			return env_socket
		end
	end
	local sockets = vim.fn.glob(os.getenv('HOME') .. '/.local/share/wezterm/gui-sock-*', true, true)
	for _, sock in ipairs(sockets) do
		local pid = tonumber(sock:match('gui%-sock%-(%d+)'))
		if pid and vim.uv.kill(pid, 0) == 0 then
			return sock
		end
	end
	return nil
end

--- @param filepath string
--- @param position string
--- @param size number
function M._show_kitty(filepath, position, size)
	if detect.in_tmux() then
		local split_flag = position == 'bottom' and '-v' or '-h'
		local cmd =
			string.format('tmux split-window %s -l %d%% \'kitten icat "%s"; read -n 1\'', split_flag, size, filepath)
		vim.fn.jobstart(cmd, { detach = true })
	else
		local cmd = string.format('kitten @ launch --type=window kitten icat --hold "%s"', filepath)
		vim.fn.jobstart(cmd, { detach = true })
	end
end

--- @param filepath string
--- @param position string
--- @param size number
function M._show_iterm(filepath, position, size)
	if detect.in_tmux() then
		local split_flag = position == 'bottom' and '-v' or '-h'
		local cmd = string.format('tmux split-window %s -l %d%% \'imgcat "%s"; read -n 1\'', split_flag, size, filepath)
		vim.fn.jobstart(cmd, { detach = true })
	else
		local cmd = string.format('iterm cli split-pane -- bash -c \'imgcat "%s"; read -n 1\'', filepath)
		vim.fn.jobstart(cmd, { detach = true })
	end
end

return M
