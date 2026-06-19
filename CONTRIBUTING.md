<!-- markdownlint-disable MD013 MD060 MD025 -->

# Contributing to glimpse.nvim

## Development environment

### Required dependencies

- **Neovim** >= 0.10
- **ImageMagick** >= 7 (`magick` CLI)

### Optional dependencies

| Dependency | Usage |
|------------|-------|
| openssl | Certificate metadata extraction |
| ffmpeg | Video thumbnail extraction and inline animation |
| f3d | 3D model thumbnails and turntable frames |
| ghostscript | PDF rendering via ImageMagick |
| tmux >= 3.4 | Escape sequence passthrough (Kitty Graphics via tmux) |
| `kitten` | Included with Kitty |
| `wezterm` CLI | External pane in WezTerm |
| `imgcat` | Included with iTerm2 shell integration |

### tmux configuration (optional)

```bash
# Required for Kitty Graphics via tmux
set -gq allow-passthrough on
set -g visual-activity off

# Propagate environment variables to new sessions
set -ga update-environment WEZTERM_UNIX_SOCKET
```

## Code structure

```bash
lua/glimpse/
├── init.lua              -- Public API: setup(), show(), preview(), close(), helpers
├── detect.lua            -- Terminal detection via tmux client_termname
├── kitty.lua             -- Kitty Graphics Protocol (transmit, delete, prefetch)
├── renderer.lua          -- Placement management and extmarks
├── sixel.lua             -- Sixel protocol (fallback)
├── thumbnail.lua         -- Video thumbnail extraction (ffmpeg, async)
├── magickwand.lua        -- ImageMagick interface for conversion
├── pipeline.lua          -- Steps-based conversion pipeline (run_steps, run_sequence)
├── util.lua              -- Image, video, model and certificate format detection
├── archive.lua           -- Archive listing and suspicious path detection
├── font.lua              -- Font metadata extraction and rendering
├── sqlite.lua            -- SQLite schema preview
├── safety.lua            -- File validation and safety checks
├── frames/
│   ├── init.lua          -- Router: selects strategy from config (auto/batch/poll/pipe)
│   ├── auto.lua          -- Selects poll when ffmpeg is available
│   ├── batch.lua         -- Low-res preview immediately, full-res all at once when done
│   ├── poll.lua          -- Progressive delivery as ffmpeg writes files to temp dir
│   └── pipe.lua          -- Binary stream via image2pipe (not yet implemented)
├── previewer/
│   ├── archive.lua       -- Archive previewer
│   ├── cert.lua          -- X.509 certificate previewer
│   ├── binary.lua        -- Binary previewer (file + hexdump)
│   ├── font.lua          -- Font previewer
│   ├── image.lua         -- Inline image previewer
│   ├── key.lua           -- GPG/SSH key previewer
│   ├── model.lua         -- 3D model previewer via conversion pipeline (f3d)
│   ├── sqlite.lua        -- SQLite previewer
│   └── video.lua         -- Inline animation (Kitty/Ghostty) or thumbnail fallback
├── strategy/
│   ├── inline.lua        -- Inline rendering + autocmds
│   └── pane.lua          -- External pane rendering (WezTerm, iTerm2)
└── integrations/
    ├── oil.lua           -- Oil.nvim integration (preview, open, prefetch)
    ├── neotree.lua       -- Neo-tree integration (auto-preview, cleanup)
    └── telescope.lua     -- Telescope integration (scoped picker preview)
```

## Image protocols

### Kitty Graphics Protocol

- Transmission via `t=f` (file path) - terminal reads from disk
- Unicode placeholders (`U=1`) - character U+10EEEE with diacritics for row/col
- Image ID encoded in foreground color of highlight (`nvim_set_hl`)
- Inside tmux: escape sequences wrapped in `\ePtmux;...\e\\`

### Sixel

- Conversion via `magick ... sixel:-`
- Displayed in tmux pane (not inline)

## Conventions

- Comments in English
- Public functions in camelCase
- Private functions with `_` prefix or `local`
- Type annotations via `@param`, `@return`, `@class`
- Formatting via [StyLua](https://github.com/JohnnyMorganz/StyLua) (`.stylua.toml`)
- Linting via [luacheck](https://github.com/mpeterv/luacheck) (`.luacheckrc`)

## Tools

### Formatting

```bash
stylua lua/ tests/
```

### Linting

```bash
luacheck lua/ tests/
```

### Tests

```bash
make test
```

Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and `ffmpeg` installed.

### Benchmark

```bash
make bench
```

## Manual testing

```vim
" Test terminal detection
:lua print(require('glimpse.detect').get_terminal())

" Test image rendering
:lua require('glimpse').show('/path/to/image.png')

" Test video preview (inline animation on Kitty/Ghostty, thumbnail otherwise)
:lua require('glimpse').preview('/path/to/video.mp4')

" Test inline animation directly
:lua require('glimpse.previewer.video').show('/path/to/video.mp4')

" Test prefetch
:lua require('glimpse.kitty').prefetch('/path/to/image.png', { width = 40, height = 30 })

" Test WezTerm socket
:lua print(require('glimpse.strategy.pane')._find_wezterm_socket())
```

## Known limitations

- **First load latency**: `magick` takes ~700ms-2s for large images. Cache resolves subsequent accesses.
- **Terminal latency**: after transmission, the terminal takes ~200-500ms to render. Outside our control.
- **WezTerm**: does not support unicode placeholders - uses external pane via `wezterm cli`.
- **WezTerm + tmux**: requires `WEZTERM_UNIX_SOCKET` propagated via `update-environment`.
- **Video thumbnails**: first extraction takes ~500ms. Subsequent previews use cache.
- **Inline animation**: requires Kitty or Ghostty. WezTerm, iTerm2, and tmux+Sixel fall back to a static thumbnail.
- **Inline animation + resize**: re-extracts all frames when the preview window is resized; expect a brief blank before the new animation starts.
