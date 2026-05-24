local M = {}

--- Faz o cwd da aba atual seguir o diretório do arquivo informado.
---@param filepath string
function M.follow(filepath)
	local dir = vim.fn.fnamemodify(filepath or '', ':p:h')
	if dir == '' then
		return
	end

	pcall(vim.cmd, 'silent keepalt tcd ' .. vim.fn.fnameescape(dir))
end

return M
