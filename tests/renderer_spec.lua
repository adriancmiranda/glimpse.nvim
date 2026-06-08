local function restore_package(name, value)
	package.loaded[name] = value
end

local function normalize(path)
	return vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

describe('renderer', function()
	it('keeps the full file path in the rendered buffer', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			assert.equals(normalize(filepath), normalize(vim.api.nvim_buf_get_name(buf)))
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('hides listed inline buffers by default', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			assert.equals('hide', vim.bo[buf].bufhidden)
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('reapplies buffer flags when reusing an existing render', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		local transmit_calls = 0
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				transmit_calls = transmit_calls + 1
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath)
			assert.is_false(vim.bo[buf].buflisted)
			renderer.render(buf, filepath, { listed = true })
			assert.equals(1, transmit_calls)
			assert.is_true(vim.bo[buf].buflisted)
			assert.equals('hide', vim.bo[buf].bufhidden)
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('preserves an explicit buffer name when rendering', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)
		local bufname = 'glimpse://telescope/media/image/abc123'

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true, bufname = bufname })
			assert.equals(bufname, vim.api.nvim_buf_get_name(buf))
			assert.is_true(renderer.has_placement(buf))
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('keeps the current render when the same file is rendered again', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		local transmit_calls = 0
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				transmit_calls = transmit_calls + 1
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
			renderer.render(buf, filepath, { listed = true })
			assert.equals(1, transmit_calls)
			assert.is_true(renderer.has_placement(buf))
			assert.equals(first_line, vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('re-renders when the same file changes on disk', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		local transmit_calls = 0
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				transmit_calls = transmit_calls + 1
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			vim.fn.writefile({ 'y' }, filepath)
			renderer.render(buf, filepath, { listed = true })
			assert.equals(2, transmit_calls)
			assert.is_true(renderer.has_placement(buf))
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('re-renders when the same file is shown in a differently sized window', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		local transmit_calls = 0
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				transmit_calls = transmit_calls + 1
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			vim.cmd('vsplit')
			local split_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(split_win, buf)
			vim.cmd('vertical resize 40')
			renderer.render(buf, filepath, { listed = true, winid = split_win })
			assert.equals(2, transmit_calls)
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)

	it('treats normalized paths as the same image', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local dir = root .. '/nested'
		vim.fn.mkdir(dir, 'p')
		local filepath = dir .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		local alias = dir .. '/../nested/sample.png'
		local transmit_calls = 0
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				transmit_calls = transmit_calls + 1
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local ok, err = pcall(function()
			renderer.render(buf, filepath, { listed = true })
			renderer.render(buf, alias, { listed = true })
			assert.equals(1, transmit_calls)
			assert.is_true(renderer.has_placement(buf))
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
		if not ok then
			error(err)
		end
	end)
end)
