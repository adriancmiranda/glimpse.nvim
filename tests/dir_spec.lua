local dir = require('glimpse.dir')

local function normalize(path)
	return vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

describe('dir helper', function()
	it('follows the parent directory of a file', function()
		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		local original_cwd = normalize(vim.fn.getcwd())
		local ok, err = pcall(function()
			dir.follow(filepath)
			assert.equals(normalize(root), normalize(vim.fn.getcwd()))
		end)

		pcall(vim.cmd, 'silent keepalt tcd ' .. vim.fn.fnameescape(original_cwd))
		if not ok then
			error(err)
		end
	end)
end)
