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

local function stub_package(name, value)
	package.loaded[name] = value
end

local function wait_for(predicate)
	return vim.wait(500, predicate, 10)
end

describe('telescope integration', function()
	it('renders text previews in the Telescope buffer', function()
		local saved = save_package({
			'glimpse',
			'glimpse.previewer.archive',
			'glimpse.previewer.sqlite',
			'glimpse.previewer.font',
			'glimpse.previewer.cert',
			'glimpse.previewer.key',
			'glimpse.previewer.binary',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		local cases = {
			{ kind = 'archive', module = 'glimpse.previewer.archive', filetype = 'glimpse_archive' },
			{ kind = 'sqlite', module = 'glimpse.previewer.sqlite', filetype = 'glimpse_sqlite' },
			{ kind = 'font', module = 'glimpse.previewer.font', filetype = 'glimpse_font' },
			{ kind = 'cert', module = 'glimpse.previewer.cert', filetype = 'glimpse_cert' },
			{ kind = 'key', module = 'glimpse.previewer.key', filetype = 'glimpse_key' },
			{ kind = 'binary', module = 'glimpse.previewer.binary', filetype = 'glimpse_binary' },
		}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for Glimpse kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})

		local telescope = require('glimpse.integrations.telescope')

		for _, case in ipairs(cases) do
			stub_package('glimpse', {
				get_preview_kind = function()
					return case.kind
				end,
			})
			stub_package(case.module, {
				preview_data = function(filepath)
					return {
						string.format('%s:%s', case.kind, filepath),
						'line-two',
					}, {
						{ 0, 0, -1, 'Title' },
					}
				end,
			})

			telescope.buffer_previewer_maker('/tmp/example.' .. case.kind, buf, { winid = win })
			assert.is_true(wait_for(function()
				return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == case.kind .. ':/tmp/example.' .. case.kind
			end))
			assert.equals(case.filetype, vim.bo[buf].filetype)
			assert.not_equals('wipe', vim.bo[buf].bufhidden)

			local ns = vim.api.nvim_create_namespace('glimpse_telescope')
			local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
			assert.is_true(#extmarks > 0)
		end

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		restore_package(saved)
	end)

	it('renders image and video previews through the media path', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.thumbnail',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local original_win = vim.api.nvim_get_current_win()
		vim.cmd('vsplit')
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		local render_calls = {}
		local close_calls = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function(target_buf, filepath, opts)
				render_calls[#render_calls + 1] = { filepath = filepath, opts = opts }
				vim.bo[target_buf].modifiable = true
				vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'rendered:' .. filepath })
				vim.bo[target_buf].modifiable = false
				vim.bo[target_buf].filetype = 'image'
			end,
			close = function(target_buf)
				close_calls[#close_calls + 1] = target_buf
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(_, callback)
				callback('/tmp/thumb.png')
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		stub_package('glimpse', {
			get_preview_kind = function()
				return 'image'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})
		telescope.buffer_previewer_maker('/tmp/example.png', buf, {
			bufname = 'glimpse://telescope/media/image/example.png',
			winid = win,
		})
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'rendered:/tmp/example.png'
		end))
		assert.equals('image', vim.bo[buf].filetype)
		assert.equals('hide', vim.bo[buf].bufhidden)
		assert.is_nil(render_calls[1].opts.bufhidden)
		assert.is_not_nil(render_calls[1].opts.bufname)
		assert.is_not_nil(render_calls[1].opts.bufname:match('^glimpse://telescope/media/image/'))

		stub_package('glimpse', {
			get_preview_kind = function()
				return 'video'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})
		telescope.buffer_previewer_maker('/tmp/example.mp4', buf, {
			bufname = 'glimpse://telescope/media/video/example.mp4',
			winid = win,
		})
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'rendered:/tmp/thumb.png'
		end))
		assert.equals('image', vim.bo[buf].filetype)
		assert.equals('hide', vim.bo[buf].bufhidden)
		assert.is_nil(render_calls[2].opts.bufhidden)
		assert.is_not_nil(render_calls[2].opts.bufname)
		assert.is_not_nil(render_calls[2].opts.bufname:match('^glimpse://telescope/media/video/'))

		vim.api.nvim_win_close(win, true)
		assert.equals(1, #close_calls)
		assert.equals(buf, close_calls[1])

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		if vim.api.nvim_win_is_valid(original_win) then
			vim.api.nvim_set_current_win(original_win)
		end
		restore_package(saved)
	end)

	it('clears the previous Kitty placement before writing text previews', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.previewer.archive',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		local render_calls = {}
		local close_calls = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for Glimpse kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function(target_buf, filepath, opts)
				render_calls[#render_calls + 1] = { target_buf = target_buf, filepath = filepath, opts = opts }
				vim.bo[target_buf].modifiable = true
				vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'image:' .. filepath })
				vim.bo[target_buf].modifiable = false
				vim.bo[target_buf].filetype = 'image'
			end,
			close = function(target_buf)
				close_calls[#close_calls + 1] = target_buf
			end,
		})
		stub_package('glimpse.previewer.archive', {
			preview_data = function(filepath)
				return { 'archive:' .. filepath }, {}
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function(filepath)
				if filepath:match('%.png$') then
					return 'image'
				end
				return 'archive'
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		telescope.buffer_previewer_maker('/tmp/example.png', buf, { winid = win })
		assert.is_true(wait_for(function()
			return render_calls[1] ~= nil
		end))

		telescope.buffer_previewer_maker('/tmp/example.zip', buf, { winid = win })
		assert.is_true(wait_for(function()
			return close_calls[1] == buf and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'archive:/tmp/example.zip'
		end))
		assert.equals(buf, close_calls[1])
		assert.equals('glimpse_archive', vim.bo[buf].filetype)

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		restore_package(saved)
	end)

	it('ignores stale video thumbnails after the preview window closes', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.thumbnail',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local original_win = vim.api.nvim_get_current_win()
		vim.cmd('vsplit')
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		local render_calls = 0
		local thumbnail_callback

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function()
				render_calls = render_calls + 1
			end,
			close = function()
				return true
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(_, callback)
				thumbnail_callback = callback
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function()
				return 'video'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		telescope.buffer_previewer_maker('/tmp/example.mp4', buf, { winid = win })
		assert.is_true(wait_for(function()
			return thumbnail_callback ~= nil
		end))
		vim.api.nvim_win_close(win, true)
		thumbnail_callback('/tmp/thumb.png')
		assert.equals(0, render_calls)

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		if vim.api.nvim_win_is_valid(original_win) then
			vim.api.nvim_set_current_win(original_win)
		end
		restore_package(saved)
	end)

	it('keeps shared media buffers alive until the last preview window closes', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local original_win = vim.api.nvim_get_current_win()
		vim.cmd('vsplit')
		local win1 = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win1, buf)
		vim.cmd('vsplit')
		local win2 = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win2, buf)
		local render_calls = 0
		local close_calls = 0

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function(target_buf, filepath, _opts)
				render_calls = render_calls + 1
				vim.bo[target_buf].modifiable = true
				vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'rendered:' .. filepath })
				vim.bo[target_buf].modifiable = false
				vim.bo[target_buf].filetype = 'image'
			end,
			close = function(_target_buf)
				close_calls = close_calls + 1
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function()
				return 'image'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		telescope.buffer_previewer_maker('/tmp/example.png', buf, { winid = win1 })
		assert.is_true(wait_for(function()
			return render_calls >= 1
		end))
		telescope.buffer_previewer_maker('/tmp/example.png', buf, { winid = win2 })
		assert.is_true(wait_for(function()
			return render_calls >= 2
		end))

		vim.api.nvim_win_close(win1, true)
		assert.equals(0, close_calls)
		vim.api.nvim_win_close(win2, true)
		assert.is_true(wait_for(function()
			return close_calls == 1
		end))

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		if vim.api.nvim_win_is_valid(original_win) then
			vim.api.nvim_set_current_win(original_win)
		end
		restore_package(saved)
	end)

	it('keeps pending video renders alive when one shared preview window closes', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.thumbnail',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local original_win = vim.api.nvim_get_current_win()
		vim.cmd('vsplit')
		local win1 = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win1, buf)
		vim.cmd('vsplit')
		local win2 = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win2, buf)
		local render_calls = 0
		local callbacks = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function()
				render_calls = render_calls + 1
			end,
			close = function()
				return true
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(_, callback)
				callbacks[#callbacks + 1] = callback
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function()
				return 'video'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		telescope.buffer_previewer_maker('/tmp/example.mp4', buf, { winid = win1 })
		assert.is_true(wait_for(function()
			return #callbacks == 1
		end))
		telescope.buffer_previewer_maker('/tmp/example.mp4', buf, { winid = win2 })
		assert.is_true(wait_for(function()
			return #callbacks == 2
		end))

		vim.api.nvim_win_close(win1, true)
		callbacks[2]('/tmp/thumb.png')
		assert.is_true(wait_for(function()
			return render_calls == 1
		end))

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		if vim.api.nvim_win_is_valid(original_win) then
			vim.api.nvim_set_current_win(original_win)
		end
		restore_package(saved)
	end)

	it('reattaches media cleanup when the preview window switches buffers', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.thumbnail',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf1 = vim.api.nvim_create_buf(false, true)
		local buf2 = vim.api.nvim_create_buf(false, true)
		local original_win = vim.api.nvim_get_current_win()
		vim.cmd('vsplit')
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf1)
		local close_calls = {}
		local win_closed_callbacks = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function(target_buf, filepath, _opts)
				vim.bo[target_buf].modifiable = true
				vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'rendered:' .. filepath })
				vim.bo[target_buf].modifiable = false
				vim.bo[target_buf].filetype = 'image'
			end,
			close = function(target_buf)
				close_calls[#close_calls + 1] = target_buf
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(_, callback)
				callback('/tmp/thumb.png')
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function(filepath)
				if filepath:match('%.mp4$') then
					return 'video'
				end
				return 'image'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})

		local original_create_autocmd = vim.api.nvim_create_autocmd
		vim.api.nvim_create_autocmd = function(event, spec)
			if event == 'WinClosed' then
				win_closed_callbacks[#win_closed_callbacks + 1] = spec.callback
			end
			return #win_closed_callbacks
		end

		local telescope = require('glimpse.integrations.telescope')
		telescope.buffer_previewer_maker('/tmp/example.png', buf1, { winid = win })
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf1, 0, 1, false)[1] == 'rendered:/tmp/example.png'
		end))
		vim.api.nvim_win_set_buf(win, buf2)
		telescope.buffer_previewer_maker('/tmp/example.mp4', buf2, { winid = win })
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf2, 0, 1, false)[1] == 'rendered:/tmp/thumb.png'
		end))

		assert.equals(1, #win_closed_callbacks)
		assert.equals(1, #close_calls)
		assert.equals(buf1, close_calls[1])
		win_closed_callbacks[1]()
		assert.equals(2, #close_calls)
		assert.equals(buf2, close_calls[2])

		if vim.api.nvim_buf_is_valid(buf1) then
			vim.api.nvim_buf_delete(buf1, { force = true })
		end
		if vim.api.nvim_buf_is_valid(buf2) then
			vim.api.nvim_buf_delete(buf2, { force = true })
		end
		if vim.api.nvim_win_is_valid(original_win) then
			vim.api.nvim_set_current_win(original_win)
		end
		vim.api.nvim_create_autocmd = original_create_autocmd
		restore_package(saved)
	end)

	it('returns stable but isolated buffer names for media previews', function()
		local saved = save_package({
			'glimpse',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function(filepath)
				if filepath:match('%.mp4$') then
					return 'video'
				end
				return 'image'
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		local previewer = telescope.previewer()
		local image_name = previewer.get_buffer_by_name(nil, { path = '/tmp/example.png' })
		local image_name_2 = previewer.get_buffer_by_name(nil, { path = '/tmp/example.png' })
		local other_name = previewer.get_buffer_by_name(nil, { path = '/tmp/another.png' })
		local video_name = previewer.get_buffer_by_name(nil, { path = '/tmp/example.mp4' })

		assert.equals(image_name, image_name_2)
		assert.not_equals(image_name, other_name)
		assert.not_equals(image_name, video_name)
		assert.not_equals(other_name, video_name)
		assert.is_not_nil(image_name:match('^glimpse://telescope/media/image/'))
		assert.is_not_nil(video_name:match('^glimpse://telescope/media/video/'))

		restore_package(saved)
	end)

	it('falls back to Telescope when specific kinds are disabled', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		local fallback_calls = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function(filepath)
				fallback_calls[#fallback_calls + 1] = filepath
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function()
				error('render should not be called when a Telescope kind is disabled')
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function(filepath)
				if filepath:match('%.png$') then
					return 'image'
				end
				return 'archive'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		telescope.setup({
			enable = true,
			pickers = { 'find_files' },
			image = false,
			archive = false,
		})

		telescope.buffer_previewer_maker('/tmp/example.png', buf, { winid = win })
		assert.is_true(wait_for(function()
			return #fallback_calls == 1
		end))

		telescope.buffer_previewer_maker('/tmp/example.zip', buf, { winid = win })
		assert.is_true(wait_for(function()
			return #fallback_calls == 2
		end))

		assert.are.same({ '/tmp/example.png', '/tmp/example.zip' }, fallback_calls)

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		restore_package(saved)
	end)

	it('keeps Telescope preview cwd unchanged by default', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.dir',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		local root = vim.fn.tempname()
		vim.fn.mkdir(root, 'p')
		local filepath = root .. '/image.png'
		vim.fn.writefile({ 'x' }, filepath)
		local original_cwd = vim.fn.getcwd()
		local follow_calls = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for Glimpse image previews')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.dir', {
			follow = function(filepath_to_follow)
				follow_calls[#follow_calls + 1] = filepath_to_follow
			end,
		})
		stub_package('glimpse.renderer', {
			render = function(target_buf, filepath_to_render)
				vim.bo[target_buf].modifiable = true
				vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'rendered:' .. filepath_to_render })
				vim.bo[target_buf].modifiable = false
				vim.bo[target_buf].filetype = 'image'
			end,
		})
		stub_package('glimpse', {
			get_preview_kind = function()
				return 'image'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})

		package.loaded['glimpse.integrations.telescope'] = nil
		local telescope = require('glimpse.integrations.telescope')
		telescope.setup({
			enable = true,
			pickers = { 'find_files' },
		})

		telescope.buffer_previewer_maker(filepath, buf, { winid = win })
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'rendered:' .. filepath
		end))
		assert.equals(original_cwd, vim.fn.getcwd())
		assert.equals(0, #follow_calls)

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		vim.loop.fs_unlink(filepath)
		restore_package(saved)
	end)

	it('ignores stale video callbacks after a newer Telescope request', function()
		local saved = save_package({
			'glimpse',
			'glimpse.renderer',
			'glimpse.thumbnail',
			'telescope.previewers',
			'telescope.from_entry',
			'telescope.config',
			'glimpse.integrations.telescope',
		})

		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_get_current_win()
		local callbacks = {}
		local render_calls = {}

		stub_package('telescope.previewers', {
			buffer_previewer_maker = function()
				error('fallback previewer should not be called for media kinds')
			end,
			new_buffer_previewer = function(spec)
				return spec
			end,
		})
		stub_package('telescope.from_entry', {
			path = function(entry)
				return entry.path
			end,
		})
		stub_package('telescope.config', {
			pickers = {},
			set_pickers = function()
				return true
			end,
		})
		stub_package('glimpse.renderer', {
			render = function(target_buf, filepath)
				render_calls[#render_calls + 1] = filepath
				vim.bo[target_buf].modifiable = true
				vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'rendered:' .. filepath })
				vim.bo[target_buf].modifiable = false
				vim.bo[target_buf].filetype = 'image'
			end,
		})
		stub_package('glimpse.thumbnail', {
			extract_async = function(_, callback)
				callbacks[#callbacks + 1] = callback
			end,
		})

		local telescope = require('glimpse.integrations.telescope')
		stub_package('glimpse', {
			get_preview_kind = function()
				return 'video'
			end,
		})

		telescope.buffer_previewer_maker('/tmp/first.mp4', buf, { winid = win })
		assert.is_true(wait_for(function()
			return #callbacks == 1
		end))

		telescope.buffer_previewer_maker('/tmp/second.mp4', buf, { winid = win })
		assert.is_true(wait_for(function()
			return #callbacks == 2
		end))

		callbacks[1]('/tmp/first-thumb.png')
		callbacks[2]('/tmp/second-thumb.png')

		assert.equals(1, #render_calls)
		assert.equals('/tmp/second-thumb.png', render_calls[1])
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'rendered:/tmp/second-thumb.png'
		end))

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		restore_package(saved)
	end)
end)
