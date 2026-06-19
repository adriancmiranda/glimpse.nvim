local kitty = require('glimpse.kitty')

local function stub_fn(table_ref, key, value)
	local original = table_ref[key]
	table_ref[key] = value
	return original
end

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

	describe('animation', function()
		local sent = {}
		local orig_write

		before_each(function()
			sent = {}
			orig_write = kitty._write
			kitty._write = function(data)
				sent[#sent + 1] = data
			end
		end)

		after_each(function()
			kitty._write = orig_write
		end)

		it('exposes animation_frame function', function()
			assert.is_function(kitty.animation_frame)
		end)

		it('exposes animation_play function', function()
			assert.is_function(kitty.animation_play)
		end)

		it('exposes animation_pause function', function()
			assert.is_function(kitty.animation_pause)
		end)

		it('animation_frame uses action T for the first frame', function()
			kitty.animation_frame(1, 'PNG', 100, true)
			assert.is_true(#sent > 0)
			assert.is_not_nil(sent[1]:find('a=T', 1, true))
		end)

		it('animation_frame uses action f for subsequent frames', function()
			kitty.animation_frame(1, 'PNG', 100, false)
			assert.is_true(#sent > 0)
			assert.is_not_nil(sent[1]:find('a=f', 1, true))
		end)

		it('animation_frame includes frame delay', function()
			kitty.animation_frame(1, 'PNG', 80, true)
			assert.is_not_nil(sent[1]:find('z=80', 1, true))
		end)

		it('animation_play sends v=3 (running)', function()
			kitty.animation_play(1)
			assert.is_not_nil(sent[1]:find('v=3', 1, true))
		end)

		it('animation_pause sends v=1 (stopped)', function()
			kitty.animation_pause(1)
			assert.is_not_nil(sent[1]:find('v=1', 1, true))
		end)
	end)

	describe('new_id', function()
		it('returns a positive integer', function()
			local id = kitty.new_id()
			assert.is_number(id)
			assert.is_true(id > 0)
		end)

		it('returns unique ids on successive calls', function()
			local a = kitty.new_id()
			local b = kitty.new_id()
			assert.not_equals(a, b)
		end)
	end)

	describe('png_dimensions_from_data', function()
		it('returns nil for data shorter than 24 bytes', function()
			local w, h = kitty.png_dimensions_from_data('tooshort')
			assert.is_nil(w)
			assert.is_nil(h)
		end)

		it('reads width and height from a valid PNG header', function()
			-- Minimal PNG header with width=640 (0x00000280) height=416 (0x000001A0)
			local header = '\137PNG\r\n\026\n' -- 8-byte PNG signature
				.. '\0\0\0\013IHDR' -- length + type
				.. '\0\0\002\128' -- width = 640
				.. '\0\0\001\160' -- height = 416
				.. '\8\2\0\0\0' -- bit depth, color type, etc.
			local w, h = kitty.png_dimensions_from_data(header)
			assert.equals(640, w)
			assert.equals(416, h)
		end)
	end)

	describe('retransmit_frame', function()
		local sent = {}
		local orig_write

		before_each(function()
			sent = {}
			orig_write = kitty._write
			kitty._write = function(data)
				sent[#sent + 1] = data
			end
		end)

		after_each(function()
			kitty._write = orig_write
		end)

		it('sends a=T with t=f (file path mode)', function()
			kitty.retransmit_frame(1, '/tmp/frame.png')
			assert.is_not_nil(sent[1]:find('a=T', 1, true))
			assert.is_not_nil(sent[1]:find('t=f', 1, true))
		end)

		it('includes U=1 (unicode placeholder mode)', function()
			kitty.retransmit_frame(1, '/tmp/frame.png')
			assert.is_not_nil(sent[1]:find('U=1', 1, true))
		end)

		it('sends a non-empty command when called', function()
			kitty.retransmit_frame(1, '/tmp/frame.png')
			assert.is_true(#sent > 0)
			assert.is_true(#sent[1] > 0)
		end)
	end)

	describe('transmit with invalid file', function()
		it('returns error for non-existent file', function()
			local id, err = kitty.transmit('/tmp/nonexistent_image_12345.png')
			assert.is_nil(id)
			assert.is_not_nil(err)
		end)
	end)

	describe('transmit_async magick fallback', function()
		local restore = {}
		local calls = {}

		before_each(function()
			calls = {
				jobstart = {},
				write = {},
			}

			restore.executable = stub_fn(vim.fn, 'executable', function(cmd)
				return cmd == 'magick' and 1 or 0
			end)
			restore.jobstart = stub_fn(vim.fn, 'jobstart', function(cmd, opts)
				calls.jobstart[#calls.jobstart + 1] = { cmd = cmd, opts = opts }
				return 1
			end)
			restore.schedule = stub_fn(vim, 'schedule', function(fn)
				fn()
			end)
			restore.write = kitty._write
			kitty._write = function(data)
				calls.write[#calls.write + 1] = data
			end
			restore.base64 = vim.base64
			vim.base64 = {
				encode = function(value)
					return 'encoded:' .. value
				end,
			}
			package.loaded['glimpse.magickwand'] = {
				available = function()
					return false
				end,
			}
		end)

		after_each(function()
			vim.fn.executable = restore.executable
			vim.fn.jobstart = restore.jobstart
			vim.schedule = restore.schedule
			kitty._write = restore.write
			vim.base64 = restore.base64
			package.loaded['glimpse.magickwand'] = nil
		end)

		it('includes stderr in the error message when magick fails', function()
			local result, err
			kitty.transmit_async('/tmp/broken.jpg', { width = 1, height = 1 }, function(id, callback_err)
				result, err = id, callback_err
			end)

			assert.equals(1, #calls.jobstart)
			calls.jobstart[1].opts.on_stderr(1, { 'no decode delegate for this image format' })
			calls.jobstart[1].opts.on_exit(1, 1)

			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.is_not_nil(err:find('magick falhou', 1, true))
			assert.is_not_nil(err:find('no decode delegate for this image format', 1, true))
		end)

		it('does not turn a successful stdout callback into an error on exit', function()
			local result, err
			kitty.transmit_async('/tmp/ok.jpg', { width = 1, height = 1 }, function(id, callback_err)
				result, err = id, callback_err
			end)

			assert.equals(1, #calls.jobstart)
			calls.jobstart[1].opts.on_stdout(1, { '12 34' })
			calls.jobstart[1].opts.on_exit(1, 1)

			assert.is_not_nil(result)
			assert.is_nil(err)
			assert.is_true(#calls.write > 0)
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
