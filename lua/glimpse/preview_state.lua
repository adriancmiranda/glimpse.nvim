local M = {}
local PREVIEW_MARK = '_glimpse_preview'

function M.mark(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	pcall(function()
		vim.b[buf][PREVIEW_MARK] = true
	end)
end

function M.unmark(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	pcall(function()
		vim.b[buf][PREVIEW_MARK] = nil
	end)
end

function M.is_marked(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end

	local ok, value = pcall(function()
		return vim.b[buf][PREVIEW_MARK]
	end)
	return ok and value == true
end

return M
