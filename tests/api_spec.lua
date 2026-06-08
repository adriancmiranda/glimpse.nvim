local glimpse = require('glimpse')

describe('public api', function()
	it('exposes file-type helpers and preview kind resolution', function()
		assert.is_true(glimpse.can_preview('/path/to/movie.mp4'))
		assert.is_true(glimpse.is_archive('/path/to/file.zip'))
		assert.is_true(glimpse.is_sqlite('/path/to/file.db'))
		assert.is_true(glimpse.is_font('/path/to/font.ttf'))
		assert.is_true(glimpse.is_key('/path/to/key.pub'))
		assert.is_true(glimpse.is_previewable('/path/to/movie.mp4'))

		assert.are.equal('image', glimpse.get_preview_kind('/path/to/photo.png'))
		assert.are.equal('video', glimpse.get_preview_kind('/path/to/movie.mp4'))
		assert.are.equal('archive', glimpse.get_preview_kind('/path/to/file.zip'))
		assert.are.equal('sqlite', glimpse.get_preview_kind('/path/to/file.db'))
		assert.are.equal('font', glimpse.get_preview_kind('/path/to/font.ttf'))
		assert.are.equal('key', glimpse.get_preview_kind('/path/to/key.pub'))
		assert.are.equal('binary', glimpse.get_preview_kind(vim.v.progpath))
		assert.is_nil(glimpse.get_preview_kind('/path/to/file.txt'))
	end)

	it('prefers video handlers when formats overlap', function()
		local saved = package.loaded['glimpse']
		package.loaded['glimpse'] = nil

		local overlapped = require('glimpse')
		overlapped.setup({
			strategy = 'pane',
			formats = { '.gif' },
			video_formats = { '.gif' },
			integrations = {
				oil = false,
				neotree = false,
				telescope = false,
			},
			cache_max_age_days = 0,
		})

		assert.are.equal('video', overlapped.get_preview_kind('/tmp/clip.gif'))

		package.loaded['glimpse'] = saved
	end)

	it('exposes git lfs pointer detection', function()
		local pointer = vim.fn.tempname() .. '.jpg'
		vim.fn.writefile({
			'version https://git-lfs.github.com/spec/v1',
			'oid sha256:fe93af5da1f8d77dac7187f24de828c8fab913629e7870ba27cff63ba5e8554f',
			'size 1576804',
		}, pointer)

		assert.is_true(glimpse.is_git_lfs_pointer(pointer))
		vim.loop.fs_unlink(pointer)
	end)

	it('exposes terminal capability helpers', function()
		assert.is_boolean(glimpse.supports_inline())
		assert.is_boolean(glimpse.in_tmux())
	end)

	it('does not change cwd when opening images by default', function()
		local function real(path)
			return vim.loop.fs_realpath(path) or path
		end

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
		local filepath = root .. '/default.png'
		vim.fn.writefile({ 'x' }, filepath)

		local original_buf = vim.api.nvim_get_current_buf()
		local original_tab_cwd = vim.fn.getcwd()
		local original_cwd = vim.loop.cwd()
		vim.o.swapfile = false

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
			cache_max_age_days = 0,
		})

		vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

		local ok = vim.wait(200, function()
			local curbuf = vim.api.nvim_get_current_buf()
			return vim.bo[curbuf].filetype == 'image' and require('glimpse.renderer').has_placement(curbuf)
		end, 10)
		assert.is_true(ok)
		assert.equals(real(original_tab_cwd), real(vim.fn.getcwd()))
		local image_buf = vim.api.nvim_get_current_buf()

		pcall(vim.api.nvim_set_current_buf, original_buf)
		if vim.api.nvim_buf_is_valid(image_buf) then
			pcall(vim.api.nvim_buf_delete, image_buf, { force = true })
		end
		vim.cmd('cd ' .. vim.fn.fnameescape(original_cwd))
		vim.loop.fs_unlink(filepath)

		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
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
		local original_cwd = vim.loop.cwd()
		local original_tab_cwd = vim.fn.getcwd()
		vim.o.swapfile = false
		pcall(vim.api.nvim_del_augroup_by_name, 'ImagePreviewInline')
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
			cache_max_age_days = 0,
		})

		local ok = vim.wait(200, function()
			return vim.bo[buf].filetype == 'image' and require('glimpse.renderer').has_placement(buf)
		end, 10)
		assert.is_true(ok)
		assert.equals(original_tab_cwd, vim.fn.getcwd())
		assert.equals('image', vim.bo[buf].filetype)
		assert.is_true(require('glimpse.renderer').has_placement(buf))

		pcall(vim.api.nvim_set_current_buf, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		vim.cmd('cd ' .. vim.fn.fnameescape(original_cwd))
		vim.loop.fs_unlink(filepath)

		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
	end)

	it('closes the active image buffer through the public close api', function()
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
		local filepath = root .. '/close.png'
		vim.fn.writefile({ 'x' }, filepath)

		local original_buf = vim.api.nvim_get_current_buf()
		local original_cwd = vim.loop.cwd()
		vim.o.swapfile = false
		vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
		vim.cmd('cd ' .. vim.fn.fnameescape(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')))

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
			cache_max_age_days = 0,
		})

		local ok = vim.wait(200, function()
			local curbuf = vim.api.nvim_get_current_buf()
			return vim.bo[curbuf].filetype == 'image' and require('glimpse.renderer').has_placement(curbuf)
		end, 10)
		assert.is_true(ok)

		local buf = vim.api.nvim_get_current_buf()
		reloaded.close()
		assert.is_false(vim.api.nvim_buf_is_valid(buf))

		pcall(vim.api.nvim_set_current_buf, original_buf)
		vim.cmd('cd ' .. vim.fn.fnameescape(original_cwd))
		vim.loop.fs_unlink(filepath)

		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
	end)
end)
