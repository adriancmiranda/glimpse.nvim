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
