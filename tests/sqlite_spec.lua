local sqlite = require('glimpse.sqlite')
local util = require('glimpse.util')

describe('sqlite', function()
	local test_dir = '/tmp/glimpse_sqlite_test_' .. os.time()
	local test_db = test_dir .. '/test.db'

	before_each(function()
		vim.fn.mkdir(test_dir, 'p')
	end)

	after_each(function()
		vim.fn.delete(test_dir, 'rf')
	end)

	describe('list', function()
		it('returns tables for a valid database', function()
			if vim.fn.executable('sqlite3') == 0 then
				pending('sqlite3 not available')
				return
			end
			vim.fn.system({ 'sqlite3', test_db, 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT);' })
			vim.fn.system({ 'sqlite3', test_db, 'CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT, user_id INTEGER);' })

			local tables, err = sqlite.list(test_db)
			assert.is_nil(err)
			assert.is_not_nil(tables)
			assert.equals(2, #tables)
		end)

		it('returns error for non-existent file', function()
			local tables, err = sqlite.list('/tmp/nonexistent.db')
			assert.is_nil(tables)
			assert.is_not_nil(err)
		end)
	end)

	describe('format', function()
		it('formats tables with names and columns', function()
			local tables = {
				{ name = 'users', sql = 'CREATE TABLE users (id INTEGER, name TEXT)', columns = { 'id', 'name' } },
				{ name = 'posts', sql = 'CREATE TABLE posts (id INTEGER, title TEXT)', columns = { 'id', 'title' } },
			}
			local lines, highlights = sqlite.format(tables)
			assert.is_true(#lines > 0)
			assert.is_true(lines[1]:match('2 table') ~= nil)
			assert.is_true(#highlights > 0)
		end)
	end)

	describe('util.is_sqlite', function()
		it('returns true for .db files', function()
			assert.is_true(util.is_sqlite('/path/to/file.db'))
		end)

		it('returns true for .sqlite files', function()
			assert.is_true(util.is_sqlite('/path/to/file.sqlite'))
		end)

		it('returns true for .sqlite3 files', function()
			assert.is_true(util.is_sqlite('/path/to/file.sqlite3'))
		end)

		it('returns false for other files', function()
			assert.is_false(util.is_sqlite('/path/to/file.json'))
		end)
	end)
end)
