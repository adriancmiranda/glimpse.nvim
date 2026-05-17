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
	local direction = position == 'bottom' and '--bottom' or '--right'
	local cmd = {
		'wezterm',
		'cli',
		'split-pane',
		direction,
		'--percent',
		tostring(size),
		'--',
		'bash',
		'-c',
		string.format('wezterm imgcat "%s"; read -n 1', filepath),
	}
	vim.fn.jobstart(cmd, { detach = true })
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
