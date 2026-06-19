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

	it('register keeps created_at so rerender can safely debounce', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/sample.png'
		vim.fn.writefile({ 'x' }, filepath)

		restore_package('glimpse.kitty', {
			transmit_async = function()
				error('rerender should debounce before starting a new transmit')
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
			renderer.register(buf, filepath)
			assert.is_not_nil(renderer.get_placement(buf).created_at)
			renderer.rerender(buf)
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

describe('renderer animation helpers', function()
	local original_kitty
	local original_renderer

	before_each(function()
		original_kitty = package.loaded['glimpse.kitty']
		original_renderer = package.loaded['glimpse.renderer']
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				callback(1, nil, 16, 16)
				return nil
			end,
			delete = function() end,
		})
		restore_package('glimpse.renderer', nil)
	end)

	after_each(function()
		restore_package('glimpse.kitty', original_kitty)
		restore_package('glimpse.renderer', original_renderer)
	end)

	it('setup_animation_buf creates a placement with image_id and created_at', function()
		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		renderer.setup_animation_buf(buf, win, 42, 4, 4, 20, 10)
		local placement = renderer.get_placement(buf)
		assert.is_not_nil(placement)
		assert.equals(42, placement.image_id)
		assert.is_not_nil(placement.created_at)
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end)

	it('setup_animation_buf writes placeholder lines to the buffer', function()
		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		renderer.setup_animation_buf(buf, win, 99, 2, 3, 20, 10)
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		assert.equals(3, #lines)
		assert.is_true(#lines[1] > 0)
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end)

	it('get_placement returns nil for unknown buffer', function()
		local renderer = require('glimpse.renderer')
		assert.is_nil(renderer.get_placement(99999))
	end)

	it('update_animation_highlight updates the placement image_id', function()
		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		renderer.setup_animation_buf(buf, win, 10, 2, 2, 20, 10)
		renderer.update_animation_highlight(buf, 20)
		local placement = renderer.get_placement(buf)
		assert.equals(20, placement.image_id)
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end)

	it('coalesces rapid rerender calls into at most 2 spawns', function()
		local saved_kitty = package.loaded['glimpse.kitty']
		local saved_renderer = package.loaded['glimpse.renderer']
		local saved_glimpse = package.loaded['glimpse']
		local original_win = vim.api.nvim_get_current_win()
		local original_buf = vim.api.nvim_get_current_buf()

		local spawn_count = 0
		local pending_cb = nil
		local next_job = 100

		restore_package('glimpse', {
			get_config = function()
				return { cell_size = { width = 20, height = 40 }, loading = { text = '...' } }
			end,
		})
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, cb)
				spawn_count = spawn_count + 1
				next_job = next_job + 1
				pending_cb = cb
				return next_job
			end,
			delete = function() end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local tmp = vim.fn.tempname() .. '.png'
		vim.fn.writefile({ 'x' }, tmp)

		-- Complete the initial render so the placement is fully set up.
		-- render()'s callback does not have dispatch_pending, so we finish it
		-- before the pending-slot test begins.
		renderer.render(buf, tmp)
		pending_cb(1, nil, 100, 100)

		-- Reset the counter and backdate created_at to bypass the 500ms guard.
		spawn_count = 0
		local placement = renderer.get_placement(buf)
		placement.created_at = 0

		-- First rerender: starts conversion #1 (in-flight, cb stored).
		renderer.rerender(buf)
		assert.equals(1, spawn_count)

		-- Three rapid rerenders while #1 is in-flight: no new spawns.
		renderer.rerender(buf)
		renderer.rerender(buf)
		renderer.rerender(buf)
		assert.equals(1, spawn_count)

		-- Complete conversion #1 (stale: request_id changed by rapid calls).
		-- dispatch_pending schedules exactly one follow-up rerender.
		pending_cb(1, nil, 100, 100)

		vim.wait(100, function()
			return spawn_count >= 2
		end)

		-- Exactly 2 spawns for 4 rerender calls: the rapid ones were coalesced.
		assert.equals(2, spawn_count)

		os.remove(tmp)
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		restore_package('glimpse.kitty', saved_kitty)
		restore_package('glimpse.renderer', saved_renderer)
		restore_package('glimpse', saved_glimpse)
	end)

	it('suppresses convert errors after the placement is closed', function()
		local saved_kitty = package.loaded['glimpse.kitty']
		local saved_renderer = package.loaded['glimpse.renderer']
		local saved_glimpse = package.loaded['glimpse']
		local original_win = vim.api.nvim_get_current_win()
		local original_buf = vim.api.nvim_get_current_buf()
		local original_notify = vim.notify

		local pending_cb = nil
		local notifications = {}

		restore_package('glimpse', {
			get_config = function()
				return { cell_size = { width = 20, height = 40 }, loading = { text = '...' } }
			end,
		})
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, cb)
				pending_cb = cb
				return 1
			end,
			delete = function() end,
		})
		restore_package('glimpse.renderer', nil)
		vim.notify = function(msg, level)
			notifications[#notifications + 1] = { msg = msg, level = level }
		end

		local renderer = require('glimpse.renderer')
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(original_win, buf)

		local tmp = vim.fn.tempname() .. '.png'
		vim.fn.writefile({ 'x' }, tmp)

		renderer.render(buf, tmp)
		renderer.close(buf)
		pending_cb(nil, 'magick falhou (code=1)')

		assert.equals(0, #notifications)

		os.remove(tmp)
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
		vim.notify = original_notify
		restore_package('glimpse.kitty', saved_kitty)
		restore_package('glimpse.renderer', saved_renderer)
		restore_package('glimpse', saved_glimpse)
	end)
end)
