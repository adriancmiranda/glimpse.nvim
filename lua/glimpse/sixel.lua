--- Implementação do protocolo Sixel para renderização de imagens.
--- @see spec https://en.wikipedia.org/wiki/Sixel
--- Usado como fallback para terminais sem suporte a Kitty Graphics.
--- Requer ImageMagick com suporte a sixel output.

local M = {}

--- Verifica se o terminal suporta Sixel.
--- @return boolean
function M.supported()
	-- Verifica via TERM ou DA1 response (simplificado: checa terminais conhecidos)
	local term = os.getenv('TERM') or ''
	local term_program = os.getenv('TERM_PROGRAM') or ''
	local sixel_terms = {
		'xterm%-256color',
		'foot',
		'mlterm',
		'contour',
		'wezterm',
	}
	for _, pattern in ipairs(sixel_terms) do
		if term:match(pattern) or term_program:lower():match(pattern) then
			return true
		end
	end
	return false
end

--- Gera comando para exibir imagem via Sixel num painel tmux.
--- @param filepath string
--- @param opts? { width?: number, height?: number }
--- @return string
function M.get_tmux_cmd(filepath, opts)
	opts = opts or {}
	local width = (opts.width or 40) * 20
	local height = (opts.height or 20) * 40
	return string.format(
		'tmux split-window -h -l 40%% \'magick "%s" -resize %dx%d\\> sixel:- ; read -n 1\'',
		filepath,
		width,
		height
	)
end

--- Exibe imagem via Sixel num painel tmux.
--- @param filepath string
--- @param opts? { width?: number, height?: number }
function M.show_pane(filepath, opts)
	local cmd = M.get_tmux_cmd(filepath, opts)
	vim.fn.jobstart(cmd, { detach = true })
end

return M
