local float = require('glimpse.float')

describe('float preview helper', function()
	it('resolves configured widths without opening a window', function()
		local config = require('glimpse').get_config()
		local saved = vim.deepcopy(config.float)
		config.float = { markdown = { width = 42 } }

		assert.equals(42, float.resolve_width({ kind = 'markdown', max_width = 100 }))

		config.float = saved
	end)

	it('applies global and preview-specific size configuration', function()
		local glimpse = require('glimpse')
		local config = glimpse.get_config()
		local user_config = glimpse._get_user_config()
		local saved = vim.deepcopy(config.float)
		local saved_user = vim.deepcopy(user_config.float)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'one', 'two' })
		config.float.width = 55
		config.float.archive.width = 33
		user_config.float = { width = 55, archive = { width = 33 } }

		local global_win = float.open(buf, { kind = 'markdown', max_width = 100 })
		assert.equals(55, vim.api.nvim_win_get_config(global_win).width)
		vim.api.nvim_win_close(global_win, true)

		local archive_win = float.open(buf, { kind = 'archive', max_width = 70 })
		assert.equals(33, vim.api.nvim_win_get_config(archive_win).width)
		vim.api.nvim_win_close(archive_win, true)

		config.float = saved
		user_config.float = saved_user
	end)

	it('uses all available columns when width is auto', function()
		local config = require('glimpse').get_config()
		local saved = vim.deepcopy(config.float)
		local buf = vim.api.nvim_create_buf(false, true)
		config.float = { width = 'auto' }

		local win = float.open(buf)
		assert.equals(vim.o.columns - 4, vim.api.nvim_win_get_config(win).width)
		vim.api.nvim_win_close(win, true)

		config.float = saved
	end)

	it('uses an expected content height before a buffer is populated', function()
		local buf = vim.api.nvim_create_buf(false, true)
		local win = float.open(buf, { content_height = 12 })

		assert.equals(12, vim.api.nvim_win_get_config(win).height)
		vim.api.nvim_win_close(win, true)
	end)

	it('resolves dynamic content height after the final width', function()
		local buf = vim.api.nvim_create_buf(false, true)
		local resolved_width
		local win = float.open(buf, {
			max_width = 40,
			content_height = function(width)
				resolved_width = width
				return 9
			end,
		})

		assert.equals(40, resolved_width)
		assert.equals(9, vim.api.nvim_win_get_config(win).height)
		vim.api.nvim_win_close(win, true)
	end)

	it('reflows tracked windows on resize events', function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
			'one',
			'two',
			'three',
			'four',
		})

		local win = float.open(buf, {
			title = ' Test ',
			max_width = 40,
		})

		local original_set_config = vim.api.nvim_win_set_config
		local called = false
		vim.api.nvim_win_set_config = function(target, config)
			if target == win then
				called = true
				assert.equals('editor', config.relative)
				assert.is_true(config.width >= 20)
				assert.is_true(config.height >= 4)
			end
			return original_set_config(target, config)
		end

		local ok, err = pcall(function()
			vim.api.nvim_exec_autocmds('WinResized', {})
		end)

		vim.api.nvim_win_set_config = original_set_config
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end

		if not ok then
			error(err)
		end

		assert.is_true(called)
	end)
end)
