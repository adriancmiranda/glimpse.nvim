local markdown = require('glimpse.previewer.markdown')

describe('markdown previewer', function()
	it('sizes and displays the float before opening the terminal', function()
		local config = require('glimpse').get_config()
		local saved_tools = vim.deepcopy(config.markdown.tools)
		local saved_float = vim.deepcopy(config.float)
		local filepath = vim.fn.tempname() .. '.md'
		local lines = {}
		for index = 1, 12 do
			lines[index] = 'line ' .. index
		end
		vim.fn.writefile(lines, filepath)
		config.markdown.tools = { { 'cat', '{input}' } }
		config.float = {}

		local original_open_term = vim.api.nvim_open_term
		local displayed_before_terminal = false
		local terminal_buf
		vim.api.nvim_open_term = function(buf, opts)
			terminal_buf = buf
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					displayed_before_terminal = true
					break
				end
			end
			return original_open_term(buf, opts)
		end

		local ok, err = pcall(markdown.preview, filepath)
		vim.api.nvim_open_term = original_open_term
		config.markdown.tools = saved_tools
		config.float = saved_float
		vim.fn.delete(filepath)

		local win = vim.api.nvim_get_current_win()
		if ok then
			assert.is_true(displayed_before_terminal)
			assert.equals(12, vim.api.nvim_win_get_config(win).height)
		end
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= '' then
			vim.api.nvim_win_close(win, true)
		end
		if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
			vim.api.nvim_buf_delete(terminal_buf, { force = true })
		end
		if not ok then
			error(err)
		end
	end)

	it('accounts for terminal rows introduced by wrapped lines', function()
		local config = require('glimpse').get_config()
		local saved_tools = vim.deepcopy(config.markdown.tools)
		local saved_float = vim.deepcopy(config.float)
		local filepath = vim.fn.tempname() .. '.md'
		vim.fn.writefile({ string.rep('x', 130), 'short' }, filepath)
		config.markdown.tools = { { 'cat', '{input}' } }
		config.float = { markdown = { width = 40 } }

		local ok, err = pcall(markdown.preview, filepath)
		config.markdown.tools = saved_tools
		config.float = saved_float
		vim.fn.delete(filepath)

		local win = vim.api.nvim_get_current_win()
		if ok then
			assert.equals(5, vim.api.nvim_win_get_config(win).height)
		end
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= '' then
			local buf = vim.api.nvim_win_get_buf(win)
			vim.api.nvim_win_close(win, true)
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
		if not ok then
			error(err)
		end
	end)

	it('passes the resolved float width to the Markdown renderer', function()
		local config = require('glimpse').get_config()
		local saved_tools = vim.deepcopy(config.markdown.tools)
		local saved_float = vim.deepcopy(config.float)
		local original_system = vim.fn.system
		local command
		config.markdown.tools = { { 'cat', 'ansi:{width}', '{input}' } }
		config.float = { markdown = { width = 47 } }
		vim.fn.system = function(cmd)
			command = cmd
			return 'rendered'
		end

		local ok, err = pcall(markdown.preview, '/tmp/README.md')
		vim.fn.system = original_system
		config.markdown.tools = saved_tools
		config.float = saved_float

		local win = vim.api.nvim_get_current_win()
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= '' then
			local buf = vim.api.nvim_win_get_buf(win)
			vim.api.nvim_win_close(win, true)
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
		if not ok then
			error(err)
		end

		assert.equals('ansi:47', command[2])
		assert.equals('/tmp/README.md', command[3])
	end)

	it('tries the next Markdown renderer when the first one fails', function()
		local config = require('glimpse').get_config()
		local saved_tools = vim.deepcopy(config.markdown.tools)
		local filepath = vim.fn.tempname() .. '.md'
		vim.fn.writefile({ '# fallback' }, filepath)
		config.markdown.tools = {
			{ 'sh', '-c', 'exit 1' },
			{ 'cat', '{input}' },
		}

		local lines, _, err = markdown.preview_data(filepath, 40)

		config.markdown.tools = saved_tools
		vim.fn.delete(filepath)

		assert.is_nil(err)
		assert.equals('# fallback', lines[1])
	end)

	it('memoizes markdown previews by width', function()
		local config = require('glimpse').get_config()
		local saved_tools = vim.deepcopy(config.markdown.tools)
		local saved_float = vim.deepcopy(config.float)
		local filepath = vim.fn.tempname() .. '.md'
		vim.fn.writefile({ '# title' }, filepath)
		config.markdown.tools = { { 'cat', '{width}', '{input}' } }
		config.float = {}

		local original_system = vim.fn.system
		local calls = {}
		vim.fn.system = function(cmd)
			calls[#calls + 1] = vim.deepcopy(cmd)
			return 'rendered'
		end

		local first = markdown.preview_data(filepath, 40)
		local second = markdown.preview_data(filepath, 40)
		local third = markdown.preview_data(filepath, 80)

		vim.fn.system = original_system
		config.markdown.tools = saved_tools
		config.float = saved_float
		vim.fn.delete(filepath)

		assert.equals(2, #calls)
		assert.equals('40', calls[1][2])
		assert.equals('80', calls[2][2])
		assert.same(first, second)
		assert.is_not_nil(third)
	end)

	it('rerenders markdown floats when the editor width changes', function()
		local config = require('glimpse').get_config()
		local saved_tools = vim.deepcopy(config.markdown.tools)
		local saved_float = vim.deepcopy(config.float)
		local original_columns = vim.o.columns
		local original_lines = vim.o.lines
		local original_system = vim.fn.system
		local filepath = vim.fn.tempname() .. '.md'
		vim.fn.writefile({ '# title' }, filepath)
		vim.o.columns = 100
		vim.o.lines = 40
		config.markdown.tools = { { 'cat', 'width={width}', '{input}' } }
		config.float = { markdown = { width = 'auto' } }

		local widths = {}
		vim.fn.system = function(cmd)
			widths[#widths + 1] = cmd[2]
			return 'rendered ' .. cmd[2]
		end

		local ok, err = pcall(markdown.preview, filepath)
		vim.o.columns = 80
		vim.api.nvim_exec_autocmds('WinResized', {})

		local win = vim.api.nvim_get_current_win()
		local win_config = vim.api.nvim_win_get_config(win)
		local buf = vim.api.nvim_win_get_buf(win)

		vim.fn.system = original_system
		config.markdown.tools = saved_tools
		config.float = saved_float
		vim.o.columns = original_columns
		vim.o.lines = original_lines
		vim.fn.delete(filepath)

		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= '' then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		if not ok then
			error(err)
		end

		assert.equals(2, #widths)
		assert.equals('width=96', widths[1])
		assert.equals('width=76', widths[2])
		assert.equals(76, win_config.width)
	end)
end)
