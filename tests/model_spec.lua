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

describe('model previewer', function()
	local saved
	local calls
	local orig = {}

	before_each(function()
		calls = { pipeline = {}, route = {}, notify = {}, tempname = 0, mkdir = {}, kitty = {}, renderer = {} }

		saved = save_package({
			'glimpse',
			'glimpse.pipeline',
			'glimpse.preview_route',
			'glimpse.kitty',
			'glimpse.renderer',
			'glimpse.preview_state',
			'glimpse.previewer.model',
		})

		stub_package('glimpse', {
			get_config = function()
				return {
					pipelines = {
						model = {
							steps = { { command = 'f3d', args = { '{input}', '{output}' } } },
						},
					},
				}
			end,
		})

		stub_package('glimpse.pipeline', {
			resolve_config = function(pipelines, kind, filepath)
				if not pipelines then
					return nil
				end
				local ext = filepath:match('(%.[^./]+)$')
				return (ext and pipelines[ext:lower()]) or pipelines[kind]
			end,
			run_steps = function(cfg, input, on_done, on_frame)
				calls.pipeline[#calls.pipeline + 1] = { cfg = cfg, input = input, on_done = on_done, on_frame = on_frame }
				return function()
					calls.pipeline.cancelled = true
				end
			end,
		})

		stub_package('glimpse.kitty', {
			new_id = function()
				calls.kitty[#calls.kitty + 1] = 'new_id'
				return #calls.kitty
			end,
			retransmit_frame = function(id, path)
				calls.kitty[#calls.kitty + 1] = { op = 'retransmit', id = id, path = path }
			end,
			delete = function(id)
				calls.kitty[#calls.kitty + 1] = { op = 'delete', id = id }
			end,
			png_dimensions_from_data = function(_data)
				return 512, 512
			end,
		})

		stub_package('glimpse.renderer', {
			setup_animation_buf = function(b, w, id, _gc, _gr, _wc, _wr)
				calls.renderer[#calls.renderer + 1] = { op = 'setup', buf = b, win = w, id = id }
			end,
			update_animation_highlight = function(b, id)
				calls.renderer[#calls.renderer + 1] = { op = 'update', buf = b, id = id }
			end,
			close = function(b)
				calls.renderer[#calls.renderer + 1] = { op = 'close', buf = b }
			end,
			find_by_filepath = function()
				return 10
			end,
		})

		stub_package('glimpse.preview_state', {
			mark = function() end,
			is_marked = function()
				return false
			end,
		})

		stub_package('glimpse.preview_route', {
			show = function(path)
				calls.route[#calls.route + 1] = { mode = 'show', path = path }
			end,
			preview = function(path)
				calls.route[#calls.route + 1] = { mode = 'preview', path = path }
			end,
		})

		stub_fn(vim.fn, 'tempname', function()
			calls.tempname = calls.tempname + 1
			return '/tmp/glimpse_model_' .. calls.tempname
		end)

		stub_fn(vim.fn, 'mkdir', function(path, _flags)
			calls.mkdir[#calls.mkdir + 1] = path
		end)

		stub_fn(vim.fn, 'delete', function() end)

		stub_fn(vim, 'notify', function(msg, level)
			calls.notify[#calls.notify + 1] = { msg = msg, level = level }
		end)

		stub_fn(vim.api, 'nvim_get_current_win', function()
			return 1
		end)

		stub_fn(vim.api, 'nvim_win_is_valid', function()
			return true
		end)

		stub_fn(vim.api, 'nvim_win_get_buf', function()
			return 10
		end)

		stub_fn(vim.api, 'nvim_win_get_width', function()
			return 80
		end)

		stub_fn(vim.api, 'nvim_win_get_height', function()
			return 40
		end)

		stub_fn(vim.api, 'nvim_buf_is_valid', function()
			return true
		end)

		stub_fn(vim.api, 'nvim_list_wins', function()
			return { 1 }
		end)

		stub_fn(vim.api, 'nvim_set_current_win', function(w)
			calls.set_current_win = calls.set_current_win or {}
			calls.set_current_win[#calls.set_current_win + 1] = w
		end)

		stub_fn(vim.api, 'nvim_create_buf', function(_listed, _scratch)
			calls.create_buf = (calls.create_buf or 0) + 1
			return 100 + calls.create_buf
		end)

		stub_fn(vim.api, 'nvim_win_set_buf', function(w, b)
			calls.win_set_buf = calls.win_set_buf or {}
			calls.win_set_buf[#calls.win_set_buf + 1] = { win = w, buf = b }
		end)

		orig.nvim_create_autocmd = stub_fn(vim.api, 'nvim_create_autocmd', function() end)

		orig.keymap_set = stub_fn(vim.keymap, 'set', function(mode, lhs, rhs, opts)
			calls.keymaps = calls.keymaps or {}
			calls.keymaps[#calls.keymaps + 1] = { mode = mode, lhs = lhs, rhs = rhs, buf = opts and opts.buffer }
		end)

		orig.cmd = stub_fn(vim, 'cmd', function(v)
			calls.cmd = calls.cmd or {}
			calls.cmd[#calls.cmd + 1] = v
		end)

		orig.new_timer = stub_fn(vim.uv, 'new_timer', function()
			return {
				start = function(_, _delay, _rep, cb)
					calls.timer_cb = cb
				end,
				stop = function() end,
				is_closing = function()
					return false
				end,
				close = function() end,
			}
		end)

		orig.schedule_wrap = stub_fn(vim, 'schedule_wrap', function(fn)
			return fn
		end)
	end)

	after_each(function()
		restore_package(saved)
		vim.fn.tempname = stub_fn(vim.fn, 'tempname', vim.fn.tempname)
		vim.fn.mkdir = stub_fn(vim.fn, 'mkdir', vim.fn.mkdir)
		vim.fn.delete = stub_fn(vim.fn, 'delete', vim.fn.delete)
		vim.notify = stub_fn(vim, 'notify', vim.notify)
		vim.api.nvim_get_current_win = stub_fn(vim.api, 'nvim_get_current_win', vim.api.nvim_get_current_win)
		vim.api.nvim_win_is_valid = stub_fn(vim.api, 'nvim_win_is_valid', vim.api.nvim_win_is_valid)
		vim.api.nvim_win_get_buf = stub_fn(vim.api, 'nvim_win_get_buf', vim.api.nvim_win_get_buf)
		vim.api.nvim_win_get_width = stub_fn(vim.api, 'nvim_win_get_width', vim.api.nvim_win_get_width)
		vim.api.nvim_win_get_height = stub_fn(vim.api, 'nvim_win_get_height', vim.api.nvim_win_get_height)
		vim.api.nvim_buf_is_valid = stub_fn(vim.api, 'nvim_buf_is_valid', vim.api.nvim_buf_is_valid)
		vim.api.nvim_list_wins = stub_fn(vim.api, 'nvim_list_wins', vim.api.nvim_list_wins)
		vim.api.nvim_set_current_win = stub_fn(vim.api, 'nvim_set_current_win', vim.api.nvim_set_current_win)
		vim.api.nvim_create_buf = stub_fn(vim.api, 'nvim_create_buf', vim.api.nvim_create_buf)
		vim.api.nvim_win_set_buf = stub_fn(vim.api, 'nvim_win_set_buf', vim.api.nvim_win_set_buf)
		vim.api.nvim_create_autocmd = orig.nvim_create_autocmd
		vim.keymap.set = orig.keymap_set
		vim.cmd = orig.cmd
		vim.uv.new_timer = orig.new_timer
		vim.schedule_wrap = orig.schedule_wrap
	end)

	it('calls pipeline.run_steps and routes to preview_route.show', function()
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')

		assert.equals(1, #calls.pipeline)
		assert.equals('/path/to/model.obj', calls.pipeline[1].input)

		calls.pipeline[1].on_done({ path = '/tmp/glimpse_model_1.png' }, nil)

		assert.equals(1, #calls.route)
		assert.equals('show', calls.route[1].mode)
		assert.equals('/tmp/glimpse_model_1.png', calls.route[1].path)
	end)

	it('uses an extension-specific pipeline when configured', function()
		stub_package('glimpse', {
			get_config = function()
				return {
					pipelines = {
						model = { steps = { { command = 'f3d' } } },
						['.blend'] = { previewers = { { command = 'blender' } } },
					},
				}
			end,
		})
		package.loaded['glimpse.previewer.model'] = nil

		local model = require('glimpse.previewer.model')
		model.show('/path/to/SCENE.BLEND')

		assert.equals('blender', calls.pipeline[1].cfg.previewers[1].command)
	end)

	it('calls preview_route.preview when using preview()', function()
		local model = require('glimpse.previewer.model')
		model.preview('/path/to/model.obj')

		calls.pipeline[1].on_done({ path = '/tmp/glimpse_model_1.png' }, nil)

		assert.equals('preview', calls.route[1].mode)
	end)

	it('cleans a retained static result when the preview is cancelled', function()
		local cleaned = 0
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')

		calls.pipeline[1].on_done({
			path = '/tmp/glimpse_model_1.png',
			cleanup = function()
				cleaned = cleaned + 1
			end,
		}, nil)
		model.cancel(1)

		assert.equals(1, cleaned)
	end)

	it('cleans the previous static result after its replacement is rendered', function()
		local cleaned = 0
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')
		calls.pipeline[1].on_done({
			path = '/tmp/glimpse_model_1.png',
			cleanup = function()
				cleaned = cleaned + 1
			end,
		}, nil)

		model.show('/path/to/model2.obj')
		calls.pipeline[2].on_done({
			path = '/tmp/glimpse_model_2.png',
			cleanup = function() end,
		}, nil)

		assert.equals(1, cleaned)
	end)

	it('notifies on pipeline failure', function()
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')

		calls.pipeline[1].on_done(nil, 'f3d not found')

		assert.equals(0, #calls.route)
		assert.equals(1, #calls.notify)
		assert.is_not_nil(calls.notify[1].msg:find('f3d not found'))
	end)

	it('notifies when no pipeline config is set', function()
		stub_package('glimpse', {
			get_config = function()
				return {}
			end,
		})
		package.loaded['glimpse.previewer.model'] = nil
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')

		assert.equals(0, #calls.pipeline)
		assert.equals(1, #calls.notify)
	end)

	it('ignores stale callback after cancel()', function()
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')
		local on_done = calls.pipeline[1].on_done

		model.cancel(1)
		on_done({ path = '/tmp/glimpse_model_1.png' }, nil)

		assert.equals(0, #calls.route)
	end)

	it('ignores stale callback when a newer show() replaces the token', function()
		local model = require('glimpse.previewer.model')
		model.show('/path/to/model.obj')
		local stale_on_done = calls.pipeline[1].on_done

		model.show('/path/to/model2.obj')
		stale_on_done({ path = '/tmp/glimpse_model_1.png' }, nil)

		assert.equals(0, #calls.route)

		calls.pipeline[2].on_done({ path = '/tmp/glimpse_model_2.png' }, nil)
		assert.equals(1, #calls.route)
		assert.equals('/tmp/glimpse_model_2.png', calls.route[1].path)
	end)

	describe('animation (sequence terminal step)', function()
		before_each(function()
			stub_package('glimpse', {
				get_config = function()
					return {
						pipelines = {
							model = {
								steps = {
									{
										command = 'f3d',
										type = 'sequence',
										frames = 4,
										args = { '{input}', '--output', '{output}' },
									},
								},
								renderer = { fps = 12 },
							},
						},
					}
				end,
			})
			package.loaded['glimpse.previewer.model'] = nil
		end)

		it('calls pipeline.run_steps', function()
			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			assert.equals(1, #calls.pipeline)
			assert.equals('/path/to/model.obj', calls.pipeline[1].input)
		end)

		it('sets up kitty animation after frames are ready', function()
			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			-- Write minimal stub files directly to /tmp (no mkdir needed)
			local frame_paths = {}
			for i = 1, 4 do
				local p = '/tmp/glimpse_model_test_frame_' .. i .. '.png'
				local fh = io.open(p, 'wb')
				if fh then
					fh:write(string.rep('\0', 24))
					fh:close()
				end
				frame_paths[i] = p
			end

			-- Progressive loading: fire on_frame for each frame before on_done.
			for i, p in ipairs(frame_paths) do
				calls.pipeline[1].on_frame(p, i - 1)
			end
			calls.pipeline[1].on_done({ frames = frame_paths, tmpdir = '/tmp/seq_test' }, nil)

			for _, p in ipairs(frame_paths) do
				os.remove(p)
			end

			local setup = nil
			for _, r in ipairs(calls.renderer) do
				if r.op == 'setup' then
					setup = r
					break
				end
			end
			assert.is_not_nil(setup)
			assert.equals(10, setup.buf)
		end)

		it('progressive: timer starts after 2nd on_frame, before on_done', function()
			local p = '/tmp/glimpse_progressive_test.png'
			local fh = io.open(p, 'wb')
			if fh then
				fh:write(string.rep('\0', 24))
				fh:close()
			end

			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			assert.is_nil(calls.timer_cb)

			calls.pipeline[1].on_frame(p, 0)
			assert.is_nil(calls.timer_cb)

			calls.pipeline[1].on_frame(p, 1)
			assert.is_not_nil(calls.timer_cb)

			os.remove(p)
		end)

		it('non-progressive: timer starts only after on_done', function()
			stub_package('glimpse', {
				get_config = function()
					return {
						pipelines = {
							model = {
								steps = {
									{
										command = 'f3d',
										type = 'sequence',
										frames = 2,
										args = { '{input}', '--output', '{output}' },
									},
								},
								renderer = { fps = 12, progressive = false },
							},
						},
					}
				end,
			})
			package.loaded['glimpse.previewer.model'] = nil

			local p = '/tmp/glimpse_nonprogressive_test.png'
			local fh = io.open(p, 'wb')
			if fh then
				fh:write(string.rep('\0', 24))
				fh:close()
			end

			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			calls.pipeline[1].on_frame(p, 0)
			calls.pipeline[1].on_frame(p, 1)
			assert.is_nil(calls.timer_cb)

			calls.pipeline[1].on_done({ frames = { p, p }, tmpdir = '/tmp/seq_nonprog' }, nil)
			os.remove(p)

			assert.is_not_nil(calls.timer_cb)
		end)

		it('ignores stale sequence callback after cancel()', function()
			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')
			local on_done = calls.pipeline[1].on_done

			model.cancel(1)
			on_done({ frames = { '/tmp/seq/frame_0001.png' }, tmpdir = '/tmp/seq' }, nil)

			assert.equals(0, #calls.renderer)
		end)

		it('notifies when sequence returns an error', function()
			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			calls.pipeline[1].on_done(nil, 'f3d crashed')

			assert.equals(1, #calls.notify)
			assert.is_not_nil(calls.notify[1].msg:find('f3d crashed'))
		end)

		it('on_frame for index 0 sets up animation buffer immediately (show_frame_immediately)', function()
			local p = '/tmp/glimpse_on_frame_test.png'
			local fh = io.open(p, 'wb')
			if fh then
				fh:write(string.rep('\0', 24))
				fh:close()
			end

			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			assert.is_function(calls.pipeline[1].on_frame)

			-- No renderer calls yet
			assert.equals(0, #calls.renderer)

			-- Fire on_frame for frame 0 — should immediately setup the animation buffer
			calls.pipeline[1].on_frame(p, 0)
			os.remove(p)

			local setup = nil
			for _, r in ipairs(calls.renderer) do
				if r.op == 'setup' then
					setup = r
					break
				end
			end
			assert.is_not_nil(setup, 'setup_animation_buf should be called on frame 0')
		end)

		it('on_frame for index > 0 does not trigger early render', function()
			local p = '/tmp/glimpse_on_frame_skip_test.png'
			local fh = io.open(p, 'wb')
			if fh then
				fh:write(string.rep('\0', 24))
				fh:close()
			end

			local model = require('glimpse.previewer.model')
			model.show('/path/to/model.obj')

			-- Fire on_frame for frame 1 — should be ignored
			calls.pipeline[1].on_frame(p, 1)
			os.remove(p)

			assert.equals(0, #calls.renderer)
		end)

		it('preview() creates a vsplit when no marked window exists', function()
			local frame_paths = {}
			for i = 1, 2 do
				local p = '/tmp/glimpse_model_vsplit_test_' .. i .. '.png'
				local fh = io.open(p, 'wb')
				if fh then
					fh:write(string.rep('\0', 24))
					fh:close()
				end
				frame_paths[i] = p
			end

			local model = require('glimpse.previewer.model')
			model.preview('/path/to/model.obj')
			for i, p in ipairs(frame_paths) do
				calls.pipeline[1].on_frame(p, i - 1)
			end
			calls.pipeline[1].on_done({ frames = frame_paths, tmpdir = '/tmp/seq_vsplit' }, nil)

			for _, p in ipairs(frame_paths) do
				os.remove(p)
			end

			local vsplit_called = false
			for _, v in ipairs(calls.set_current_win or {}) do
				_ = v
			end
			-- vsplit is issued via vim.cmd
			local cmd_calls = calls.cmd or {}
			for _, v in ipairs(cmd_calls) do
				if v == 'vsplit' then
					vsplit_called = true
				end
			end
			assert.is_true(vsplit_called)
		end)

		it('preview() reuses existing marked window instead of creating a new vsplit', function()
			-- Win=2 exists with a marked preview buffer (buf=20). ensure_window() finds
			-- it lazily at frame-0 time and reuses the existing window+buffer directly,
			-- matching video.lua's _show_animated pattern.
			stub_package('glimpse.preview_state', {
				mark = function() end,
				is_marked = function(b)
					return b == 20
				end,
			})
			vim.api.nvim_list_wins = function()
				return { 1, 2 }
			end
			vim.api.nvim_win_get_buf = function(w)
				if w == 2 then
					return 20
				end
				return 10
			end
			package.loaded['glimpse.previewer.model'] = nil

			local frame_paths = {}
			for i = 1, 2 do
				local p = '/tmp/glimpse_model_reuse_test_' .. i .. '.png'
				local fh = io.open(p, 'wb')
				if fh then
					fh:write(string.rep('\0', 24))
					fh:close()
				end
				frame_paths[i] = p
			end

			local model = require('glimpse.previewer.model')
			calls.cmd = {}
			model.preview('/path/to/model.obj')
			for i, p in ipairs(frame_paths) do
				calls.pipeline[1].on_frame(p, i - 1)
			end
			calls.pipeline[1].on_done({ frames = frame_paths, tmpdir = '/tmp/seq_reuse' }, nil)

			for _, p in ipairs(frame_paths) do
				os.remove(p)
			end

			-- No vsplit should have been created
			local vsplit_called = false
			for _, v in ipairs(calls.cmd or {}) do
				if v == 'vsplit' then
					vsplit_called = true
				end
			end
			assert.is_false(vsplit_called)
			-- setup_animation_buf was called on the existing buffer (20), not a new one
			local setup_on_existing = false
			for _, r in ipairs(calls.renderer) do
				if r.op == 'setup' and r.buf == 20 then
					setup_on_existing = true
				end
			end
			assert.is_true(setup_on_existing)
		end)
	end)
end)
