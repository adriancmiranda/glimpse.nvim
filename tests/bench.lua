--- Benchmark para glimpse.nvim
--- Uso: make bench (nvim -l)

vim.opt.rtp:prepend('.')

local function bench(name, iterations, fn)
	for _ = 1, 3 do
		fn()
	end
	local start = vim.uv.hrtime()
	for _ = 1, iterations do
		fn()
	end
	local elapsed = (vim.uv.hrtime() - start) / 1e6
	print(string.format('  %-36s %6d ops  %8.2f ms  %6.3f ms/op', name, iterations, elapsed, elapsed / iterations))
end

print('')
print(string.rep('=', 70))
print('  glimpse.nvim benchmark')
print(string.rep('=', 70))
print('')

package.loaded['glimpse'] = {
	get_config = function()
		return {
			loading = {
				text = '  ⏳ Loading...',
			},
			cell_size = {
				width = 20,
				height = 40,
			},
			image = {
				formats = { '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.avif', '.svg', '.pdf', '.pict' },
			},
			video = {
				formats = { '.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.m4v' },
			},
			archive = {
				formats = { '.zip', '.tar', '.tar.gz', '.tgz', '.tar.bz2', '.tar.xz', '.txz', '.jar', '.war', '.apk' },
			},
		}
	end,
}

local detect = require('glimpse.detect')
-- In -l mode, vim.fn.system may not work. We only test it when not in tmux.
local can_detect = os.getenv('TERM_PROGRAM') ~= 'tmux'
if can_detect then
	bench('detect.get_terminal', 10000, function()
		detect.get_terminal()
	end)
	bench('detect.supports_inline', 10000, function()
		detect.supports_inline()
	end)
end
bench('detect.in_tmux', 10000, function()
	detect.in_tmux()
end)

local util = require('glimpse.util')
bench('util.is_image (hit)', 10000, function()
	util.is_image('/a/b.png')
end)
bench('util.is_image (miss)', 10000, function()
	util.is_image('/a/b.lua')
end)
bench('util.is_image (no ext)', 10000, function()
	util.is_image('Makefile')
end)

local fake_header = '\137PNG\r\n\026\n\0\0\0\rIHDR\0\0\003\032\0\0\002\088'
bench('png header parse', 10000, function()
	local _ = fake_header:byte(17) * 16777216
		+ fake_header:byte(18) * 65536
		+ fake_header:byte(19) * 256
		+ fake_header:byte(20)
end)

package.loaded['glimpse'] = nil
local glimpse = require('glimpse')

bench('glimpse.get_preview_kind (image hit)', 100000, function()
	glimpse.get_preview_kind('/a/b.png')
end)

package.loaded['glimpse.renderer'] = {
	render = function() end,
	close = function() end,
	has_placement = function()
		return false
	end,
	register = function() end,
	rerender = function() end,
}
package.loaded['glimpse.dir'] = { follow = function() end }

local inline = require('glimpse.strategy.inline')
bench('inline.show (real jpg)', 1000, function()
	inline.show('/private/tmp/glimpse-test.jpg')
end)

package.loaded['glimpse.kitty'] = {
	transmit_async = function(_, _, callback)
		callback(1, nil, 160, 120)
		return nil
	end,
	delete = function()
		return true
	end,
}
package.loaded['glimpse'] = {
	get_config = function()
		return {
			loading = {
				text = '  ⏳ Loading...',
			},
			cell_size = {
				width = 20,
				height = 40,
			},
		}
	end,
}
package.loaded['glimpse.renderer'] = nil
package.loaded['glimpse.dir'] = { follow = function() end }
local renderer = require('glimpse.renderer')
local render_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(render_buf)
bench('renderer.render (real jpg)', 1000, function()
	renderer.render(render_buf, '/private/tmp/glimpse-test.jpg', { winid = vim.api.nvim_get_current_win() })
end)

local pointer = vim.fn.tempname() .. '.jpg'
vim.fn.writefile({
	'version https://git-lfs.github.com/spec/v1',
	'oid sha256:fe93af5da1f8d77dac7187f24de828c8fab913629e7870ba27cff63ba5e8554f',
	'size 1576804',
}, pointer)

bench('util.parse_git_lfs_pointer', 1000, function()
	util.parse_git_lfs_pointer(pointer)
end)

vim.fn.delete(pointer)

if vim.base64 then
	local s1k = string.rep('x', 1024)
	local s10k = string.rep('x', 10240)
	bench('base64 encode 1KB', 10000, function()
		vim.base64.encode(s1k)
	end)
	bench('base64 encode 10KB', 1000, function()
		vim.base64.encode(s10k)
	end)
end

print('')
print(string.rep('=', 70))
