describe('inline strategy', function()
	it('resolves vsplit size from the actual left split position', function()
		local original_win_get_position = vim.api.nvim_win_get_position
		vim.api.nvim_win_get_position = function(win)
			if win == 1 then
				return { 0, 40 }
			end
			return { 0, 0 }
		end

		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')

		assert.equals(60, inline._resolve_vsplit_size({ left = 60, right = 30 }, 1, 2))

		vim.api.nvim_win_get_position = original_win_get_position
		package.loaded['glimpse.strategy.inline'] = nil
	end)

	it('resolves vsplit size from the actual right split position', function()
		local original_win_get_position = vim.api.nvim_win_get_position
		vim.api.nvim_win_get_position = function(win)
			if win == 1 then
				return { 0, 0 }
			end
			return { 0, 40 }
		end

		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')

		assert.equals(30, inline._resolve_vsplit_size({ left = 60, right = 30 }, 1, 2))

		vim.api.nvim_win_get_position = original_win_get_position
		package.loaded['glimpse.strategy.inline'] = nil
	end)

	it('uses a numeric vsplit size for either side', function()
		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')

		assert.equals(45, inline._resolve_vsplit_size(45, 1, 2))

		package.loaded['glimpse.strategy.inline'] = nil
	end)

	it('falls back to right size when split position cannot be read', function()
		local original_win_get_position = vim.api.nvim_win_get_position
		vim.api.nvim_win_get_position = function()
			error('invalid window')
		end

		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')

		assert.equals(30, inline._resolve_vsplit_size({ left = 60, right = 30 }, 1, 2))

		vim.api.nvim_win_get_position = original_win_get_position
		package.loaded['glimpse.strategy.inline'] = nil
	end)

	it('keeps model files in their source buffers on BufReadPost', function()
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_get_name = vim.api.nvim_buf_get_name
		local original_schedule = vim.schedule
		local callback

		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.api.nvim_create_autocmd = function(event, spec)
			if event == 'BufReadPost' then
				callback = spec.callback
			end
			return 1
		end
		vim.api.nvim_buf_get_name = function()
			return '/tmp/model.obj'
		end
		vim.schedule = function() end

		local shown = false
		package.loaded['glimpse.previewer.model'] = {
			show = function()
				shown = true
			end,
		}
		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')
		inline.setup_autocmds()

		assert.is_function(callback)
		callback({ buf = 1 })

		vim.api.nvim_create_augroup = original_create_augroup
		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_buf_get_name = original_get_name
		vim.schedule = original_schedule

		assert.is_false(shown)
		package.loaded['glimpse.previewer.model'] = nil
		package.loaded['glimpse.strategy.inline'] = nil
	end)
end)
