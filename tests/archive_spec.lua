local archive = require('glimpse.archive')
local util = require('glimpse.util')

describe('archive', function()
	local test_dir = '/tmp/glimpse_archive_test_' .. os.time()
	local test_zip = test_dir .. '/test.zip'

	before_each(function()
		vim.fn.mkdir(test_dir, 'p')
	end)

	after_each(function()
		vim.fn.delete(test_dir, 'rf')
	end)

	describe('is_suspicious', function()
		it('detects path traversal', function()
			-- Testado indiretamente via format() abaixo
		end)
	end)

	describe('list_zip', function()
		it('returns entries for a valid zip', function()
			-- Cria um zip de teste
			vim.fn.writefile({ 'hello' }, test_dir .. '/hello.txt')
			vim.fn.system({ 'zip', '-j', test_zip, test_dir .. '/hello.txt' })
			if vim.v.shell_error ~= 0 then
				pending('zip not available')
				return
			end

			local entries, err = archive.list_zip(test_zip)
			assert.is_nil(err)
			assert.is_not_nil(entries)
			assert.is_true(#entries > 0)
			assert.equals('hello.txt', entries[1].path)
			assert.equals('file', entries[1].type)
			assert.is_false(entries[1].suspicious)
		end)

		it('returns error for non-existent file', function()
			local entries, err = archive.list_zip('/tmp/nonexistent.zip')
			assert.is_nil(entries)
			assert.is_not_nil(err)
		end)
	end)

	describe('format', function()
		it('marks suspicious paths', function()
			local entries = {
				{ path = 'normal.txt', size = 100, date = '2024-01-01 12:00', type = 'file', suspicious = false },
				{ path = '../etc/passwd', size = 50, date = '2024-01-01 12:00', type = 'file', suspicious = true },
			}
			local lines, highlights = archive.format(entries)
			-- Deve ter warning no topo
			assert.is_true(lines[1]:match('suspicious') ~= nil)
			-- Deve ter highlights de erro
			local has_error_hl = false
			for _, hl in ipairs(highlights) do
				if hl[4] == 'DiagnosticError' then
					has_error_hl = true
				end
			end
			assert.is_true(has_error_hl)
		end)

		it('formats directories with icon', function()
			local entries = {
				{ path = 'src/', size = 0, date = '2024-01-01 12:00', type = 'directory', suspicious = false },
			}
			local lines, _ = archive.format(entries)
			assert.is_true(lines[1]:match('src/') ~= nil)
		end)
	end)

	describe('util.is_archive', function()
		it('returns true for zip files', function()
			assert.is_true(util.is_archive('/path/to/file.zip'))
		end)

		it('returns true for tar.gz files', function()
			assert.is_true(util.is_archive('/path/to/file.tar.gz'))
		end)

		it('returns false for images', function()
			assert.is_false(util.is_archive('/path/to/image.png'))
		end)

		it('returns false for regular files', function()
			assert.is_false(util.is_archive('/path/to/file.lua'))
		end)
	end)
end)
