--- Previewer para fontes (.ttf, .otf, .woff, .woff2).
local M = {}
local float = require('glimpse.float')

local font_mod = require('glimpse.font')

--- Renderiza a fonte como imagem via magick.
--- @param filepath string
function M.show(filepath)
	local config = require('glimpse').get_config()
	local info, err = font_mod.query(filepath)
	if not info then
		vim.notify('[glimpse] ' .. (err or 'failed to read font'), vim.log.levels.WARN)
		return
	end

	if vim.fn.executable('magick') == 0 then
		M.preview(filepath)
		return
	end

	local cache_dir = config.cache_dir
	vim.fn.mkdir(cache_dir, 'p')
	local hash = vim.fn.sha256(filepath):sub(1, 12)
	local tmp = cache_dir .. '/font_' .. hash .. '.png'
	local sample = table.concat({
		info.family .. ' - ' .. (info.style or 'Regular'),
		'',
		'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
		'abcdefghijklmnopqrstuvwxyz',
		'0123456789 !@#$%&*()+-=[]{}',
		'',
		'The quick brown fox jumps over the lazy dog',
	}, '\\n')
	vim.fn.system({
		'magick',
		'-background',
		'#1a1b26',
		'-fill',
		'#c0caf5',
		'-font',
		filepath,
		'-pointsize',
		'42',
		'label:' .. sample,
		tmp,
	})
	if vim.v.shell_error == 0 and vim.uv.fs_stat(tmp) then
		local glimpse = require('glimpse')
		if glimpse._should_use_inline() then
			require('glimpse.strategy.inline').show(tmp)
		else
			require('glimpse.strategy.pane').show(tmp, { position = config.pane_position, size = config.pane_size })
		end
		return
	end

	M.preview(filepath)
end

--- Preview com metadados num float.
--- @param filepath string
function M.preview(filepath)
	local config = require('glimpse').get_config()
	local info, err = font_mod.query(filepath)
	if not info then
		vim.notify('[glimpse] ' .. (err or 'failed to read font'), vim.log.levels.WARN)
		return
	end

	local lines, highlights = font_mod.format(info)

	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].filetype = 'glimpse_font'

	local ns = vim.api.nvim_create_namespace('glimpse_font')
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

	float.open(buf, {
		title = ' Font ',
		max_width = 60,
		max_height = #lines,
	})

	vim.keymap.set('n', config.keys.close, '<cmd>close<CR>', { buffer = buf, silent = true })
	vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

return M
