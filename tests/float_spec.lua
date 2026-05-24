local float = require('glimpse.float')

describe('float preview helper', function()
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
