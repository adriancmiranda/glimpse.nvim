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

describe('performance guards', function()
	it('keeps image preview kind on the extension fast path', function()
		local saved = save_package({
			'glimpse',
			'glimpse.previewer.binary',
			'glimpse.strategy.inline',
			'glimpse.renderer',
			'glimpse.dir',
		})

		package.loaded['glimpse.previewer.binary'] = {
			can_preview = function()
				error('binary fallback should not run for image extensions')
			end,
		}

		local ok, err = pcall(function()
			local glimpse = require('glimpse')
			local kind = glimpse.get_preview_kind('/tmp/photo.png')
			assert.equals('image', kind)
		end)
		restore_package(saved)
		assert.is_true(ok, err)
	end)
end)
