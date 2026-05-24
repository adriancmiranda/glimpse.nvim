local function restore_package(name, value)
	package.loaded[name] = value
end

local function normalize(path)
	return vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

describe('renderer', function()
	it('mantém o caminho completo do arquivo no buffer renderizado', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			assert.equals(normalize(filepath), normalize(vim.api.nvim_buf_get_name(buf)))
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)
end)
