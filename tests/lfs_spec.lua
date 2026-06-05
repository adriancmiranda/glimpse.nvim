describe('git lfs pointer handling', function()
	it('keeps git lfs pointers out of the image renderer', function()
		local saved = {
			renderer = package.loaded['glimpse.renderer'],
			detect = package.loaded['glimpse.detect'],
			dir = package.loaded['glimpse.dir'],
			oil = package.loaded['glimpse.integrations.oil'],
			neotree = package.loaded['glimpse.integrations.neotree'],
			telescope = package.loaded['glimpse.integrations.telescope'],
		}

		package.loaded['glimpse.renderer'] = {
			render = function()
				error('render should not be called for git lfs pointers')
			end,
			close = function() end,
			has_placement = function()
				return false
			end,
			register = function() end,
			rerender = function() end,
		}
		package.loaded['glimpse.detect'] = {
			supports_inline = function()
				return true
			end,
		}
		package.loaded['glimpse.dir'] = { follow = function() end }
		package.loaded['glimpse.integrations.oil'] = { setup = function() end }
		package.loaded['glimpse.integrations.neotree'] = { setup = function() end }
		package.loaded['glimpse.integrations.telescope'] = { setup = function() end }

		local pointer = vim.fn.tempname() .. '.jpg'
		vim.fn.writefile({
			'version https://git-lfs.github.com/spec/v1',
			'oid sha256:fe93af5da1f8d77dac7187f24de828c8fab913629e7870ba27cff63ba5e8554f',
			'size 1576804',
		}, pointer)

		local glimpse = require('glimpse')
		glimpse.setup({
			strategy = 'inline',
			integrations = {
				oil = false,
				neotree = false,
				telescope = false,
			},
			inline = {
				rerender_on_tab = true,
			},
			cache_max_age_days = 0,
		})

		vim.o.swapfile = false
		vim.cmd('edit ' .. pointer)
		assert.is_true(vim.wait(500, function()
			return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'version https://git-lfs.github.com/spec/v1'
		end, 10))
		assert.is_true(glimpse.is_git_lfs_pointer(pointer))

		vim.loop.fs_unlink(pointer)
		for name, value in pairs(saved) do
			package.loaded[name] = value
		end
	end)
end)
