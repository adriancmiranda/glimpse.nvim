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

	it('treats missing git lfs pointer files as non-pointers', function()
		local missing = vim.fn.tempname() .. '.jpg'

		assert.is_false(glimpse.is_git_lfs_pointer(missing))
	end)

	it('uses nested pane config defaults', function()
		local config = glimpse.get_config()
		assert.is_table(config.pane)
		assert.is_table(config.cache)
		assert.is_table(config.safety)
		assert.is_table(config.loading)
		assert.is_table(config.image)
		assert.is_table(config.video)
		assert.is_table(config.pipelines)
		assert.is_table(config.pipelines.model)
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
		assert.is_table(config.video.keys)
		assert.equals('<CR>', config.video.keys.toggle)
		assert.equals('l', config.video.keys.seek_forward)
		assert.equals('h', config.video.keys.seek_backward)
		assert.equals('f3d', config.pipelines.model.steps[1].command)
		assert.equals('.png', config.pipelines.model.steps[1].output_ext)
		assert.equals(12, config.pipelines.model.renderer.fps)
		assert.are.same(
			{ '.zip', '.tar', '.tar.gz', '.tgz', '.tar.bz2', '.tar.xz', '.txz', '.jar', '.war', '.apk' },
			config.archive.formats
		)
	end)

	it('renders images that were already open before setup', function()
		local saved = {}
		for _, name in ipairs({
			'glimpse',
			'glimpse.renderer',
			'glimpse.kitty',
			'glimpse.strategy.inline',
		}) do
			saved[name] = package.loaded[name]
		end

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/startup.png'
		vim.fn.writefile({ 'x' }, filepath)

		local original_buf = vim.api.nvim_get_current_buf()
		local original_swapfile = vim.o.swapfile
		vim.o.swapfile = false
		vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

		local buf = vim.api.nvim_get_current_buf()
		assert.equals('', vim.bo[buf].filetype)

		package.loaded['glimpse.kitty'] = {
			transmit_async = function(_, _, callback)
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
			prefetch = function()
				return true
			end,
			detect_cell_size = function() end,
		}
		package.loaded['glimpse'] = nil
		package.loaded['glimpse.renderer'] = nil
		package.loaded['glimpse.strategy.inline'] = nil

		local reloaded = require('glimpse')
		reloaded.setup({
			strategy = 'inline',
			integrations = {
				oil = false,
				neotree = false,
				telescope = false,
			},
			cache = { max_age_days = 0 },
		})

		local ok = vim.wait(200, function()
			return vim.bo[buf].filetype == 'image' and require('glimpse.renderer').has_placement(buf)
		end, 10)
		assert.is_true(ok)
		assert.equals('image', vim.bo[buf].filetype)
		assert.is_true(require('glimpse.renderer').has_placement(buf))

		pcall(vim.api.nvim_set_current_buf, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		vim.o.swapfile = original_swapfile
		vim.loop.fs_unlink(filepath)

		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
	end)

	it('exposes terminal capability helpers', function()
		assert.is_boolean(glimpse.supports_inline())
		assert.is_boolean(glimpse.in_tmux())
	end)

	it('closes the active image buffer through the public close api', function()
		local saved = {}
		for _, name in ipairs({
			'glimpse',
			'glimpse.strategy.inline',
		}) do
			saved[name] = package.loaded[name]
		end

		local calls = {}
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].filetype = 'image'
		vim.api.nvim_set_current_buf(buf)

		package.loaded['glimpse.strategy.inline'] = {
			close = function(target_buf, delete_buf)
				calls.buf = target_buf
				calls.delete_buf = delete_buf
			end,
		}

		package.loaded['glimpse'] = nil
		local reloaded = require('glimpse')
		reloaded.close()

		assert.equals(buf, calls.buf)
		assert.is_true(calls.delete_buf)

		vim.api.nvim_set_current_buf(0)
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end

		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
	end)

	it('moves to a scratch buffer before closing the current image buffer', function()
		local saved = {}
		for _, name in ipairs({
			'glimpse.renderer',
			'glimpse.strategy.inline',
		}) do
			saved[name] = package.loaded[name]
		end

		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].filetype = 'image'
		vim.api.nvim_set_current_buf(buf)

		package.loaded['glimpse.renderer'] = {
			close = function()
				return true
			end,
		}

		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')
		inline.close(buf, true)

		assert.not_equals(buf, vim.api.nvim_get_current_buf())
		assert.is_true(vim.api.nvim_buf_is_valid(vim.api.nvim_get_current_buf()))
		assert.is_false(vim.api.nvim_buf_is_valid(buf))

		local scratch = vim.api.nvim_get_current_buf()
		vim.api.nvim_set_current_buf(0)
		if vim.api.nvim_buf_is_valid(scratch) then
			vim.api.nvim_buf_delete(scratch, { force = true })
		end

		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
	end)

	it('keeps shared image buffers alive when closing one split', function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].filetype = 'image'
		vim.api.nvim_set_current_buf(buf)
		vim.cmd('vsplit')

		local other_win
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == buf and win ~= vim.api.nvim_get_current_win() then
				other_win = win
				break
			end
		end

		local inline = require('glimpse.strategy.inline')
		inline.close(buf, true)

		assert.is_true(vim.api.nvim_buf_is_valid(buf))
		assert.equals(1, #vim.fn.win_findbuf(buf))

		if other_win and vim.api.nvim_win_is_valid(other_win) then
			vim.api.nvim_win_close(other_win, true)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end)
end)
