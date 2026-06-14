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

	it('reuses a bounded pool of highlight groups across renders', function()
		local original_kitty = package.loaded['glimpse.kitty']
		local original_renderer = package.loaded['glimpse.renderer']
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win = vim.api.nvim_get_current_win()

		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')

		local id_seq = 0
		restore_package('glimpse.kitty', {
			transmit_async = function(_, _, callback)
				id_seq = id_seq + 1
				callback(id_seq, nil, 16, 16)
				return nil
			end,
			delete = function()
				return true
			end,
		})
		restore_package('glimpse.renderer', nil)

		local renderer = require('glimpse.renderer')

		local ok, err = pcall(function()
			local bufs = {}
			local hl_names = {}

			-- render 4 different buffers and collect their highlight group names
			for i = 1, 4 do
				local fp = root .. '/img' .. i .. '.png'
				vim.fn.writefile({ tostring(i) }, fp)
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_win_set_buf(original_win, buf)
				renderer.render(buf, fp)
				bufs[i] = buf

				-- find the extmark highlight group applied to this buffer
				local marks =
					vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace('glimpse'), 0, -1, { details = true })
				if marks and marks[1] then
					hl_names[i] = marks[1][4] and marks[1][4].hl_group
				end
			end

			-- all highlight groups must start with 'GlimpseImage' (not 'ImagePreview')
			for i = 1, 4 do
				if hl_names[i] then
					assert.truthy(hl_names[i]:match('^GlimpseImage'))
				end
			end

			-- each active buffer must hold a distinct slot
			local seen = {}
			for i = 1, 4 do
				if hl_names[i] then
					assert.is_nil(seen[hl_names[i]], 'slot collision: ' .. (hl_names[i] or '?'))
					seen[hl_names[i]] = true
				end
			end

			-- after closing a buffer its slot must be available for reuse
			renderer.close(bufs[1])
			local fp_new = root .. '/new.png'
			vim.fn.writefile({ 'n' }, fp_new)
			local buf_new = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_win_set_buf(original_win, buf_new)
			renderer.render(buf_new, fp_new)
			local marks_new =
				vim.api.nvim_buf_get_extmarks(buf_new, vim.api.nvim_create_namespace('glimpse'), 0, -1, { details = true })
			local hl_new = marks_new and marks_new[1] and marks_new[1][4] and marks_new[1][4].hl_group
			-- the new render must reuse the slot freed by bufs[1]
			assert.equals(hl_names[1], hl_new)

			for i = 2, 4 do
				renderer.close(bufs[i])
			end
			renderer.close(buf_new)
		end)

		pcall(vim.api.nvim_win_set_buf, original_win, original_buf)
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
