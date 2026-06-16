local preview_state = require('glimpse.preview_state')
local util = require('glimpse.util')

local M = {}

function M.same_path(lhs, rhs)
	if util.same_path then
		return util.same_path(lhs, rhs)
	end
	return lhs == rhs
end

function M.buffer_matches_path(buf, filepath)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end

	if M.same_path(vim.api.nvim_buf_get_name(buf), filepath) then
		return true
	end

	local ok, marker = pcall(function()
		return vim.b[buf]._glimpse_filepath
	end)
	return ok and marker ~= nil and M.same_path(marker, filepath)
end

function M.set_buffer_filepath(buf, filepath)
	pcall(function()
		vim.b[buf]._glimpse_filepath = filepath
	end)
end

function M.buffer_filetype(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end

	local ok, ft = pcall(function()
		return vim.bo[buf].filetype
	end)
	if ok then
		return ft
	end
	return nil
end

function M.fresh_buffer_name(filepath, buf)
	return string.format('glimpse://oil/image/%s/%d', vim.fn.sha256(filepath), buf)
end

function M.buffer_filepath(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end

	local candidates = {}
	local name = vim.api.nvim_buf_get_name(buf)
	if name ~= '' then
		candidates[#candidates + 1] = name
	end

	local ok, marker = pcall(function()
		return vim.b[buf]._glimpse_filepath
	end)
	if ok and type(marker) == 'string' and marker ~= '' then
		candidates[#candidates + 1] = marker
	end

	for _, candidate in ipairs(candidates) do
		local normalized = vim.fs.normalize(candidate)
		local stat = vim.uv.fs_stat(normalized)
		if stat and stat.type == 'file' then
			return normalized
		end
	end

	return nil
end

function M.should_open_fresh_buffer(filepath)
	local list_bufs = vim.api.nvim_list_bufs or function()
		return {}
	end

	for _, buf in ipairs(list_bufs()) do
		if M.buffer_matches_path(buf, filepath) then
			if not preview_state.is_marked(buf) then
				return false
			end
		end
	end

	return true
end

return M
