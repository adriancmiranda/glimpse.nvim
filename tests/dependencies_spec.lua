local archive = require('glimpse.archive')
local cert = require('glimpse.previewer.cert')
local font_data = require('glimpse.font')
local font_previewer = require('glimpse.previewer.font')
local key = require('glimpse.previewer.key')
local sqlite = require('glimpse.sqlite')

local function with_missing_executables(missing, fn)
	local original_executable = vim.fn.executable

	---@diagnostic disable-next-line: duplicate-set-field
	vim.fn.executable = function(name)
		if missing[name] then
			return 0
		end
		return original_executable(name)
	end

	local ok, err = pcall(fn)
	vim.fn.executable = original_executable

	if not ok then
		error(err)
	end
end

local function with_notify_capture(fn)
	local original_notify = vim.notify
	local messages = {}

	vim.notify = function(msg, level, opts)
		table.insert(messages, tostring(msg))
		return original_notify(msg, level, opts)
	end

	local ok, err = pcall(fn, messages)
	vim.notify = original_notify

	if not ok then
		error(err)
	end
end

describe('dependency fallbacks', function()
	it('returns an error when sqlite3 is unavailable', function()
		with_missing_executables({ sqlite3 = true }, function()
			local tables, err = sqlite.list('/tmp/example.db')
			assert.is_nil(tables)
			assert.equals('sqlite3 not found', err)
		end)
	end)

	it('returns an error when zipinfo is unavailable', function()
		with_missing_executables({ zipinfo = true }, function()
			local entries, err = archive.list_zip('/tmp/example.zip')
			assert.is_nil(entries)
			assert.equals('zipinfo not found', err)
		end)
	end)

	it('returns an error when fc-query is unavailable', function()
		with_missing_executables({ ['fc-query'] = true }, function()
			local info, err = font_data.query('/tmp/example.ttf')
			assert.is_nil(info)
			assert.equals('fc-query not found', err)
		end)
	end)

	it('falls back to the textual font preview when magick is unavailable', function()
		with_missing_executables({ magick = true }, function()
			local original_query = font_data.query
			local original_preview = font_previewer.preview
			local called = false

			font_data.query = function()
				return {
					family = 'Example Sans',
					style = 'Regular',
					weight = '400',
					slant = '0',
					width = '100',
				}
			end

			font_previewer.preview = function(filepath)
				called = filepath == '/tmp/example.ttf'
			end

			local ok, err = pcall(function()
				font_previewer.show('/tmp/example.ttf')
				assert.is_true(called)
			end)

			font_data.query = original_query
			font_previewer.preview = original_preview

			if not ok then
				error(err)
			end
		end)
	end)

	it('notifies and returns early when openssl is unavailable', function()
		with_missing_executables({ openssl = true }, function()
			with_notify_capture(function(messages)
				cert.show('/tmp/example.crt')
				assert.is_true(#messages > 0)
				assert.is_true(messages[1]:find('openssl not found', 1, true) ~= nil)
			end)
		end)
	end)

	it('notifies and returns early when ssh-keygen is unavailable', function()
		local key_file = vim.fn.tempname() .. '.pub'
		vim.fn.writefile({ 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtest user@example' }, key_file)

		with_missing_executables({ ['ssh-keygen'] = true, gpg = true }, function()
			with_notify_capture(function(messages)
				key.show(key_file)
				assert.is_true(#messages > 0)
				assert.is_true(messages[1]:find('ssh-keygen not found', 1, true) ~= nil)
			end)
		end)
	end)
end)
