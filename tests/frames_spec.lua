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

describe('frames', function()
	describe('router', function()
		local saved

		before_each(function()
			saved = save_package({
				'glimpse',
				'glimpse.frames',
				'glimpse.frames.auto',
				'glimpse.frames.batch',
				'glimpse.frames.poll',
				'glimpse.frames.pipe',
			})
		end)

		after_each(function()
			restore_package(saved)
		end)

		it('calls the strategy named in opts.strategy', function()
			local called_with = nil
			package.loaded['glimpse.frames.poll'] = {
				extract = function(filepath, opts, _on_frame, on_done)
					called_with = { filepath = filepath, opts = opts }
					on_done(0, nil)
					return function() end
				end,
			}
			package.loaded['glimpse.frames'] = nil
			local frames = require('glimpse.frames')
			frames.extract_frames_async('/tmp/test.mp4', { strategy = 'poll' }, function() end, function() end)
			assert.is_not_nil(called_with)
			assert.equals('/tmp/test.mp4', called_with.filepath)
		end)

		it('falls back to auto when no strategy is set', function()
			local auto_called = false
			package.loaded['glimpse'] = {
				get_config = function()
					return { video = {} }
				end,
			}
			package.loaded['glimpse.frames.auto'] = {
				extract = function(_filepath, _opts, _on_frame, on_done)
					auto_called = true
					on_done(0, nil)
					return function() end
				end,
			}
			package.loaded['glimpse.frames'] = nil
			local frames = require('glimpse.frames')
			frames.extract_frames_async('/tmp/test.mp4', {}, function() end, function() end)
			assert.is_true(auto_called)
		end)

		it('reads video.frames.strategy from config when not in opts', function()
			local batch_called = false
			package.loaded['glimpse'] = {
				get_config = function()
					return { video = { frames = { strategy = 'batch' } } }
				end,
			}
			package.loaded['glimpse.frames.batch'] = {
				extract = function(_filepath, _opts, _on_frame, on_done)
					batch_called = true
					on_done(0, nil)
					return function() end
				end,
			}
			package.loaded['glimpse.frames'] = nil
			local frames = require('glimpse.frames')
			frames.extract_frames_async('/tmp/test.mp4', {}, function() end, function() end)
			assert.is_true(batch_called)
		end)

		it('returns a cancel function', function()
			package.loaded['glimpse.frames.auto'] = {
				extract = function(_filepath, _opts, _on_frame, on_done)
					on_done(0, nil)
					return function() end
				end,
			}
			package.loaded['glimpse'] = {
				get_config = function()
					return { video = {} }
				end,
			}
			package.loaded['glimpse.frames'] = nil
			local frames = require('glimpse.frames')
			local cancel = frames.extract_frames_async('/tmp/test.mp4', {}, function() end, function() end)
			assert.is_function(cancel)
		end)

		it('rejects unsupported strategies', function()
			local err = nil
			local original_schedule = vim.schedule
			vim.schedule = function(fn)
				fn()
			end
			package.loaded['glimpse'] = {
				get_config = function()
					return { video = { frames = { strategy = 'pipe' } } }
				end,
			}
			package.loaded['glimpse.frames'] = nil
			local frames = require('glimpse.frames')
			local cancel = frames.extract_frames_async('/tmp/test.mp4', {}, function() end, function(_count, done_err)
				err = done_err
			end)

			assert.is_function(cancel)
			assert.equals("unsupported frame strategy 'pipe'", err)

			vim.schedule = original_schedule
		end)
	end)

	describe('poll strategy', function()
		local saved

		before_each(function()
			saved = save_package({
				'glimpse',
				'glimpse.frames.poll',
			})
		end)

		after_each(function()
			restore_package(saved)
		end)

		it('waits for a frame file to stabilize before reading it', function()
			local calls = {}
			local timer = {}
			local stats = {
				{ size = 1, mtime = { sec = 1, nsec = 1 } },
				{ size = 2, mtime = { sec = 1, nsec = 2 } },
				{ size = 2, mtime = { sec = 1, nsec = 2 } },
			}
			local original_executable = vim.fn.executable
			local original_tempname = vim.fn.tempname
			local original_mkdir = vim.fn.mkdir
			local original_delete = vim.fn.delete
			local original_jobstart = vim.fn.jobstart
			local original_new_timer = vim.uv.new_timer
			local original_fs_stat = vim.uv.fs_stat
			local original_schedule_wrap = vim.schedule_wrap
			local original_open = rawget(io, 'open')

			package.loaded['glimpse'] = {
				get_config = function()
					return { video = { frames = { per_second = 10, limit = 1 } } }
				end,
			}
			vim.fn.executable = function()
				return 1
			end
			vim.fn.tempname = function()
				return '/tmp/glimpse-test-frames'
			end
			vim.fn.mkdir = function(path)
				calls.mkdir = path
				return 1
			end
			vim.fn.delete = function(path)
				calls.deleted = path
				return 0
			end
			vim.fn.jobstart = function()
				return 42
			end
			vim.uv.new_timer = function()
				function timer.start(_, _timeout, _repeat, callback)
					timer.callback = callback
				end
				function timer.stop() end
				function timer.close()
					timer.closed = true
				end
				function timer.is_closing()
					return timer.closed == true
				end
				return timer
			end
			vim.uv.fs_stat = function()
				calls.stat = (calls.stat or 0) + 1
				return stats[calls.stat] or stats[#stats]
			end
			vim.schedule_wrap = function(fn)
				return fn
			end
			rawset(io, 'open', function(path)
				calls.opened = path
				return {
					read = function()
						return 'complete-frame'
					end,
					close = function() end,
				}
			end)

			package.loaded['glimpse.frames.poll'] = nil
			local poll = require('glimpse.frames.poll')
			poll.extract('/tmp/test.mp4', { max_frames = 1, poll_ms = 1 }, function(data, index)
				calls.frame = { data = data, index = index }
			end, function() end)

			timer.callback()
			assert.is_nil(calls.frame)
			assert.is_nil(calls.opened)

			timer.callback()
			assert.is_nil(calls.frame)
			assert.is_nil(calls.opened)

			timer.callback()
			assert.are.same({ data = 'complete-frame', index = 1 }, calls.frame)

			vim.fn.executable = original_executable
			vim.fn.tempname = original_tempname
			vim.fn.mkdir = original_mkdir
			vim.fn.delete = original_delete
			vim.fn.jobstart = original_jobstart
			vim.uv.new_timer = original_new_timer
			vim.uv.fs_stat = original_fs_stat
			vim.schedule_wrap = original_schedule_wrap
			rawset(io, 'open', original_open)
		end)
	end)
end)
