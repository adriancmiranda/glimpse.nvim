# Contribuindo para o glimpse.nvim

## Ambiente de desenvolvimento

### Dependências obrigatórias

- **Neovim** >= 0.10
- **ImageMagick** >= 7 (`magick` CLI)

### Dependências opcionais

| Dependência | Uso |
|-------------|-----|
| ffmpeg | Extração de thumbnails de video |
| tmux >= 3.4 | Passthrough de escape sequences (Kitty Graphics via tmux) |
| `kitten` | Incluso no Kitty |
| `wezterm` CLI | Painel externo no WezTerm |
| `imgcat` | Incluso no iTerm2 shell integration |

### Configuração do tmux (opcional)

```bash
# Necessário para Kitty Graphics via tmux
set -gq allow-passthrough on
set -g visual-activity off

# Propagar variáveis de ambiente para novas sessoes
set -ga update-environment WEZTERM_UNIX_SOCKET
```

## Estrutura do código

```bash
lua/glimpse/
├── init.lua              -- API pública: setup(), show(), preview(), close()
├── detect.lua            -- Detecção de terminal via tmux client_termname
├── kitty.lua             -- Protocolo Kitty Graphics (transmit, delete, prefetch)
├── renderer.lua          -- Gerenciamento de placements e extmarks
├── sixel.lua             -- Protocolo Sixel (fallback)
├── thumbnail.lua         -- Extração de thumbnails de video (ffmpeg, async)
├── magickwand.lua        -- Interface com ImageMagick para conversão
├── util.lua              -- Detecção de formatos de imagem e video
├── strategy/
│   ├── inline.lua        -- Renderização inline + autocmds
│   └── pane.lua          -- Renderização via painel externo (WezTerm, iTerm2)
└── integrations/
    └── oil.lua           -- Integração Oil.nvim (preview, open, prefetch)

lua/telescope/
└── _extensions/
    └── glimpse.lua       -- Extensão Telescope (previewer customizado)
```

## Protocolos de imagem

### Kitty Graphics Protocol

- Transmissão via `t=f` (file path) - terminal le do disco
- Unicode placeholders (`U=1`) - caractere U+10EEEE com diacríticos para row/col
- Image ID codificado no foreground color do highlight (`nvim_set_hl`)
- Dentro do tmux: escape sequences envolvidas em `\ePtmux;...\e\\`

### Sixel

- Conversão via `magick ... sixel:-`
- Exibido em painel tmux (não inline)

## Convenções

- Comentários em portugues brasileiro
- Funções públicas em camelCase
- Funções privadas com `_` prefixo ou `local`
- Type annotations via `@param`, `@return`, `@class`
- Formatação via [StyLua](https://github.com/JohnnyMorganz/StyLua) (`.stylua.toml`)
- Linting via [luacheck](https://github.com/mpeterv/luacheck) (`.luacheckrc`)

## Ferramentas

### Formatação

```bash
stylua lua/ tests/
```

### Linting

```bash
luacheck lua/ tests/
```

### Testes

```bash
make test
```

Requer [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) e `ffmpeg` instalados.

### Benchmark

```bash
make bench
```

## Testes manuais

```bash
# Testar deteccao de terminal
:lua print(require('glimpse.detect').get_terminal())

# Testar renderização de imagem
:lua require('glimpse').show('/path/to/image.png')

# Testar preview de video (async thumbnail)
:lua require('glimpse').preview('/path/to/video.mp4')

# Testar prefetch
:lua require('glimpse.kitty').prefetch('/path/to/image.png', { width = 40, height = 30 })

# Testar socket do WezTerm
:lua print(require('glimpse.strategy.pane')._find_wezterm_socket())
```

## Limitações conhecidas

- **Latência no primeiro load**: `magick` leva ~700ms-2s para converter imagens grandes. Cache resolve para acessos subsequentes.
- **Latência do terminal**: após transmitir, o terminal leva ~200-500ms para renderizar. Fora do nosso controle.
- **WezTerm**: não suporta unicode placeholders - usa painel externo via `wezterm cli`.
- **WezTerm + tmux**: requer `WEZTERM_UNIX_SOCKET` propagado via `update-environment`.
- **Video thumbnails**: primeira extração é síncrona (~500ms). Subsequentes usam cache.
