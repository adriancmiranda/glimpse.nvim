--- Previewer for SQLite databases.
local M = {}
local float = require('glimpse.float')

local sqlite = require('glimpse.sqlite')
local preview_cache = require('glimpse.preview_cache')
local shared = require('glimpse.previewer.shared')

local _header_lines = shared.header_lines
local _offset_highlights = shared.offset_highlights

local function _preview_data(filepath)
	return preview_cache.memoize(filepath, 'sqlite', function()
		local tables, err = sqlite.list(filepath)
		if not tables then
			return nil, nil, err
		end

		local lines, highlights = sqlite.format(tables)
		_header_lines(filepath, lines)
		return lines, _offset_highlights(highlights, 2)
	end)
end

--- Display the schema in a floating window.
--- @param filepath string
function M.show(filepath, opts)
	local config = require('glimpse').get_config()
	local lines, highlights, err = _preview_data(filepath)
	if not lines then
		vim.notify('[glimpse] ' .. (err or 'failed to read database'), vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_sqlite'

	local ns = vim.api.nvim_create_namespace('glimpse_sqlite')
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

	float.open(buf, {
		kind = 'sqlite',
		title = ' SQLite ',
		max_width = 80,
		max_height = #lines,
		window = opts and opts.window,
	})

	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

--- Preview (same as show for SQLite).
--- @param filepath string
M.preview = M.show

M.preview_data = _preview_data

return M
