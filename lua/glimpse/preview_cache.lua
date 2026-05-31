local M = {}

local cache = {}

local unpack_fn = unpack

local function pack(...)
	return { n = select('#', ...), ... }
end

local function _key(filepath, tag)
	local stat = vim.uv.fs_stat(filepath)
	if not stat then
		return nil
	end

	local mtime = stat.mtime or {}
	return table.concat({
		tag or 'default',
		filepath,
		stat.size or 0,
		mtime.sec or 0,
		mtime.nsec or 0,
	}, ':')
end

--- Memoize a preview computation by file identity and optional tag.
--- @param filepath string
--- @param tag? string
--- @param producer fun():any
--- @return any ...
function M.memoize(filepath, tag, producer)
	local cache_key = _key(filepath, tag)
	if not cache_key then
		return producer()
	end

	local cached = cache[cache_key]
	if cached then
		return unpack_fn(cached, 1, cached.n)
	end

	local result = pack(producer())
	if result[1] ~= nil then
		cache[cache_key] = result
	end

	return unpack_fn(result, 1, result.n)
end

function M.clear()
	cache = {}
end

return M
