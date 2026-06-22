-- Normalize a vim.cmd argument (string or structured table) to a string so
-- mocks can match against it with the same logic regardless of call style.
local function cmd_to_str(cmd)
	if type(cmd) == 'string' then
		return cmd
	end
	if type(cmd) == 'table' and cmd.cmd then
		local arg = cmd.args and cmd.args[1] or nil
		return arg and (cmd.cmd .. ' ' .. arg) or cmd.cmd
	end
	return tostring(cmd)
end

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
	it('reuses an existing image buffer instead of creating a new unnamed one', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil.float',
			'glimpse.integrations.oil.open',
			'glimpse.integrations.oil.path',
			'glimpse.integrations.oil',
		})

		local oil_buf = 1
		local image_buf = 10
		local current_buf = oil_buf
		local current_win = 100
		local render_calls = {}
		local autocmds = {}
		local mappings = {}
		local follow_calls = {}
		local buf_names = {
			[oil_buf] = '/tmp/image.png',
			[image_buf] = '/tmp/image.png',
		}
		local windows = {
			[100] = oil_buf,
			[101] = image_buf,
		}

		package.loaded['oil'] = {
			close = function()
				return true
			end,
			get_cursor_entry = function()
				return { type = 'file', name = 'image.png' }
			end,
			get_current_dir = function()
				return '/tmp'
			end,
		}
		package.loaded['glimpse.util'] = {
			is_video = function()
				return false
			end,
			is_image = function()
				return true
			end,
			is_font = function()
				return false
			end,
		}
		package.loaded['glimpse.dir'] = {
			follow = function(filepath)
				follow_calls[#follow_calls + 1] = filepath
			end,
		}
		package.loaded['glimpse.renderer'] = {
			find_by_filepath = function()
				return image_buf
			end,
			render = function(buf, filepath)
				render_calls[#render_calls + 1] = { buf = buf, filepath = filepath }
			end,
		}
		package.loaded['glimpse'] = {
			get_config = function()
				return {
					keys = { preview = 'p', open = 'o', close = 'q' },
					video = { open = nil },
				}
			end,
			_should_use_inline = function()
				return true
			end,
			preview = function()
				return true
			end,
		}

		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_keymap_set = vim.keymap.set
		local original_cmd = vim.cmd
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_buf = vim.api.nvim_set_current_buf
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_bufs = vim.api.nvim_list_bufs
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_buf_get_name = vim.api.nvim_buf_get_name
		local original_buf_set_name = vim.api.nvim_buf_set_name
		local original_buf_get_option = vim.api.nvim_buf_get_option
		local original_buf_set_option = vim.api.nvim_buf_set_option

		vim.api.nvim_create_autocmd = function(event, spec)
			autocmds[event] = spec
			return 1
		end
		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.keymap.set = function(_, lhs, cb)
			mappings[lhs] = cb
		end
		vim.cmd = function(cmd)
			local cmd_str = cmd_to_str(cmd)
			if cmd_str:match('^edit ') then
				current_buf = image_buf
				current_win = 101
			end
			return true
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
			current_buf = windows[win] or current_buf
		end
		vim.api.nvim_list_bufs = function()
			return { oil_buf, image_buf }
		end
		vim.api.nvim_list_wins = function()
			return { 100, 101 }
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == oil_buf or buf == image_buf
		end
		vim.api.nvim_buf_get_name = function(buf)
			return buf_names[buf] or ''
		end
		vim.api.nvim_buf_set_name = function(buf, name)
			buf_names[buf] = name
		end
		vim.api.nvim_buf_get_option = function()
			return ''
		end
		vim.api.nvim_buf_set_option = function()
			return true
		end

		local oil = require('glimpse.integrations.oil')
		oil.setup()
		autocmds.FileType.callback({ buf = oil_buf })
		mappings.o()

		assert.equals(0, #render_calls)
		assert.equals(1, #follow_calls)
		assert.equals('/tmp/image.png', follow_calls[1])
		assert.equals(image_buf, current_buf)
		assert.equals(101, current_win)

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_buf = original_set_current_buf
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_bufs = original_list_bufs
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_buf_get_name = original_buf_get_name
		vim.api.nvim_buf_set_name = original_buf_set_name
		vim.api.nvim_buf_get_option = original_buf_get_option
		vim.api.nvim_buf_set_option = original_buf_set_option
		restore_package(saved)
	end)

	it('respects tabedit when opening a fresh image buffer', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil.float',
			'glimpse.integrations.oil.open',
			'glimpse.integrations.oil.path',
			'glimpse.integrations.oil',
		})

		local oil_buf = 1
		local tab_buf = 20
		local current_buf = oil_buf
		local current_win = 100
		local render_calls = {}
		local autocmds = {}
		local mappings = {}
		local cmd_calls = {}
		local create_buf_calls = 0
		local buf_names = {
			[oil_buf] = '',
			[tab_buf] = '',
		}
		local windows = {
			[100] = oil_buf,
		}

		package.loaded['oil'] = {
			close = function()
				return true
			end,
			get_cursor_entry = function()
				return { type = 'file', name = 'image.png' }
			end,
			get_current_dir = function()
				return '/tmp'
			end,
		}
		package.loaded['glimpse.util'] = {
			is_video = function()
				return false
			end,
			is_image = function()
				return true
			end,
			is_font = function()
				return false
			end,
		}
		package.loaded['glimpse.renderer'] = {
			find_by_filepath = function()
				return nil
			end,
			render = function(buf, filepath)
				render_calls[#render_calls + 1] = { buf = buf, filepath = filepath }
			end,
		}
		package.loaded['glimpse'] = {
			get_config = function()
				return {
					keys = { preview = 'p', open = 'o', close = 'q' },
					integrations = {
						oil = {
							open = 'tabedit',
						},
					},
					video = { open = nil },
				}
			end,
			_should_use_inline = function()
				return true
			end,
			preview = function()
				return true
			end,
		}

		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_keymap_set = vim.keymap.set
		local original_cmd = vim.cmd
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_buf = vim.api.nvim_set_current_buf
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_bufs = vim.api.nvim_list_bufs
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_buf_get_name = vim.api.nvim_buf_get_name
		local original_buf_set_name = vim.api.nvim_buf_set_name
		local original_buf_get_option = vim.api.nvim_buf_get_option
		local original_buf_set_option = vim.api.nvim_buf_set_option
		local original_create_buf = vim.api.nvim_create_buf

		vim.api.nvim_create_autocmd = function(event, spec)
			autocmds[event] = spec
			return 1
		end
		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.keymap.set = function(_, lhs, cb)
			mappings[lhs] = cb
		end
		vim.cmd = function(cmd)
			local cmd_str = cmd_to_str(cmd)
			cmd_calls[#cmd_calls + 1] = cmd_str
			if cmd_str:match('^tabedit ') then
				current_buf = tab_buf
				current_win = 101
			end
			return true
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
			current_buf = windows[win] or current_buf
		end
		vim.api.nvim_list_bufs = function()
			return { oil_buf }
		end
		vim.api.nvim_list_wins = function()
			return { 100 }
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == oil_buf or buf == tab_buf
		end
		vim.api.nvim_buf_get_name = function(buf)
			return buf_names[buf] or ''
		end
		vim.api.nvim_buf_set_name = function(buf, name)
			buf_names[buf] = name
		end
		vim.api.nvim_buf_get_option = function()
			return ''
		end
		vim.api.nvim_buf_set_option = function()
			return true
		end
		vim.api.nvim_create_buf = function()
			create_buf_calls = create_buf_calls + 1
			return 99
		end

		local oil = require('glimpse.integrations.oil')
		oil.setup()
		autocmds.FileType.callback({ buf = oil_buf })
		mappings.o()

		assert.equals(1, #cmd_calls)
		assert.equals('tabedit /tmp/image.png', cmd_calls[1])
		assert.equals(0, create_buf_calls)
		assert.equals(1, #render_calls)
		assert.equals(tab_buf, render_calls[1].buf)
		assert.equals('/tmp/image.png', render_calls[1].filepath)
		assert.equals(tab_buf, current_buf)
		assert.equals(101, current_win)

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_buf = original_set_current_buf
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_bufs = original_list_bufs
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_buf_get_name = original_buf_get_name
		vim.api.nvim_buf_set_name = original_buf_set_name
		vim.api.nvim_buf_get_option = original_buf_get_option
		vim.api.nvim_buf_set_option = original_buf_set_option
		vim.api.nvim_create_buf = original_create_buf
		restore_package(saved)
	end)

	it('resolves the float directory from the current file buffer', function()
		local saved = save_package({
			'glimpse.integrations.oil.float',
			'glimpse.integrations.oil.path',
			'glimpse.integrations.oil',
		})

		local original_buf = vim.api.nvim_get_current_buf()
		local image_buf = vim.api.nvim_create_buf(false, true)
		local filepath = vim.fs.joinpath(vim.fn.tempname(), 'target.png')
		vim.fn.mkdir(vim.fs.dirname(filepath), 'p')
		vim.fn.writefile({ 'png' }, filepath)

		vim.api.nvim_set_current_buf(image_buf)
		vim.bo[image_buf].filetype = 'markdown'
		vim.api.nvim_buf_set_name(image_buf, filepath)

		local oil = require('glimpse.integrations.oil')
		local dirpath, cursor = oil.resolve_float_dir()

		assert.equals(vim.uv.fs_realpath(vim.fs.dirname(filepath)), vim.uv.fs_realpath(dirpath))
		assert.equals(vim.fs.basename(filepath), cursor)

		vim.api.nvim_set_current_buf(original_buf)
		if vim.api.nvim_buf_is_valid(image_buf) then
			vim.api.nvim_buf_delete(image_buf, { force = true })
		end
		vim.fn.delete(filepath)
		vim.fn.delete(vim.fs.dirname(filepath), 'd')
		restore_package(saved)
	end)

	it('toggles Oil float with resolved dir and restores cursor target', function()
		local saved = save_package({
			'oil',
			'glimpse.integrations.oil.float',
			'glimpse.integrations.oil.path',
			'glimpse.integrations.oil',
		})

		local image_buf = vim.api.nvim_create_buf(false, true)
		local oil_buf = vim.api.nvim_create_buf(false, true)
		local filepath = vim.fn.tempname() .. '.png'
		local original_buf = vim.api.nvim_get_current_buf()
		local original_win_get_cursor = vim.api.nvim_win_get_cursor
		local original_win_set_cursor = vim.api.nvim_win_set_cursor
		local cursor_calls = {}
		local calls = {}

		package.loaded['oil'] = {
			toggle_float = function(dirpath, opts, cb)
				calls.dirpath = dirpath
				calls.opts = opts
				vim.api.nvim_set_current_buf(oil_buf)
				vim.bo[oil_buf].filetype = 'oil'
				if cb then
					cb()
				end
			end,
			get_entry_on_line = function(_, lnum)
				if lnum == 2 then
					return { name = vim.fs.basename(filepath) }
				end
				return { name = 'other.png' }
			end,
		}

		vim.fn.mkdir(vim.fs.dirname(filepath), 'p')
		vim.fn.writefile({ 'png' }, filepath)
		vim.api.nvim_set_current_buf(image_buf)
		vim.bo[image_buf].filetype = 'lua'
		vim.api.nvim_buf_set_name(image_buf, filepath)
		vim.api.nvim_buf_set_lines(oil_buf, 0, -1, false, { 'other.png', vim.fs.basename(filepath) })
		vim.api.nvim_win_get_cursor = function()
			return { 1, 0 }
		end
		vim.api.nvim_win_set_cursor = function(_, pos)
			cursor_calls[#cursor_calls + 1] = pos
		end

		local oil = require('glimpse.integrations.oil')
		oil.toggle_float({
			oil_opts = { border = 'rounded' },
			cb = function(dirpath, cursor)
				calls.cb = { dirpath = dirpath, cursor = cursor }
			end,
		})

		assert.equals(vim.uv.fs_realpath(vim.fs.dirname(filepath)), vim.uv.fs_realpath(calls.dirpath))
		assert.are.same({ border = 'rounded' }, calls.opts)
		assert.are.same({ 2, 0 }, cursor_calls[1])
		assert.equals(calls.dirpath, calls.cb.dirpath)
		assert.equals(vim.fs.basename(filepath), calls.cb.cursor)

		vim.api.nvim_win_get_cursor = original_win_get_cursor
		vim.api.nvim_win_set_cursor = original_win_set_cursor
		vim.api.nvim_set_current_buf(original_buf)
		if vim.api.nvim_buf_is_valid(image_buf) then
			vim.api.nvim_buf_delete(image_buf, { force = true })
		end
		if vim.api.nvim_buf_is_valid(oil_buf) then
			vim.api.nvim_buf_delete(oil_buf, { force = true })
		end
		vim.fn.delete(filepath)
		vim.fn.delete(vim.fs.dirname(filepath), 'd')
		restore_package(saved)
	end)

	it('refreshes a directly opened image after toggling the Oil float', function()
		local saved = save_package({
			'oil',
			'glimpse.renderer',
			'glimpse.integrations.oil.float',
			'glimpse.integrations.oil.path',
			'glimpse.integrations.oil',
		})

		local image_buf = vim.api.nvim_create_buf(false, true)
		local oil_buf = vim.api.nvim_create_buf(false, true)
		local filepath = vim.fn.tempname() .. '.png'
		local original_buf = vim.api.nvim_get_current_buf()
		local calls = {}

		vim.fn.writefile({ 'png' }, filepath)
		vim.api.nvim_set_current_buf(image_buf)
		vim.api.nvim_buf_set_name(image_buf, filepath)
		vim.bo[image_buf].filetype = 'image'

		package.loaded['oil'] = {
			toggle_float = function(_, _, cb)
				vim.api.nvim_set_current_buf(oil_buf)
				vim.bo[oil_buf].filetype = 'oil'
				cb()
			end,
		}
		package.loaded['glimpse.renderer'] = {
			has_placement = function(buf)
				return buf == image_buf
			end,
			rerender = function(buf, opts)
				calls.buf = buf
				calls.opts = opts
			end,
		}

		require('glimpse.integrations.oil').toggle_float()

		assert.equals(image_buf, calls.buf)
		assert.are.same({ force = true }, calls.opts)

		vim.api.nvim_set_current_buf(original_buf)
		if vim.api.nvim_buf_is_valid(image_buf) then
			vim.api.nvim_buf_delete(image_buf, { force = true })
		end
		if vim.api.nvim_buf_is_valid(oil_buf) then
			vim.api.nvim_buf_delete(oil_buf, { force = true })
		end
		vim.fn.delete(filepath)
		restore_package(saved)
	end)

	it('resolves the startup argv path when no file buffer is active', function()
		local saved = save_package({
			'glimpse.integrations.oil.float',
			'glimpse.integrations.oil.path',
			'glimpse.integrations.oil',
		})

		local original_buf = vim.api.nvim_get_current_buf()
		local original_argc = vim.fn.argc
		local original_argv = vim.fn.argv
		local temp_dir = vim.fn.tempname()
		local relative_dir = 'nested/oil'
		local expected_dir = vim.fs.joinpath(vim.uv.cwd() or vim.fn.getcwd(), relative_dir)

		vim.fn.mkdir(expected_dir, 'p')
		vim.api.nvim_buf_set_name(original_buf, '')
		vim.fn.argc = function()
			return 1
		end
		vim.fn.argv = function()
			return relative_dir
		end

		local oil = require('glimpse.integrations.oil')
		local dirpath, cursor = oil.resolve_float_dir()

		assert.equals(vim.fs.normalize(expected_dir), vim.fs.normalize(dirpath))
		assert.is_nil(cursor)

		vim.fn.argc = original_argc
		vim.fn.argv = original_argv
		vim.api.nvim_set_current_buf(original_buf)
		vim.fn.delete(expected_dir, 'd')
		vim.fn.delete(temp_dir)
		restore_package(saved)
	end)
end)
