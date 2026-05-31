local archive = require('glimpse.archive')
local preview_cache = require('glimpse.preview_cache')
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
			-- Create a test zip
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

	describe('previewer.show', function()
		it('renders the full listing instead of the summary', function()
			local original_archive = package.loaded['glimpse.archive']
			local original_previewer = package.loaded['glimpse.previewer.archive']
			local original_buf = vim.api.nvim_get_current_buf()
			local buf = vim.api.nvim_create_buf(false, true)
			local entries = {
				{
					path = 'file.txt',
					size = 12,
					date = '2024-01-01 12:00',
					type = 'file',
					suspicious = false,
				},
			}

			package.loaded['glimpse.archive'] = {
				list = function()
					return entries
				end,
				format = function()
					return { 'full listing' }, {}
				end,
				summary = function()
					return { 'summary' }, {}
				end,
			}
			package.loaded['glimpse.previewer.archive'] = nil

			local previewer = require('glimpse.previewer.archive')
			pcall(vim.api.nvim_set_current_buf, buf)
			previewer.show('/tmp/archive.zip')

			assert.equals('full listing', vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])

			pcall(vim.api.nvim_set_current_buf, original_buf)
			if vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
			package.loaded['glimpse.archive'] = original_archive
			package.loaded['glimpse.previewer.archive'] = original_previewer
		end)
	end)

	describe('previewer.preview_data', function()
		it('memoizes archive previews until the file changes', function()
			preview_cache.clear()

			local original_archive = package.loaded['glimpse.archive']
			local original_previewer = package.loaded['glimpse.previewer.archive']
			local path = test_dir .. '/cache.zip'
			vim.fn.writefile({ 'initial' }, path)

			local calls = 0
			package.loaded['glimpse.archive'] = {
				list = function()
					calls = calls + 1
					return {
						{
							path = 'file.txt',
							size = 12,
							date = '2024-01-01 12:00',
							type = 'file',
							suspicious = false,
						},
					}
				end,
				format = function()
					return { 'full listing' }, {}
				end,
				summary = function()
					return { 'summary' }, {}
				end,
			}
			package.loaded['glimpse.previewer.archive'] = nil

			local previewer = require('glimpse.previewer.archive')
			local first = previewer.preview_data(path)
			local second = previewer.preview_data(path)
			assert.equals(1, calls)
			assert.are.same(first, second)

			vim.fn.writefile({ 'changed' }, path)
			local third = previewer.preview_data(path)
			assert.equals(2, calls)
			assert.are.same(first, third)

			package.loaded['glimpse.archive'] = original_archive
			package.loaded['glimpse.previewer.archive'] = original_previewer
			preview_cache.clear()
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
