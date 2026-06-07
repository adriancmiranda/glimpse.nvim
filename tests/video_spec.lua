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
					pane_position = 'right',
					pane_size = 40,
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
					pane_position = 'bottom',
					pane_size = 55,
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
end)
