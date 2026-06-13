<!-- markdownlint-disable MD013 MD034 MD060 MD025 -->

# glimpse.nvim

> Fast multi-format file previewer with inline Kitty graphics support,
> external pane previews, and integrations for file explorers and pickers.

<https://github.com/user-attachments/assets/686e39aa-1fa9-4a79-8a07-70ce5d4062bb>

## Features

- 🖼️ Inline rendering via **Kitty Graphics Protocol** (Kitty, Ghostty)
- 🎬 **Video preview** via ffmpeg thumbnail extraction (cached)
- 📦 **Archive preview** - list contents of zip/tar without extraction
- 🗄️ **SQLite preview** - show tables and columns without modifying the database
- 💾 **Binary preview** - detect binaries with `file` and show a short `xxd` hexdump
- 🪟 External pane via **WezTerm CLI**, **kitten icat**, **iTerm imgcat**
- 🎨 **Font rendering** via ImageMagick, with a textual fallback when rendering is unavailable
- 🎨 **Sixel** fallback for terminals without Kitty Graphics support
- 📂 **Oil.nvim** integration (`<leader>p` for preview, `;` to open)
- 🔭 **Telescope** integration (scoped previews for images, videos, archives, SQLite, fonts, keys, certificates, and binaries)
- 🌳 **Neo-tree** integration
- 🔐 **Certificate preview** - show subject, issuer, validity, and
  fingerprint for `.crt`/`.pem`
- ⚡ Image conversion cache + background prefetch
- 🔄 Auto re-render on window resize or tab switch
- 📐 Contain resize (images always fully visible)

## Requirements

- Neovim >= 0.10
- [ImageMagick](https://imagemagick.org/) (`magick` CLI) - inline image conversion and font rendering
- [ffmpeg](https://ffmpeg.org/) (optional) - video thumbnail extraction
- [OpenSSL](https://www.openssl.org/) (`openssl` CLI) - certificate metadata extraction
- [file](https://man7.org/linux/man-pages/man1/file.1.html) (`file` CLI) - binary type detection
- [xxd](https://linux.die.net/man/1/xxd) (`xxd` CLI) - binary hexdump rendering
- Terminal with support for at least one protocol:
  - **Kitty Graphics** (recommended): Kitty, Ghostty
  - **Terminal CLI**: WezTerm, iTerm2
  - **Sixel**: xterm, foot, mlterm, contour

> [!NOTE]
> `magick` is required for inline image rendering and font rendering. Font preview still has a textual fallback if rendering is unavailable.

### Feature Dependencies

| Feature | Dependency | Required |
|---|---|---|
| Inline image preview | `magick` | Yes |
| Font rendering | `magick` | Yes, with textual fallback if unavailable |
| Video preview | `ffmpeg` | No |
| Archive preview | `zipinfo`, `tar` | Yes when the archive type is used |
| SQLite preview | `sqlite3` | Yes when the SQLite preview is used |
| Certificate preview | `openssl` | Yes when the certificate preview is used |
| Binary preview | `file`, `xxd` | Yes when the binary preview is used |
| SSH/GPG key preview | `ssh-keygen`, `gpg` | Yes when the key preview is used |

## Installing dependencies

> [!NOTE]
> Binary preview depends on `file` and `xxd`. They are usually available on Unix-like systems, but if your OS does not ship them by default, install them separately.

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
file --version
xxd -h
```

## Usage

### Setup (lazy.nvim)

```lua
{
  'adriancmiranda/glimpse.nvim',
  ft = { 'oil', 'neo-tree' },
  event = {
    'BufReadPre *.png', 'BufReadPre *.jpg', 'BufReadPre *.jpeg',
    'BufReadPre *.gif', 'BufReadPre *.bmp', 'BufReadPre *.webp',
    'BufReadPre *.avif', 'BufReadPre *.svg', 'BufReadPre *.pdf',
    'BufReadPre *.ttf', 'BufReadPre *.otf',
    'BufReadPre *.crt', 'BufReadPre *.pem',
    'BufReadPre *.zip', 'BufReadPre *.tar', 'BufReadPre *.tgz',
    'BufReadPre *.jar', 'BufReadPre *.war', 'BufReadPre *.apk',
    'BufReadPre *.db', 'BufReadPre *.sqlite', 'BufReadPre *.sqlite3',
  },
  opts = {
    strategy = 'auto',        -- 'auto' | 'inline' | 'pane'
    pane = {
      position = 'right',     -- 'right' | 'bottom'
      size = 40,              -- split/pane size percentage
    },
    inline = {
      rerender_on_tab = true, -- re-render when switching back to image tab
      close_with_q = true,    -- map key to close image buffer
    },
    keys = {
      preview = '<leader>p',  -- preview image/video side by side (Oil)
      open = ';',             -- open image (configurable: current tab or new tab) (Oil)
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
    cache = {
      dir = vim.fn.stdpath('cache') .. '/glimpse',
      max_age_days = 7,      -- auto-remove cached files older than N days (0 to disable)
    },
    safety = {
      max_file_size = 50 * 1024 * 1024, -- skip files larger than 50MB
    },
    loading = {
      text = '  ⏳ Loading...',
    },
    image = {
      formats = {            -- supported image extensions
        '.png', '.jpg', '.jpeg', '.gif', '.bmp',
        '.webp', '.avif', '.svg', '.pdf', '.pict',
      },
    },
    video = {
      formats = {            -- supported video extensions (requires ffmpeg)
        '.mp4', '.mkv', '.avi', '.mov',
        '.webm', '.flv', '.wmv', '.m4v',
      },
      open = nil,            -- command or function to open videos externally
                              -- string: 'open' (macOS), 'xdg-open' (Linux)
                              -- function: fun(filepath) for custom logic
                              -- nil: plays inline (Kitty/Ghostty) or shows thumbnail
      frames = {
        strategy   = 'auto', -- 'auto' | 'batch' | 'poll' | 'pipe'
                              -- auto: selects poll when ffmpeg is available
                              -- batch: low-res preview immediately, full-res when done
                              -- poll: frames delivered progressively as ffmpeg writes them
                              -- pipe: binary stream via image2pipe (no temp files)
        per_second = 10,     -- frames per second to extract
        limit      = 120,    -- maximum frames to extract per video
      },
      keys = {
        toggle        = '<CR>', -- play / pause inline animation
        seek_forward  = 'l',   -- seek forward 5 seconds
        seek_backward = 'h',   -- seek backward 5 seconds
      },
    },
    archive = {
      formats = {            -- supported archive extensions (preview only, no extraction)
        '.zip', '.tar', '.tar.gz', '.tgz',
        '.tar.bz2', '.tar.xz', '.txz',
        '.jar', '.war', '.apk',
      },
    },
    integrations = {
      oil = {
        enable = true,        -- keymaps in Oil
        open = 'edit',        -- 'edit' | 'tabedit' | function(filepath)
      },
      neotree = {             -- Neo-tree integration
        enable = false,       -- enable auto-preview in Neo-tree
        auto_preview = true,  -- preview on cursor move (set false to disable)
      },
      telescope = {
        enable = true,        -- enables image/video previews in :Telescope find_files
      },
    },
  },
}
```

Breaking change: the public config was reorganized into nested tables.

### Keymaps (Oil.nvim)

| Key | Action |
|-----|--------|
| `<leader>p` | Preview image/video side by side (reuses window) |
| `;` | Open image (configurable: current tab or new tab) |
| `q` | Close image buffer and residual empty window |

When an image is opened, the current window follows that file's directory, so `Oil.nvim` opens in the same folder.

### Keymaps (Neo-tree)

Enable with `integrations = { neotree = { enable = true } }` in setup.

| Key | Action |
|-------|------|
| `<leader>p` | Preview image/video side by side |
| `;` | Open image inline or video with external player |

### Telescope

Enable with `integrations = { telescope = { enable = true } }` in setup. With lazy.nvim,
glimpse applies its previewer when telescope.nvim loads. By default, only
`:Telescope find_files` receives Glimpse previews.

```lua
require('glimpse').setup({
  integrations = {
    telescope = {
      enable = true,
    },
  },
})
```

To choose the Telescope pickers that receive Glimpse previews:

```lua
require('glimpse').setup({
  integrations = {
    telescope = {
      enable = true,
      pickers = { 'find_files', 'git_files' },
    },
  },
})
```

To disable specific preview kinds inside Telescope while keeping the integration
enabled:

```lua
require('glimpse').setup({
  integrations = {
    telescope = {
      enable = true,
      pickers = { 'find_files', 'git_files' },
      image = true,
      video = true,
      archive = true,
      sqlite = false,
      font = false,
      cert = true,
      key = true,
      binary = false,
    },
  },
})
```

If you prefer configuring Telescope manually, use the exported previewer:

```lua
require('telescope').setup({
  pickers = {
    find_files = {
      previewer = require('glimpse.integrations.telescope').previewer(),
    },
  },
})
```

- **Images** are rendered inline via Kitty Graphics Protocol with a 100ms debounce
- **Videos** extract a thumbnail via ffmpeg before rendering
- **Archives, SQLite databases, fonts, keys, certificates, and binaries** use the matching Glimpse previewer inside the Telescope preview pane
- **Other files** fall back to Telescope's default previewer

Switching between files is fast after thumbnails and conversions are cached.

### API

```lua
local img = require('glimpse')

img.can_preview(filepath)    -- check whether Glimpse knows how to preview it
img.get_preview_kind(filepath) -- return the preview kind that would be used
img.show(filepath)           -- show image or video thumbnail
img.preview(filepath)        -- show reusing existing window
img.close()                  -- close active preview
img.is_image(filepath)       -- check if supported image
img.is_video(filepath)       -- check if supported video
img.is_archive(filepath)     -- check if supported archive
img.is_sqlite(filepath)      -- check if supported SQLite database
img.is_previewable(filepath) -- check if supported previewable file
img.is_cert(filepath)        -- check if supported certificate
img.is_font(filepath)        -- check if supported font
img.is_key(filepath)         -- check if supported GPG/SSH key
img.get_terminal()           -- return detected terminal
img.supports_inline()        -- check whether inline rendering is supported
img.in_tmux()                -- check whether Neovim runs inside tmux
```

## Security & Privacy

glimpse.nvim runs **only local commands** on files you explicitly select.
It never makes network requests or sends data externally.

> [!IMPORTANT]
> The plugin only uses local tools on files you explicitly select. When a tool is missing, the affected previewer fails safely instead of breaking the rest of the plugin.

### File validation

- **Symlinks** are rejected (prevents reading unintended targets)
- **Large files** above `safety.max_file_size` are skipped (default: 50MB)
- **SVG files** are processed with restricted XML parsing (no entity expansion, no external resources)
- **Archive preview** never extracts files, only reads metadata
- **Shell commands** use list arguments (no shell interpolation)

### External tools used

| Tool | Purpose | When |
|------|---------|------|
| magick (ImageMagick) | Image resize/conversion | Image preview |
| ffmpeg | Video thumbnail extraction | Video preview |
| openssl | X.509 certificate metadata extraction | Certificate preview |
| zipinfo | Archive listing (read-only) | Archive preview |
| tar | Archive listing (read-only) | tar/tgz preview |
| sqlite3 | Schema listing (read-only) | SQLite preview |

No files are extracted, modified, or uploaded. All processing is local and read-only.

<!-- markdownlint-disable MD033 -->
<details>
<summary>Optional: ImageMagick resource policy</summary>

Optional extra protection: place this in `~/.config/ImageMagick/policy.xml`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policymap [
  <!ELEMENT policymap (policy)*>
  <!ATTLIST policymap xmlns CDATA #FIXED "">
  <!ELEMENT policy EMPTY>
  <!ATTLIST policy xmlns CDATA #FIXED "">
  <!ATTLIST policy domain NMTOKEN #REQUIRED>
  <!ATTLIST policy name NMTOKEN #IMPLIED>
  <!ATTLIST policy pattern CDATA #IMPLIED>
  <!ATTLIST policy rights NMTOKEN #IMPLIED>
  <!ATTLIST policy stealth NMTOKEN #IMPLIED>
  <!ATTLIST policy value CDATA #IMPLIED>
]>
<policymap>
  <policy domain="resource" name="memory" value="256MiB"/>
  <policy domain="resource" name="map" value="512MiB"/>
  <policy domain="resource" name="disk" value="1GiB"/>
  <policy domain="resource" name="time" value="30"/>
  <policy domain="resource" name="thread" value="2"/>
  <policy domain="resource" name="list-length" value="64"/>
  <!--
  "area" is an extra safety limit and may block very large images.
  If Glimpse starts rejecting legitimate previews, remove or
  increase it.
  -->
  <policy domain="resource" name="area" value="100MP"/>
</policymap>
```

</details>
<!-- markdownlint-enable MD033 -->

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

**Certificates:** CRT, PEM (X.509 certificates)

**Videos:** MP4, MKV, AVI, MOV, WebM, FLV, WMV, M4V (requires ffmpeg)

## Architecture

```bash
lua/
├── glimpse/
│   ├── init.lua              -- Public API: setup(), show(), preview(), close(), helpers
│   ├── detect.lua            -- Terminal detection via tmux client_termname
│   ├── kitty.lua             -- Kitty Graphics Protocol (transmit, delete, prefetch)
│   ├── renderer.lua          -- Placement management and extmarks
│   ├── sixel.lua             -- Sixel protocol (fallback)
│   ├── thumbnail.lua         -- Video thumbnail extraction (ffmpeg, async)
│   ├── magickwand.lua        -- FFI bindings for libMagickWand
│   ├── util.lua              -- Image, video and certificate format detection
│   ├── archive.lua           -- Archive listing and suspicious path detection
│   ├── font.lua              -- Font metadata extraction and rendering
│   ├── sqlite.lua            -- SQLite schema preview
│   ├── safety.lua            -- File validation and safety checks
│   ├── previewer/
│   │   ├── archive.lua       -- Archive previewer
│   │   ├── cert.lua          -- X.509 certificate previewer
│   │   ├── binary.lua        -- Binary previewer (file + hexdump)
│   │   ├── font.lua          -- Font previewer
│   │   ├── image.lua         -- Inline image previewer
│   │   ├── key.lua           -- GPG/SSH key previewer
│   │   └── sqlite.lua        -- SQLite previewer
│   ├── strategy/
│   │   ├── inline.lua        -- Inline rendering + autocmds
│   │   └── pane.lua          -- External pane rendering (WezTerm, iTerm2)
│   └── integrations/
│       ├── oil.lua           -- Oil.nvim integration
│       ├── neotree.lua       -- Neo-tree integration (auto-preview)
│       └── telescope.lua     -- Telescope integration (scoped picker preview)
```

## Credits

- [snacks.nvim](https://github.com/folke/snacks.nvim) - inspiration for the rendering protocol
- [Yazi](https://github.com/sxyazi/yazi) - inspiration for performance optimizations
- [Reddit post](https://www.reddit.com/r/neovim/comments/1e1txpz/) - original WezTerm preview concept
