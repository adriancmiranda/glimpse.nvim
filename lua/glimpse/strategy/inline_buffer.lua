local M = {}

local state = {}

local function _restore(bufnr)
	local s = state[bufnr]
	if not s then return end
	local ok, err = pcall(function()
		vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
		vim.api.nvim_buf_set_option(bufnr, 'readonly', false)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, s.orig_lines)
		vim.api.nvim_buf_set_option(bufnr, 'modifiable', s.modifiable)
		vim.api.nvim_buf_set_option(bufnr, 'readonly', s.readonly)
		vim.cmd('stopinsert')
	end)
	if not ok then vim.notify('glimpse: ' .. err, vim.log.levels.ERROR) end
	vim.api.nvim_clear_autocmds({ group = s.augroup, buffer = bufnr })
	state[bufnr] = nil
end

function M.show(filepath, opts)
	local bufnr = vim.api.nvim_get_current_buf()
	if state[bufnr] then return end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
	local readonly = vim.api.nvim_buf_get_option(bufnr, 'readonly')

	local augroup = vim.api.nvim_create_augroup('GlimpseInlineBuffer_' .. bufnr, { clear = true, buffer = bufnr })

	vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
	vim.api.nvim_buf_set_option(bufnr, 'readonly', false)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '  ⏳ Loading...' })

	state[bufnr] = { orig_lines = lines, modifiable = modifiable, readonly = readonly, augroup = augroup }

	vim.api.nvim_create_autocmd('BufWritePre', {
		group = augroup,
		callback = function()
			_restore(bufnr)
		end,
	})

	vim.api.nvim_create_autocmd({ 'BufWipeout', 'QuitPre' }, {
		group = augroup,
		callback = function()
			_restore(bufnr)
		end,
	})
end

function M.close(bufnr)
	_restore(bufnr or vim.api.nvim_get_current_buf())
end

return M
