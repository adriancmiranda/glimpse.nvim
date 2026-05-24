# Changelog

<!-- markdownlint-disable MD012 MD024 -->

> All notable changes to glimpse.nvim will be documented in this file.

## [unreleased]

### ⚙️ Miscellaneous Tasks

- Harden changelog workflow retry
- Serialize release writers
- Serialize release writers without canceling
- Add manual release tag workflow
- Sync release tag workflow with main


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

