-- Minimal init for running tests with plenary.nvim
local plenary_path = os.getenv('PLENARY_PATH')
	or vim.fn.glob(vim.fn.stdpath('data') .. '/packages/*/plenary.nvim')
	or vim.fn.glob(vim.fn.stdpath('data') .. '/lazy/plenary.nvim')

vim.opt.rtp:prepend('.')
vim.opt.rtp:prepend(plenary_path)
vim.cmd('runtime plugin/plenary.vim')
