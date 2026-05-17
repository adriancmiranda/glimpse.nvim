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
			formats = { '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.avif', '.svg', '.pdf', '.pict' },
		}
	end,
}

local detect = require('glimpse.detect')
-- Em modo -l, vim.fn.system pode não funcionar. Testamos apenas se não estiver no tmux.
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
