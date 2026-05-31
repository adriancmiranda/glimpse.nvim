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

describe('previewer highlight offsets', function()
	it('shifts sqlite preview_data highlights below the header', function()
		local saved = save_package({
			'glimpse.sqlite',
			'glimpse.preview_cache',
			'glimpse.previewer.sqlite',
		})

		stub_package('glimpse.preview_cache', {
			memoize = function(_, _, producer)
				return producer()
			end,
		})
		stub_package('glimpse.sqlite', {
			list = function()
				return { { name = 'users', columns = { 'id' }, sql = '' } }
			end,
			format = function()
				return { '  1 table(s)', '', '  users' }, {
					{ 0, 0, -1, 'Title' },
					{ 2, 0, 6, 'Function' },
				}
			end,
		})

		local previewer = require('glimpse.previewer.sqlite')
		local lines, highlights = previewer.preview_data('/tmp/example.db')

		assert.equals('  example.db', lines[1])
		assert.equals(2, highlights[1][1])
		assert.equals(4, highlights[2][1])

		restore_package(saved)
	end)

	it('shifts font preview_data highlights below the header', function()
		local saved = save_package({
			'glimpse.font',
			'glimpse.preview_cache',
			'glimpse.previewer.font',
		})

		stub_package('glimpse.preview_cache', {
			memoize = function(_, _, producer)
				return producer()
			end,
		})
		stub_package('glimpse.font', {
			query = function()
				return {
					family = 'Example',
					style = 'Regular',
					weight = '400',
					slant = '0',
					width = '100',
				}
			end,
			format = function()
				return { '  Family: Example', '  Sample:' }, {
					{ 0, 2, 8, 'Identifier' },
					{ 1, 2, 8, 'Identifier' },
				}
			end,
		})

		local previewer = require('glimpse.previewer.font')
		local lines, highlights = previewer.preview_data('/tmp/example.ttf')

		assert.equals('  example.ttf', lines[1])
		assert.equals(2, highlights[1][1])
		assert.equals(3, highlights[2][1])

		restore_package(saved)
	end)

	it('shifts archive summary highlights below the header', function()
		local saved = save_package({
			'glimpse.archive',
			'glimpse.preview_cache',
			'glimpse.previewer.archive',
		})

		stub_package('glimpse.preview_cache', {
			memoize = function(_, _, producer)
				return producer()
			end,
		})
		stub_package('glimpse.archive', {
			list = function()
				return { { path = 'file.txt', type = 'file', suspicious = true } }
			end,
			format = function()
				return { 'full' }, {}
			end,
			summary = function()
				return { '  1 entry', '⚠ suspicious path' }, {
					{ 1, 0, -1, 'DiagnosticWarn' },
				}
			end,
		})

		local previewer = require('glimpse.previewer.archive')
		local lines, highlights = previewer.preview_data('/tmp/example.zip')

		assert.equals('  example.zip', lines[1])
		assert.equals(3, highlights[1][1])

		restore_package(saved)
	end)
end)
