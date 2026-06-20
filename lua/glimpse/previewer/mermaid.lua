--- Previewer for Mermaid diagrams (.mmd, .mermaid) via user-configured pipeline.
--- Requires a `pipelines.mermaid` entry in the glimpse config with at least one step.
---
--- Default config (ships out of the box when mmdc is installed):
--- >lua
---   require('glimpse').setup({
---     pipelines = {
---       mermaid = {
---         steps = {
---           {
---             command = 'mmdc',
---             args = function(input, output)
---               return { '-i', input, '-o', output }
---             end,
---           },
---         },
---       },
---     },
---   })
--- <
local M = {}

local pp = require('glimpse.pipeline_previewer')
local OPTS = { label = 'mermaid' }

local function _get_cfg()
	local cfg = require('glimpse').get_config()
	return cfg.pipelines and cfg.pipelines.mermaid
end

--- Show the diagram (full view).
--- @param filepath string
--- @param source_win? number
function M.show(filepath, source_win)
	local pipeline_cfg = _get_cfg()
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for mermaid preview', vim.log.levels.WARN)
		return
	end
	pp.show(pipeline_cfg, filepath, source_win, OPTS)
end

--- Preview the diagram in the current preview target.
--- @param filepath string
--- @param source_win? number
function M.preview(filepath, source_win)
	local pipeline_cfg = _get_cfg()
	if not pipeline_cfg then
		vim.notify('[glimpse] no pipeline config for mermaid preview', vim.log.levels.WARN)
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
