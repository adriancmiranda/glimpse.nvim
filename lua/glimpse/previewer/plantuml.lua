--- Previewer for PlantUML diagrams (.puml, .pu, .wsd, …) via user-configured pipeline.
--- Requires a `pipelines.plantuml` entry in the glimpse config with at least one step.
---
--- Default config (ships out of the box when plantuml is installed):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       plantuml = {
---         steps = {
---           {
---             command = 'sh',
---             args = function(input, output)
---               return { '-c', 'plantuml -tpng -pipe < "$1" > "$2"', '--', input, output }
---             end,
---           },
---         },
---       },
---     },
---   })
--- <
local M = {}

local pipeline = require('glimpse.pipeline')
local pp = require('glimpse.pipeline_previewer')
local OPTS = { label = 'plantuml' }

local function _get_cfg(filepath)
	local cfg = require('glimpse').get_config()
	return pipeline.resolve_config(cfg.pipelines, 'plantuml', filepath)
end

--- Show the diagram (full view).
--- @param filepath string
--- @param source_win? number
function M.show(filepath, source_win)
	local pipeline_cfg = _get_cfg(filepath)
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for plantuml preview', vim.log.levels.WARN)
		return
	end
	pp.show(pipeline_cfg, filepath, source_win, OPTS)
end

--- Preview the diagram in the current preview target.
--- @param filepath string
--- @param source_win? number
function M.preview(filepath, source_win)
	local pipeline_cfg = _get_cfg(filepath)
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for plantuml preview', vim.log.levels.WARN)
		return
	end
	pp.preview(pipeline_cfg, filepath, source_win, OPTS)
end

--- Cancel any in-flight render for the given window.
--- @param winid? number Defaults to current window
function M.cancel(winid)
	pp.cancel(winid)
end

return M
