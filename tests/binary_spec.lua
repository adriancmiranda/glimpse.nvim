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

	it('still previews binaries renamed to json', function()
		local source = vim.v.progpath
		local target = vim.fn.tempname() .. '.json'
		local ok, err = vim.uv.fs_copyfile(source, target)
		assert.is_true(ok, err)
		assert.is_true(binary.can_preview(target))
		assert.is_true(glimpse.can_preview(target))
	end)

	it('does not preview text files as binaries', function()
		local file = vim.fn.tempname() .. '.txt'
		vim.fn.writefile({ 'hello world' }, file)
		assert.is_false(binary.can_preview(file))
	end)

	it('does not treat executable json as binary', function()
		local file = vim.fn.tempname() .. '.json'
		vim.fn.writefile({ '{', '"name": "example"', '}' }, file)
		vim.fn.setfperm(file, 'rwxr-xr-x')
		assert.is_false(binary.can_preview(file))
		assert.is_false(glimpse.can_preview(file))
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

	it('memoizes preview_data so xxd is only run once per file version', function()
		local original_executable = vim.fn.executable
		local original_system = vim.fn.system
		local original_vim_system = vim.system
		local file = vim.fn.tempname() .. '.bin'
		vim.fn.writefile({ 'binary' }, file)

		local xxd_calls = 0

		---@diagnostic disable-next-line: duplicate-set-field
		vim.fn.executable = function(name)
			if name == 'file' or name == 'xxd' then
				return 1
			end
			return original_executable(name)
		end

		---@diagnostic disable-next-line: duplicate-set-field
		vim.system = nil
		---@diagnostic disable-next-line: duplicate-set-field
		vim.fn.system = function(args)
			if args[1] == 'file' and args[3] == file and args[2] == '-b' then
				return 'Binary data'
			end
			if args[1] == 'file' and args[2] == '-b' and args[3] == '--mime-encoding' then
				return 'binary'
			end
			if args[1] == 'xxd' then
				xxd_calls = xxd_calls + 1
				return '00000000: 0001 02                                   ...'
			end
			return original_system(args)
		end

		local first = binary.preview_data(file)
		local second = binary.preview_data(file)

		vim.fn.executable = original_executable
		vim.fn.system = original_system
		vim.system = original_vim_system
		vim.fn.delete(file)

		assert.are.same(first, second)
		assert.equals(1, xxd_calls)
	end)
end)
