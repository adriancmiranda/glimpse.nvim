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
		local win = vim.api.nvim_get_current_win()
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
				if opts and opts.bufhidden then
					vim.bo[target_buf].bufhidden = opts.bufhidden
				end
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
		telescope.buffer_previewer_maker('/tmp/example.png', buf, { winid = win })
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'rendered:/tmp/example.png'
		end))
		assert.equals('image', vim.bo[buf].filetype)
		assert.equals('wipe', vim.bo[buf].bufhidden)
		assert.equals('wipe', render_calls[1].opts.bufhidden)

		stub_package('glimpse', {
			get_preview_kind = function()
				return 'video'
			end,
			is_git_lfs_pointer = function()
				return false
			end,
		})
		telescope.buffer_previewer_maker('/tmp/example.mp4', buf, { winid = win })
		assert.is_true(wait_for(function()
			return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'rendered:/tmp/thumb.png'
		end))
		assert.equals('image', vim.bo[buf].filetype)
		assert.equals('wipe', vim.bo[buf].bufhidden)
		assert.equals('wipe', render_calls[2].opts.bufhidden)

		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		assert.equals(1, #close_calls)
		assert.equals(buf, close_calls[1])
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
