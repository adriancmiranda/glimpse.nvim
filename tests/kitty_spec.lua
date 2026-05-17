local kitty = require('glimpse.kitty')

describe('kitty', function()
	describe('transmit', function()
		it('exposes transmit function', function()
			assert.is_function(kitty.transmit)
		end)

		it('exposes transmit_async function', function()
			assert.is_function(kitty.transmit_async)
		end)

		it('exposes prefetch function', function()
			assert.is_function(kitty.prefetch)
		end)

		it('exposes delete function', function()
			assert.is_function(kitty.delete)
		end)

		it('exposes delete_all function', function()
			assert.is_function(kitty.delete_all)
		end)
	end)

	describe('transmit with invalid file', function()
		it('returns error for non-existent file', function()
			local id, err = kitty.transmit('/tmp/nonexistent_image_12345.png')
			assert.is_nil(id)
			assert.is_not_nil(err)
		end)
	end)

	describe('png_dimensions (via transmit_async)', function()
		-- Create a minimal valid 1x1 PNG for testing
		local test_png = '/tmp/glimpse_test_1x1.png'

		before_each(function()
			-- Minimal 1x1 white PNG (67 bytes)
			local png = '\137PNG\r\n\026\n' -- signature (8 bytes)
				.. '\0\0\0\rIHDR' -- IHDR chunk length + type
				.. '\0\0\0\001' -- width = 1
				.. '\0\0\0\001' -- height = 1
				.. '\008\002' -- bit depth=8, color type=2 (RGB)
				.. '\0\0\0' -- compression, filter, interlace
				.. '\144\119\083\222' -- CRC
				.. '\0\0\0\012IDAT' -- IDAT chunk
				.. '\008\215\099\248\015\0\0\001\001\0\005' -- compressed data
				.. '\024\217\138\163' -- CRC
				.. '\0\0\0\0IEND' -- IEND chunk
				.. '\174\066\096\130' -- CRC
			local f = io.open(test_png, 'wb')
			if f then
				f:write(png)
				f:close()
			end
		end)

		after_each(function()
			os.remove(test_png)
		end)

		it('can read a valid PNG file', function()
			assert.equals(1, vim.fn.filereadable(test_png))
		end)
	end)
end)
