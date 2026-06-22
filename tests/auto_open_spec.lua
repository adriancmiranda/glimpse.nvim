describe('auto-open', function()
	it('renders non-text previews without replacing Markdown source buffers', function()
		local original_create_autocmd = vim.api.nvim_create_autocmd
		local callback
		vim.api.nvim_create_autocmd = function(event, spec)
			if event == 'BufReadPost' and spec.callback then
				callback = spec.callback
			end
			return 1
		end

		local glimpse = require('glimpse')
		glimpse.setup({
			auto_open = true,
			strategy = 'pane',
			integrations = {
				oil = false,
				neotree = false,
				telescope = false,
			},
			cache = { max_age_days = 0 },
		})
		vim.api.nvim_create_autocmd = original_create_autocmd

		assert.is_function(callback)
		local shown
		glimpse.show = function(filepath)
			shown = filepath
		end

		callback({ file = '/tmp/README.md' })
		assert.is_nil(shown)

		callback({ file = '/tmp/model.obj' })
		assert.is_nil(shown)

		callback({ file = '/tmp/movie.mp4' })
		assert.equals('/tmp/movie.mp4', shown)
	end)
end)
