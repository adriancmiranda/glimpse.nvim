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
	end)
end)
