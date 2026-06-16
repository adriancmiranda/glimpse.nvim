local M = {}

--- Make the current tab's cwd follow the directory of the given file.
---@param filepath string
function M.follow(filepath)
	local dir = vim.fn.fnamemodify(filepath or '', ':p:h')
	if dir == '' then
		return
	end

	pcall(function()
		vim.cmd({ cmd = 'tcd', args = { dir }, mods = { silent = true, keepalt = true } })
	end)
end

return M
