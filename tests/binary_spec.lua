local glimpse = require('glimpse')
local binary = require('glimpse.previewer.binary')

describe('previewer.binary', function()
	it('exposes can_preview through the public glimpse api', function()
		assert.is_true(glimpse.can_preview(vim.v.progpath))
	end)

	it('exposes resolve_previewer through the public glimpse api', function()
		local previewer, safety_opts = glimpse.resolve_previewer(vim.v.progpath)
		assert.is_truthy(previewer)
		assert.are.equal(binary, previewer)
		assert.is_table(safety_opts)
		assert.are.equal(0, safety_opts.max_size)
	end)

	it('can preview the running nvim binary', function()
		assert.is_true(binary.can_preview(vim.v.progpath))
	end)

	it('does not preview plain text files', function()
		local file = vim.fn.tempname() .. '.txt'
		vim.fn.writefile({ 'hello world' }, file)
		assert.is_false(binary.can_preview(file))
	end)
end)
