local safety = require('glimpse.safety')

describe('safety', function()
	local test_dir = '/tmp/glimpse_safety_test_' .. os.time()

	before_each(function()
		vim.fn.mkdir(test_dir, 'p')
	end)

	after_each(function()
		vim.fn.delete(test_dir, 'rf')
	end)

	describe('check', function()
		it('returns true for a regular file', function()
			local file = test_dir .. '/normal.png'
			vim.fn.writefile({ 'data' }, file)
			local safe, reason = safety.check(file)
			assert.is_true(safe)
			assert.is_nil(reason)
		end)

		it('rejects symlinks', function()
			local target = test_dir .. '/target.png'
			local link = test_dir .. '/link.png'
			vim.fn.writefile({ 'data' }, target)
			vim.uv.fs_symlink(target, link)
			local safe, reason = safety.check(link)
			assert.is_false(safe)
			assert.equals('symlink rejected', reason)
		end)

		it('rejects files larger than max_size', function()
			local file = test_dir .. '/big.png'
			-- Cria arquivo de 2KB
			local data = string.rep('x', 2048)
			vim.fn.writefile({ data }, file)
			local safe, reason = safety.check(file, { max_size = 1024 })
			assert.is_false(safe)
			assert.is_truthy(reason:match('too large'))
		end)

		it('rejects non-existent files', function()
			local safe, reason = safety.check('/tmp/nonexistent_12345.png')
			assert.is_false(safe)
			assert.equals('file not found', reason)
		end)

		it('rejects directories', function()
			local safe, reason = safety.check(test_dir)
			assert.is_false(safe)
			assert.equals('not a regular file', reason)
		end)
	end)
end)
