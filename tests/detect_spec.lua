-- luacheck: ignore 122
local detect = require('glimpse.detect')

describe('detect', function()
	local orig_getenv

	before_each(function()
		orig_getenv = os.getenv
		detect._reset()
		-- Mock TMUX as nil by default to isolate tests from the real environment
		local real_getenv = orig_getenv
		os.getenv = function(var)
			if var == 'TMUX' then
				return nil
			end
			return real_getenv(var)
		end
	end)

	after_each(function()
		os.getenv = orig_getenv
	end)

	describe('get_terminal', function()
		it('returns kitty for TERM_PROGRAM=kitty', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'kitty'
				end
				if var == 'TMUX' then
					return nil
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.equals('kitty', detect.get_terminal())
		end)

		it('returns ghostty for TERM_PROGRAM=ghostty', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'ghostty'
				end
				if var == 'TMUX' then
					return nil
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.equals('ghostty', detect.get_terminal())
		end)

		it('returns wezterm for TERM_PROGRAM=WezTerm', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'WezTerm'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.equals('wezterm', detect.get_terminal())
		end)

		it('returns iterm for TERM_PROGRAM=iTerm2', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'iTerm2'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.equals('iterm', detect.get_terminal())
		end)

		it('returns nil for unknown terminal', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'alacritty'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.is_nil(detect.get_terminal())
		end)
	end)

	describe('supports_inline', function()
		it('returns true for kitty', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'kitty'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.is_true(detect.supports_inline())
		end)

		it('returns true for ghostty', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'ghostty'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.is_true(detect.supports_inline())
		end)

		it('returns false for wezterm', function()
			os.getenv = function(var)
				if var == 'TERM_PROGRAM' then
					return 'WezTerm'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.is_false(detect.supports_inline())
		end)
	end)

	describe('in_tmux', function()
		it('returns true when TMUX is set', function()
			os.getenv = function(var)
				if var == 'TMUX' then
					return '/tmp/tmux-501/default,12345,0'
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.is_true(detect.in_tmux())
		end)

		it('returns false when TMUX is not set', function()
			os.getenv = function(var)
				if var == 'TMUX' then
					return nil
				end
				if var == 'TMUX' then
					return nil
				end
				return orig_getenv(var)
			end
			assert.is_false(detect.in_tmux())
		end)
	end)
end)
