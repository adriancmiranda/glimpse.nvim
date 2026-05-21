--- Previewer para archives (zip, tar, etc).
local M = {}

local archive = require('glimpse.archive')

--- Renderiza listagem completa no buffer atual.
--- @param filepath string
function M.show(filepath)
	local entries, err = archive.list(filepath)
	if not entries then
		vim.notify('[glimpse] ' .. (err or 'failed to read archive'), vim.log.levels.WARN)
		return
	end
	local lines, highlights = archive.format(entries)
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_archive'
	-- Aplica highlights
	local ns = vim.api.nvim_create_namespace('glimpse_archive')
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, hl in ipairs(highlights) do
		local row = hl[1]
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end
end

--- Preview com resumo num float.
--- @param filepath string
function M.preview(filepath)
	local config = require('glimpse').get_config()
	local entries, err = archive.list(filepath)
	if not entries then
		vim.notify('[glimpse] ' .. (err or 'failed to read archive'), vim.log.levels.WARN)
		return
	end
	local lines, highlights = archive.summary(entries, filepath)

	-- Header
	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	-- Cria buffer flutuante
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_archive'

	-- Aplica highlights (offset +2 pelo header)
	local ns = vim.api.nvim_create_namespace('glimpse_archive_preview')
	for _, hl in ipairs(highlights) do
		local row = hl[1] + 2
		local col_end = hl[3]
		if col_end < 0 then
			col_end = #(lines[row + 1] or '')
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, hl[2], {
			end_col = col_end,
			hl_group = hl[4],
		})
	end

	-- Abre float
	local width = math.min(70, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Archive Summary ',
		title_pos = 'center',
	})

	-- Keymap para fechar
	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

return M
