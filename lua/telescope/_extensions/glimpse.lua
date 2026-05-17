--- Extensão Telescope para glimpse.nvim
--- Uso: require('telescope').load_extension('glimpse')
--- NOTA: NÃO adicione 'glimpse' ao extensions_list do Telescope.
--- Use buffer_previewer_maker nos defaults para preview automático de imagens.

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
	return {}
end

return telescope.register_extension({
	setup = function() end,
	exports = {
		previewer = function()
			local renderer = require('glimpse.renderer')
			local util = require('glimpse.util')
			local previewers = require('telescope.previewers')
			local from_entry = require('telescope.from_entry')
			local conf = require('telescope.config').values

			return previewers.new_buffer_previewer({
				title = 'Glimpse',
				define_preview = function(self, entry)
					local filepath = from_entry.path(entry, false, false)
					if not filepath or not util.is_previewable(filepath) then
						conf.buffer_previewer_maker(filepath, self.state.bufnr, {
							bufname = self.state.bufname,
						})
						return
					end
					local target = require('glimpse')._resolve_filepath(filepath)
					if target then
						renderer.render(self.state.bufnr, target, { winid = self.state.winid })
					end
				end,
				teardown = function(self)
					if self.state and self.state.bufnr then
						renderer.close(self.state.bufnr)
					end
				end,
			})
		end,
	},
})
