describe('GlimpsePreview command', function()
	local original_create_user_command
	local original_buf_get_name
	local original_expand
	local original_fnamemodify
	local original_notify
	local command

	before_each(function()
		original_create_user_command = vim.api.nvim_create_user_command
		original_buf_get_name = vim.api.nvim_buf_get_name
		original_expand = vim.fn.expand
		original_fnamemodify = vim.fn.fnamemodify
		original_notify = vim.notify

		vim.api.nvim_create_user_command = function(name, callback, opts)
			if name == 'GlimpsePreview' then
				command = { callback = callback, opts = opts }
			end
		end

		package.loaded['glimpse'] = nil
		local glimpse = require('glimpse')
		glimpse.setup({
			strategy = 'pane',
			integrations = {
				oil = false,
				neotree = false,
				telescope = false,
			},
			cache = { max_age_days = 0 },
		})
	end)

	after_each(function()
		vim.api.nvim_create_user_command = original_create_user_command
		vim.api.nvim_buf_get_name = original_buf_get_name
		vim.fn.expand = original_expand
		vim.fn.fnamemodify = original_fnamemodify
		vim.notify = original_notify
		package.loaded['glimpse'] = nil
	end)

	it('registers with an optional file argument and file completion', function()
		assert.is_table(command)
		assert.equals('*', command.opts.nargs)
		assert.equals('file', command.opts.complete)
	end)

	it('previews the current buffer when no argument is given', function()
		local glimpse = require('glimpse')
		local called
		glimpse.preview = function(filepath, opts)
			called = { filepath = filepath, opts = opts }
		end
		vim.api.nvim_buf_get_name = function()
			return '/tmp/current.md'
		end
		vim.fn.fnamemodify = function(filepath)
			return filepath
		end

		command.callback({ args = '' })

		assert.equals('/tmp/current.md', called.filepath)
		assert.equals('auto', called.opts.target)
	end)

	it('expands an explicit file argument before previewing it', function()
		local glimpse = require('glimpse')
		local filepath
		glimpse.preview = function(value)
			filepath = value
		end
		vim.fn.expand = function(value)
			assert.equals('~/model.obj', value)
			return '/Users/test/model.obj'
		end
		vim.fn.fnamemodify = function(value, modifier)
			assert.equals(':p', modifier)
			return value
		end

		command.callback({ args = '~/model.obj' })

		assert.equals('/Users/test/model.obj', filepath)
	end)

	it('warns when the current buffer has no file', function()
		local message
		vim.api.nvim_buf_get_name = function()
			return ''
		end
		vim.notify = function(value)
			message = value
		end

		command.callback({ args = '' })

		assert.equals('[glimpse] current buffer has no file', message)
	end)
end)
