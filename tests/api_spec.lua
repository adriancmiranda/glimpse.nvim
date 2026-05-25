local glimpse = require('glimpse')

describe('public api', function()
	it('exposes file-type helpers and preview kind resolution', function()
		local pointer = vim.fn.tempname() .. '.jpg'
		vim.fn.writefile({
			'version https://git-lfs.github.com/spec/v1',
			'oid sha256:fe93af5da1f8d77dac7187f24de828c8fab913629e7870ba27cff63ba5e8554f',
			'size 1576804',
		}, pointer)

		assert.is_true(glimpse.is_git_lfs_pointer(pointer))
		assert.is_true(glimpse.is_archive('/path/to/file.zip'))
		assert.is_true(glimpse.is_sqlite('/path/to/file.db'))
		assert.is_true(glimpse.is_font('/path/to/font.ttf'))
		assert.is_true(glimpse.is_key('/path/to/key.pub'))
		assert.is_true(glimpse.can_preview('/path/to/movie.mp4'))

		assert.are.equal('image', glimpse.get_preview_kind('/path/to/photo.png'))
		assert.are.equal('video', glimpse.get_preview_kind('/path/to/movie.mp4'))
		assert.are.equal('archive', glimpse.get_preview_kind('/path/to/file.zip'))
		assert.are.equal('sqlite', glimpse.get_preview_kind('/path/to/file.db'))
		assert.are.equal('font', glimpse.get_preview_kind('/path/to/font.ttf'))
		assert.are.equal('key', glimpse.get_preview_kind('/path/to/key.pub'))
		assert.are.equal('binary', glimpse.get_preview_kind(vim.v.progpath))
		assert.is_nil(glimpse.get_preview_kind('/path/to/file.txt'))

		vim.loop.fs_unlink(pointer)
	end)

	it('uses nested pane config defaults', function()
		local config = glimpse.get_config()
		assert.is_table(config.pane)
		assert.is_table(config.cache)
		assert.is_table(config.safety)
		assert.is_table(config.loading)
		assert.is_table(config.image)
		assert.is_table(config.video)
		assert.is_table(config.archive)
		assert.equals('right', config.pane.position)
		assert.equals(40, config.pane.size)
		assert.equals(vim.fn.stdpath('cache') .. '/glimpse', config.cache.dir)
		assert.equals(7, config.cache.max_age_days)
		assert.equals(50 * 1024 * 1024, config.safety.max_file_size)
		assert.equals('  ⏳ Loading...', config.loading.text)
		assert.are.same(
			{ '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.avif', '.svg', '.pdf', '.pict' },
			config.image.formats
		)
		assert.are.same({ '.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.m4v' }, config.video.formats)
		assert.are.same(
			{ '.zip', '.tar', '.tar.gz', '.tgz', '.tar.bz2', '.tar.xz', '.txz', '.jar', '.war', '.apk' },
			config.archive.formats
		)
	end)

	it('exposes terminal capability helpers', function()
		assert.is_boolean(glimpse.supports_inline())
		assert.is_boolean(glimpse.in_tmux())
	end)
end)
