local thumbnail = require('glimpse.thumbnail')

describe('thumbnail', function()
	local test_cache = '/tmp/glimpse_test_cache'

	before_each(function()
		vim.fn.mkdir(test_cache, 'p')
	end)

	after_each(function()
		vim.fn.delete(test_cache, 'rf')
	end)

	describe('extract', function()
		it('returns nil for non-existent file', function()
			local result = thumbnail.extract('/tmp/nonexistent.mp4', { cache_dir = test_cache })
			assert.is_nil(result)
		end)

		it('returns a png path for a valid video', function()
			-- Criar um vídeo de teste mínimo com ffmpeg
			local test_video = test_cache .. '/test_input.mp4'
			vim.fn.system({
				'ffmpeg',
				'-y',
				'-f',
				'lavfi',
				'-i',
				'color=c=red:s=64x64:d=1',
				'-c:v',
				'libx264',
				'-pix_fmt',
				'yuv420p',
				test_video,
			})
			if vim.v.shell_error ~= 0 then
				pending('ffmpeg not available')
				return
			end

			local result = thumbnail.extract(test_video, { cache_dir = test_cache })
			assert.is_not_nil(result)
			assert.is_true(vim.endswith(result, '.png'))
			assert.is_not_nil(vim.uv.fs_stat(result))
		end)

		it('returns cached thumbnail on second call', function()
			local test_video = test_cache .. '/test_cached.mp4'
			vim.fn.system({
				'ffmpeg',
				'-y',
				'-f',
				'lavfi',
				'-i',
				'color=c=blue:s=64x64:d=1',
				'-c:v',
				'libx264',
				'-pix_fmt',
				'yuv420p',
				test_video,
			})
			if vim.v.shell_error ~= 0 then
				pending('ffmpeg not available')
				return
			end

			local first = thumbnail.extract(test_video, { cache_dir = test_cache })
			local second = thumbnail.extract(test_video, { cache_dir = test_cache })
			assert.equals(first, second)
		end)
	end)
end)
