--- Previewer for 3D model files via user-configured pipeline.
--- Requires a `pipelines.model` entry with `steps` or `previewers`.
---
--- Static thumbnail example (f3d):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       model = {
---       steps = {
---         {
---           command = 'f3d',
---           args = function(input, output)
---             return { input, '--output', output, '--config=thumbnail' }
---           end,
---         },
---       },
---       },
---     },
---   })
--- <
---
--- Turntable animation example (f3d sequence, no assembler):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       model = {
---       steps = {
---         {
---           command = 'f3d',
---           type = 'sequence',
---           frames = 36,
---           args = function(input, output, frame)
---             return { input, '--output', output, '--config=thumbnail',
---                      '--camera-azimuth-angle=' .. (frame * 10) }
---           end,
---         },
---       },
---       renderer = { fps = 12 },
---       },
---     },
---   })
--- <
---
--- Turntable-to-GIF example (f3d + ffmpeg assembly):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       model = {
---       steps = {
---         {
---           command = 'f3d',
---           type = 'sequence',
---           frames = 36,
---           args = function(input, output, frame)
---             return { input, '--output', output, '--config=thumbnail',
---                      '--camera-azimuth-angle=' .. (frame * 10) }
---           end,
---         },
---         {
---           command = 'ffmpeg',
---           output_ext = '.gif',
---           args = function(frames_dir, output, fps)
---             return { '-y', '-framerate', tostring(fps),
---                      '-i', frames_dir .. '/frame_%04d.png',
---                      output }
---           end,
---         },
---       },
---       renderer = { fps = 12 },
---       },
---     },
---   })
--- <
local M = {}

local pipeline = require('glimpse.pipeline')
local pp = require('glimpse.pipeline_previewer')
local OPTS = { label = 'model' }

local function _get_cfg(filepath)
	local cfg = require('glimpse').get_config()
	return pipeline.resolve_config(cfg.pipelines, 'model', filepath)
end

local function _normalize_opts(opts)
	if type(opts) ~= 'table' then
		return opts, OPTS
	end

	local source_win = opts.window
	local pp_opts = vim.tbl_extend('force', OPTS, opts)
	pp_opts.window = nil
	return source_win, pp_opts
end

--- Show the model (full view).
--- @param filepath string
--- @param source_win? number|{window?: number}
function M.show(filepath, source_win)
	local pp_opts
	source_win, pp_opts = _normalize_opts(source_win)
	local pipeline_cfg = _get_cfg(filepath)
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for model preview', vim.log.levels.WARN)
		return
	end
	pp.show(pipeline_cfg, filepath, source_win, pp_opts)
end

--- Preview the model in the current preview target.
--- @param filepath string
--- @param source_win? number|{window?: number}
function M.preview(filepath, source_win)
	local pp_opts
	source_win, pp_opts = _normalize_opts(source_win)
	local pipeline_cfg = _get_cfg(filepath)
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for model preview', vim.log.levels.WARN)
		return
	end
	pp.preview(pipeline_cfg, filepath, source_win, pp_opts)
end

--- Cancel any in-flight render for the given window.
--- @param winid? number Defaults to current window
function M.cancel(winid)
	pp.cancel(winid)
end

return M
