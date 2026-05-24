local binary = require('glimpse.previewer.binary')

describe('previewer.binary', function()
	it('can preview the running nvim binary', function()
		assert.is_true(binary.can_preview(vim.v.progpath))
	end)

	it('does not preview plain text files', function()
		local file = vim.fn.tempname() .. '.txt'
		vim.fn.writefile({ 'hello world' }, file)
		assert.is_false(binary.can_preview(file))
	end)
end)
