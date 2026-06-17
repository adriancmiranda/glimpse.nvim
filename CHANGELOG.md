# Changelog

<!-- markdownlint-disable MD012 MD024 -->

> All notable changes to glimpse.nvim will be documented in this file.

## [unreleased]

### 🚀 Features

- *(video)* Add configurable frame extraction width

### 📚 Documentation

- Add video.frames.width to README configuration example

### ⚡ Performance

- *(renderer)* Coalesce rapid rerender requests with a one-deep pending slot

### 🧪 Testing

- *(renderer)* Verify pending slot coalesces rapid rerenders to 2 spawns

### ⚙️ Miscellaneous Tasks

- *(ci)* Move merged PRs to Done in GitHub project board
- *(ci)* Bump github-script to v9 and move IDs to repository variables


## [2.1.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v2.0.0..v2.1.0) - 2026-06-16

### 🚀 Features

- *(kitty)* Auto-detect terminal cell pixel dimensions
- *(changelog)* Include commit body in changelog for breaking changes
- *(preview)* Separate preview state and oil image flow
- *(video)* Inline video playback via Kitty Animation Protocol

### 🐛 Bug Fixes

- *(docs)* Replace broken xxd vimhelp link with linux.die.net man page
- *(docs)* Fix v1.0.0 changelog link to point to commits
- *(telescope)* Scaffold investigation for stale render state (#71)
- *(telescope)* Close active Kitty render before text preview
- *(telescope)* Also clear stale image on disabled-kind fallback path
- *(oil)* Preserve cwd and open modes
- Move oil float context into glimpse
- Avoid vim.fs.isabspath in oil float
- *(types)* Resolve lua_ls diagnostic warnings across the codebase
- *(oil)* Resolve float dir from oil buffer state instead of process cwd
- Align animation state with placement_state
- Keep telescope text previews and renderer state consistent
- *(video)* Keep resize restarts from flashing
- *(video)* Reuse preview window across media kinds
- Scope media preview reuse to preview targets
- *(video)* Prevent stale animation from clobbering new preview state
- *(video)* Fix window ownership, thumbnail fallback target, and frame file tracking
- Harden video frame extraction
- *(video)* Cancel batch extraction when preview split is closed early

### 📚 Documentation

- Update README feature line and drop manual CHANGELOG entry

### 🧪 Testing

- *(telescope)* Add regression for stale Kitty image on text preview

### ⚙️ Miscellaneous Tasks

- Add stylua and luacheck to lint targets (from PR #67)
- Remove pipe strategy stub (will be implemented in a separate PR)


## [2.0.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.16.0..v2.0.0) - 2026-06-09

### 🚀 Features

- [**breaking**] Refactor public config contract


## [1.16.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.15.1..v1.16.0) - 2026-06-08

### 🚀 Features

- Telescope all previews
- *(glimpse)* Refine lfs pointer preview
- *(glimpse)* Support git lfs pointers
- *(telescope)* Add per-kind flags
- *(oil)* Make image opening configurable
- *(oil)* Support custom openers
- Separate cwd following from preview flow

### 🐛 Bug Fixes

- *(inline)* Avoid hit-enter on close
- *(telescope)* Keep preview buffers reusable
- *(glimpse)* Harden image buffer lifecycle
- *(glimpse)* Remove lfs interception
- Harden telescope cwd follow and thumbnail fallback

### 🚜 Refactor

- *(types)* Consolidate config aliases
- Isolate preview lifecycles

### 📚 Documentation

- Add optional ImageMagick policy example

### 🎨 Styling

- *(glimpse)* Fix stylua formatting
- *(telescope)* Wrap config aliases

### 🧪 Testing

- *(perf)* Add benchmark suite


## [1.15.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.15.0..v1.15.1) - 2026-05-27

### 🐛 Bug Fixes

- Avoid previewing json as binary
- Use mime encoding to detect binaries


## [1.15.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.2..v1.15.0) - 2026-05-25

### 🚀 Features

- Expose preview introspection

### 📚 Documentation

- Revert generated vimdoc
- Sync api references
- Translate comments to en-us
- Drop generated vimdoc

### ⚙️ Miscellaneous Tasks

- Harden docs workflow retry


## [1.14.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.1..v1.14.2) - 2026-05-24

### 🐛 Bug Fixes

- Follow image directory after open


## [1.14.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.0..v1.14.1) - 2026-05-24

### 🐛 Bug Fixes

- Reflow floating previews on resize

### ⚙️ Miscellaneous Tasks

- Harden changelog workflow retry
- Serialize release writers
- Serialize release writers without canceling
- Add manual release tag workflow
- Sync release tag workflow with main
- Add workflow icons


## [1.14.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.13.1..v1.14.0) - 2026-05-24

### 🚀 Features

- Add binary previewer
- Improve binary preview integration
- Improve previewer fallbacks

### 🐛 Bug Fixes

- Satisfy luacheck
- Harden test plenary discovery

### 📚 Documentation

- Add git-cliff changelog workflow
- Prune changelog boilerplate
- Update binary previewer tree
- Mention binary preview in README
- Clarify dependency guidance


## [1.13.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.13.0..v1.13.1) - 2026-05-22

### 🐛 Bug Fixes

- Show metadata for encrypted gpg files


## [1.13.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.12.0..v1.13.0) - 2026-05-22

### 🚀 Features

- Add x509 certificate preview
- Warn on suspicious certificates

### 🐛 Bug Fixes

- Detect pem certificates before private keys

### 📚 Documentation

- Refresh glimpse certificate docs


## [1.12.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.11.0..v1.12.0) - 2026-05-22

### 🚀 Features

- *(telescope)* Native integration via buffer_previewer_maker
- Add scoped telescope media previewer

### 🐛 Bug Fixes

- *(telescope)* Usar opts.winid do telescope ao invés de bufwinid no schedule_wrap


## [1.11.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.2..v1.11.0) - 2026-05-21

### 🚀 Features

- *(key)* Preview GPG and SSH key metadata

### 🚜 Refactor

- Extract previewers into previewer/ directory


## [1.10.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.1..v1.10.2) - 2026-05-21

### 🐛 Bug Fixes

- *(encoding)* Add UTF-8 validation + CP1252/Latin-1 heuristic fallback


## [1.10.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.0..v1.10.1) - 2026-05-21

### 🐛 Bug Fixes

- *(types)* Correct neotree config annotation to accept boolean|table
- *(renderer)* Guard nil dimensions + add pdf/avif to events + ghostscript docs

### 📚 Documentation

- Add sqlite extensions to setup example


## [1.10.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.9.0..v1.10.0) - 2026-05-21

### 🚀 Features

- *(archive)* Separate preview (summary) from show (full listing)


## [1.9.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.8.0..v1.9.0) - 2026-05-21

### 🚀 Features

- *(font)* Preview font metadata (family, style, weight, sample)

### 📚 Documentation

- Update lazy.nvim setup example with event-based loading
- Remove font extensions from setup example (not yet merged)


## [1.8.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.7.0..v1.8.0) - 2026-05-21

### 🚀 Features

- *(sqlite)* Preview database schema (tables and columns)


## [1.7.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.6.0..v1.7.0) - 2026-05-20

### 🚀 Features

- *(archive)* Preview contents of zip/tar archives

### 📚 Documentation

- Expand Security section into Security & Privacy


## [1.6.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.5.0..v1.6.0) - 2026-05-20

### 🚀 Features

- *(security)* Add SVG safety flags to magick calls


## [1.5.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.4.0..v1.5.0) - 2026-05-20

### 🚀 Features

- *(security)* Validate files before processing (symlinks, size)


## [1.4.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.3.1..v1.4.0) - 2026-05-20

### 🚀 Features

- *(renderer)* Cancel stale conversion jobs on new request


## [1.3.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.3.0..v1.3.1) - 2026-05-20

### 🐛 Bug Fixes

- *(security)* Use list args instead of string.format for shell commands


## [1.3.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.2.1..v1.3.0) - 2026-05-20

### 🚀 Features

- *(cache)* Auto-cleanup files older than cache_max_age_days

### 📚 Documentation

- Add cache_max_age_days option to README


## [1.2.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.2.0..v1.2.1) - 2026-05-20

### 🐛 Bug Fixes

- *(cache)* Incluir mtime na chave do cache para invalidacao automatica

### 📚 Documentation

- Translate CONTRIBUTING to English


## [1.2.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.1.1..v1.2.0) - 2026-05-20

### 🚀 Features

- Open images via pane in WezTerm instead of binary buffer
- WezTerm pane reuse with read-eval loop, open via pane on ;


## [1.1.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.1.0..v1.1.1) - 2026-05-20

### 🐛 Bug Fixes

- Detect active WezTerm socket by checking PID

### 📚 Documentation

- Update README and CONTRIBUTING with Neo-tree integration


## [1.1.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.3..v1.1.0) - 2026-05-19

### 🚀 Features

- Add Neo-tree integration
- Implement Neo-tree integration
- Auto-preview with dedicated window, pane fallback for WezTerm
- Add auto_preview config and cleanup on Neo-tree close

### 📚 Documentation

- Translate README to English
- Translate issue templates to English
- Translate Neo-tree section to English, update config example

### 🎨 Styling

- Replace unicode arrow with ASCII in comment


## [1.0.3](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.2..v1.0.3) - 2026-05-19

### 🐛 Bug Fixes

- Use unique image IDs per tmux pane to prevent placement leaks
- Scope image IDs per tmux pane to prevent placement leaks

### 📚 Documentation

- Update CONTRIBUTING with video, wezterm socket, telescope info
- Fix Portuguese accents in CONTRIBUTING


## [1.0.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.1..v1.0.2) - 2026-05-19

### 🐛 Bug Fixes

- Oil opens wrong directory after viewing image
- Restore correct directory when Oil reopens after image view


## [1.0.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.0..v1.0.1) - 2026-05-18

### 🐛 Bug Fixes

- Auto-detect WezTerm socket inside tmux
- Auto-detect WezTerm socket for tmux environments


## [1.0.0](https://github.com/adriancmiranda/glimpse.nvim/compare/..v1.0.0) - 2026-05-18

### 🚀 Features

- Glimpse.nvim - image and video preview for Neovim

### 📚 Documentation

- Add WezTerm + tmux troubleshooting to README

