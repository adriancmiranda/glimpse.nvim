# glimpse.nvim

> Inline image and video preview for Neovim via Kitty Graphics Protocol, with Sixel and external pane fallbacks.

https://github.com/user-attachments/assets/686e39aa-1fa9-4a79-8a07-70ce5d4062bb

## Features

- 🖼️ Inline rendering via **Kitty Graphics Protocol** (Kitty, Ghostty)
- 🎬 **Video preview** via ffmpeg thumbnail extraction (cached)
- 🪟 External pane via **WezTerm CLI**, **kitten icat**, **iTerm imgcat**
- 🎨 **Sixel** fallback for terminals without Kitty Graphics support
- 📂 **Oil.nvim** integration (`<leader>p` for preview, `;` to open)
- 🔭 **Telescope** integration (custom previewer for images and videos)
- 🌳 **Neo-tree** integration
- ⚡ Image conversion cache + background prefetch
- 🔄 Auto re-render on window resize or tab switch
- 📐 Contain resize (images always fully visible)

## Requirements

- Neovim >= 0.10
- [ImageMagick](https://imagemagick.org/) (`magick` CLI) - conversion and resizing
- [ffmpeg](https://ffmpeg.org/) (optional) - video thumbnail extraction
- Terminal with support for at least one protocol:
  - **Kitty Graphics** (recommended): Kitty, Ghostty
  - **Terminal CLI**: WezTerm, iTerm2
  - **Sixel**: xterm, foot, mlterm, contour

## Installing dependencies

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

### Verify installation

```bash
magick --version
```

## Usage

### Setup (lazy.nvim)

```lua
{
  'adriancmiranda/glimpse.nvim',
  ft = 'oil',
  opts = {
    strategy = 'auto',        -- 'auto' | 'inline' | 'pane'
    pane_position = 'right',  -- 'right' | 'bottom'
    pane_size = 40,           -- split/pane size percentage
    inline = {
      rerender_on_tab = true, -- re-render when switching back to image tab
      close_with_q = true,    -- map key to close image buffer
    },
    keys = {
      preview = '<leader>p',  -- preview image/video side by side (Oil)
      open = ';',             -- open image in tab or video with external player (Oil)
      close = 'q',            -- close image buffer
    },
    debounce = {
      prefetch = 200,         -- ms before pre-converting on cursor move
      resize = 100,           -- ms before re-rendering on resize
    },
    cell_size = {
      width = 20,             -- estimated pixels per terminal column
      height = 40,            -- estimated pixels per terminal row
    },
    cache_dir = vim.fn.stdpath('cache') .. '/glimpse',
    cache_max_age_days = 7,   -- auto-remove cached files older than N days (0 to disable)
    max_file_size = 50 * 1024 * 1024, -- skip files larger than 50MB
    loading_text = '  ⏳ Loading...',
    formats = {               -- supported image extensions
      '.png', '.jpg', '.jpeg', '.gif', '.bmp',
      '.webp', '.avif', '.svg', '.pdf', '.pict',
    },
    video_formats = {         -- supported video extensions (requires ffmpeg)
      '.mp4', '.mkv', '.avi', '.mov',
      '.webm', '.flv', '.wmv', '.m4v',
    },
    video_open = nil,         -- command or function to open videos externally
                              -- string: 'open' (macOS), 'xdg-open' (Linux)
                              -- function: fun(filepath) for custom logic
                              -- nil: opens as buffer in Neovim
    integrations = {
      oil = true,             -- keymaps in Oil
      neotree = {             -- Neo-tree integration
        enable = false,       -- enable auto-preview in Neo-tree
        auto_preview = true,  -- preview on cursor move (set false to disable)
      },
      telescope = true,       -- loads via require('telescope').load_extension('glimpse')
    },
  },
}
```

### Keymaps (Oil.nvim)

| Key | Action |
|-----|--------|
| `<leader>p` | Preview image/video side by side (reuses window) |
| `;` | Open image in tab or video with external player |
| `q` | Close image buffer and residual empty window |

### Keymaps (Neo-tree)

Enable with `integrations = { neotree = { enable = true } }` in setup.

| Key | Action |
|-------|------|
| `<leader>p` | Preview image/video side by side |
| `;` | Open image inline or video with external player |

### Telescope

The recommended approach is to use `buffer_previewer_maker` in Telescope defaults:

```lua
-- In Telescope setup (defaults):
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

> **NOTE**: Do NOT add `'glimpse'` to Telescope's `extensions_list`.
> This forces Telescope to load on startup, increasing init time by ~1300ms.

The previewer renders images inline in the preview pane and falls back to the default previewer for non-image files. Switching between files is instant thanks to automatic placement cleanup and conversion cache.

### API

```lua
local img = require('glimpse')

img.show(filepath)           -- show image or video thumbnail
img.preview(filepath)        -- show reusing existing window
img.close()                  -- close active preview
img.is_image(filepath)       -- check if supported image
img.is_video(filepath)       -- check if supported video
img.is_previewable(filepath) -- check if image or video
img.get_terminal()           -- return detected terminal
```

## Security & Privacy

glimpse.nvim runs **only local commands** on files you explicitly select.
It never makes network requests or sends data externally.

### File validation

- **Symlinks** are rejected (prevents reading unintended targets)
- **Large files** above `max_file_size` are skipped (default: 50MB)
- **SVG files** are processed with restricted XML parsing (no entity expansion, no external resources)
- **Shell commands** use list arguments (no shell interpolation)

### External tools used

| Tool | Purpose | When |
|------|---------|------|
| magick (ImageMagick) | Image resize/conversion | Image preview |
| ffmpeg | Video thumbnail extraction | Video preview |
| zipinfo | Archive listing (read-only) | Archive preview |
| tar | Archive listing (read-only) | tar/tgz preview |

No files are extracted, modified, or uploaded. All processing is local and read-only.

For additional protection, consider configuring ImageMagick's
[policy.xml](https://imagemagick.org/script/security-policy.php)
to limit resource usage.

## Supported terminals

| Terminal | Strategy | Method |
|----------|----------|--------|
| Kitty | inline | Kitty Graphics + unicode placeholders |
| Ghostty | inline | Kitty Graphics + unicode placeholders |
| WezTerm | pane | `wezterm cli split-pane` + `wezterm imgcat` |
| iTerm2 | pane | `imgcat` |
| xterm/foot/mlterm | pane (sixel) | `magick ... sixel:-` via tmux |

### WezTerm + tmux

`wezterm cli` needs access to the WezTerm GUI socket. Inside tmux, the
`WEZTERM_UNIX_SOCKET` variable can become stale if WezTerm restarts.

Add to `tmux.conf`:

```bash
set -ga update-environment WEZTERM_UNIX_SOCKET
```

If preview stops working, update manually:

```bash
# Find the active socket
ls ~/.local/share/wezterm/gui-sock-*

# Export the correct one
tmux set-environment WEZTERM_UNIX_SOCKET ~/.local/share/wezterm/gui-sock-<PID>
```

## Supported formats

**Images:** PNG, JPG, JPEG, GIF, BMP, WebP, AVIF, SVG, PDF, PICT

**Videos:** MP4, MKV, AVI, MOV, WebM, FLV, WMV, M4V (requires ffmpeg)

## Architecture

```bash
lua/
├── glimpse/
│   ├── init.lua              -- Public API: setup(), show(), preview(), close()
│   ├── detect.lua            -- Terminal detection via tmux client_termname
│   ├── kitty.lua             -- Kitty Graphics Protocol (transmit, delete, prefetch)
│   ├── renderer.lua          -- Placement management and extmarks
│   ├── sixel.lua             -- Sixel protocol (fallback)
│   ├── thumbnail.lua         -- Video thumbnail extraction (ffmpeg, async)
│   ├── magickwand.lua        -- FFI bindings for libMagickWand
│   ├── util.lua              -- Image and video format detection
│   ├── strategy/
│   │   ├── inline.lua        -- Inline rendering + autocmds
│   │   └── pane.lua          -- External pane rendering (WezTerm, iTerm2)
│   └── integrations/
│       ├── oil.lua           -- Oil.nvim integration
│       └── neotree.lua       -- Neo-tree integration (auto-preview)
└── telescope/
    └── _extensions/
        └── glimpse.lua       -- Telescope extension (custom previewer)
```

## Credits

- [snacks.nvim](https://github.com/folke/snacks.nvim) - inspiration for the rendering protocol
- [Yazi](https://github.com/sxyazi/yazi) - inspiration for performance optimizations
- [Reddit post](https://www.reddit.com/r/neovim/comments/1e1txpz/) - original WezTerm preview concept
