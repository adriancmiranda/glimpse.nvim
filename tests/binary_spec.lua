local glimpse = require('glimpse')
local binary = require('glimpse.previewer.binary')

describe('previewer.binary', function()
	it('exposes can_preview through the public glimpse api', function()
		assert.is_true(glimpse.can_preview(vim.v.progpath))
	end)

	it('detects a binary without relying on the extension', function()
		local source = vim.v.progpath
		local target = vim.fn.tempname()
		local ok, err = vim.uv.fs_copyfile(source, target)
		assert.is_true(ok, err)
		assert.is_true(glimpse.can_preview(target))
		assert.is_true(binary.can_preview(target))
	end)

	it('can preview the running nvim binary', function()
		assert.is_true(binary.can_preview(vim.v.progpath))
	end)

	it('does not preview plain text files', function()
		local file = vim.fn.tempname() .. '.txt'
		vim.fn.writefile({ 'hello world' }, file)
		assert.is_false(binary.can_preview(file))
	end)

	it('does not preview json files as binaries', function()
		local file = vim.fn.tempname() .. '.json'
		vim.fn.writefile({ '{', '"name": "example"', '}' }, file)
		assert.is_false(binary.can_preview(file))
		assert.is_false(glimpse.can_preview(file))
	end)

	it('does not preview binaries renamed to json', function()
		local source = vim.v.progpath
		local target = vim.fn.tempname() .. '.json'
		local ok, err = vim.uv.fs_copyfile(source, target)
		assert.is_true(ok, err)
		assert.is_false(binary.can_preview(target))
		assert.is_false(glimpse.can_preview(target))
	end)

	it('does not preview text files as binaries', function()
		local file = vim.fn.tempname() .. '.txt'
		vim.fn.writefile({ 'hello world' }, file)
		assert.is_false(binary.can_preview(file))
	end)

	it('fails safely when file or xxd is not available', function()
		local original_executable = vim.fn.executable

		---@diagnostic disable-next-line: duplicate-set-field
		vim.fn.executable = function(name)
			if name == 'file' or name == 'xxd' then
				return 0
			end
			return original_executable(name)
		end

		local ok, err = pcall(function()
			assert.is_false(binary.can_preview(vim.v.progpath))
			assert.is_false(binary.show(vim.v.progpath))
		end)

		vim.fn.executable = original_executable

		if not ok then
			error(err)
		end
	end)
end)
