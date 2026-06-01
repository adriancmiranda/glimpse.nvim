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

describe('preview kind cache', function()
	it('recomputes preview kind after setup clears the cache', function()
		local saved = save_package({
			'glimpse',
			'glimpse.util',
			'glimpse.previewer.binary',
			'glimpse.strategy.inline',
			'glimpse.integrations.oil',
			'glimpse.integrations.neotree',
			'glimpse.integrations.telescope',
		})

		local video_enabled = true
		local video_calls = 0
		local path = vim.fn.tempname() .. '.mp4'
		vim.fn.writefile({ 'dummy' }, path)

		stub_package('glimpse.util', {
			is_archive = function()
				return false
			end,
			is_sqlite = function()
				return false
			end,
			is_cert = function()
				return false
			end,
			is_key = function()
				return false
			end,
			is_font = function()
				return false
			end,
			is_video = function()
				video_calls = video_calls + 1
				return video_enabled
			end,
			is_image = function()
				return false
			end,
		})
		stub_package('glimpse.previewer.binary', {
			can_preview = function()
				return false
			end,
		})
		stub_package('glimpse.strategy.inline', {
			setup_autocmds = function()
				return true
			end,
		})
		stub_package('glimpse.integrations.oil', {
			setup = function()
				return true
			end,
		})
		stub_package('glimpse.integrations.neotree', {
			setup = function()
				return true
			end,
		})
		stub_package('glimpse.integrations.telescope', {
			setup = function()
				return true
			end,
		})

		package.loaded['glimpse'] = nil
		local glimpse = require('glimpse')

		assert.equals('video', glimpse.get_preview_kind(path))
		assert.equals(1, video_calls)

		video_enabled = false
		assert.equals('video', glimpse.get_preview_kind(path))
		assert.equals(1, video_calls)

		glimpse.setup({
			strategy = 'pane',
			integrations = {
				oil = false,
				neotree = false,
				telescope = false,
			},
		})

		assert.is_nil(glimpse.get_preview_kind(path))
		assert.equals(2, video_calls)

		vim.fn.delete(path)
		restore_package(saved)
	end)
end)
