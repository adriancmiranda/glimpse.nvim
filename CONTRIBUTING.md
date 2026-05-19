# Contribuindo

## Ambiente de desenvolvimento

### Dependencias obrigatorias

- **Neovim** >= 0.10
- **ImageMagick** >= 7 (`magick` CLI)

### Dependencias opcionais

| Dependencia | Uso |
|-------------|-----|
| ffmpeg | Extracao de thumbnails de video |
| tmux >= 3.4 | Passthrough de escape sequences (Kitty Graphics via tmux) |
| `kitten` | Incluso no Kitty |
| `wezterm` CLI | Painel externo no WezTerm |
| `imgcat` | Incluso no iTerm2 shell integration |

### Configuracao do tmux (opcional)

```bash
# Necessario para Kitty Graphics via tmux
set -gq allow-passthrough on
set -g visual-activity off

# Propagar variaveis de ambiente para novas sessoes
set -ga update-environment WEZTERM_UNIX_SOCKET
```

## Estrutura do codigo

```bash
lua/glimpse/
├── init.lua              -- API publica: setup(), show(), preview(), close()
├── detect.lua            -- Deteccao de terminal via tmux client_termname
├── kitty.lua             -- Protocolo Kitty Graphics (transmit, delete, prefetch)
├── renderer.lua          -- Gerenciamento de placements e extmarks
├── sixel.lua             -- Protocolo Sixel (fallback)
├── thumbnail.lua         -- Extracao de thumbnails de video (ffmpeg, async)
├── magickwand.lua        -- Interface com ImageMagick para conversao
├── util.lua              -- Deteccao de formatos de imagem e video
├── strategy/
│   ├── inline.lua        -- Renderizacao inline + autocmds
│   └── pane.lua          -- Renderizacao via painel externo (WezTerm, iTerm2)
└── integrations/
    └── oil.lua           -- Integracao Oil.nvim (preview, open, prefetch)

lua/telescope/
└── _extensions/
    └── glimpse.lua       -- Extensao Telescope (previewer customizado)
```

## Protocolos de imagem

### Kitty Graphics Protocol

- Transmissao via `t=f` (file path) - terminal le do disco
- Unicode placeholders (`U=1`) - caractere U+10EEEE com diacriticos para row/col
- Image ID codificado no foreground color do highlight (`nvim_set_hl`)
- Dentro do tmux: escape sequences envolvidas em `\ePtmux;...\e\\`

### Sixel

- Conversao via `magick ... sixel:-`
- Exibido em painel tmux (nao inline)

## Convencoes

- Comentarios em portugues brasileiro
- Funcoes publicas em camelCase
- Funcoes privadas com `_` prefixo ou `local`
- Type annotations via `@param`, `@return`, `@class`
- Formatacao via [StyLua](https://github.com/JohnnyMorganz/StyLua) (`.stylua.toml`)
- Linting via [luacheck](https://github.com/mpeterv/luacheck) (`.luacheckrc`)

## Ferramentas

### Formatacao

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

# Testar renderizacao de imagem
:lua require('glimpse').show('/path/to/image.png')

# Testar preview de video (async thumbnail)
:lua require('glimpse').preview('/path/to/video.mp4')

# Testar prefetch
:lua require('glimpse.kitty').prefetch('/path/to/image.png', { width = 40, height = 30 })

# Testar socket do WezTerm
:lua print(require('glimpse.strategy.pane')._find_wezterm_socket())
```

## Limitacoes conhecidas

- **Latencia no primeiro load**: `magick` leva ~700ms-2s para converter imagens grandes. Cache resolve para acessos subsequentes.
- **Latencia do terminal**: apos transmitir, o terminal leva ~200-500ms para renderizar. Fora do nosso controle.
- **WezTerm**: nao suporta unicode placeholders - usa painel externo via `wezterm cli`.
- **WezTerm + tmux**: requer `WEZTERM_UNIX_SOCKET` propagado via `update-environment`.
- **Video thumbnails**: primeira extracao e sincrona (~500ms). Subsequentes usam cache.
