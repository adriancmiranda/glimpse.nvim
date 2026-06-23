local M = {}

local augroup_name = 'GlimpseAutoRefresh'

local function is_same_file(left, right)
	local util = require('glimpse.util')
	return util.same_path(left, right)
end

--- Register a save hook for a source buffer.
--- The callback only runs when the preview is still active.
--- @param buf number
--- @param filepath string
--- @param is_active fun(): boolean
--- @param refresh fun()
function M.register(buf, filepath, is_active, refresh)
	local glimpse = require('glimpse')
	if not glimpse.get_config().auto_refresh then
		return
	end
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local ok, current_name = pcall(vim.api.nvim_buf_get_name, buf)
	if not ok then
		return
	end
	if current_name == '' or not is_same_file(current_name, filepath) then
		return
	end

	local group = vim.api.nvim_create_augroup(augroup_name, { clear = false })
	pcall(vim.api.nvim_clear_autocmds, { group = group, buffer = buf })

	vim.api.nvim_create_autocmd('BufWritePost', {
		group = group,
		buffer = buf,
		callback = function()
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end

			local ok_current, buf_name = pcall(vim.api.nvim_buf_get_name, buf)
			if not ok_current then
				return
			end
			if buf_name == '' or not is_same_file(buf_name, filepath) then
				return
			end

			if is_active and not is_active() then
				return
			end

			refresh()
		end,
	})
end

return M
