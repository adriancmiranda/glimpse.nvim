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
	it('renames the image buffer that edit created, not the current buffer at schedule time', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil',
		})

		local current_buf = 1
		local created_buf = 12
		local scheduled
		local renamed_buf
		local renamed_name
		local autocmds = {}
		local mappings = {}

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
		local original_schedule = vim.schedule
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_buf_set_name = vim.api.nvim_buf_set_name
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_set_current_buf = vim.api.nvim_set_current_buf

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
			if cmd:match('^edit ') then
				current_buf = created_buf
			end
			return true
		end
		vim.schedule = function(cb)
			scheduled = cb
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == created_buf or buf == 1 or buf == 99
		end
		vim.api.nvim_buf_set_name = function(buf, name)
			renamed_buf = buf
			renamed_name = name
		end

		local oil = require('glimpse.integrations.oil')
		oil.setup()
		autocmds.FileType.callback({ buf = 1 })
		mappings.o()
		assert.equals(created_buf, current_buf)
		assert.is_not_nil(scheduled)
		current_buf = 99
		scheduled()
		assert.equals(created_buf, renamed_buf)
		assert.equals('/tmp/image.png', renamed_name)

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.schedule = original_schedule
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_buf_set_name = original_buf_set_name
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_set_current_buf = original_set_current_buf
		restore_package(saved)
	end)

	it('does not follow cwd when image opening is disabled', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil',
		})

		local current_buf = 1
		local created_buf = 12
		local scheduled
		local renamed_buf
		local renamed_name
		local autocmds = {}
		local mappings = {}
		local follow_calls = {}

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
		}
		package.loaded['glimpse.dir'] = {
			follow = function(filepath)
				follow_calls[#follow_calls + 1] = filepath
			end,
		}
		package.loaded['glimpse'] = {
			get_config = function()
				return {
					keys = { preview = 'p', open = 'o', close = 'q' },
					integrations = {
						oil = {
							follow_cwd = false,
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
		local original_schedule = vim.schedule
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_buf_set_name = vim.api.nvim_buf_set_name
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_set_current_buf = vim.api.nvim_set_current_buf

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
			if cmd:match('^edit ') then
				current_buf = created_buf
			end
			return true
		end
		vim.schedule = function(cb)
			scheduled = cb
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == created_buf or buf == 1 or buf == 99
		end
		vim.api.nvim_buf_set_name = function(buf, name)
			renamed_buf = buf
			renamed_name = name
		end

		package.loaded['glimpse.integrations.oil'] = nil
		local oil = require('glimpse.integrations.oil')
		oil.setup()
		autocmds.FileType.callback({ buf = 1 })
		mappings.o()
		assert.equals(created_buf, current_buf)
		assert.is_not_nil(scheduled)
		current_buf = 99
		scheduled()
		assert.equals(0, #follow_calls)
		assert.equals(created_buf, renamed_buf)
		assert.equals('/tmp/image.png', renamed_name)

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.schedule = original_schedule
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_buf_set_name = original_buf_set_name
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_set_current_buf = original_set_current_buf
		restore_package(saved)
	end)

	it('preview does not change cwd even when oil follow is enabled', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil',
		})

		local current_buf = 1
		local original_cwd = vim.fn.getcwd()
		local preview_calls = {}
		local follow_calls = {}
		local autocmds = {}
		local mappings = {}

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
		}
		package.loaded['glimpse.dir'] = {
			follow = function(filepath)
				follow_calls[#follow_calls + 1] = filepath
			end,
		}
		package.loaded['glimpse'] = {
			get_config = function()
				return {
					keys = { preview = 'p', open = 'o', close = 'q' },
					integrations = {
						oil = {
							follow_cwd = true,
						},
					},
					video = { open = nil },
				}
			end,
			_should_use_inline = function()
				return true
			end,
			preview = function(filepath)
				preview_calls[#preview_calls + 1] = filepath
			end,
		}

		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_keymap_set = vim.keymap.set
		local original_cmd = vim.cmd
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_set_current_buf = vim.api.nvim_set_current_buf

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
		vim.cmd = function(_)
			return true
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end

		package.loaded['glimpse.integrations.oil'] = nil
		local oil = require('glimpse.integrations.oil')
		oil.setup()
		autocmds.FileType.callback({ buf = 1 })
		mappings.p()
		assert.equals(1, #preview_calls)
		assert.equals('/tmp/image.png', preview_calls[1])
		assert.equals(0, #follow_calls)
		assert.equals(original_cwd, vim.fn.getcwd())

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_set_current_buf = original_set_current_buf
		restore_package(saved)
	end)

	it('renames the buffer returned by a custom open callback even if focus changes', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil',
		})

		local current_buf = 1
		local opened_buf = 12
		local scheduled
		local renamed_buf
		local renamed_name
		local autocmds = {}
		local mappings = {}
		local open_calls = 0

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
		}
		package.loaded['glimpse'] = {
			get_config = function()
				return {
					keys = { preview = 'p', open = 'o', close = 'q' },
					video = { open = nil },
					integrations = {
						oil = {
							open = function(filepath)
								open_calls = open_calls + 1
								assert.equals('/tmp/image.png', filepath)
								current_buf = opened_buf
								return opened_buf
							end,
						},
					},
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
		local original_schedule = vim.schedule
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_buf_set_name = vim.api.nvim_buf_set_name
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_set_current_buf = vim.api.nvim_set_current_buf

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
			if cmd:match('^edit ') then
				current_buf = opened_buf
			end
			return true
		end
		vim.schedule = function(cb)
			scheduled = cb
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == opened_buf or buf == 1 or buf == 99
		end
		vim.api.nvim_buf_set_name = function(buf, name)
			renamed_buf = buf
			renamed_name = name
		end

		local oil = require('glimpse.integrations.oil')
		oil.setup()
		autocmds.FileType.callback({ buf = 1 })
		mappings.o()
		assert.equals(opened_buf, current_buf)
		assert.is_not_nil(scheduled)
		current_buf = 99
		scheduled()
		assert.equals(1, open_calls)
		assert.equals(opened_buf, renamed_buf)
		assert.equals('/tmp/image.png', renamed_name)

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.schedule = original_schedule
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_buf_set_name = original_buf_set_name
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_set_current_buf = original_set_current_buf
		restore_package(saved)
	end)

	it('rerenders existing images before following cwd and focusing another tab', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.util',
			'oil',
			'glimpse.integrations.oil',
		})

		local events = {}
		local current_win = 10
		local current_buf = 1
		local windows = {
			[10] = 1,
			[11] = 12,
		}
		local render_calls = {}
		local autocmds = {}

		package.loaded['oil'] = {
			close = function()
				events[#events + 1] = 'close'
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
				return 12
			end,
			render = function(buf, filepath, opts)
				render_calls[#render_calls + 1] = { buf = buf, filepath = filepath, opts = opts }
				events[#events + 1] = 'render'
			end,
		}
		package.loaded['glimpse.dir'] = {
			follow = function()
				events[#events + 1] = 'follow'
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
		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_get_current_buf = vim.api.nvim_get_current_buf
		local original_set_current_buf = vim.api.nvim_set_current_buf
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_buf_is_valid = vim.api.nvim_buf_is_valid

		vim.api.nvim_create_autocmd = function(event, spec)
			autocmds[event] = spec
			return 1
		end
		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.keymap.set = function(_, lhs, cb)
			if lhs == 'o' then
				events[#events + 1] = 'mapped'
				package.loaded['__oil_open'] = cb
			end
		end
		vim.cmd = function(_cmd)
			return true
		end
		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
			events[#events + 1] = 'switch'
		end
		vim.api.nvim_get_current_buf = function()
			return current_buf
		end
		vim.api.nvim_set_current_buf = function(buf)
			current_buf = buf
		end
		vim.api.nvim_list_wins = function()
			return { 10, 11 }
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == 1 or buf == 12
		end

		package.loaded['glimpse.integrations.oil'] = nil
		local oil = require('glimpse.integrations.oil')
		oil.setup()
		assert.is_not_nil(autocmds.FileType)
		autocmds.FileType.callback({ buf = 1 })
		assert.is_not_nil(package.loaded['__oil_open'])
		package.loaded['__oil_open']()

		assert.are.same({ 'mapped', 'close', 'switch', 'follow', 'render' }, events)
		assert.equals(1, #render_calls)
		assert.equals(12, render_calls[1].buf)
		assert.equals('/tmp/image.png', render_calls[1].filepath)
		assert.is_true(render_calls[1].opts.listed)

		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_get_current_buf = original_get_current_buf
		vim.api.nvim_set_current_buf = original_set_current_buf
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		package.loaded['__oil_open'] = nil
		restore_package(saved)
	end)

	it('reuses an already open image window for aliased paths', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.strategy.inline',
		})

		local original_win = 10
		local current_win = original_win
		local image_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(image_buf, '/tmp/real/image.png')
		vim.bo[image_buf].filetype = 'image'
		local render_calls = 0
		local follow_calls = {}
		local windows = {
			[10] = 1,
			[11] = image_buf,
		}

		package.loaded['glimpse.renderer'] = {
			find_by_filepath = function()
				return image_buf
			end,
			render = function()
				render_calls = render_calls + 1
			end,
		}
		package.loaded['glimpse.dir'] = {
			follow = function(filepath)
				follow_calls[#follow_calls + 1] = filepath
			end,
		}

		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_buf_is_valid = vim.api.nvim_buf_is_valid

		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
		end
		vim.api.nvim_list_wins = function()
			return { 10, 11 }
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == 1 or buf == image_buf
		end

		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')
		inline.preview('/tmp/link/image.png')

		assert.equals(original_win, vim.api.nvim_get_current_win())
		assert.equals(1, render_calls)
		assert.equals(0, #follow_calls)

		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		if vim.api.nvim_buf_is_valid(image_buf) then
			vim.api.nvim_buf_delete(image_buf, { force = true })
		end
		restore_package(saved)
	end)

	it('reuses the existing image split when previewing a different file', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'glimpse.strategy.inline',
		})

		local original_win = 10
		local current_win = original_win
		local image_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(image_buf, '/tmp/real/first.png')
		vim.bo[image_buf].filetype = 'image'
		local render_calls = {}
		local follow_calls = {}
		local wins_before = 2
		local windows = {
			[10] = 1,
			[11] = image_buf,
		}

		package.loaded['glimpse.renderer'] = {
			find_by_filepath = function()
				return nil
			end,
			render = function(buf, filepath)
				render_calls[#render_calls + 1] = { buf = buf, filepath = filepath }
			end,
		}
		package.loaded['glimpse.dir'] = {
			follow = function(filepath)
				follow_calls[#follow_calls + 1] = filepath
			end,
		}

		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_buf_is_valid = vim.api.nvim_buf_is_valid

		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
		end
		vim.api.nvim_list_wins = function()
			return { 10, 11 }
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return buf == 1 or buf == image_buf
		end

		package.loaded['glimpse.strategy.inline'] = nil
		local inline = require('glimpse.strategy.inline')
		inline.preview('/tmp/new/second.png')

		assert.equals(original_win, vim.api.nvim_get_current_win())
		assert.equals(wins_before, #vim.api.nvim_list_wins())
		assert.equals(1, #render_calls)
		assert.equals(image_buf, render_calls[1].buf)
		assert.equals('/tmp/new/second.png', render_calls[1].filepath)
		assert.equals(0, #follow_calls)

		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		if vim.api.nvim_buf_is_valid(image_buf) then
			vim.api.nvim_buf_delete(image_buf, { force = true })
		end
		restore_package(saved)
	end)
end)
