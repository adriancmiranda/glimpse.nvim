<!-- markdownlint-disable MD013 MD034 MD060 MD025 -->

# glimpse.nvim

> Fast multi-format file previewer with inline Kitty graphics support,
> external pane previews, and integrations for file explorers and pickers.

<https://github.com/user-attachments/assets/686e39aa-1fa9-4a79-8a07-70ce5d4062bb>

## Features

- 🖼️ Inline rendering via **Kitty Graphics Protocol** (Kitty, Ghostty)
- 🎬 **Inline video playback** via Kitty Animation Protocol (play/pause, seek); thumbnail fallback for other terminals
- 🧊 **3D model preview** via f3d, with Blender fallback for `.blend` files and configurable turntable animation
- 📝 **Markdown preview** via a configurable CLI renderer (leaf, glow, mdcat, pandoc) with full ANSI color support
- 📊 **Diagram preview** - PlantUML (`.puml`) and Mermaid (`.mmd`) rendered as inline images
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
- 💾 **Auto-refresh on save** - re-render open previews when the source file is saved
- 📐 Contain resize (images always fully visible)

## Requirements

- Neovim >= 0.10
- [ImageMagick](https://imagemagick.org/) (`magick` CLI) - inline image conversion and font rendering
- [ffmpeg](https://ffmpeg.org/) (optional) - video thumbnail extraction
- [f3d](https://f3d.app/) (optional) - 3D model thumbnails and turntable frames
- [Blender](https://www.blender.org/) (optional) - fallback renderer for `.blend` files
- [plantuml](https://plantuml.com/) (optional) - PlantUML diagram rendering (requires Java)
- [mmdc](https://github.com/mermaid-js/mermaid-cli) (optional) - Mermaid diagram rendering
- One of [leaf](https://github.com/rivolink/leaf), [glow](https://github.com/charmbracelet/glow), [mdcat](https://github.com/BIRSAx2/mdcat), or [pandoc](https://pandoc.org/) (optional) - Markdown rendering
- [OpenSSL](https://www.openssl.org/) (`openssl` CLI) - certificate metadata extraction
- [file](https://man7.org/linux/man-pages/man1/file.1.html) (`file` CLI) - binary type detection
- [xxd](https://linux.die.net/man/1/xxd) (`xxd` CLI) - binary hexdump rendering
- Terminal with support for at least one protocol:
  - **Kitty Graphics** (recommended): Kitty, Ghostty
  - **Terminal CLI**: WezTerm, iTerm2
  - **Sixel**: xterm, foot, mlterm, contour

> [!NOTE]
> Windows is not currently a fully validated platform. Markdown previews may work
> when a supported CLI renderer is available, but image protocols, terminal panes,
> video previews, and external integrations may require additional setup or may not
> work.
> [!NOTE]
> `magick` is required for inline image rendering and font rendering. Font preview still has a textual fallback if rendering is unavailable.

### Feature Dependencies

| Feature              | Dependency                                           | Required                                  |
| -------------------- | ---------------------------------------------------- | ----------------------------------------- |
| Inline image preview | `magick`                                             | Yes                                       |
| Font rendering       | `magick`                                             | Yes, with textual fallback if unavailable |
| Video preview        | `ffmpeg`                                             | No                                        |
| 3D model preview     | `f3d`, with optional `blender` fallback for `.blend` | No                                        |
| Archive preview      | `zipinfo`, `tar`                                     | Yes when the archive type is used         |
| SQLite preview       | `sqlite3`                                            | Yes when the SQLite preview is used       |
| Certificate preview  | `openssl`                                            | Yes when the certificate preview is used  |
| Binary preview       | `file`, `xxd`                                        | Yes when the binary preview is used       |
| SSH/GPG key preview  | `ssh-keygen`, `gpg`                                  | Yes when the key preview is used          |
| Markdown preview     | `leaf`, `glow`, `mdcat`, `pandoc`, or `cat`          | First executable found wins               |
| PlantUML preview     | `plantuml` + Java runtime                            | Yes when the PlantUML previewer is used   |
| Mermaid preview      | `mmdc`                                               | Yes when the Mermaid previewer is used    |

## Installing dependencies

> [!NOTE]
> Binary preview depends on `file` and `xxd`. They are usually available on Unix-like systems, but if your OS does not ship them by default, install them separately.

### macOS (Homebrew)

```bash
brew install imagemagick ffmpeg f3d
```

### Linux (apt)

```bash
sudo apt install imagemagick ffmpeg
```

### Linux (pacman)

```bash
sudo pacman -S imagemagick ffmpeg
```

### Markdown renderer

Markdown previews use the first executable found in the configured list. Install at least one renderer.

```bash
# macOS (Homebrew): choose one
brew install leaf-markdown-viewer
# brew install glow
# brew install mdcat
# brew install pandoc
```

On Linux, use the command for the renderer you want:

```bash
# leaf (Linux or macOS)
curl -fsSL https://raw.githubusercontent.com/RivoLink/leaf/main/scripts/install.sh | sh

# glow (requires Go)
go install github.com/charmbracelet/glow/v2@latest

# mdcat (requires Rust and Cargo)
cargo install mdcat

# pandoc (Debian or Ubuntu)
sudo apt install pandoc
```

Other platform-specific options are documented in the [leaf installation guide](https://github.com/rivolink/leaf#install), [glow installation guide](https://github.com/charmbracelet/glow#installation), [mdcat installation guide](https://github.com/swsnr/mdcat#installation), and [pandoc installation guide](https://pandoc.org/installing.html).

You do not need to install every renderer. The default fallback order is `leaf`, `glow`, `mdcat`, `pandoc`, then `cat`.

### Verify installation

```bash
magick --version
f3d --version
file --version
xxd -h

# Check whichever Markdown renderers are installed.
for cmd in leaf glow mdcat pandoc; do
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" --version
  fi
done
```

PowerShell:

```powershell
'leaf', 'glow', 'mdcat', 'pandoc' | ForEach-Object {
  if (Get-Command $_ -ErrorAction SilentlyContinue) {
    & $_ --version
  }
}
```

## Usage

### Setup (lazy.nvim)

```lua
{
  'adriancmiranda/glimpse.nvim',
  ft = { 'oil', 'neo-tree' },
  opts = {},
}
```

The setup above loads Glimpse when entering a supported file explorer. If
`auto_open = true`, add `event = 'BufReadPre'` to the plugin spec so Glimpse can
register its automatic preview handler before the file finishes loading. This
intentionally applies to every file instead of duplicating the configurable
format list in the lazy-loading specification. `keys.preview` configures the
mapping installed by the file explorer integration; it is not a lazy.nvim
loading trigger.

The full default setup is available here as a reference when overriding only
part of the configuration:

<details>
<summary>Default configuration</summary>

```lua
{
  -- Rendering backend: 'auto', 'inline', or 'pane'. 'auto' uses inline
  -- terminal graphics when supported, otherwise it falls back to a pane.
  strategy = 'auto',

  -- Render non-text previewable files as soon as they are opened.
  auto_open = false,

  -- Re-render open previews when the source file is saved.
  auto_refresh = false,

  -- External pane settings used when inline rendering is unavailable.
  pane = {
    position = 'right',
    size = 40,
  },

  -- Inline image buffer behavior.
  inline = {
    rerender_on_tab = true,
    close_with_q = true,
  },

  -- Default floating window sizes for text-like previews.
  float = {
    markdown = { width = 100 },
    archive = { width = 70 },
    cert = { width = 90 },
    font = { width = 60 },
    key = { width = 70 },
    sqlite = { width = 80 },
    binary = { width = 100 },
  },

  -- File explorer mappings installed by integrations such as Oil.nvim.
  keys = {
    preview = '<leader>p',
    open = ';',
    close = 'q',
  },

  -- Debounce intervals in milliseconds for background work.
  debounce = {
    prefetch = 200,
    resize = 100,
  },

  -- Estimated terminal cell size in pixels, used for image scaling.
  cell_size = {
    width = 20,
    height = 40,
  },

  -- Cache directory and expiration for generated preview artifacts.
  cache = {
    dir = vim.fn.stdpath('cache') .. '/glimpse',
    max_age_days = 7,
  },

  -- Safety limits before invoking external tools on a file.
  safety = {
    max_file_size = 50 * 1024 * 1024, -- 50 MiB
  },

  -- Placeholder shown while an async preview is being generated.
  loading = {
    text = '  ⏳ Loading...',
  },

  -- Image formats rendered directly through the selected strategy.
  image = {
    formats = {
      '.png', '.jpg', '.jpeg', '.gif', '.bmp',
      '.webp', '.avif', '.svg', '.pdf', '.pict',
    },
  },

  -- Video formats and inline animation settings.
  video = {
    formats = {
      '.mp4', '.mkv', '.avi', '.mov',
      '.webm', '.flv', '.wmv', '.m4v',
    },
    -- Optional external video opener: command string or function(filepath).
    -- nil keeps videos in the inline preview flow.
    open = nil,
    frames = {
      -- 'auto' | 'pipe' | 'poll' | 'batch'
      -- 'pipe' streams frames via image2pipe (default, binary-safe, single temp file)
      -- 'poll' writes numbered PNGs to a temp dir and polls for each
      -- 'batch' extracts all frames first, then plays
      strategy = 'auto',
      per_second = 10,
      limit = 120,
      width = 640,
    },
    keys = {
      toggle = '<CR>',
      seek_forward = 'l',
      seek_backward = 'h',
    },
  },

  -- Markdown renderers are fallback candidates tried in order.
  markdown = {
    formats = { '.md', '.markdown', '.mdx', '.mdwn', '.mdown' },
    tools = {
      { 'leaf', '--inline', 'ansi:{width}', '{input}' },
      { 'glow', '-s', 'dark', '--width', '{width}', '{input}' },
      { 'mdcat', '{input}' },
      { 'pandoc', '--to', 'plain', '--wrap', 'none', '{input}' },
      { 'cat', '{input}' },
    },
  },

  -- Conversion pipelines map preview kinds or extensions to external commands.
  pipelines = {
    -- PlantUML reads from stdin and writes a PNG to the requested output file.
    plantuml = {
      -- steps run sequentially; each output becomes the next step's input.
      steps = {
        {
          command = 'sh',
          args = function(input, output)
            return { '-c', 'plantuml -tpng -pipe < "$1" > "$2"', '--', input, output }
          end,
        },
      },
    },
    -- Mermaid CLI writes the rendered diagram directly to the output path.
    mermaid = {
      -- args receives the source path and the output path Glimpse expects.
      steps = {
        {
          command = 'mmdc',
          args = function(input, output)
            return { '-i', input, '-o', output }
          end,
        },
      },
    },
    -- 3D models render to a static thumbnail by default.
    model = {
      -- A single static step produces one image for the preview.
      steps = {
        {
          command = 'f3d',
          output_ext = '.png',
          args = function(input, output)
            return { input, '--output', output, '--config=thumbnail' }
          end,
        },
      },
      -- renderer controls sequence playback when a pipeline produces frames.
      renderer = {
        fps = 12,
        progressive = true,
      },
      -- keys apply to animated previews created from frame sequences.
      keys = {
        toggle = '<CR>',
        seek_forward = 'l',
        seek_backward = 'h',
      },
    },
    -- Extension-specific pipelines override the generic model pipeline.
    ['.blend'] = {
      -- previewers are fallbacks: Glimpse tries each command until one works.
      previewers = {
        -- Try f3d first for Blender files.
        {
          command = 'f3d',
          output_ext = '.png',
          args = function(input, output)
            return { input, '--output', output, '--config=thumbnail' }
          end,
        },
        -- Fall back to Blender itself when f3d is unavailable or fails.
        {
          command = 'blender',
          output_ext = '.png',
          args = function(input, output)
            return {
              '--background', input,
              '--render-output', output:gsub('%.png$', '_'),
              '--render-format', 'PNG',
              '--render-frame', '1',
            }
          end,
          output_pattern = function(output)
            return output:gsub('%.png$', '_0001.png')
          end,
        },
      },
    },
  },

  -- Archive formats shown as read-only file listings.
  archive = {
    formats = {
      '.zip', '.tar', '.tar.gz', '.tgz',
      '.tar.bz2', '.tar.xz', '.txz',
      '.jar', '.war', '.apk',
    },
  },

  -- Optional integrations with file explorers and pickers.
  integrations = {
    oil = {
      enable = true,
      open = 'edit',
      follow_cwd = true,
    },
    neotree = {
      enable = false,
      auto_preview = true,
    },
    telescope = {
      enable = true,
      -- Limit Glimpse previews to these Telescope pickers.
      pickers = { 'find_files' },
      follow_cwd = false,
      -- Toggle individual preview kinds inside Telescope.
      image = true,
      video = true,
      archive = true,
      sqlite = true,
      font = true,
      cert = true,
      key = true,
      binary = true,
    },
  },
}
```

</details>

---

### Automatic opening

Set `auto_open = true` to render non-text previewable files opened directly with
Neovim or selected normally in a file explorer. Native text formats such as
Markdown and PlantUML remain editable; use the preview key to render them.

### Auto-refresh on save

Set `auto_refresh = true` to re-render open previews whenever the source file is
saved. Supports Markdown floats and pipeline-based previewers (PlantUML, Mermaid,
3D models). The refresh only runs while the preview window is still open; closing
the preview stops the hook automatically.

### Explicit preview command

Use `:GlimpsePreview` to preview the current buffer without depending on a file
explorer integration:

```vim
:GlimpsePreview
:GlimpsePreview README.md
:GlimpsePreview %
:GlimpsePreview ~/models/scene.blend
```

The optional path supports file completion and expands relative paths, `~`, and
`%`. Glimpse currently selects the preview destination automatically according
to the file type.

An optional `[window]` argument controls where the preview opens:

```vim
:GlimpsePreview right
:GlimpsePreview left README.md
:GlimpsePreview bottom ~/models/scene.blend
```

Valid values are `float` (default), `right`, `left`, `bottom`, and `top`.

### Cache management

`:GlimpseClearCache` removes cached conversions so the next preview re-runs from
scratch. Useful when a file has changed on disk but the cached version is stale,
or to free up disk space.

```vim
:GlimpseClearCache           " clear everything
:GlimpseClearCache images    " image conversions only (disk + memory)
:GlimpseClearCache previews  " text preview cache only (markdown, sqlite, etc.)
```

### Float sizing

`float.width` and `float.height` override every floating preview. A preview-specific
entry such as `float.markdown` takes precedence over the global value. Numeric
widths use that many columns and numeric heights cap the content height.
`width = 'auto'` fills the available editor width; `height = 'auto'` fits the
content within the available editor height. Float margins are always respected.
Without overrides, the built-in sizes remain unchanged, except Markdown now
defaults to 100 columns.

### 3D model turntable

The default pipeline renders a static thumbnail with f3d. To generate a
progressive turntable animation instead, use a sequence step:

```lua
require('glimpse').setup({
  pipelines = {
    model = {
      steps = {
        {
          command = 'f3d',
          type = 'sequence',
          frames = 36,
          args = function(input, output, frame)
            return {
              input, '--output', output,
              '--config=thumbnail',
              '--camera-azimuth-angle=' .. (frame * 10),
            }
          end,
        },
      },
      renderer = { fps = 12, progressive = true },
    },
  },
})
```

To start the turntable paused and rotate manually, disable autoplay. The default
keys seek one frame backward/forward with `h`/`l`, and `<CR>` toggles playback:

```lua
renderer = { fps = 12, progressive = true, auto_play = false }
keys = { seek_backward = 'h', seek_forward = 'l', toggle = '<CR>' }
```

`.blend` files try f3d first, then Blender when f3d is unavailable or fails.
Blender renders frame 1 with the camera and render settings stored in the
scene.

`steps` form a sequential conversion chain: each output becomes the next
step's input. `previewers` are alternatives: Glimpse tries them in order,
skipping missing commands and continuing after failed commands until one
produces a preview. An extension-specific entry such as `pipelines['.blend']`
takes precedence over the type-level entry such as `pipelines.model`.

```lua
require('glimpse').setup({
  pipelines = {
    model = {
      previewers = {
        {
          command = 'first-model-renderer',
          args = { '{input}', '--output', '{output}' },
        },
        {
          command = 'fallback-model-renderer',
          args = { '{input}', '--output', '{output}' },
        },
      },
    },
  },
})
```

### Keymaps (Oil.nvim)

| Key         | Action                                            |
| ----------- | ------------------------------------------------- |
| `<leader>p` | Preview image/video side by side (reuses window)  |
| `;`         | Open image (configurable: current tab or new tab) |
| `q`         | Close image buffer and residual empty window      |

When an image is opened, the current window follows that file's directory, so `Oil.nvim` opens in the same folder.

<details>
<summary>Advanced: bind Oil float to current directory</summary>

```lua
-- Toggle open/close
vim.keymap.set('n', '<leader>e', function()
  require('glimpse.integrations.oil').toggle_float()
end)

-- Always open (useful if you handle close separately via Oil's own keymap)
vim.keymap.set('n', '<leader>E', function()
  require('glimpse.integrations.oil').open_float()
end)
```

Both ensure the float opens at the directory Oil is currently browsing,
even when the cursor is on an image buffer. To close, use Oil's built-in
close keymap (default `q` inside the float).

</details>

### Keymaps (Neo-tree)

Enable with `integrations = { neotree = { enable = true } }` in setup.

| Key         | Action                                          |
| ----------- | ----------------------------------------------- |
| `<leader>p` | Preview image/video side by side                |
| `;`         | Open image inline or video with external player |

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
      markdown = true,
      model = true,
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
- **3D models** render through the configured model pipeline inside the Telescope preview pane
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

| Tool                               | Purpose                               | When                |
| ---------------------------------- | ------------------------------------- | ------------------- |
| magick (ImageMagick)               | Image resize/conversion               | Image preview       |
| ffmpeg                             | Video thumbnail extraction            | Video preview       |
| openssl                            | X.509 certificate metadata extraction | Certificate preview |
| zipinfo                            | Archive listing (read-only)           | Archive preview     |
| tar                                | Archive listing (read-only)           | tar/tgz preview     |
| sqlite3                            | Schema listing (read-only)            | SQLite preview      |
| leaf / glow / mdcat / pandoc / cat | Markdown rendering                    | Markdown preview    |
| plantuml                           | PlantUML diagram rendering            | PlantUML preview    |
| mmdc                               | Mermaid diagram rendering             | Mermaid preview     |

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

| Terminal          | Strategy     | Method                                      |
| ----------------- | ------------ | ------------------------------------------- |
| Kitty             | inline       | Kitty Graphics + unicode placeholders       |
| Ghostty           | inline       | Kitty Graphics + unicode placeholders       |
| WezTerm           | pane         | `wezterm cli split-pane` + `wezterm imgcat` |
| iTerm2            | pane         | `imgcat`                                    |
| xterm/foot/mlterm | pane (sixel) | `magick ... sixel:-` via tmux               |

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

**Markdown:** MD, MARKDOWN, MDX, MDWN, MDOWN (requires leaf, glow, mdcat, pandoc, or cat)

**Diagrams:** PUML, PLANTUML, PU, WSD, IUML (PlantUML, requires plantuml + Java), MMD, MERMAID (Mermaid, requires mmdc)

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
│   ├── util.lua              -- Format detection (image, video, model, diagram, markdown...)
│   ├── archive.lua           -- Archive listing and suspicious path detection
│   ├── font.lua              -- Font metadata extraction and rendering
│   ├── sqlite.lua            -- SQLite schema preview
│   ├── safety.lua            -- File validation and safety checks
│   ├── pipeline.lua          -- Steps-based conversion pipeline (run_steps, run_sequence)
│   ├── pipeline_previewer.lua -- Shared runtime for pipeline-based previewers (tokens, animation, cleanup)
│   ├── previewer/
│   │   ├── archive.lua       -- Archive previewer
│   │   ├── cert.lua          -- X.509 certificate previewer
│   │   ├── binary.lua        -- Binary previewer (file + hexdump)
│   │   ├── font.lua          -- Font previewer
│   │   ├── image.lua         -- Inline image previewer
│   │   ├── key.lua           -- GPG/SSH key previewer
│   │   ├── markdown.lua      -- Markdown previewer (leaf/glow/mdcat/pandoc, terminal buffer)
│   │   ├── mermaid.lua       -- Mermaid diagram previewer (mmdc)
│   │   ├── plantuml.lua      -- PlantUML diagram previewer (plantuml -pipe)
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
