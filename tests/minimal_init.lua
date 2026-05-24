-- Minimal init for running tests with plenary.nvim
local function first_non_empty(...)
	for _, path in ipairs({ ... }) do
		if path ~= nil and path ~= '' then
			return path
		end
	end
end

local plenary_path = first_non_empty(
	os.getenv('PLENARY_PATH'),
	vim.fn.glob(vim.fn.stdpath('data') .. '/packages/*/plenary.nvim'),
	vim.fn.glob(vim.fn.stdpath('data') .. '/lazy/plenary.nvim')
)

vim.opt.rtp:prepend('.')

if plenary_path then
	vim.opt.rtp:prepend(plenary_path)
end

vim.cmd('runtime plugin/plenary.vim')
