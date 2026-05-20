local cache = require('glimpse.cache')

describe('cache', function()
	local test_dir = '/tmp/glimpse_cache_test_' .. os.time()

	before_each(function()
		vim.fn.mkdir(test_dir, 'p')
	end)

	after_each(function()
		vim.fn.delete(test_dir, 'rf')
	end)

	describe('cleanup', function()
		it('removes files older than max_age_days', function()
			-- Cria arquivo com mtime antigo (simula tocando e mudando mtime)
			local old_file = test_dir .. '/old.png'
			local new_file = test_dir .. '/new.png'
			vim.fn.writefile({ '' }, old_file)
			vim.fn.writefile({ '' }, new_file)
			-- Seta mtime do old_file para 10 dias atras
			local ten_days_ago = os.time() - (10 * 86400)
			vim.uv.fs_utime(old_file, ten_days_ago, ten_days_ago)

			cache.cleanup(test_dir, 7)

			assert.is_nil(vim.uv.fs_stat(old_file))
			assert.is_not_nil(vim.uv.fs_stat(new_file))
		end)

		it('does nothing for non-existent directory', function()
			assert.has_no.errors(function()
				cache.cleanup('/tmp/nonexistent_dir_12345', 7)
			end)
		end)

		it('keeps all files when none are expired', function()
			local file = test_dir .. '/recent.png'
			vim.fn.writefile({ '' }, file)

			cache.cleanup(test_dir, 7)

			assert.is_not_nil(vim.uv.fs_stat(file))
		end)
	end)
end)
