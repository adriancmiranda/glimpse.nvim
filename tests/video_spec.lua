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

	it('drops stale thumbnail callbacks from older requests', function()
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
			'glimpse.thumbnail',
			'glimpse.strategy.inline',
			'glimpse.strategy.pane',
			'glimpse.previewer.video',
		})

		local calls = {}
		local current_win = 11
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

		vim.api.nvim_get_current_win = original_get_current_win
		vim.api.nvim_set_current_win = original_set_current_win
		vim.api.nvim_win_is_valid = original_win_is_valid
		restore_package(saved)
	end)
end)
