# glimpse.nvim

> Visualização de imagens e vídeos inline no Neovim via Kitty Graphics Protocol, com fallback para Sixel e painéis externos.

## Funcionalidades

- 🖼️ Renderização inline via **Kitty Graphics Protocol** (Kitty, Ghostty)
- 🎬 **Preview de vídeos** via thumbnail extraído com ffmpeg (cached)
- 🪟 Painel externo via **WezTerm CLI**, **kitten icat**, **iTerm imgcat**
- 🎨 Fallback **Sixel** para terminais sem suporte a Kitty Graphics
- 📂 Integração com **Oil.nvim** (`<leader>p` para preview, `;` para abrir em aba)
- 🔭 Integração com **Telescope** (previewer customizado para imagens e vídeos)
- 🌳 Integração com **NeoTree**
- ⚡ Cache de imagens convertidas + prefetch em background
- 🔄 Re-render automático ao redimensionar janela ou trocar de aba
- 📐 Contain resize (imagens sempre visíveis por completo)

## Requisitos

- Neovim >= 0.10
- [ImageMagick](https://imagemagick.org/) (`magick` CLI) - conversão e redimensionamento
- [ffmpeg](https://ffmpeg.org/) (opcional) - extração de thumbnails de vídeos
- Terminal com suporte a pelo menos um dos protocolos:
  - **Kitty Graphics** (recomendado): Kitty, Ghostty
  - **Terminal CLI**: WezTerm, iTerm2
  - **Sixel**: xterm, foot, mlterm, contour

## Instalação de dependências

### macOS (Homebrew)

```bash
brew install imagemagick ffmpeg
```

### Linux (apt)

```bash
sudo apt install imagemagick ffmpeg
```

### Linux (pacman)

```bash
sudo pacman -S imagemagick ffmpeg
```

### Verificar instalação

```bash
magick --version
```

## Uso

### Setup (lazy.nvim)

```lua
{
  'adriancmiranda/glimpse.nvim',
  ft = 'oil',
  opts = {
    strategy = 'auto',        -- 'auto' | 'inline' | 'pane'
    pane_position = 'right',  -- 'right' | 'bottom'
    pane_size = 40,           -- percentual do split/pane
    inline = {
      rerender_on_tab = true, -- re-renderiza ao voltar para aba com imagem
      close_with_q = true,    -- mapeia tecla para fechar buffer de imagem
    },
    keys = {
      preview = '<leader>p',  -- preview da imagem/video ao lado (Oil)
      open = ';',             -- abre imagem em aba ou video com player externo (Oil)
      close = 'q',            -- fecha buffer de imagem
    },
    debounce = {
      prefetch = 200,         -- ms antes de pre-converter ao mover cursor
      resize = 100,           -- ms antes de re-renderizar ao redimensionar
    },
    cell_size = {
      width = 20,             -- pixels estimados por coluna do terminal
      height = 40,            -- pixels estimados por linha do terminal
    },
    cache_dir = vim.fn.stdpath('cache') .. '/glimpse',
    loading_text = '  ⏳ Carregando...',
    formats = {               -- extensoes de imagem suportadas
      '.png', '.jpg', '.jpeg', '.gif', '.bmp',
      '.webp', '.avif', '.svg', '.pdf', '.pict',
    },
    video_formats = {         -- extensoes de video suportadas (requer ffmpeg)
      '.mp4', '.mkv', '.avi', '.mov',
      '.webm', '.flv', '.wmv', '.m4v',
    },
    video_open = nil,         -- comando ou funcao para abrir videos externamente
                              -- string: 'open' (macOS), 'xdg-open' (Linux)
                              -- function: fun(filepath) para logica customizada
                              -- nil: abre como buffer no Neovim
  integrations = {
    oil = true,             -- keymaps no Oil
    neotree = false,        -- keymaps no NeoTree
    telescope = true,       -- carrega via require('telescope').load_extension('glimpse')
  },
}
```

### Keymaps (Oil.nvim)

| Tecla | Ação |
|-------|------|
| `<leader>p` | Preview da imagem/vídeo ao lado (reutiliza janela) |
| `;` | Abre imagem em aba ou vídeo com player externo |
| `q` | Fecha buffer de imagem e janela vazia residual |

### Telescope

A forma recomendada e usar `buffer_previewer_maker` nos defaults do Telescope:

```lua
-- No setup do Telescope (defaults):
defaults = {
  buffer_previewer_maker = function(filepath, bufnr, opts)
    opts = opts or {}
    if require('glimpse.util').is_image(filepath) then
      require('glimpse.renderer').render(bufnr, filepath, { winid = vim.fn.bufwinid(bufnr) })
      return
    end
    require('telescope.previewers').buffer_previewer_maker(filepath, bufnr, opts)
  end,
}
```

> **NOTA**: NAO adicione `'glimpse'` ao `extensions_list` do Telescope.
> Isso forca o carregamento do Telescope no startup, aumentando o tempo de inicializacao em ~1300ms.

O previewer renderiza imagens inline no painel de preview e faz fallback ao previewer padrão para arquivos não-imagem. A troca entre arquivos é instantânea graças ao cleanup automático de placements e cache de conversões.

### API

```lua
local img = require('glimpse')

img.show(filepath)          -- exibe imagem ou thumbnail de vídeo
img.preview(filepath)       -- exibe reutilizando janela existente
img.close()                 -- fecha preview ativo
img.is_image(filepath)      -- verifica se é imagem suportada
img.is_video(filepath)      -- verifica se é vídeo suportado
img.is_previewable(filepath) -- verifica se é imagem ou vídeo
img.get_terminal()          -- retorna terminal detectado
```

## Terminais suportados

| Terminal | Estratégia | Método |
|----------|-----------|--------|
| Kitty | inline | Kitty Graphics + unicode placeholders |
| Ghostty | inline | Kitty Graphics + unicode placeholders |
| WezTerm | pane | `wezterm cli split-pane` + `wezterm imgcat` |
| iTerm2 | pane | `imgcat` |
| xterm/foot/mlterm | pane (sixel) | `magick ... sixel:-` via tmux |

### WezTerm + tmux

O `wezterm cli` precisa acessar o socket do WezTerm GUI. Dentro do tmux, a variavel
`WEZTERM_UNIX_SOCKET` pode ficar desatualizada se o WezTerm reiniciar.

Adicione ao `tmux.conf`:

```bash
set -ga update-environment WEZTERM_UNIX_SOCKET
```

Se o preview parar de funcionar, atualize manualmente:

```bash
# Encontrar o socket ativo
ls ~/.local/share/wezterm/gui-sock-*

# Exportar o correto
tmux set-environment WEZTERM_UNIX_SOCKET ~/.local/share/wezterm/gui-sock-<PID>
```

## Formatos suportados

**Imagens:** PNG, JPG, JPEG, GIF, BMP, WebP, AVIF, SVG, PDF, PICT

**Vídeos:** MP4, MKV, AVI, MOV, WebM, FLV, WMV, M4V (requer ffmpeg)

## Arquitetura

```bash
lua/
├── glimpse/
│   ├── init.lua              -- API pública: setup(), show(), preview(), close()
│   ├── detect.lua            -- Detecção de terminal
│   ├── kitty.lua             -- Protocolo Kitty Graphics (transmit, delete, prefetch)
│   ├── renderer.lua          -- Gerenciamento de placements e extmarks
│   ├── sixel.lua             -- Protocolo Sixel (fallback)
│   ├── thumbnail.lua         -- Extração de thumbnails de vídeo (ffmpeg)
│   ├── magickwand.lua        -- FFI bindings para libMagickWand
│   ├── util.lua              -- Detecção de formatos de imagem e vídeo
│   ├── strategy/
│   │   ├── inline.lua        -- Renderização inline + autocmds
│   │   └── pane.lua          -- Renderização via painel externo
│   └── integrations/
│       └── oil.lua           -- Integração Oil.nvim
└── telescope/
    └── _extensions/
        └── glimpse.lua       -- Extensão Telescope (previewer customizado)
```

## Créditos

- [snacks.nvim](https://github.com/folke/snacks.nvim) - inspiração para o protocolo de renderização
- [Yazi](https://github.com/sxyazi/yazi) - inspiração para otimizações de performance
- [Reddit post](https://www.reddit.com/r/neovim/comments/1e1txpz/) - conceito original de preview com WezTerm
