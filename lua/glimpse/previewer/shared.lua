--- Shared formatting utilities for text previewers.
local M = {}

--- Insert a filename header and separator at the top of a lines table.
--- @param filepath string
--- @param lines string[]
function M.header_lines(filepath, lines)
	local header = string.format('  %s', vim.fn.fnamemodify(filepath, ':t'))
	table.insert(lines, 1, header)
	table.insert(lines, 2, string.rep('─', #header + 4))
end

--- Return a copy of highlights with every row shifted by offset.
--- @param highlights table
--- @param offset integer
--- @return table
function M.offset_highlights(highlights, offset)
	local shifted = {}
	for _, hl in ipairs(highlights or {}) do
		shifted[#shifted + 1] = { hl[1] + offset, hl[2], hl[3], hl[4] }
	end
	return shifted
end

return M
