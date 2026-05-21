--- Previewer para bancos SQLite.
local M = {}

local sqlite = require('glimpse.sqlite')

--- Exibe schema num float.
--- @param filepath string
function M.show(filepath)
	local config = require('glimpse').get_config()
	local tables, err = sqlite.list(filepath)
	if not tables then
		vim.notify('[glimpse] ' .. (err or 'failed to read database'), vim.log.levels.WARN)
		return
	end
	local lines, highlights = sqlite.format(tables)

	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_sqlite'

	local ns = vim.api.nvim_create_namespace('glimpse_sqlite')
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

	local width = math.min(80, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)
	vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' SQLite ',
		title_pos = 'center',
	})

	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

--- Preview (mesmo que show para sqlite).
--- @param filepath string
M.preview = M.show

return M
