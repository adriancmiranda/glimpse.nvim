local function save_package(names)
	local saved = {}
	for _, name in ipairs(names) do
		saved[name] = package.loaded[name]
	end
	return saved
end

local function restore_package(saved)
	for name, value in pairs(saved) do
		package.loaded[name] = value
	end
end

describe('oil integration', function()
	it('keeps the default image opener on edit', function()
		local saved = save_package({
			'glimpse',
			'oil',
			'glimpse.integrations.oil',
		})

		local calls = {}
		local dir = vim.fn.tempname() .. '/'
		vim.fn.mkdir(dir, 'p')
		local path = dir .. 'image.png'
		vim.fn.writefile({ 'png' }, path)

		package.loaded['oil'] = {
			close = function()
				calls.close = (calls.close or 0) + 1
			end,
		}

		local original_cmd = vim.cmd
		vim.cmd = function(cmd)
			calls.cmd = cmd
		end

		package.loaded['glimpse'] = nil
		local glimpse = require('glimpse')
		glimpse.setup({
			strategy = 'inline',
			integrations = {
				oil = true,
				neotree = false,
				telescope = false,
			},
			cache_max_age_days = 0,
		})

		local oil = require('glimpse.integrations.oil')
		assert.equals('edit', glimpse.get_config().integrations.oil.open)
		oil._open_image(path, glimpse.get_config().integrations.oil.open)

		assert.equals('edit ' .. vim.fn.fnameescape(path), calls.cmd)
		assert.equals(1, calls.close or 0)

		vim.cmd = original_cmd
		vim.loop.fs_unlink(path)
		restore_package(saved)
	end)

	it('opens images in a new tab when configured', function()
		local saved = save_package({
			'glimpse',
			'oil',
			'glimpse.integrations.oil',
		})

		local calls = {}
		local dir = vim.fn.tempname() .. '/'
		vim.fn.mkdir(dir, 'p')
		local path = dir .. 'image.png'
		vim.fn.writefile({ 'png' }, path)

		package.loaded['oil'] = {
			close = function()
				calls.close = (calls.close or 0) + 1
			end,
		}

		local original_cmd = vim.cmd
		vim.cmd = function(cmd)
			calls.cmd = cmd
		end

		package.loaded['glimpse'] = nil
		local glimpse = require('glimpse')
		glimpse.setup({
			strategy = 'inline',
			integrations = {
				oil = {
					open = 'tabedit',
				},
				neotree = false,
				telescope = false,
			},
			cache_max_age_days = 0,
		})

		local oil = require('glimpse.integrations.oil')
		assert.equals('tabedit', glimpse.get_config().integrations.oil.open)
		oil._open_image(path, glimpse.get_config().integrations.oil.open)

		assert.equals('tabedit ' .. vim.fn.fnameescape(path), calls.cmd)
		assert.equals(1, calls.close or 0)

		vim.cmd = original_cmd
		vim.loop.fs_unlink(path)
		restore_package(saved)
	end)
end)
