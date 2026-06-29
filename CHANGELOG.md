# Changelog

<!-- markdownlint-disable MD012 MD024 -->

> All notable changes to glimpse.nvim will be documented in this file.

## [unreleased]

### 🚀 Features

- [`7cd0126`](https://github.com/adriancmiranda/glimpse.nvim/commit/7cd0126961c8e6aed2cd0b2bca0a215f8f13b4cf) [#123](https://github.com/adriancmiranda/glimpse.nvim/pull/123 "PR de @adriancmiranda") Add :GlimpseClearCache command with optional images/previews argument
- [`e87b0d8`](https://github.com/adriancmiranda/glimpse.nvim/commit/e87b0d8ec5b4e07ce6d7a674660a52ff891f9b04) [#124](https://github.com/adriancmiranda/glimpse.nvim/pull/124 "PR de @adriancmiranda") Add pipe frame extraction strategy
- [`dfd96dd`](https://github.com/adriancmiranda/glimpse.nvim/commit/dfd96ddcb377411b4bf31fc8cd2b0cb2a87c9c45) [#128](https://github.com/adriancmiranda/glimpse.nvim/pull/128 "PR de @adriancmiranda") Add manual playback for pipeline animations
- [`f153495`](https://github.com/adriancmiranda/glimpse.nvim/commit/f1534955d338997edcab568eacc6d0a93ec281f3) [#133](https://github.com/adriancmiranda/glimpse.nvim/pull/133 "PR de @adriancmiranda") *(telescope)* Render markdown previews

### 🐛 Bug Fixes

- [`2cbec35`](https://github.com/adriancmiranda/glimpse.nvim/commit/2cbec35d3bc37fa17d26d83a4d2b32332f40fba1) [#125](https://github.com/adriancmiranda/glimpse.nvim/pull/125 "PR de @adriancmiranda") Handle opts table in model.preview and model.show
- [`5507509`](https://github.com/adriancmiranda/glimpse.nvim/commit/55075090b9b37b903c7665813057fa546a73789f) [#134](https://github.com/adriancmiranda/glimpse.nvim/pull/134 "PR de @adriancmiranda") *(markdown)* Fall back to raw text without renderer

### 📚 Documentation

- [`99ffe33`](https://github.com/adriancmiranda/glimpse.nvim/commit/99ffe33fb1890e6898226e9e604326e01d065018) Document pipe as default frame extraction strategy
- [`b014357`](https://github.com/adriancmiranda/glimpse.nvim/commit/b01435703240a8f7e30ea4e4ec3f06a615bff27f) [#129](https://github.com/adriancmiranda/glimpse.nvim/pull/129 "PR de @adriancmiranda") Highlight default configuration
- [`3ddd930`](https://github.com/adriancmiranda/glimpse.nvim/commit/3ddd9302d6ea70736e427d8e1886f63c7a96973b) [#130](https://github.com/adriancmiranda/glimpse.nvim/pull/130 "PR de @adriancmiranda") Link pull requests in changelog


## [2.2.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v2.1.0..v2.2.0) - 2026-06-23

### 🚀 Features

- [`bb0577e`](https://github.com/adriancmiranda/glimpse.nvim/commit/bb0577e664dbbbb37438455a52b1f40ed85157a3) [#88](https://github.com/adriancmiranda/glimpse.nvim/pull/88 "PR de @adriancmiranda") *(video)* Add configurable frame extraction width
- [`35fe92c`](https://github.com/adriancmiranda/glimpse.nvim/commit/35fe92c4a2a4eee76254be3cde273f5d6eaacc40) [#87](https://github.com/adriancmiranda/glimpse.nvim/pull/87 "PR de @adriancmiranda") *(model)* Add 3D model previews via conversion pipeline
- [`70430c7`](https://github.com/adriancmiranda/glimpse.nvim/commit/70430c732d5b17bfb678287e69aca6e4d6de5353) [#99](https://github.com/adriancmiranda/glimpse.nvim/pull/99 "PR de @adriancmiranda") *(markdown)* Add Markdown previewer with configurable CLI renderer
- [`cc8c145`](https://github.com/adriancmiranda/glimpse.nvim/commit/cc8c145dacd7bddc360452f1509a4999b4657de4) [#100](https://github.com/adriancmiranda/glimpse.nvim/pull/100 "PR de @adriancmiranda") *(plantuml)* Add PlantUML diagram previewer via pipeline
- [`af1c21b`](https://github.com/adriancmiranda/glimpse.nvim/commit/af1c21b48b49027c8e205f6fbd094ed5b1268f79) [#108](https://github.com/adriancmiranda/glimpse.nvim/pull/108 "PR de @adriancmiranda") Make float preview sizes configurable
- [`264f9f9`](https://github.com/adriancmiranda/glimpse.nvim/commit/264f9f93624dfa2acff25269f5e569ee0ba4768a) [#111](https://github.com/adriancmiranda/glimpse.nvim/pull/111 "PR de @adriancmiranda") *(mermaid)* Add Mermaid diagram previewer via pipeline
- [`178ad46`](https://github.com/adriancmiranda/glimpse.nvim/commit/178ad46fa19e801db06f16d9653393acbc595e4d) [#109](https://github.com/adriancmiranda/glimpse.nvim/pull/109 "PR de @adriancmiranda") Add safe automatic preview opening
- [`285c8fd`](https://github.com/adriancmiranda/glimpse.nvim/commit/285c8fd90e7d0e3c127e2f73ce75e0cce28d9506) [#117](https://github.com/adriancmiranda/glimpse.nvim/pull/117 "PR de @adriancmiranda") *(pipeline)* Add previewer fallback chains
- [`e3d99b5`](https://github.com/adriancmiranda/glimpse.nvim/commit/e3d99b5f221f5c7f8444867f3db4ed22981f6d4e) [#118](https://github.com/adriancmiranda/glimpse.nvim/pull/118 "PR de @adriancmiranda") *(model)* Add Blender fallback for blend files
- [`74f2ace`](https://github.com/adriancmiranda/glimpse.nvim/commit/74f2acefce2a3a2dba3ed5fa6805d6dd104747ae) [#119](https://github.com/adriancmiranda/glimpse.nvim/pull/119 "PR de @adriancmiranda") Add GlimpsePreview command
- [`9f0dd91`](https://github.com/adriancmiranda/glimpse.nvim/commit/9f0dd918baa7a44959c9417aca5658dad569c08f) [#120](https://github.com/adriancmiranda/glimpse.nvim/pull/120 "PR de @adriancmiranda") Auto-refresh previews on save
- [`a18241d`](https://github.com/adriancmiranda/glimpse.nvim/commit/a18241d0477140e136b15d1bf6005ad7325ce324) [#122](https://github.com/adriancmiranda/glimpse.nvim/pull/122 "PR de @adriancmiranda") Extend :GlimpsePreview with optional [window] and [path] arguments

### 🐛 Bug Fixes

- [`52f0321`](https://github.com/adriancmiranda/glimpse.nvim/commit/52f03211502c8a507f6f77ef93521688f5028700) [#93](https://github.com/adriancmiranda/glimpse.nvim/pull/93 "PR de @adriancmiranda") *(telescope)* Render media previews immediately
- [`99a4212`](https://github.com/adriancmiranda/glimpse.nvim/commit/99a42129085cd5eaaaa1adcc9cfe87ebda924052) [#95](https://github.com/adriancmiranda/glimpse.nvim/pull/95 "PR de @adriancmiranda") *(renderer)* Use source filename as preview buffer name instead of image hash
- [`3d1830f`](https://github.com/adriancmiranda/glimpse.nvim/commit/3d1830f6bb1ba16a5c904b95d086becbde21b44c) [#97](https://github.com/adriancmiranda/glimpse.nvim/pull/97 "PR de @adriancmiranda") *(video)* Stop animation and timers when preview window is closed directly
- [`337db59`](https://github.com/adriancmiranda/glimpse.nvim/commit/337db59d7c56e00157c496b2ad353fa513b3e842) [#96](https://github.com/adriancmiranda/glimpse.nvim/pull/96 "PR de @adriancmiranda") *(preview)* Show filename instead of sha256 hash in preview buffer names
- [`419b780`](https://github.com/adriancmiranda/glimpse.nvim/commit/419b780feb3f8e132ecf7a133593a3e77ac42a9c) [#87](https://github.com/adriancmiranda/glimpse.nvim/pull/87 "PR de @adriancmiranda") *(model)* Name preview buffer with model filename instead of image hash
- [`695a84f`](https://github.com/adriancmiranda/glimpse.nvim/commit/695a84f3198107e3e6b61dec4b57e85cd58aedf9) [#87](https://github.com/adriancmiranda/glimpse.nvim/pull/87 "PR de @adriancmiranda") *(model)* Pass filepath to setup_animation_buf for buffer naming
- [`37eb2b2`](https://github.com/adriancmiranda/glimpse.nvim/commit/37eb2b2e2990e060a7f70d9d310ab5c93666d280) [#99](https://github.com/adriancmiranda/glimpse.nvim/pull/99 "PR de @adriancmiranda") *(float)* Omit title_pos when title is nil
- [`de59297`](https://github.com/adriancmiranda/glimpse.nvim/commit/de5929791311a936f166cf85f6546d2cbd14eabd) [#99](https://github.com/adriancmiranda/glimpse.nvim/pull/99 "PR de @adriancmiranda") *(markdown)* Use terminal buffer for ANSI colors and ansi leaf spec
- [`88e5573`](https://github.com/adriancmiranda/glimpse.nvim/commit/88e5573ba92ab1e87329a3b2c0ea88bb8abf87fe) [#107](https://github.com/adriancmiranda/glimpse.nvim/pull/107 "PR de @adriancmiranda") *(float)* Bind close keymap in every float window
- [`43b0ae6`](https://github.com/adriancmiranda/glimpse.nvim/commit/43b0ae6560f5fa5d01ce25e89070a9a12a0db92f) [#110](https://github.com/adriancmiranda/glimpse.nvim/pull/110 "PR de @adriancmiranda") *(video)* Cancel in-flight extraction when preview window closes
- [`cec2c46`](https://github.com/adriancmiranda/glimpse.nvim/commit/cec2c465bd90ff65761a8be658bc0d1c8842b198) [#114](https://github.com/adriancmiranda/glimpse.nvim/pull/114 "PR de @adriancmiranda") *(oil)* Refresh images after toggling float
- [`984f6b0`](https://github.com/adriancmiranda/glimpse.nvim/commit/984f6b075974f23e52a301d611df2d5b22273b58) [#115](https://github.com/adriancmiranda/glimpse.nvim/pull/115 "PR de @adriancmiranda") *(auto-open)* Keep model files in text buffers
- [`78c150c`](https://github.com/adriancmiranda/glimpse.nvim/commit/78c150c43086f37fb6dd0ce7f7e8accc2d53f804) [#116](https://github.com/adriancmiranda/glimpse.nvim/pull/116 "PR de @adriancmiranda") *(auto-open)* Keep models as text inline
- [`98b9f59`](https://github.com/adriancmiranda/glimpse.nvim/commit/98b9f593885ba692f2a819e98a6551cd3a3d642f) Replace em dash with hyphen in auto-refresh feature bullet

### 🚜 Refactor

- [`2620138`](https://github.com/adriancmiranda/glimpse.nvim/commit/262013818aa6fc539a5188a051fc52a971f001ce) [#95](https://github.com/adriancmiranda/glimpse.nvim/pull/95 "PR de @adriancmiranda") *(renderer)* Extract buffer label into local variable
- [`92daec7`](https://github.com/adriancmiranda/glimpse.nvim/commit/92daec7ae89f8c44982c77489bd86a9c5807be66) [#98](https://github.com/adriancmiranda/glimpse.nvim/pull/98 "PR de @adriancmiranda") *(model)* Extract pipeline_previewer as shared runtime
- [`f38008e`](https://github.com/adriancmiranda/glimpse.nvim/commit/f38008e35ced57c28fe3913f32dc0f5b9d4650ae) [#113](https://github.com/adriancmiranda/glimpse.nvim/pull/113 "PR de @adriancmiranda") *(config)* Centralize public defaults

### 📚 Documentation

- [`ed04496`](https://github.com/adriancmiranda/glimpse.nvim/commit/ed04496a6cef9a573aeb20d3145d9ff0e656553b) [#89](https://github.com/adriancmiranda/glimpse.nvim/pull/89 "PR de @adriancmiranda") Add video.frames.width to README configuration example
- [`702c875`](https://github.com/adriancmiranda/glimpse.nvim/commit/702c875fa17513202aa6263a5ccbc65cc73dccf8) [#90](https://github.com/adriancmiranda/glimpse.nvim/pull/90 "PR de @adriancmiranda") Document oil.toggle_float integration and allow details/summary HTML
- [`59351b7`](https://github.com/adriancmiranda/glimpse.nvim/commit/59351b74b5cfc4ef6e1aa0e0dac1ac77cb0e9ec7) [#94](https://github.com/adriancmiranda/glimpse.nvim/pull/94 "PR de @adriancmiranda") *(changelog)* Prefix each entry with a linked commit hash
- [`8a62200`](https://github.com/adriancmiranda/glimpse.nvim/commit/8a62200174f3440d705ddb57b2b4112b1382bd0e) [#87](https://github.com/adriancmiranda/glimpse.nvim/pull/87 "PR de @adriancmiranda") *(contributing)* Add f3d dependency, pipeline.lua and model.lua to code structure
- [`c4ded15`](https://github.com/adriancmiranda/glimpse.nvim/commit/c4ded15ee06d5cf455221e48e8f224554eab3a45) [#102](https://github.com/adriancmiranda/glimpse.nvim/pull/102 "PR de @adriancmiranda") Update README and CONTRIBUTING for markdown, plantuml and mermaid previewers
- [`665cf20`](https://github.com/adriancmiranda/glimpse.nvim/commit/665cf20181866b3a7dda06d4e4b3caca80dd906a) Clarify float.markdown.width default in config example
- [`375389d`](https://github.com/adriancmiranda/glimpse.nvim/commit/375389d0b327b0506d84678b64bec256052170b5) [#112](https://github.com/adriancmiranda/glimpse.nvim/pull/112 "PR de @adriancmiranda") Simplify lazy-loading setup

### ⚡ Performance

- [`10687f7`](https://github.com/adriancmiranda/glimpse.nvim/commit/10687f7dd2f5c04726086f920b8ddd3cd756fe8b) [#83](https://github.com/adriancmiranda/glimpse.nvim/pull/83 "PR de @adriancmiranda") *(renderer)* Coalesce rapid rerender requests with a one-deep pending slot

### 🧪 Testing

- [`b706cf7`](https://github.com/adriancmiranda/glimpse.nvim/commit/b706cf70211bea7f05f21d39424e2eaa2044b9d1) [#83](https://github.com/adriancmiranda/glimpse.nvim/pull/83 "PR de @adriancmiranda") *(renderer)* Verify pending slot coalesces rapid rerenders to 2 spawns

### ⚙️ Miscellaneous Tasks

- [`81464d6`](https://github.com/adriancmiranda/glimpse.nvim/commit/81464d6dc42b7718131f0e3ba17599a45fe03b9a) [#84](https://github.com/adriancmiranda/glimpse.nvim/pull/84 "PR de @adriancmiranda") *(ci)* Move merged PRs to Done in GitHub project board
- [`1265820`](https://github.com/adriancmiranda/glimpse.nvim/commit/12658203dfb92678c055181dce202ca4d6b3b59f) [#85](https://github.com/adriancmiranda/glimpse.nvim/pull/85 "PR de @adriancmiranda") *(ci)* Bump github-script to v9 and move IDs to repository variables


## [2.1.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v2.0.0..v2.1.0) - 2026-06-16

### 🚀 Features

- [`028935b`](https://github.com/adriancmiranda/glimpse.nvim/commit/028935be248bd7e28176794ac8dfb8d4b8d48887) [#64](https://github.com/adriancmiranda/glimpse.nvim/pull/64 "PR de @adriancmiranda") *(kitty)* Auto-detect terminal cell pixel dimensions
- [`68e2fc8`](https://github.com/adriancmiranda/glimpse.nvim/commit/68e2fc8ddb2ae77ce8dafe0a8d8f568aede52b0e) *(changelog)* Include commit body in changelog for breaking changes
- [`c2f5e84`](https://github.com/adriancmiranda/glimpse.nvim/commit/c2f5e84f1078a2a978d79ff218885936863d1754) [#78](https://github.com/adriancmiranda/glimpse.nvim/pull/78 "PR de @adriancmiranda") *(preview)* Separate preview state and oil image flow
- [`40decd1`](https://github.com/adriancmiranda/glimpse.nvim/commit/40decd10f426223c6f0c2e36c76484112710a7cd) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") *(video)* Inline video playback via Kitty Animation Protocol

### 🐛 Bug Fixes

- [`73d0f77`](https://github.com/adriancmiranda/glimpse.nvim/commit/73d0f773379a7d88112964c8978ad047a0ec5a0c) *(docs)* Replace broken xxd vimhelp link with linux.die.net man page
- [`49edd95`](https://github.com/adriancmiranda/glimpse.nvim/commit/49edd958ede8dc520d5560fdb814f461bf7d4b07) *(docs)* Fix v1.0.0 changelog link to point to commits
- [`dd26d2d`](https://github.com/adriancmiranda/glimpse.nvim/commit/dd26d2dbeab95c2219da628dddf195a6b927faa7) [#76](https://github.com/adriancmiranda/glimpse.nvim/pull/76 "PR de @adriancmiranda") *(telescope)* Scaffold investigation for stale render state (#71)
- [`ebf5653`](https://github.com/adriancmiranda/glimpse.nvim/commit/ebf565300a018613e25af7ff12bef003b7858221) [#76](https://github.com/adriancmiranda/glimpse.nvim/pull/76 "PR de @adriancmiranda") *(telescope)* Close active Kitty render before text preview
- [`ca9eaea`](https://github.com/adriancmiranda/glimpse.nvim/commit/ca9eaea59ba33bc18f5284de4fa8435ffb7eb77a) [#76](https://github.com/adriancmiranda/glimpse.nvim/pull/76 "PR de @adriancmiranda") *(telescope)* Also clear stale image on disabled-kind fallback path
- [`7a69df9`](https://github.com/adriancmiranda/glimpse.nvim/commit/7a69df9a5002d3a95596daa2569cd41bc6cb0b40) [#78](https://github.com/adriancmiranda/glimpse.nvim/pull/78 "PR de @adriancmiranda") *(oil)* Preserve cwd and open modes
- [`10cc3ea`](https://github.com/adriancmiranda/glimpse.nvim/commit/10cc3ea9d9dc053e0d88c9047f9e6d8cf4515f50) [#79](https://github.com/adriancmiranda/glimpse.nvim/pull/79 "PR de @adriancmiranda") Move oil float context into glimpse
- [`1d7fbcf`](https://github.com/adriancmiranda/glimpse.nvim/commit/1d7fbcf32777af671de0bdd95ff6c60b1901f774) [#79](https://github.com/adriancmiranda/glimpse.nvim/pull/79 "PR de @adriancmiranda") Avoid vim.fs.isabspath in oil float
- [`aa06fcb`](https://github.com/adriancmiranda/glimpse.nvim/commit/aa06fcb428aaa0af1be2a2e136e9850c0e1f7179) [#79](https://github.com/adriancmiranda/glimpse.nvim/pull/79 "PR de @adriancmiranda") *(types)* Resolve lua_ls diagnostic warnings across the codebase
- [`9c0879b`](https://github.com/adriancmiranda/glimpse.nvim/commit/9c0879b215e683db24d5f69ec961f4887b97d05a) [#80](https://github.com/adriancmiranda/glimpse.nvim/pull/80 "PR de @adriancmiranda") *(oil)* Resolve float dir from oil buffer state instead of process cwd
- [`52e08da`](https://github.com/adriancmiranda/glimpse.nvim/commit/52e08da431f52a5023607f6693e0db56802cfd32) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") Align animation state with placement_state
- [`c4c7fa4`](https://github.com/adriancmiranda/glimpse.nvim/commit/c4c7fa492a7a177147253cc5e36579aa35687651) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") Keep telescope text previews and renderer state consistent
- [`90030d9`](https://github.com/adriancmiranda/glimpse.nvim/commit/90030d939f2ddce1009e7d837892fe0773115043) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") *(video)* Keep resize restarts from flashing
- [`68f9fab`](https://github.com/adriancmiranda/glimpse.nvim/commit/68f9fab6dca372d6a79395176e7a461a45d448bb) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") *(video)* Reuse preview window across media kinds
- [`e178eb6`](https://github.com/adriancmiranda/glimpse.nvim/commit/e178eb645cadc015f32c2b977567147288cd223d) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") Scope media preview reuse to preview targets
- [`8483471`](https://github.com/adriancmiranda/glimpse.nvim/commit/8483471a30e79003cff65ca49ae998a3871bcf50) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") *(video)* Prevent stale animation from clobbering new preview state
- [`4b41262`](https://github.com/adriancmiranda/glimpse.nvim/commit/4b412629683936075629f8e72e648108064630dd) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") *(video)* Fix window ownership, thumbnail fallback target, and frame file tracking
- [`605091d`](https://github.com/adriancmiranda/glimpse.nvim/commit/605091d5ee4bfbdb527676ce3a731e58e542213d) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") Harden video frame extraction
- [`2a66380`](https://github.com/adriancmiranda/glimpse.nvim/commit/2a663809e9ddf2d353cec3d4de8cfe17fa7eb3dd) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") *(video)* Cancel batch extraction when preview split is closed early

### 📚 Documentation

- [`85b7e84`](https://github.com/adriancmiranda/glimpse.nvim/commit/85b7e84e33cd545eed3d980d5b4ede0e855633a0) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") Update README feature line and drop manual CHANGELOG entry

### 🧪 Testing

- [`59fd051`](https://github.com/adriancmiranda/glimpse.nvim/commit/59fd05167e4d787db0ac880f3cd58f24023b3b52) [#76](https://github.com/adriancmiranda/glimpse.nvim/pull/76 "PR de @adriancmiranda") *(telescope)* Add regression for stale Kitty image on text preview

### ⚙️ Miscellaneous Tasks

- [`beed14b`](https://github.com/adriancmiranda/glimpse.nvim/commit/beed14bd9f1013a2fa26b21ec2714a401936d9c7) Add stylua and luacheck to lint targets (from [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda"))
- [`b5097c5`](https://github.com/adriancmiranda/glimpse.nvim/commit/b5097c5d39af81cfe378570cc0076164ea9dc65c) [#67](https://github.com/adriancmiranda/glimpse.nvim/pull/67 "PR de @adriancmiranda") Remove pipe strategy stub (will be implemented in a separate PR)


## [2.0.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.16.0..v2.0.0) - 2026-06-09

### 🚀 Features

- [`26357a0`](https://github.com/adriancmiranda/glimpse.nvim/commit/26357a0fc737d94c132179f26a717094b6b544fe) [#63](https://github.com/adriancmiranda/glimpse.nvim/pull/63 "PR de @adriancmiranda") [**breaking**] Refactor public config contract


## [1.16.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.15.1..v1.16.0) - 2026-06-08

### 🚀 Features

- [`a1d2f07`](https://github.com/adriancmiranda/glimpse.nvim/commit/a1d2f070817c34d270c4d5e5adc2c6fb31510275) [#48](https://github.com/adriancmiranda/glimpse.nvim/pull/48 "PR de @adriancmiranda") Telescope all previews
- [`094e48b`](https://github.com/adriancmiranda/glimpse.nvim/commit/094e48b715319dfd8a4b146dc5374e7f9ceb0a66) [#48](https://github.com/adriancmiranda/glimpse.nvim/pull/48 "PR de @adriancmiranda") *(glimpse)* Refine lfs pointer preview
- [`65a5789`](https://github.com/adriancmiranda/glimpse.nvim/commit/65a578997f2b1925c33e9e0f7598e1b5d553cf45) [#48](https://github.com/adriancmiranda/glimpse.nvim/pull/48 "PR de @adriancmiranda") *(glimpse)* Support git lfs pointers
- [`6cb2986`](https://github.com/adriancmiranda/glimpse.nvim/commit/6cb298612c0f927e57544b64d3001acc3d4cc2f4) [#52](https://github.com/adriancmiranda/glimpse.nvim/pull/52 "PR de @adriancmiranda") *(telescope)* Add per-kind flags
- [`d173e39`](https://github.com/adriancmiranda/glimpse.nvim/commit/d173e3928609342c31e393b4ce6e5546f7f6db4d) [#58](https://github.com/adriancmiranda/glimpse.nvim/pull/58 "PR de @adriancmiranda") *(oil)* Make image opening configurable
- [`75e11d9`](https://github.com/adriancmiranda/glimpse.nvim/commit/75e11d96d89bfdd2f4d6ffb01ace0adeecb876bf) [#58](https://github.com/adriancmiranda/glimpse.nvim/pull/58 "PR de @adriancmiranda") *(oil)* Support custom openers
- [`233f9c7`](https://github.com/adriancmiranda/glimpse.nvim/commit/233f9c724b8186749525de92c4b5feb585677e8c) [#62](https://github.com/adriancmiranda/glimpse.nvim/pull/62 "PR de @adriancmiranda") Separate cwd following from preview flow

### 🐛 Bug Fixes

- [`e75005a`](https://github.com/adriancmiranda/glimpse.nvim/commit/e75005ae544c5d1f5c5f2d8677807accc5b38499) [#55](https://github.com/adriancmiranda/glimpse.nvim/pull/55 "PR de @adriancmiranda") *(inline)* Avoid hit-enter on close
- [`b36ba8a`](https://github.com/adriancmiranda/glimpse.nvim/commit/b36ba8ad3881ca01d8ecba72ff61b13e1ce5cb1f) [#57](https://github.com/adriancmiranda/glimpse.nvim/pull/57 "PR de @adriancmiranda") *(telescope)* Keep preview buffers reusable
- [`35fdcd0`](https://github.com/adriancmiranda/glimpse.nvim/commit/35fdcd0ed5bb3470e855d0f063e1f6f4fafc12de) [#59](https://github.com/adriancmiranda/glimpse.nvim/pull/59 "PR de @adriancmiranda") *(glimpse)* Harden image buffer lifecycle
- [`27a3664`](https://github.com/adriancmiranda/glimpse.nvim/commit/27a366434b5a46e4fbc92d947415752fc1e9de54) [#56](https://github.com/adriancmiranda/glimpse.nvim/pull/56 "PR de @adriancmiranda") *(glimpse)* Remove lfs interception
- [`8f62159`](https://github.com/adriancmiranda/glimpse.nvim/commit/8f621598e0c6c1458ae469657efb70d88733f3ff) [#62](https://github.com/adriancmiranda/glimpse.nvim/pull/62 "PR de @adriancmiranda") Harden telescope cwd follow and thumbnail fallback

### 🚜 Refactor

- [`3fd3633`](https://github.com/adriancmiranda/glimpse.nvim/commit/3fd36330bb5e7762a5164ca05223545e6c5c4acf) [#54](https://github.com/adriancmiranda/glimpse.nvim/pull/54 "PR de @adriancmiranda") *(types)* Consolidate config aliases
- [`f5bf2a8`](https://github.com/adriancmiranda/glimpse.nvim/commit/f5bf2a88e375f9c9657fa44418f212f9b1c79a8e) [#62](https://github.com/adriancmiranda/glimpse.nvim/pull/62 "PR de @adriancmiranda") Isolate preview lifecycles

### 📚 Documentation

- [`0bceebc`](https://github.com/adriancmiranda/glimpse.nvim/commit/0bceebc9499c849fe179f0e0c5e7108f2a6c98d4) [#47](https://github.com/adriancmiranda/glimpse.nvim/pull/47 "PR de @adriancmiranda") Add optional ImageMagick policy example

### 🎨 Styling

- [`8365314`](https://github.com/adriancmiranda/glimpse.nvim/commit/8365314d67656dc298db103776d966923840492f) [#48](https://github.com/adriancmiranda/glimpse.nvim/pull/48 "PR de @adriancmiranda") *(glimpse)* Fix stylua formatting
- [`490335e`](https://github.com/adriancmiranda/glimpse.nvim/commit/490335e37bde5c422512e1cc36f9ccf40878ee2c) [#52](https://github.com/adriancmiranda/glimpse.nvim/pull/52 "PR de @adriancmiranda") *(telescope)* Wrap config aliases

### 🧪 Testing

- [`5563cca`](https://github.com/adriancmiranda/glimpse.nvim/commit/5563cca9c0ca5f4c67470aa66042afa3bff0ab6f) [#53](https://github.com/adriancmiranda/glimpse.nvim/pull/53 "PR de @adriancmiranda") *(perf)* Add benchmark suite


## [1.15.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.15.0..v1.15.1) - 2026-05-27

### 🐛 Bug Fixes

- [`4e15c04`](https://github.com/adriancmiranda/glimpse.nvim/commit/4e15c04428cb915fa79444da96674e2dadc830de) [#46](https://github.com/adriancmiranda/glimpse.nvim/pull/46 "PR de @adriancmiranda") Avoid previewing json as binary
- [`d322285`](https://github.com/adriancmiranda/glimpse.nvim/commit/d322285b4382db7f00f0267a8562307563bbd2f8) [#46](https://github.com/adriancmiranda/glimpse.nvim/pull/46 "PR de @adriancmiranda") Use mime encoding to detect binaries


## [1.15.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.2..v1.15.0) - 2026-05-25

### 🚀 Features

- [`a78d2f0`](https://github.com/adriancmiranda/glimpse.nvim/commit/a78d2f0406a3bf67e55376d7a03e4c7181564204) [#43](https://github.com/adriancmiranda/glimpse.nvim/pull/43 "PR de @adriancmiranda") Expose preview introspection

### 📚 Documentation

- [`0589cdf`](https://github.com/adriancmiranda/glimpse.nvim/commit/0589cdff65c69d7d8c250125cf19d1e031465cf1) [#43](https://github.com/adriancmiranda/glimpse.nvim/pull/43 "PR de @adriancmiranda") Revert generated vimdoc
- [`8bcfe2b`](https://github.com/adriancmiranda/glimpse.nvim/commit/8bcfe2b62972a20c1323a79fdd92a1311c12bb91) [#43](https://github.com/adriancmiranda/glimpse.nvim/pull/43 "PR de @adriancmiranda") Sync api references
- [`6efec96`](https://github.com/adriancmiranda/glimpse.nvim/commit/6efec96a605d25c32b5fe274a4338ee26b4e5d1d) [#44](https://github.com/adriancmiranda/glimpse.nvim/pull/44 "PR de @adriancmiranda") Translate comments to en-us
- [`8fc94f8`](https://github.com/adriancmiranda/glimpse.nvim/commit/8fc94f87c2dfae7df29c5d6b4f4256603ca8f24f) [#44](https://github.com/adriancmiranda/glimpse.nvim/pull/44 "PR de @adriancmiranda") Drop generated vimdoc

### ⚙️ Miscellaneous Tasks

- [`cdef3fa`](https://github.com/adriancmiranda/glimpse.nvim/commit/cdef3fa4c464d2fa7dcabb96e00e23c3e0394220) [#42](https://github.com/adriancmiranda/glimpse.nvim/pull/42 "PR de @adriancmiranda") Harden docs workflow retry


## [1.14.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.1..v1.14.2) - 2026-05-24

### 🐛 Bug Fixes

- [`7c50b46`](https://github.com/adriancmiranda/glimpse.nvim/commit/7c50b4607940762a522d2fde0a237923cb2e70f7) [#41](https://github.com/adriancmiranda/glimpse.nvim/pull/41 "PR de @adriancmiranda") Follow image directory after open


## [1.14.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.0..v1.14.1) - 2026-05-24

### 🐛 Bug Fixes

- [`8180b43`](https://github.com/adriancmiranda/glimpse.nvim/commit/8180b43c1c24fdd64b066c6f1ba58fed25a03641) [#39](https://github.com/adriancmiranda/glimpse.nvim/pull/39 "PR de @adriancmiranda") Reflow floating previews on resize

### ⚙️ Miscellaneous Tasks

- [`beb0a95`](https://github.com/adriancmiranda/glimpse.nvim/commit/beb0a955e1a6b82a5c53a8307e2783ab2aab3f70) [#36](https://github.com/adriancmiranda/glimpse.nvim/pull/36 "PR de @adriancmiranda") Harden changelog workflow retry
- [`3966752`](https://github.com/adriancmiranda/glimpse.nvim/commit/3966752bc648c1d4cea164b2429aa8c36316b159) [#38](https://github.com/adriancmiranda/glimpse.nvim/pull/38 "PR de @adriancmiranda") Serialize release writers
- [`7dd5d5d`](https://github.com/adriancmiranda/glimpse.nvim/commit/7dd5d5d1b16cb100b4b4d8bdc76cf2da07b2d470) [#38](https://github.com/adriancmiranda/glimpse.nvim/pull/38 "PR de @adriancmiranda") Serialize release writers without canceling
- [`c85a772`](https://github.com/adriancmiranda/glimpse.nvim/commit/c85a772c7b6ccabc55d432370b97110772527d2a) [#37](https://github.com/adriancmiranda/glimpse.nvim/pull/37 "PR de @adriancmiranda") Add manual release tag workflow
- [`e192640`](https://github.com/adriancmiranda/glimpse.nvim/commit/e192640f540edb8cd3d465a5339271a6beff7d4c) [#37](https://github.com/adriancmiranda/glimpse.nvim/pull/37 "PR de @adriancmiranda") Sync release tag workflow with main
- [`0ef872f`](https://github.com/adriancmiranda/glimpse.nvim/commit/0ef872fe1ccb09b7f9abab408590990767d1e190) [#40](https://github.com/adriancmiranda/glimpse.nvim/pull/40 "PR de @adriancmiranda") Add workflow icons


## [1.14.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.13.1..v1.14.0) - 2026-05-24

### 🚀 Features

- [`411e0db`](https://github.com/adriancmiranda/glimpse.nvim/commit/411e0db55404f2dbc5c2ca27cadfae683c5761ff) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Add binary previewer
- [`76ba29f`](https://github.com/adriancmiranda/glimpse.nvim/commit/76ba29f35f91438c5f3bf83d2e6b32a1c21eeb49) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Improve binary preview integration
- [`7621704`](https://github.com/adriancmiranda/glimpse.nvim/commit/7621704111bd2724963541f2dce7986c570e2700) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Improve previewer fallbacks

### 🐛 Bug Fixes

- [`1eda27a`](https://github.com/adriancmiranda/glimpse.nvim/commit/1eda27a21b53413e19e3efd5c101740e46487d77) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Satisfy luacheck
- [`f3d4e3b`](https://github.com/adriancmiranda/glimpse.nvim/commit/f3d4e3bb29f549d30f7948591601707b933354de) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Harden test plenary discovery

### 📚 Documentation

- [`5e7180c`](https://github.com/adriancmiranda/glimpse.nvim/commit/5e7180c7ca910616020990fbb44b80817be27838) [#33](https://github.com/adriancmiranda/glimpse.nvim/pull/33 "PR de @adriancmiranda") Add git-cliff changelog workflow
- [`d9eda15`](https://github.com/adriancmiranda/glimpse.nvim/commit/d9eda15713dd443ea1941a18c5bc87a3b1dcae72) [#34](https://github.com/adriancmiranda/glimpse.nvim/pull/34 "PR de @adriancmiranda") Prune changelog boilerplate
- [`3e7e027`](https://github.com/adriancmiranda/glimpse.nvim/commit/3e7e027d2cf20fc7004ac6a2f2237b4dacb00940) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Update binary previewer tree
- [`4da1e3f`](https://github.com/adriancmiranda/glimpse.nvim/commit/4da1e3f46682537fdc897b13151994196446a2e0) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Mention binary preview in README
- [`0cbd860`](https://github.com/adriancmiranda/glimpse.nvim/commit/0cbd860eba428072972fd259230d77913d329f5b) [#35](https://github.com/adriancmiranda/glimpse.nvim/pull/35 "PR de @adriancmiranda") Clarify dependency guidance


## [1.13.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.13.0..v1.13.1) - 2026-05-22

### 🐛 Bug Fixes

- [`da8c6a0`](https://github.com/adriancmiranda/glimpse.nvim/commit/da8c6a0cf11ef95f01cd113f379e8b4a7dc62a22) [#32](https://github.com/adriancmiranda/glimpse.nvim/pull/32 "PR de @adriancmiranda") Show metadata for encrypted gpg files


## [1.13.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.12.0..v1.13.0) - 2026-05-22

### 🚀 Features

- [`4fe284e`](https://github.com/adriancmiranda/glimpse.nvim/commit/4fe284e9f52387143ae841391e55c3a48e919fa5) [#31](https://github.com/adriancmiranda/glimpse.nvim/pull/31 "PR de @adriancmiranda") Add x509 certificate preview
- [`ac26a96`](https://github.com/adriancmiranda/glimpse.nvim/commit/ac26a9689b8e8657f766a17907aecb5bbdd4a66c) [#31](https://github.com/adriancmiranda/glimpse.nvim/pull/31 "PR de @adriancmiranda") Warn on suspicious certificates

### 🐛 Bug Fixes

- [`bb03e21`](https://github.com/adriancmiranda/glimpse.nvim/commit/bb03e219c95e9ce61cf378b6d4ca507a2720cefb) [#31](https://github.com/adriancmiranda/glimpse.nvim/pull/31 "PR de @adriancmiranda") Detect pem certificates before private keys

### 📚 Documentation

- [`b0255e5`](https://github.com/adriancmiranda/glimpse.nvim/commit/b0255e51f3b879ed2763a1d9b78d970915d325b0) [#31](https://github.com/adriancmiranda/glimpse.nvim/pull/31 "PR de @adriancmiranda") Refresh glimpse certificate docs


## [1.12.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.11.0..v1.12.0) - 2026-05-22

### 🚀 Features

- [`d4fbd09`](https://github.com/adriancmiranda/glimpse.nvim/commit/d4fbd09535a95ef4e9fb4b520eba768587c8de66) [#30](https://github.com/adriancmiranda/glimpse.nvim/pull/30 "PR de @adriancmiranda") *(telescope)* Native integration via buffer_previewer_maker
- [`97ca9fd`](https://github.com/adriancmiranda/glimpse.nvim/commit/97ca9fd56947d62930727424d5521edd1b553809) [#30](https://github.com/adriancmiranda/glimpse.nvim/pull/30 "PR de @adriancmiranda") Add scoped telescope media previewer

### 🐛 Bug Fixes

- [`092934f`](https://github.com/adriancmiranda/glimpse.nvim/commit/092934ffaf5f346c29e61c22a6b241998420778c) [#30](https://github.com/adriancmiranda/glimpse.nvim/pull/30 "PR de @adriancmiranda") *(telescope)* Usar opts.winid do telescope ao invés de bufwinid no schedule_wrap


## [1.11.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.2..v1.11.0) - 2026-05-21

### 🚀 Features

- [`c6db083`](https://github.com/adriancmiranda/glimpse.nvim/commit/c6db0838dc07f79c0b144bbfd07a742201984406) [#29](https://github.com/adriancmiranda/glimpse.nvim/pull/29 "PR de @adriancmiranda") *(key)* Preview GPG and SSH key metadata

### 🚜 Refactor

- [`50dc4c8`](https://github.com/adriancmiranda/glimpse.nvim/commit/50dc4c8f400607a59796752cdb68c227194d70db) [#28](https://github.com/adriancmiranda/glimpse.nvim/pull/28 "PR de @adriancmiranda") Extract previewers into previewer/ directory


## [1.10.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.1..v1.10.2) - 2026-05-21

### 🐛 Bug Fixes

- [`2dadf87`](https://github.com/adriancmiranda/glimpse.nvim/commit/2dadf87bd26b12d4106ef1440f29610a1a860b3f) [#27](https://github.com/adriancmiranda/glimpse.nvim/pull/27 "PR de @adriancmiranda") *(encoding)* Add UTF-8 validation + CP1252/Latin-1 heuristic fallback


## [1.10.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.0..v1.10.1) - 2026-05-21

### 🐛 Bug Fixes

- [`cdf0942`](https://github.com/adriancmiranda/glimpse.nvim/commit/cdf09425dba6e6fba28778d39d9d03ae9e12ff3c) *(types)* Correct neotree config annotation to accept boolean|table
- [`14739e3`](https://github.com/adriancmiranda/glimpse.nvim/commit/14739e346bd66929ed1633cde47e8ba5aaab6b7c) [#26](https://github.com/adriancmiranda/glimpse.nvim/pull/26 "PR de @adriancmiranda") *(renderer)* Guard nil dimensions + add pdf/avif to events + ghostscript docs

### 📚 Documentation

- [`36b0ea1`](https://github.com/adriancmiranda/glimpse.nvim/commit/36b0ea133c9c0e9ab6fed9a2b5bdc3543e2f43b7) Add sqlite extensions to setup example


## [1.10.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.9.0..v1.10.0) - 2026-05-21

### 🚀 Features

- [`94a7b69`](https://github.com/adriancmiranda/glimpse.nvim/commit/94a7b69787f178afa38fdfb0ecc5b7d8339275a2) [#25](https://github.com/adriancmiranda/glimpse.nvim/pull/25 "PR de @adriancmiranda") *(archive)* Separate preview (summary) from show (full listing)


## [1.9.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.8.0..v1.9.0) - 2026-05-21

### 🚀 Features

- [`3e8b2f8`](https://github.com/adriancmiranda/glimpse.nvim/commit/3e8b2f8c67ff5cfc7ef8424d4945d2a8e2ed8eb7) [#24](https://github.com/adriancmiranda/glimpse.nvim/pull/24 "PR de @adriancmiranda") *(font)* Preview font metadata (family, style, weight, sample)

### 📚 Documentation

- [`da614d2`](https://github.com/adriancmiranda/glimpse.nvim/commit/da614d2a902cc1eba4a437ff95d56d0f5162470f) Update lazy.nvim setup example with event-based loading
- [`66d1483`](https://github.com/adriancmiranda/glimpse.nvim/commit/66d1483d4b93e3ef13cf5c9ea7171553c48e50f5) Remove font extensions from setup example (not yet merged)


## [1.8.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.7.0..v1.8.0) - 2026-05-21

### 🚀 Features

- [`3b5341b`](https://github.com/adriancmiranda/glimpse.nvim/commit/3b5341b58c83e5fe326c83bc8ad86c0c2660ee71) [#23](https://github.com/adriancmiranda/glimpse.nvim/pull/23 "PR de @adriancmiranda") *(sqlite)* Preview database schema (tables and columns)


## [1.7.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.6.0..v1.7.0) - 2026-05-20

### 🚀 Features

- [`9d62596`](https://github.com/adriancmiranda/glimpse.nvim/commit/9d62596aee256adfdd16a810defd9905ac6d9f40) [#19](https://github.com/adriancmiranda/glimpse.nvim/pull/19 "PR de @adriancmiranda") *(archive)* Preview contents of zip/tar archives

### 📚 Documentation

- [`248a88f`](https://github.com/adriancmiranda/glimpse.nvim/commit/248a88f8acdadc459d8f1447659a26fc7ebea18d) [#22](https://github.com/adriancmiranda/glimpse.nvim/pull/22 "PR de @adriancmiranda") Expand Security section into Security & Privacy


## [1.6.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.5.0..v1.6.0) - 2026-05-20

### 🚀 Features

- [`20b5d3d`](https://github.com/adriancmiranda/glimpse.nvim/commit/20b5d3dff1dd46f95e292cfdf543de44dbf039bb) [#21](https://github.com/adriancmiranda/glimpse.nvim/pull/21 "PR de @adriancmiranda") *(security)* Add SVG safety flags to magick calls


## [1.5.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.4.0..v1.5.0) - 2026-05-20

### 🚀 Features

- [`fbffbf9`](https://github.com/adriancmiranda/glimpse.nvim/commit/fbffbf93daaf3b1ef88b4542174c487cba467546) [#20](https://github.com/adriancmiranda/glimpse.nvim/pull/20 "PR de @adriancmiranda") *(security)* Validate files before processing (symlinks, size)


## [1.4.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.3.1..v1.4.0) - 2026-05-20

### 🚀 Features

- [`b49a389`](https://github.com/adriancmiranda/glimpse.nvim/commit/b49a389d80826b1800692fca934358cef8dba1e7) [#18](https://github.com/adriancmiranda/glimpse.nvim/pull/18 "PR de @adriancmiranda") *(renderer)* Cancel stale conversion jobs on new request


## [1.3.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.3.0..v1.3.1) - 2026-05-20

### 🐛 Bug Fixes

- [`122ca43`](https://github.com/adriancmiranda/glimpse.nvim/commit/122ca43471dc71f0f8ac1b9653db161c89add86d) [#15](https://github.com/adriancmiranda/glimpse.nvim/pull/15 "PR de @adriancmiranda") *(security)* Use list args instead of string.format for shell commands


## [1.3.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.2.1..v1.3.0) - 2026-05-20

### 🚀 Features

- [`c8879f8`](https://github.com/adriancmiranda/glimpse.nvim/commit/c8879f8136917703490c51cb838df00f7b772456) [#16](https://github.com/adriancmiranda/glimpse.nvim/pull/16 "PR de @adriancmiranda") *(cache)* Auto-cleanup files older than cache_max_age_days

### 📚 Documentation

- [`763ed7b`](https://github.com/adriancmiranda/glimpse.nvim/commit/763ed7ba7f7ee57111117f38b2d0ac21762299ab) [#17](https://github.com/adriancmiranda/glimpse.nvim/pull/17 "PR de @adriancmiranda") Add cache_max_age_days option to README


## [1.2.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.2.0..v1.2.1) - 2026-05-20

### 🐛 Bug Fixes

- [`e1dc303`](https://github.com/adriancmiranda/glimpse.nvim/commit/e1dc303c801dd5cb549558dfff15653bd80abf8e) [#14](https://github.com/adriancmiranda/glimpse.nvim/pull/14 "PR de @adriancmiranda") *(cache)* Incluir mtime na chave do cache para invalidacao automatica

### 📚 Documentation

- [`01c985a`](https://github.com/adriancmiranda/glimpse.nvim/commit/01c985a6b5de7394f3f4978a768b0cc859dd0329) [#13](https://github.com/adriancmiranda/glimpse.nvim/pull/13 "PR de @adriancmiranda") Translate CONTRIBUTING to English


## [1.2.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.1.1..v1.2.0) - 2026-05-20

### 🚀 Features

- [`9421e80`](https://github.com/adriancmiranda/glimpse.nvim/commit/9421e8045cd48fdef59adb3281297bdea8ff12ce) [#11](https://github.com/adriancmiranda/glimpse.nvim/pull/11 "PR de @adriancmiranda") Open images via pane in WezTerm instead of binary buffer
- [`8138f78`](https://github.com/adriancmiranda/glimpse.nvim/commit/8138f78676b814004601563d3ea9d11fc76ac44d) [#11](https://github.com/adriancmiranda/glimpse.nvim/pull/11 "PR de @adriancmiranda") WezTerm pane reuse with read-eval loop, open via pane on ;


## [1.1.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.1.0..v1.1.1) - 2026-05-20

### 🐛 Bug Fixes

- [`f2f6b58`](https://github.com/adriancmiranda/glimpse.nvim/commit/f2f6b582155d1ae0efc0cce52dd4dfce30e2fa46) [#12](https://github.com/adriancmiranda/glimpse.nvim/pull/12 "PR de @adriancmiranda") Detect active WezTerm socket by checking PID

### 📚 Documentation

- [`32e8915`](https://github.com/adriancmiranda/glimpse.nvim/commit/32e8915eb51723bef98550557e9d7e5f70617f8c) Update README and CONTRIBUTING with Neo-tree integration


## [1.1.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.3..v1.1.0) - 2026-05-19

### 🚀 Features

- [`3ca1078`](https://github.com/adriancmiranda/glimpse.nvim/commit/3ca1078c672af1725d95fb290185b135ef0cd110) [#5](https://github.com/adriancmiranda/glimpse.nvim/pull/5 "PR de @adriancmiranda") Add Neo-tree integration
- [`b4b79a3`](https://github.com/adriancmiranda/glimpse.nvim/commit/b4b79a32c900daff7bc8935cc1abbeb0949192bd) [#5](https://github.com/adriancmiranda/glimpse.nvim/pull/5 "PR de @adriancmiranda") Implement Neo-tree integration
- [`486a761`](https://github.com/adriancmiranda/glimpse.nvim/commit/486a761be14762339f5f0485fdad5fb0180b6fe0) [#5](https://github.com/adriancmiranda/glimpse.nvim/pull/5 "PR de @adriancmiranda") Auto-preview with dedicated window, pane fallback for WezTerm
- [`b19653b`](https://github.com/adriancmiranda/glimpse.nvim/commit/b19653ba180495c51093564a9f6099080cbe79fa) [#5](https://github.com/adriancmiranda/glimpse.nvim/pull/5 "PR de @adriancmiranda") Add auto_preview config and cleanup on Neo-tree close

### 📚 Documentation

- [`2349ffd`](https://github.com/adriancmiranda/glimpse.nvim/commit/2349ffd16caa911c591eda4e86787b9bf1a2b09f) [#6](https://github.com/adriancmiranda/glimpse.nvim/pull/6 "PR de @adriancmiranda") Translate README to English
- [`8d0488b`](https://github.com/adriancmiranda/glimpse.nvim/commit/8d0488bcd29cccc230df39bf324ba650d0044c31) [#9](https://github.com/adriancmiranda/glimpse.nvim/pull/9 "PR de @adriancmiranda") Translate issue templates to English
- [`406e1d8`](https://github.com/adriancmiranda/glimpse.nvim/commit/406e1d8c3649a8ceddc88060cc9222a1b9a2af0a) [#5](https://github.com/adriancmiranda/glimpse.nvim/pull/5 "PR de @adriancmiranda") Translate Neo-tree section to English, update config example

### 🎨 Styling

- [`59d85c4`](https://github.com/adriancmiranda/glimpse.nvim/commit/59d85c423a635be2d15afc9560098eab027549a1) Replace unicode arrow with ASCII in comment


## [1.0.3](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.2..v1.0.3) - 2026-05-19

### 🐛 Bug Fixes

- [`a82fd9e`](https://github.com/adriancmiranda/glimpse.nvim/commit/a82fd9efcd2ea8d9542df135f53749308eaab42c) [#3](https://github.com/adriancmiranda/glimpse.nvim/pull/3 "PR de @adriancmiranda") Use unique image IDs per tmux pane to prevent placement leaks
- [`60ecf61`](https://github.com/adriancmiranda/glimpse.nvim/commit/60ecf61199e2e3aa2c9d849590d42af48a51a42b) [#3](https://github.com/adriancmiranda/glimpse.nvim/pull/3 "PR de @adriancmiranda") Scope image IDs per tmux pane to prevent placement leaks

### 📚 Documentation

- [`1f2ec9a`](https://github.com/adriancmiranda/glimpse.nvim/commit/1f2ec9a02b85916fa3c246c8a82ac47b40acb1f8) Update CONTRIBUTING with video, wezterm socket, telescope info
- [`0e98c53`](https://github.com/adriancmiranda/glimpse.nvim/commit/0e98c53cd8634779e3247814d25fdbf82376e585) Fix Portuguese accents in CONTRIBUTING


## [1.0.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.1..v1.0.2) - 2026-05-19

### 🐛 Bug Fixes

- [`551cec4`](https://github.com/adriancmiranda/glimpse.nvim/commit/551cec44a3a326133684cd5b4058df3282f45b9b) [#2](https://github.com/adriancmiranda/glimpse.nvim/pull/2 "PR de @adriancmiranda") Oil opens wrong directory after viewing image
- [`cb04ebb`](https://github.com/adriancmiranda/glimpse.nvim/commit/cb04ebb246f6b9d17771e5c8e10ec8b0cf0879b3) [#2](https://github.com/adriancmiranda/glimpse.nvim/pull/2 "PR de @adriancmiranda") Restore correct directory when Oil reopens after image view


## [1.0.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.0..v1.0.1) - 2026-05-18

### 🐛 Bug Fixes

- [`f6d3898`](https://github.com/adriancmiranda/glimpse.nvim/commit/f6d3898bafbb35b6e21a704618cf2ce3f6aed777) [#1](https://github.com/adriancmiranda/glimpse.nvim/pull/1 "PR de @adriancmiranda") Auto-detect WezTerm socket inside tmux
- [`30bc7c3`](https://github.com/adriancmiranda/glimpse.nvim/commit/30bc7c37cd2f2189407ccee362ece810ebe4d6c3) [#1](https://github.com/adriancmiranda/glimpse.nvim/pull/1 "PR de @adriancmiranda") Auto-detect WezTerm socket for tmux environments


## [1.0.0](https://github.com/adriancmiranda/glimpse.nvim/compare/..v1.0.0) - 2026-05-18

### 🚀 Features

- [`3ec8735`](https://github.com/adriancmiranda/glimpse.nvim/commit/3ec8735106af4e4ad8a3af9fb35a641475d62db4) Glimpse.nvim - image and video preview for Neovim

### 📚 Documentation

- [`40b90f7`](https://github.com/adriancmiranda/glimpse.nvim/commit/40b90f72da5a51424999430cbc507001cb23dbb4) Add WezTerm + tmux troubleshooting to README

