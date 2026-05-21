--- @see credits https://github.com/folke/snacks.nvim (snacks.image) - inspiração original
--- Renderização inline via Kitty Graphics Protocol (implementação própria).

local renderer = require('glimpse.renderer')

local M = {}

--- Exibe imagem num vsplit reutilizando janela existente.
--- @param filepath string
function M.preview(filepath)
	local oil_win = vim.api.nvim_get_current_win()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= oil_win and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'image' then
			local buf = vim.api.nvim_win_get_buf(win)
			renderer.render(buf, filepath)
			return
		end
	end
	-- Cria vsplit com buffer novo
	vim.cmd('vsplit')
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	renderer.render(buf, filepath)
	vim.api.nvim_set_current_win(oil_win)
end

--- Exibe imagem no buffer atual.
--- @param filepath string
function M.show(filepath)
	local buf = vim.api.nvim_get_current_buf()
	renderer.render(buf, filepath)
end

--- Fecha e limpa o buffer de imagem.
--- @param buf number
function M.close(buf)
	renderer.close(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

--- Registra autocmds para re-render e keymap q.
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup('ImagePreviewInline', { clear = true })
	local util = require('glimpse.util')

	-- Intercepta abertura de arquivos de imagem, fonte e archive
	vim.api.nvim_create_autocmd('BufReadPost', {
		group = group,
		callback = function(info)
			local filepath = vim.api.nvim_buf_get_name(info.buf)
			if util.is_image(filepath) then
				renderer.render(info.buf, filepath, { listed = true })
			elseif util.is_font(filepath) then
				require('glimpse.previewer.font').show(filepath)
			elseif util.is_archive(filepath) then
				require('glimpse.previewer.archive').show(filepath)
			end
		end,
	})

	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'image',
		group = group,
		callback = function(info)
			vim.keymap.set('n', require('glimpse').get_config().keys.close, function()
				local wins = vim.api.nvim_list_wins()
				M.close(info.buf)
				if #wins > 1 then
					local cur_name = vim.api.nvim_buf_get_name(0)
					if cur_name == '' and not vim.bo.modified then
						vim.cmd('quit')
					end
				end
			end, { buffer = info.buf, silent = true })
		end,
	})

	vim.api.nvim_create_autocmd('BufEnter', {
		group = group,
		callback = function(info)
			if vim.bo[info.buf].filetype == 'image' then
				if not vim.b[info.buf]._image_rendered then
					vim.b[info.buf]._image_rendered = true
					if not renderer.has_placement(info.buf) then
						local filepath = vim.api.nvim_buf_get_name(info.buf)
						if filepath ~= '' then
							renderer.register(info.buf, filepath)
						end
					end
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd('TabEnter', {
		group = group,
		callback = function()
			vim.schedule(function()
				local buf = vim.api.nvim_get_current_buf()
				if vim.bo[buf].filetype == 'image' and renderer.has_placement(buf) then
					renderer.rerender(buf)
				end
			end)
		end,
	})

	local resize_timer = nil
	vim.api.nvim_create_autocmd('WinResized', {
		group = group,
		callback = function()
			if resize_timer then
				resize_timer:stop()
			end
			resize_timer = vim.defer_fn(function()
				resize_timer = nil
				for _, win in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_is_valid(win) then
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].filetype == 'image' and renderer.has_placement(buf) then
							renderer.rerender(buf)
						end
					end
				end
			end, require('glimpse').get_config().debounce.resize)
		end,
	})
end

return M
