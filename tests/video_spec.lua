local missing = {}

local function save_package(names)
	local saved = {}
	for _, name in ipairs(names) do
		local value = package.loaded[name]
		saved[name] = value == nil and missing or value
	end
	return saved
end

local function restore_package(saved)
	for name, value in pairs(saved) do
		if value == missing then
			package.loaded[name] = nil
		else
			package.loaded[name] = value
		end
	end
end

local function stub_package(name, value)
	package.loaded[name] = value
end

local function stub_fn(table_ref, key, value)
	local original = table_ref[key]
	table_ref[key] = value
	return original
end

describe('video preview', function()
	it('routes through the thumbnail and strategy helpers', function()
		local saved = save_package({
			'glimpse',
			'glimpse.thumbnail',
			'glimpse.strategy.inline',
			'glimpse.strategy.pane',
			'glimpse.previewer.video',
		})

		local calls = {}
		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					pane = { position = 'right', size = 40 },
				}
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(filepath, callback)
				calls.extract = filepath
				callback('/tmp/thumb.png')
			end,
		})
		stub_package('glimpse.strategy.inline', {
			show = function(filepath)
				calls.inline_show = filepath
			end,
			preview = function(filepath)
				calls.inline_preview = filepath
			end,
		})
		stub_package('glimpse.strategy.pane', {
			show = function(filepath, opts)
				calls.pane_show = { filepath = filepath, opts = opts }
			end,
		})

		local video = require('glimpse.previewer.video')
		video.show('/tmp/example.mp4')
		video.preview('/tmp/example.mp4')

		assert.equals('/tmp/example.mp4', calls.extract)
		assert.equals('/tmp/thumb.png', calls.inline_show)
		assert.equals('/tmp/thumb.png', calls.inline_preview)

		restore_package(saved)
	end)

	it('uses the pane strategy when inline rendering is unavailable', function()
		local saved = save_package({
			'glimpse',
			'glimpse.thumbnail',
			'glimpse.strategy.inline',
			'glimpse.strategy.pane',
			'glimpse.previewer.video',
		})

		local calls = {}
		stub_package('glimpse', {
			_should_use_inline = function()
				return false
			end,
			get_config = function()
				return {
					pane = { position = 'bottom', size = 55 },
				}
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(filepath, callback)
				calls.extract = filepath
				callback('/tmp/thumb.png')
			end,
		})
		stub_package('glimpse.strategy.inline', {
			show = function(filepath)
				calls.inline_show = filepath
			end,
			preview = function(filepath)
				calls.inline_preview = filepath
			end,
		})
		stub_package('glimpse.strategy.pane', {
			show = function(filepath, opts)
				calls.pane_show = { filepath = filepath, opts = opts }
			end,
		})

		local video = require('glimpse.previewer.video')
		video.show('/tmp/example.mp4')

		assert.equals('/tmp/example.mp4', calls.extract)
		assert.is_nil(calls.inline_show)
		assert.is_nil(calls.inline_preview)
		assert.is_not_nil(calls.pane_show)
		assert.equals('/tmp/thumb.png', calls.pane_show.filepath)
		assert.equals('bottom', calls.pane_show.opts.position)
		assert.equals(55, calls.pane_show.opts.size)

		restore_package(saved)
	end)

	it('falls back to thumbnails when animated extraction fails', function()
		local saved = save_package({
			'glimpse',
			'glimpse.detect',
			'glimpse.frames',
			'glimpse.kitty',
			'glimpse.preview_route',
			'glimpse.renderer',
			'glimpse.thumbnail',
			'glimpse.previewer.video',
		})

		local calls = {}
		local original_has = stub_fn(vim.fn, 'has', function(feature)
			return feature == 'ttyin' and 1 or 0
		end)

		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					video = {
						frames = { per_second = 10 },
					},
					cell_size = { width = 20, height = 40 },
				}
			end,
		})
		stub_package('glimpse.detect', {
			supports_animation = function()
				return true
			end,
		})
		stub_package('glimpse.frames', {
			extract_frames_async = function(filepath, _, _on_frame, on_done)
				calls.extract = filepath
				calls.on_done = on_done
				calls.cancelled = false
				return function()
					calls.cancelled = true
				end
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(filepath, callback)
				calls.thumbnail = filepath
				callback('/tmp/thumb.png')
			end,
		})
		stub_package('glimpse.preview_route', {
			show = function(filepath)
				calls.show = filepath
			end,
			preview = function(filepath)
				calls.preview = filepath
			end,
		})
		stub_package('glimpse.renderer', {
			close = function(buf)
				calls.close = buf
			end,
		})
		stub_package('glimpse.kitty', {
			new_id = function()
				return 101
			end,
			retransmit_frame = function()
				return true
			end,
			delete = function()
				return true
			end,
			png_dimensions_from_data = function()
				return 100, 60
			end,
		})

		local video = require('glimpse.previewer.video')
		video.show('/tmp/example.mp4')
		calls.on_done(nil, 'boom')

		assert.equals('/tmp/example.mp4', calls.extract)
		assert.is_true(calls.cancelled)
		assert.equals('/tmp/example.mp4', calls.thumbnail)
		assert.equals('/tmp/thumb.png', calls.show)
		assert.is_nil(calls.preview)
		assert.is_nil(calls.close)

		vim.fn.has = original_has
		restore_package(saved)
	end)

	it('cancels extraction and closes the active frame on cleanup', function()
		local saved = save_package({
			'glimpse',
			'glimpse.detect',
			'glimpse.frames',
			'glimpse.kitty',
			'glimpse.renderer',
			'glimpse.previewer.video',
		})

		local calls = {}
		local autocmds = {}
		local current_win = 11
		local current_buf = 1
		local windows = { [11] = current_buf }
		local bufs = { [1] = true, [20] = true }
		local original_has = stub_fn(vim.fn, 'has', function(feature)
			return feature == 'ttyin' and 1 or 0
		end)
		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_create_buf = vim.api.nvim_create_buf
		local original_win_set_buf = vim.api.nvim_win_set_buf
		local original_win_get_width = vim.api.nvim_win_get_width
		local original_win_get_height = vim.api.nvim_win_get_height
		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_keymap_set = vim.keymap.set
		local original_cmd = vim.cmd
		local original_timer = vim.uv.new_timer

		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					video = {
						frames = { per_second = 10 },
					},
					cell_size = { width = 20, height = 40 },
				}
			end,
		})
		stub_package('glimpse.detect', {
			supports_animation = function()
				return true
			end,
		})
		stub_package('glimpse.frames', {
			extract_frames_async = function(filepath, _, on_frame, on_done)
				calls.extract = filepath
				calls.on_frame = on_frame
				calls.on_done = on_done
				return function()
					calls.cancelled = true
				end
			end,
		})
		stub_package('glimpse.kitty', {
			new_id = function()
				calls.next_id = (calls.next_id or 100) + 1
				return calls.next_id
			end,
			retransmit_frame = function()
				return true
			end,
			delete = function(id)
				calls.deleted = calls.deleted or {}
				table.insert(calls.deleted, id)
			end,
			png_dimensions_from_data = function()
				return 200, 120
			end,
		})
		stub_package('glimpse.renderer', {
			setup_animation_buf = function(buf, win, image_id)
				calls.setup = { buf = buf, win = win, image_id = image_id }
			end,
			update_animation_highlight = function(buf, new_id)
				calls.updated = { buf = buf, new_id = new_id }
			end,
			close = function(buf)
				calls.closed = buf
			end,
		})

		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
			current_buf = windows[win] or current_buf
		end
		vim.api.nvim_list_wins = function()
			return { 11 }
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return bufs[buf] or false
		end
		vim.api.nvim_create_buf = function()
			bufs[20] = true
			windows[11] = 20
			current_buf = 20
			return 20
		end
		vim.api.nvim_win_set_buf = function(win, buf)
			windows[win] = buf
			current_buf = buf
		end
		vim.api.nvim_win_get_width = function()
			return 80
		end
		vim.api.nvim_win_get_height = function()
			return 24
		end
		vim.api.nvim_create_autocmd = function(event, spec)
			autocmds[event] = autocmds[event] or {}
			table.insert(autocmds[event], spec)
			return #autocmds[event]
		end
		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.keymap.set = function()
			return true
		end
		vim.cmd = function()
			return true
		end
		vim.uv.new_timer = function()
			local timer = {
				closed = false,
			}
			function timer.start()
				return true
			end
			function timer.stop()
				return true
			end
			function timer.close()
				timer.closed = true
				return true
			end
			function timer.is_closing()
				return timer.closed
			end
			return timer
		end

		local video = require('glimpse.previewer.video')
		video.show('/tmp/example.mp4')

		calls.on_frame('frame-one', 1, false)
		calls.on_done(1, nil)

		assert.is_not_nil(autocmds.BufDelete)
		assert.equals(20, calls.setup.buf)
		autocmds.BufDelete[1].callback()
		assert.is_true(calls.cancelled)
		assert.equals(20, calls.closed)

		vim.fn.has = original_has
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_create_buf = original_create_buf
		vim.api.nvim_win_set_buf = original_win_set_buf
		vim.api.nvim_win_get_width = original_win_get_width
		vim.api.nvim_win_get_height = original_win_get_height
		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.uv.new_timer = original_timer
		restore_package(saved)
	end)

	it('keeps preview frame temp files in the registry until they are removed', function()
		local saved = save_package({
			'glimpse',
			'glimpse.detect',
			'glimpse.frames',
			'glimpse.kitty',
			'glimpse.renderer',
			'glimpse.previewer.video',
		})

		local calls = {}
		local autocmds = {}
		local current_win = 11
		local current_buf = 1
		local windows = { [11] = current_buf }
		local bufs = { [1] = true, [20] = true }
		local temp_path = '/tmp/glimpse-video-preview.png'
		local original_has = stub_fn(vim.fn, 'has', function(feature)
			return feature == 'ttyin' and 1 or 0
		end)
		local original_tempname = vim.fn.tempname
		local original_remove = os.remove
		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_create_buf = vim.api.nvim_create_buf
		local original_win_set_buf = vim.api.nvim_win_set_buf
		local original_win_get_width = vim.api.nvim_win_get_width
		local original_win_get_height = vim.api.nvim_win_get_height
		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_keymap_set = vim.keymap.set
		local original_cmd = vim.cmd
		local original_timer = vim.uv.new_timer

		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					video = {
						frames = { per_second = 10 },
					},
					cell_size = { width = 20, height = 40 },
				}
			end,
		})
		stub_package('glimpse.detect', {
			supports_animation = function()
				return true
			end,
		})
		stub_package('glimpse.frames', {
			extract_frames_async = function(filepath, _, on_frame)
				calls.extract = filepath
				calls.on_frame = on_frame
				return function()
					calls.cancelled = true
				end
			end,
		})
		stub_package('glimpse.kitty', {
			new_id = function()
				return 500
			end,
			retransmit_frame = function()
				return true
			end,
			delete = function()
				return true
			end,
			png_dimensions_from_data = function()
				return 200, 120
			end,
		})
		stub_package('glimpse.renderer', {
			setup_animation_buf = function(buf, win, image_id)
				calls.setup = { buf = buf, win = win, image_id = image_id }
			end,
			update_animation_highlight = function()
				return true
			end,
			close = function()
				return true
			end,
		})

		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
			current_buf = windows[win] or current_buf
		end
		vim.api.nvim_list_wins = function()
			return { 11 }
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return bufs[buf] or false
		end
		vim.api.nvim_create_buf = function()
			bufs[20] = true
			windows[11] = 20
			current_buf = 20
			return 20
		end
		vim.api.nvim_win_set_buf = function(win, buf)
			windows[win] = buf
			current_buf = buf
		end
		vim.api.nvim_win_get_width = function()
			return 80
		end
		vim.api.nvim_win_get_height = function()
			return 24
		end
		vim.api.nvim_create_autocmd = function(event, spec)
			autocmds[event] = autocmds[event] or {}
			table.insert(autocmds[event], spec)
			return #autocmds[event]
		end
		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.keymap.set = function()
			return true
		end
		vim.cmd = function()
			return true
		end
		vim.uv.new_timer = function()
			local timer = {
				closed = false,
			}
			function timer.start()
				return true
			end
			function timer.stop()
				return true
			end
			function timer.close()
				timer.closed = true
				return true
			end
			function timer.is_closing()
				return timer.closed
			end
			return timer
		end
		vim.fn.tempname = function()
			return temp_path:gsub('%.png$', '')
		end
		rawset(os, 'remove', function(path)
			assert.equals(temp_path, path)
			assert.is_true(calls.video._temp_registry[temp_path])
			calls.removed = path
			return true
		end)

		local video = require('glimpse.previewer.video')
		calls.video = video
		video.show('/tmp/example.mp4')
		calls.on_frame('frame-one', 1, true)

		assert.equals('/tmp/example.mp4', calls.extract)
		assert.equals(temp_path, calls.removed)
		assert.is_nil(video._temp_registry[temp_path])
		assert.equals(20, calls.setup.buf)

		vim.fn.has = original_has
		vim.fn.tempname = original_tempname
		rawset(os, 'remove', original_remove)
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_create_buf = original_create_buf
		vim.api.nvim_win_set_buf = original_win_set_buf
		vim.api.nvim_win_get_width = original_win_get_width
		vim.api.nvim_win_get_height = original_win_get_height
		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.uv.new_timer = original_timer
		restore_package(saved)
	end)

	it('restarts animation on resize without clearing the current frame first', function()
		local saved = save_package({
			'glimpse',
			'glimpse.detect',
			'glimpse.frames',
			'glimpse.kitty',
			'glimpse.renderer',
			'glimpse.previewer.video',
		})

		local calls = {}
		local autocmds = {}
		local timers = {}
		local current_win = 11
		local current_buf = 1
		local windows = { [11] = current_buf }
		local bufs = { [1] = true, [20] = true }
		local original_has = stub_fn(vim.fn, 'has', function(feature)
			return feature == 'ttyin' and 1 or 0
		end)
		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_list_wins = vim.api.nvim_list_wins
		local original_win_get_buf = vim.api.nvim_win_get_buf
		local original_win_is_valid = vim.api.nvim_win_is_valid
		local original_buf_is_valid = vim.api.nvim_buf_is_valid
		local original_create_buf = vim.api.nvim_create_buf
		local original_win_set_buf = vim.api.nvim_win_set_buf
		local original_win_get_width = vim.api.nvim_win_get_width
		local original_win_get_height = vim.api.nvim_win_get_height
		local original_create_autocmd = vim.api.nvim_create_autocmd
		local original_create_augroup = vim.api.nvim_create_augroup
		local original_keymap_set = vim.keymap.set
		local original_cmd = vim.cmd
		local original_timer = vim.uv.new_timer
		local vim_v_mt = getmetatable(vim.v)
		local original_newindex = vim_v_mt and vim_v_mt.__newindex or nil

		if vim_v_mt then
			vim_v_mt.__newindex = function(t, k, v)
				rawset(t, k, v)
			end
		end

		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					video = {
						frames = { per_second = 10 },
					},
					debounce = { resize = 1 },
					cell_size = { width = 20, height = 40 },
				}
			end,
		})
		stub_package('glimpse.detect', {
			supports_animation = function()
				return true
			end,
		})
		stub_package('glimpse.frames', {
			extract_frames_async = function(filepath, _, on_frame, on_done)
				calls.extract = calls.extract or {}
				calls.extract[#calls.extract + 1] = filepath
				calls.on_frame = calls.on_frame or {}
				calls.on_frame[#calls.on_frame + 1] = on_frame
				calls.on_done = calls.on_done or {}
				calls.on_done[#calls.on_done + 1] = on_done
				return function()
					calls.cancelled = (calls.cancelled or 0) + 1
				end
			end,
		})
		stub_package('glimpse.kitty', {
			new_id = function()
				calls.next_id = (calls.next_id or 100) + 1
				return calls.next_id
			end,
			retransmit_frame = function()
				return true
			end,
			delete = function(id)
				calls.deleted = calls.deleted or {}
				table.insert(calls.deleted, id)
			end,
			png_dimensions_from_data = function()
				return 200, 120
			end,
		})
		stub_package('glimpse.renderer', {
			setup_animation_buf = function(buf, win, image_id)
				calls.setup = calls.setup or {}
				calls.setup[#calls.setup + 1] = { buf = buf, win = win, image_id = image_id }
			end,
			update_animation_highlight = function(buf, new_id)
				calls.updated = calls.updated or {}
				table.insert(calls.updated, { buf = buf, new_id = new_id })
			end,
			close = function(buf)
				calls.closed = calls.closed or {}
				table.insert(calls.closed, buf)
			end,
		})

		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
			current_buf = windows[win] or current_buf
		end
		vim.api.nvim_list_wins = function()
			return { 11 }
		end
		vim.api.nvim_win_get_buf = function(win)
			return windows[win]
		end
		vim.api.nvim_win_is_valid = function(win)
			return windows[win] ~= nil
		end
		vim.api.nvim_buf_is_valid = function(buf)
			return bufs[buf] or false
		end
		vim.api.nvim_create_buf = function()
			bufs[20] = true
			windows[11] = 20
			current_buf = 20
			return 20
		end
		vim.api.nvim_win_set_buf = function(win, buf)
			windows[win] = buf
			current_buf = buf
		end
		vim.api.nvim_win_get_width = function()
			return 80
		end
		vim.api.nvim_win_get_height = function()
			return 24
		end
		vim.api.nvim_create_autocmd = function(event, spec)
			autocmds[event] = autocmds[event] or {}
			table.insert(autocmds[event], spec)
			return #autocmds[event]
		end
		vim.api.nvim_create_augroup = function()
			return 1
		end
		vim.keymap.set = function()
			return true
		end
		vim.cmd = function()
			return true
		end
		vim.uv.new_timer = function()
			local timer = {
				closed = false,
			}
			function timer.start(_, _, cb)
				timer.cb = cb
				timers[#timers + 1] = timer
				return true
			end
			function timer.stop()
				return true
			end
			function timer.close()
				timer.closed = true
				return true
			end
			function timer.is_closing()
				return timer.closed
			end
			return timer
		end

		local video = require('glimpse.previewer.video')
		video.show('/tmp/example.mp4')
		calls.on_frame[1]('frame-one', 1, false)
		calls.on_done[1](1, nil)

		assert.is_not_nil(autocmds.WinResized)
		assert.equals(1, #calls.setup)
		assert.is_nil(calls.closed)
		assert.is_nil(calls.deleted)

		vim.v.event = { windows = { 11 } }
		autocmds.WinResized[1].callback()
		assert.is_nil(calls.closed)
		assert.is_nil(calls.deleted)
		assert.is_not_nil(timers[2])
		assert.is_not_nil(timers[2].cb)
		timers[2].cb()
		assert.is_nil(calls.closed)
		assert.is_nil(calls.deleted)

		if vim_v_mt then
			vim_v_mt.__newindex = original_newindex
		end
		vim.fn.has = original_has
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_list_wins = original_list_wins
		vim.api.nvim_win_get_buf = original_win_get_buf
		vim.api.nvim_win_is_valid = original_win_is_valid
		vim.api.nvim_buf_is_valid = original_buf_is_valid
		vim.api.nvim_create_buf = original_create_buf
		vim.api.nvim_win_set_buf = original_win_set_buf
		vim.api.nvim_win_get_width = original_win_get_width
		vim.api.nvim_win_get_height = original_win_get_height
		vim.api.nvim_create_autocmd = original_create_autocmd
		vim.api.nvim_create_augroup = original_create_augroup
		vim.keymap.set = original_keymap_set
		vim.cmd = original_cmd
		vim.uv.new_timer = original_timer
		restore_package(saved)
	end)

	it('drops stale thumbnail callbacks from older requests', function()
		local saved = save_package({
			'glimpse',
			'glimpse.detect',
			'glimpse.thumbnail',
			'glimpse.strategy.inline',
			'glimpse.strategy.pane',
			'glimpse.previewer.video',
		})

		local calls = {}
		package.loaded['glimpse.previewer.video'] = nil
		local original_has = stub_fn(vim.fn, 'has', function(feature)
			return feature == 'ttyin' and 0 or 0
		end)
		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					pane = { position = 'right', size = 40 },
				}
			end,
		})
		stub_package('glimpse.detect', {
			supports_animation = function()
				return false
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(filepath, callback)
				calls.extract = filepath
				calls.callback = callback
			end,
		})
		stub_package('glimpse.strategy.inline', {
			show = function(filepath)
				calls.inline_show = filepath
			end,
			preview = function(filepath)
				calls.inline_preview = filepath
			end,
		})
		stub_package('glimpse.strategy.pane', {
			show = function(filepath, opts)
				calls.pane_show = { filepath = filepath, opts = opts }
			end,
		})

		local video = require('glimpse.previewer.video')
		video.show('/tmp/first.mp4')
		local first_callback = calls.callback
		video.show('/tmp/second.mp4')
		local second_callback = calls.callback

		first_callback('/tmp/first-thumb.png')
		assert.is_nil(calls.inline_show)
		assert.is_nil(calls.inline_preview)
		assert.is_nil(calls.pane_show)

		second_callback('/tmp/second-thumb.png')
		assert.equals('/tmp/second-thumb.png', calls.inline_show)
		assert.is_nil(calls.inline_preview)
		assert.is_nil(calls.pane_show)

		vim.fn.has = original_has
		restore_package(saved)
	end)

	it('registers temp files and clears the registry after normal cleanup', function()
		local saved = save_package({ 'glimpse.previewer.video' })
		package.loaded['glimpse.previewer.video'] = nil
		local video = require('glimpse.previewer.video')

		local registry = video._temp_registry
		assert.are.same({}, registry)

		local tmp1 = vim.fn.tempname() .. '.png'
		local tmp2 = vim.fn.tempname() .. '.png'
		vim.fn.writefile({ 'a' }, tmp1)
		vim.fn.writefile({ 'b' }, tmp2)

		registry[tmp1] = true
		registry[tmp2] = true
		assert.is_not_nil(registry[tmp1])
		assert.equals(1, vim.fn.filereadable(tmp1))

		-- simulate what cleanup_anim does on normal stop
		os.remove(tmp1)
		os.remove(tmp2)
		registry[tmp1] = nil
		registry[tmp2] = nil

		assert.is_nil(registry[tmp1])
		assert.is_nil(registry[tmp2])
		assert.equals(0, vim.fn.filereadable(tmp1))
		assert.equals(0, vim.fn.filereadable(tmp2))

		restore_package(saved)
	end)

	it('keeps independent video previews isolated by window', function()
		local saved = save_package({
			'glimpse',
			'glimpse.detect',
			'glimpse.thumbnail',
			'glimpse.strategy.inline',
			'glimpse.strategy.pane',
			'glimpse.previewer.video',
		})

		local calls = {}
		local current_win = 11
		package.loaded['glimpse.previewer.video'] = nil
		local original_has = stub_fn(vim.fn, 'has', function(feature)
			return feature == 'ttyin' and 0 or 0
		end)
		stub_package('glimpse', {
			_should_use_inline = function()
				return true
			end,
			get_config = function()
				return {
					pane = { position = 'right', size = 40 },
				}
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(filepath, callback)
				calls.extract = calls.extract or {}
				calls.extract[#calls.extract + 1] = { filepath = filepath, callback = callback, win = current_win }
			end,
		})
		stub_package('glimpse.strategy.inline', {
			show = function(filepath)
				calls.inline_show = calls.inline_show or {}
				calls.inline_show[#calls.inline_show + 1] = { filepath = filepath, win = current_win }
			end,
			preview = function(filepath)
				calls.inline_preview = calls.inline_preview or {}
				calls.inline_preview[#calls.inline_preview + 1] = { filepath = filepath, win = current_win }
			end,
		})
		stub_package('glimpse.strategy.pane', {
			show = function(filepath, opts)
				calls.pane_show = calls.pane_show or {}
				calls.pane_show[#calls.pane_show + 1] = { filepath = filepath, opts = opts, win = current_win }
			end,
		})

		local original_get_current_win = vim.api.nvim_get_current_win
		local original_set_current_win = vim.api.nvim_set_current_win
		local original_win_is_valid = vim.api.nvim_win_is_valid

		vim.api.nvim_get_current_win = function()
			return current_win
		end
		vim.api.nvim_set_current_win = function(win)
			current_win = win
		end
		vim.api.nvim_win_is_valid = function(win)
			return win == 11 or win == 22
		end

		local video = require('glimpse.previewer.video')
		current_win = 11
		video.show('/tmp/example.mp4')
		current_win = 22
		video.show('/tmp/example.mp4')

		calls.extract[1].callback('/tmp/thumb-1.png')
		calls.extract[2].callback('/tmp/thumb-2.png')

		assert.equals(2, #calls.inline_show)
		assert.equals('/tmp/thumb-1.png', calls.inline_show[1].filepath)
		assert.equals(11, calls.inline_show[1].win)
		assert.equals('/tmp/thumb-2.png', calls.inline_show[2].filepath)
		assert.equals(22, calls.inline_show[2].win)

		vim.fn.has = original_has
		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_win_is_valid = original_win_is_valid
		restore_package(saved)
	end)
end)
