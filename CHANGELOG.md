# Changelog

<!-- markdownlint-disable MD012 MD024 -->

> All notable changes to glimpse.nvim will be documented in this file.

## [unreleased]

### 🚀 Features

- [`bb0577e`](https://github.com/adriancmiranda/glimpse.nvim/commit/bb0577e664dbbbb37438455a52b1f40ed85157a3) *(video)* Add configurable frame extraction width
- [`35fe92c`](https://github.com/adriancmiranda/glimpse.nvim/commit/35fe92c4a2a4eee76254be3cde273f5d6eaacc40) *(model)* Add 3D model previews via conversion pipeline
- [`70430c7`](https://github.com/adriancmiranda/glimpse.nvim/commit/70430c732d5b17bfb678287e69aca6e4d6de5353) *(markdown)* Add Markdown previewer with configurable CLI renderer

### 🐛 Bug Fixes

- [`52f0321`](https://github.com/adriancmiranda/glimpse.nvim/commit/52f03211502c8a507f6f77ef93521688f5028700) *(telescope)* Render media previews immediately
- [`99a4212`](https://github.com/adriancmiranda/glimpse.nvim/commit/99a42129085cd5eaaaa1adcc9cfe87ebda924052) *(renderer)* Use source filename as preview buffer name instead of image hash
- [`3d1830f`](https://github.com/adriancmiranda/glimpse.nvim/commit/3d1830f6bb1ba16a5c904b95d086becbde21b44c) *(video)* Stop animation and timers when preview window is closed directly
- [`337db59`](https://github.com/adriancmiranda/glimpse.nvim/commit/337db59d7c56e00157c496b2ad353fa513b3e842) *(preview)* Show filename instead of sha256 hash in preview buffer names
- [`419b780`](https://github.com/adriancmiranda/glimpse.nvim/commit/419b780feb3f8e132ecf7a133593a3e77ac42a9c) *(model)* Name preview buffer with model filename instead of image hash
- [`695a84f`](https://github.com/adriancmiranda/glimpse.nvim/commit/695a84f3198107e3e6b61dec4b57e85cd58aedf9) *(model)* Pass filepath to setup_animation_buf for buffer naming
- [`37eb2b2`](https://github.com/adriancmiranda/glimpse.nvim/commit/37eb2b2e2990e060a7f70d9d310ab5c93666d280) *(float)* Omit title_pos when title is nil
- [`de59297`](https://github.com/adriancmiranda/glimpse.nvim/commit/de5929791311a936f166cf85f6546d2cbd14eabd) *(markdown)* Use terminal buffer for ANSI colors and ansi leaf spec

### 🚜 Refactor

- [`2620138`](https://github.com/adriancmiranda/glimpse.nvim/commit/262013818aa6fc539a5188a051fc52a971f001ce) *(renderer)* Extract buffer label into local variable
- [`92daec7`](https://github.com/adriancmiranda/glimpse.nvim/commit/92daec7ae89f8c44982c77489bd86a9c5807be66) *(model)* Extract pipeline_previewer as shared runtime

### 📚 Documentation

- [`ed04496`](https://github.com/adriancmiranda/glimpse.nvim/commit/ed04496a6cef9a573aeb20d3145d9ff0e656553b) Add video.frames.width to README configuration example
- [`702c875`](https://github.com/adriancmiranda/glimpse.nvim/commit/702c875fa17513202aa6263a5ccbc65cc73dccf8) Document oil.toggle_float integration and allow details/summary HTML
- [`59351b7`](https://github.com/adriancmiranda/glimpse.nvim/commit/59351b74b5cfc4ef6e1aa0e0dac1ac77cb0e9ec7) *(changelog)* Prefix each entry with a linked commit hash
- [`8a62200`](https://github.com/adriancmiranda/glimpse.nvim/commit/8a62200174f3440d705ddb57b2b4112b1382bd0e) *(contributing)* Add f3d dependency, pipeline.lua and model.lua to code structure

### ⚡ Performance

- [`10687f7`](https://github.com/adriancmiranda/glimpse.nvim/commit/10687f7dd2f5c04726086f920b8ddd3cd756fe8b) *(renderer)* Coalesce rapid rerender requests with a one-deep pending slot

### 🧪 Testing

- [`b706cf7`](https://github.com/adriancmiranda/glimpse.nvim/commit/b706cf70211bea7f05f21d39424e2eaa2044b9d1) *(renderer)* Verify pending slot coalesces rapid rerenders to 2 spawns

### ⚙️ Miscellaneous Tasks

- [`81464d6`](https://github.com/adriancmiranda/glimpse.nvim/commit/81464d6dc42b7718131f0e3ba17599a45fe03b9a) *(ci)* Move merged PRs to Done in GitHub project board
- [`1265820`](https://github.com/adriancmiranda/glimpse.nvim/commit/12658203dfb92678c055181dce202ca4d6b3b59f) *(ci)* Bump github-script to v9 and move IDs to repository variables


## [2.1.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v2.0.0..v2.1.0) - 2026-06-16

### 🚀 Features

- [`028935b`](https://github.com/adriancmiranda/glimpse.nvim/commit/028935be248bd7e28176794ac8dfb8d4b8d48887) *(kitty)* Auto-detect terminal cell pixel dimensions
- [`68e2fc8`](https://github.com/adriancmiranda/glimpse.nvim/commit/68e2fc8ddb2ae77ce8dafe0a8d8f568aede52b0e) *(changelog)* Include commit body in changelog for breaking changes
- [`c2f5e84`](https://github.com/adriancmiranda/glimpse.nvim/commit/c2f5e84f1078a2a978d79ff218885936863d1754) *(preview)* Separate preview state and oil image flow
- [`40decd1`](https://github.com/adriancmiranda/glimpse.nvim/commit/40decd10f426223c6f0c2e36c76484112710a7cd) *(video)* Inline video playback via Kitty Animation Protocol

### 🐛 Bug Fixes

- [`73d0f77`](https://github.com/adriancmiranda/glimpse.nvim/commit/73d0f773379a7d88112964c8978ad047a0ec5a0c) *(docs)* Replace broken xxd vimhelp link with linux.die.net man page
- [`49edd95`](https://github.com/adriancmiranda/glimpse.nvim/commit/49edd958ede8dc520d5560fdb814f461bf7d4b07) *(docs)* Fix v1.0.0 changelog link to point to commits
- [`dd26d2d`](https://github.com/adriancmiranda/glimpse.nvim/commit/dd26d2dbeab95c2219da628dddf195a6b927faa7) *(telescope)* Scaffold investigation for stale render state (#71)
- [`ebf5653`](https://github.com/adriancmiranda/glimpse.nvim/commit/ebf565300a018613e25af7ff12bef003b7858221) *(telescope)* Close active Kitty render before text preview
- [`ca9eaea`](https://github.com/adriancmiranda/glimpse.nvim/commit/ca9eaea59ba33bc18f5284de4fa8435ffb7eb77a) *(telescope)* Also clear stale image on disabled-kind fallback path
- [`7a69df9`](https://github.com/adriancmiranda/glimpse.nvim/commit/7a69df9a5002d3a95596daa2569cd41bc6cb0b40) *(oil)* Preserve cwd and open modes
- [`10cc3ea`](https://github.com/adriancmiranda/glimpse.nvim/commit/10cc3ea9d9dc053e0d88c9047f9e6d8cf4515f50) Move oil float context into glimpse
- [`1d7fbcf`](https://github.com/adriancmiranda/glimpse.nvim/commit/1d7fbcf32777af671de0bdd95ff6c60b1901f774) Avoid vim.fs.isabspath in oil float
- [`aa06fcb`](https://github.com/adriancmiranda/glimpse.nvim/commit/aa06fcb428aaa0af1be2a2e136e9850c0e1f7179) *(types)* Resolve lua_ls diagnostic warnings across the codebase
- [`9c0879b`](https://github.com/adriancmiranda/glimpse.nvim/commit/9c0879b215e683db24d5f69ec961f4887b97d05a) *(oil)* Resolve float dir from oil buffer state instead of process cwd
- [`52e08da`](https://github.com/adriancmiranda/glimpse.nvim/commit/52e08da431f52a5023607f6693e0db56802cfd32) Align animation state with placement_state
- [`c4c7fa4`](https://github.com/adriancmiranda/glimpse.nvim/commit/c4c7fa492a7a177147253cc5e36579aa35687651) Keep telescope text previews and renderer state consistent
- [`90030d9`](https://github.com/adriancmiranda/glimpse.nvim/commit/90030d939f2ddce1009e7d837892fe0773115043) *(video)* Keep resize restarts from flashing
- [`68f9fab`](https://github.com/adriancmiranda/glimpse.nvim/commit/68f9fab6dca372d6a79395176e7a461a45d448bb) *(video)* Reuse preview window across media kinds
- [`e178eb6`](https://github.com/adriancmiranda/glimpse.nvim/commit/e178eb645cadc015f32c2b977567147288cd223d) Scope media preview reuse to preview targets
- [`8483471`](https://github.com/adriancmiranda/glimpse.nvim/commit/8483471a30e79003cff65ca49ae998a3871bcf50) *(video)* Prevent stale animation from clobbering new preview state
- [`4b41262`](https://github.com/adriancmiranda/glimpse.nvim/commit/4b412629683936075629f8e72e648108064630dd) *(video)* Fix window ownership, thumbnail fallback target, and frame file tracking
- [`605091d`](https://github.com/adriancmiranda/glimpse.nvim/commit/605091d5ee4bfbdb527676ce3a731e58e542213d) Harden video frame extraction
- [`2a66380`](https://github.com/adriancmiranda/glimpse.nvim/commit/2a663809e9ddf2d353cec3d4de8cfe17fa7eb3dd) *(video)* Cancel batch extraction when preview split is closed early

### 📚 Documentation

- [`85b7e84`](https://github.com/adriancmiranda/glimpse.nvim/commit/85b7e84e33cd545eed3d980d5b4ede0e855633a0) Update README feature line and drop manual CHANGELOG entry

### 🧪 Testing

- [`59fd051`](https://github.com/adriancmiranda/glimpse.nvim/commit/59fd05167e4d787db0ac880f3cd58f24023b3b52) *(telescope)* Add regression for stale Kitty image on text preview

### ⚙️ Miscellaneous Tasks

- [`beed14b`](https://github.com/adriancmiranda/glimpse.nvim/commit/beed14bd9f1013a2fa26b21ec2714a401936d9c7) Add stylua and luacheck to lint targets (from PR #67)
- [`b5097c5`](https://github.com/adriancmiranda/glimpse.nvim/commit/b5097c5d39af81cfe378570cc0076164ea9dc65c) Remove pipe strategy stub (will be implemented in a separate PR)


## [2.0.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.16.0..v2.0.0) - 2026-06-09

### 🚀 Features

- [`26357a0`](https://github.com/adriancmiranda/glimpse.nvim/commit/26357a0fc737d94c132179f26a717094b6b544fe) [**breaking**] Refactor public config contract


## [1.16.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.15.1..v1.16.0) - 2026-06-08

### 🚀 Features

- [`a1d2f07`](https://github.com/adriancmiranda/glimpse.nvim/commit/a1d2f070817c34d270c4d5e5adc2c6fb31510275) Telescope all previews
- [`094e48b`](https://github.com/adriancmiranda/glimpse.nvim/commit/094e48b715319dfd8a4b146dc5374e7f9ceb0a66) *(glimpse)* Refine lfs pointer preview
- [`65a5789`](https://github.com/adriancmiranda/glimpse.nvim/commit/65a578997f2b1925c33e9e0f7598e1b5d553cf45) *(glimpse)* Support git lfs pointers
- [`6cb2986`](https://github.com/adriancmiranda/glimpse.nvim/commit/6cb298612c0f927e57544b64d3001acc3d4cc2f4) *(telescope)* Add per-kind flags
- [`d173e39`](https://github.com/adriancmiranda/glimpse.nvim/commit/d173e3928609342c31e393b4ce6e5546f7f6db4d) *(oil)* Make image opening configurable
- [`75e11d9`](https://github.com/adriancmiranda/glimpse.nvim/commit/75e11d96d89bfdd2f4d6ffb01ace0adeecb876bf) *(oil)* Support custom openers
- [`233f9c7`](https://github.com/adriancmiranda/glimpse.nvim/commit/233f9c724b8186749525de92c4b5feb585677e8c) Separate cwd following from preview flow

### 🐛 Bug Fixes

- [`e75005a`](https://github.com/adriancmiranda/glimpse.nvim/commit/e75005ae544c5d1f5c5f2d8677807accc5b38499) *(inline)* Avoid hit-enter on close
- [`b36ba8a`](https://github.com/adriancmiranda/glimpse.nvim/commit/b36ba8ad3881ca01d8ecba72ff61b13e1ce5cb1f) *(telescope)* Keep preview buffers reusable
- [`35fdcd0`](https://github.com/adriancmiranda/glimpse.nvim/commit/35fdcd0ed5bb3470e855d0f063e1f6f4fafc12de) *(glimpse)* Harden image buffer lifecycle
- [`27a3664`](https://github.com/adriancmiranda/glimpse.nvim/commit/27a366434b5a46e4fbc92d947415752fc1e9de54) *(glimpse)* Remove lfs interception
- [`8f62159`](https://github.com/adriancmiranda/glimpse.nvim/commit/8f621598e0c6c1458ae469657efb70d88733f3ff) Harden telescope cwd follow and thumbnail fallback

### 🚜 Refactor

- [`3fd3633`](https://github.com/adriancmiranda/glimpse.nvim/commit/3fd36330bb5e7762a5164ca05223545e6c5c4acf) *(types)* Consolidate config aliases
- [`f5bf2a8`](https://github.com/adriancmiranda/glimpse.nvim/commit/f5bf2a88e375f9c9657fa44418f212f9b1c79a8e) Isolate preview lifecycles

### 📚 Documentation

- [`0bceebc`](https://github.com/adriancmiranda/glimpse.nvim/commit/0bceebc9499c849fe179f0e0c5e7108f2a6c98d4) Add optional ImageMagick policy example

### 🎨 Styling

- [`8365314`](https://github.com/adriancmiranda/glimpse.nvim/commit/8365314d67656dc298db103776d966923840492f) *(glimpse)* Fix stylua formatting
- [`490335e`](https://github.com/adriancmiranda/glimpse.nvim/commit/490335e37bde5c422512e1cc36f9ccf40878ee2c) *(telescope)* Wrap config aliases

### 🧪 Testing

- [`5563cca`](https://github.com/adriancmiranda/glimpse.nvim/commit/5563cca9c0ca5f4c67470aa66042afa3bff0ab6f) *(perf)* Add benchmark suite


## [1.15.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.15.0..v1.15.1) - 2026-05-27

### 🐛 Bug Fixes

- [`4e15c04`](https://github.com/adriancmiranda/glimpse.nvim/commit/4e15c04428cb915fa79444da96674e2dadc830de) Avoid previewing json as binary
- [`d322285`](https://github.com/adriancmiranda/glimpse.nvim/commit/d322285b4382db7f00f0267a8562307563bbd2f8) Use mime encoding to detect binaries


## [1.15.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.2..v1.15.0) - 2026-05-25

### 🚀 Features

- [`a78d2f0`](https://github.com/adriancmiranda/glimpse.nvim/commit/a78d2f0406a3bf67e55376d7a03e4c7181564204) Expose preview introspection

### 📚 Documentation

- [`0589cdf`](https://github.com/adriancmiranda/glimpse.nvim/commit/0589cdff65c69d7d8c250125cf19d1e031465cf1) Revert generated vimdoc
- [`8bcfe2b`](https://github.com/adriancmiranda/glimpse.nvim/commit/8bcfe2b62972a20c1323a79fdd92a1311c12bb91) Sync api references
- [`6efec96`](https://github.com/adriancmiranda/glimpse.nvim/commit/6efec96a605d25c32b5fe274a4338ee26b4e5d1d) Translate comments to en-us
- [`8fc94f8`](https://github.com/adriancmiranda/glimpse.nvim/commit/8fc94f87c2dfae7df29c5d6b4f4256603ca8f24f) Drop generated vimdoc

### ⚙️ Miscellaneous Tasks

- [`cdef3fa`](https://github.com/adriancmiranda/glimpse.nvim/commit/cdef3fa4c464d2fa7dcabb96e00e23c3e0394220) Harden docs workflow retry


## [1.14.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.1..v1.14.2) - 2026-05-24

### 🐛 Bug Fixes

- [`7c50b46`](https://github.com/adriancmiranda/glimpse.nvim/commit/7c50b4607940762a522d2fde0a237923cb2e70f7) Follow image directory after open


## [1.14.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.14.0..v1.14.1) - 2026-05-24

### 🐛 Bug Fixes

- [`8180b43`](https://github.com/adriancmiranda/glimpse.nvim/commit/8180b43c1c24fdd64b066c6f1ba58fed25a03641) Reflow floating previews on resize

### ⚙️ Miscellaneous Tasks

- [`beb0a95`](https://github.com/adriancmiranda/glimpse.nvim/commit/beb0a955e1a6b82a5c53a8307e2783ab2aab3f70) Harden changelog workflow retry
- [`3966752`](https://github.com/adriancmiranda/glimpse.nvim/commit/3966752bc648c1d4cea164b2429aa8c36316b159) Serialize release writers
- [`7dd5d5d`](https://github.com/adriancmiranda/glimpse.nvim/commit/7dd5d5d1b16cb100b4b4d8bdc76cf2da07b2d470) Serialize release writers without canceling
- [`c85a772`](https://github.com/adriancmiranda/glimpse.nvim/commit/c85a772c7b6ccabc55d432370b97110772527d2a) Add manual release tag workflow
- [`e192640`](https://github.com/adriancmiranda/glimpse.nvim/commit/e192640f540edb8cd3d465a5339271a6beff7d4c) Sync release tag workflow with main
- [`0ef872f`](https://github.com/adriancmiranda/glimpse.nvim/commit/0ef872fe1ccb09b7f9abab408590990767d1e190) Add workflow icons


## [1.14.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.13.1..v1.14.0) - 2026-05-24

### 🚀 Features

- [`411e0db`](https://github.com/adriancmiranda/glimpse.nvim/commit/411e0db55404f2dbc5c2ca27cadfae683c5761ff) Add binary previewer
- [`76ba29f`](https://github.com/adriancmiranda/glimpse.nvim/commit/76ba29f35f91438c5f3bf83d2e6b32a1c21eeb49) Improve binary preview integration
- [`7621704`](https://github.com/adriancmiranda/glimpse.nvim/commit/7621704111bd2724963541f2dce7986c570e2700) Improve previewer fallbacks

### 🐛 Bug Fixes

- [`1eda27a`](https://github.com/adriancmiranda/glimpse.nvim/commit/1eda27a21b53413e19e3efd5c101740e46487d77) Satisfy luacheck
- [`f3d4e3b`](https://github.com/adriancmiranda/glimpse.nvim/commit/f3d4e3bb29f549d30f7948591601707b933354de) Harden test plenary discovery

### 📚 Documentation

- [`5e7180c`](https://github.com/adriancmiranda/glimpse.nvim/commit/5e7180c7ca910616020990fbb44b80817be27838) Add git-cliff changelog workflow
- [`d9eda15`](https://github.com/adriancmiranda/glimpse.nvim/commit/d9eda15713dd443ea1941a18c5bc87a3b1dcae72) Prune changelog boilerplate
- [`3e7e027`](https://github.com/adriancmiranda/glimpse.nvim/commit/3e7e027d2cf20fc7004ac6a2f2237b4dacb00940) Update binary previewer tree
- [`4da1e3f`](https://github.com/adriancmiranda/glimpse.nvim/commit/4da1e3f46682537fdc897b13151994196446a2e0) Mention binary preview in README
- [`0cbd860`](https://github.com/adriancmiranda/glimpse.nvim/commit/0cbd860eba428072972fd259230d77913d329f5b) Clarify dependency guidance


## [1.13.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.13.0..v1.13.1) - 2026-05-22

### 🐛 Bug Fixes

- [`da8c6a0`](https://github.com/adriancmiranda/glimpse.nvim/commit/da8c6a0cf11ef95f01cd113f379e8b4a7dc62a22) Show metadata for encrypted gpg files


## [1.13.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.12.0..v1.13.0) - 2026-05-22

### 🚀 Features

- [`4fe284e`](https://github.com/adriancmiranda/glimpse.nvim/commit/4fe284e9f52387143ae841391e55c3a48e919fa5) Add x509 certificate preview
- [`ac26a96`](https://github.com/adriancmiranda/glimpse.nvim/commit/ac26a9689b8e8657f766a17907aecb5bbdd4a66c) Warn on suspicious certificates

### 🐛 Bug Fixes

- [`bb03e21`](https://github.com/adriancmiranda/glimpse.nvim/commit/bb03e219c95e9ce61cf378b6d4ca507a2720cefb) Detect pem certificates before private keys

### 📚 Documentation

- [`b0255e5`](https://github.com/adriancmiranda/glimpse.nvim/commit/b0255e51f3b879ed2763a1d9b78d970915d325b0) Refresh glimpse certificate docs


## [1.12.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.11.0..v1.12.0) - 2026-05-22

### 🚀 Features

- [`d4fbd09`](https://github.com/adriancmiranda/glimpse.nvim/commit/d4fbd09535a95ef4e9fb4b520eba768587c8de66) *(telescope)* Native integration via buffer_previewer_maker
- [`97ca9fd`](https://github.com/adriancmiranda/glimpse.nvim/commit/97ca9fd56947d62930727424d5521edd1b553809) Add scoped telescope media previewer

### 🐛 Bug Fixes

- [`092934f`](https://github.com/adriancmiranda/glimpse.nvim/commit/092934ffaf5f346c29e61c22a6b241998420778c) *(telescope)* Usar opts.winid do telescope ao invés de bufwinid no schedule_wrap


## [1.11.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.2..v1.11.0) - 2026-05-21

### 🚀 Features

- [`c6db083`](https://github.com/adriancmiranda/glimpse.nvim/commit/c6db0838dc07f79c0b144bbfd07a742201984406) *(key)* Preview GPG and SSH key metadata

### 🚜 Refactor

- [`50dc4c8`](https://github.com/adriancmiranda/glimpse.nvim/commit/50dc4c8f400607a59796752cdb68c227194d70db) Extract previewers into previewer/ directory


## [1.10.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.1..v1.10.2) - 2026-05-21

### 🐛 Bug Fixes

- [`2dadf87`](https://github.com/adriancmiranda/glimpse.nvim/commit/2dadf87bd26b12d4106ef1440f29610a1a860b3f) *(encoding)* Add UTF-8 validation + CP1252/Latin-1 heuristic fallback


## [1.10.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.10.0..v1.10.1) - 2026-05-21

### 🐛 Bug Fixes

- [`cdf0942`](https://github.com/adriancmiranda/glimpse.nvim/commit/cdf09425dba6e6fba28778d39d9d03ae9e12ff3c) *(types)* Correct neotree config annotation to accept boolean|table
- [`14739e3`](https://github.com/adriancmiranda/glimpse.nvim/commit/14739e346bd66929ed1633cde47e8ba5aaab6b7c) *(renderer)* Guard nil dimensions + add pdf/avif to events + ghostscript docs

### 📚 Documentation

- [`36b0ea1`](https://github.com/adriancmiranda/glimpse.nvim/commit/36b0ea133c9c0e9ab6fed9a2b5bdc3543e2f43b7) Add sqlite extensions to setup example


## [1.10.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.9.0..v1.10.0) - 2026-05-21

### 🚀 Features

- [`94a7b69`](https://github.com/adriancmiranda/glimpse.nvim/commit/94a7b69787f178afa38fdfb0ecc5b7d8339275a2) *(archive)* Separate preview (summary) from show (full listing)


## [1.9.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.8.0..v1.9.0) - 2026-05-21

### 🚀 Features

- [`3e8b2f8`](https://github.com/adriancmiranda/glimpse.nvim/commit/3e8b2f8c67ff5cfc7ef8424d4945d2a8e2ed8eb7) *(font)* Preview font metadata (family, style, weight, sample)

### 📚 Documentation

- [`da614d2`](https://github.com/adriancmiranda/glimpse.nvim/commit/da614d2a902cc1eba4a437ff95d56d0f5162470f) Update lazy.nvim setup example with event-based loading
- [`66d1483`](https://github.com/adriancmiranda/glimpse.nvim/commit/66d1483d4b93e3ef13cf5c9ea7171553c48e50f5) Remove font extensions from setup example (not yet merged)


## [1.8.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.7.0..v1.8.0) - 2026-05-21

### 🚀 Features

- [`3b5341b`](https://github.com/adriancmiranda/glimpse.nvim/commit/3b5341b58c83e5fe326c83bc8ad86c0c2660ee71) *(sqlite)* Preview database schema (tables and columns)


## [1.7.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.6.0..v1.7.0) - 2026-05-20

### 🚀 Features

- [`9d62596`](https://github.com/adriancmiranda/glimpse.nvim/commit/9d62596aee256adfdd16a810defd9905ac6d9f40) *(archive)* Preview contents of zip/tar archives

### 📚 Documentation

- [`248a88f`](https://github.com/adriancmiranda/glimpse.nvim/commit/248a88f8acdadc459d8f1447659a26fc7ebea18d) Expand Security section into Security & Privacy


## [1.6.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.5.0..v1.6.0) - 2026-05-20

### 🚀 Features

- [`20b5d3d`](https://github.com/adriancmiranda/glimpse.nvim/commit/20b5d3dff1dd46f95e292cfdf543de44dbf039bb) *(security)* Add SVG safety flags to magick calls


## [1.5.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.4.0..v1.5.0) - 2026-05-20

### 🚀 Features

- [`fbffbf9`](https://github.com/adriancmiranda/glimpse.nvim/commit/fbffbf93daaf3b1ef88b4542174c487cba467546) *(security)* Validate files before processing (symlinks, size)


## [1.4.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.3.1..v1.4.0) - 2026-05-20

### 🚀 Features

- [`b49a389`](https://github.com/adriancmiranda/glimpse.nvim/commit/b49a389d80826b1800692fca934358cef8dba1e7) *(renderer)* Cancel stale conversion jobs on new request


## [1.3.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.3.0..v1.3.1) - 2026-05-20

### 🐛 Bug Fixes

- [`122ca43`](https://github.com/adriancmiranda/glimpse.nvim/commit/122ca43471dc71f0f8ac1b9653db161c89add86d) *(security)* Use list args instead of string.format for shell commands


## [1.3.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.2.1..v1.3.0) - 2026-05-20

### 🚀 Features

- [`c8879f8`](https://github.com/adriancmiranda/glimpse.nvim/commit/c8879f8136917703490c51cb838df00f7b772456) *(cache)* Auto-cleanup files older than cache_max_age_days

### 📚 Documentation

- [`763ed7b`](https://github.com/adriancmiranda/glimpse.nvim/commit/763ed7ba7f7ee57111117f38b2d0ac21762299ab) Add cache_max_age_days option to README


## [1.2.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.2.0..v1.2.1) - 2026-05-20

### 🐛 Bug Fixes

- [`e1dc303`](https://github.com/adriancmiranda/glimpse.nvim/commit/e1dc303c801dd5cb549558dfff15653bd80abf8e) *(cache)* Incluir mtime na chave do cache para invalidacao automatica

### 📚 Documentation

- [`01c985a`](https://github.com/adriancmiranda/glimpse.nvim/commit/01c985a6b5de7394f3f4978a768b0cc859dd0329) Translate CONTRIBUTING to English


## [1.2.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.1.1..v1.2.0) - 2026-05-20

### 🚀 Features

- [`9421e80`](https://github.com/adriancmiranda/glimpse.nvim/commit/9421e8045cd48fdef59adb3281297bdea8ff12ce) Open images via pane in WezTerm instead of binary buffer
- [`8138f78`](https://github.com/adriancmiranda/glimpse.nvim/commit/8138f78676b814004601563d3ea9d11fc76ac44d) WezTerm pane reuse with read-eval loop, open via pane on ;


## [1.1.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.1.0..v1.1.1) - 2026-05-20

### 🐛 Bug Fixes

- [`f2f6b58`](https://github.com/adriancmiranda/glimpse.nvim/commit/f2f6b582155d1ae0efc0cce52dd4dfce30e2fa46) Detect active WezTerm socket by checking PID

### 📚 Documentation

- [`32e8915`](https://github.com/adriancmiranda/glimpse.nvim/commit/32e8915eb51723bef98550557e9d7e5f70617f8c) Update README and CONTRIBUTING with Neo-tree integration


## [1.1.0](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.3..v1.1.0) - 2026-05-19

### 🚀 Features

- [`3ca1078`](https://github.com/adriancmiranda/glimpse.nvim/commit/3ca1078c672af1725d95fb290185b135ef0cd110) Add Neo-tree integration
- [`b4b79a3`](https://github.com/adriancmiranda/glimpse.nvim/commit/b4b79a32c900daff7bc8935cc1abbeb0949192bd) Implement Neo-tree integration
- [`486a761`](https://github.com/adriancmiranda/glimpse.nvim/commit/486a761be14762339f5f0485fdad5fb0180b6fe0) Auto-preview with dedicated window, pane fallback for WezTerm
- [`b19653b`](https://github.com/adriancmiranda/glimpse.nvim/commit/b19653ba180495c51093564a9f6099080cbe79fa) Add auto_preview config and cleanup on Neo-tree close

### 📚 Documentation

- [`2349ffd`](https://github.com/adriancmiranda/glimpse.nvim/commit/2349ffd16caa911c591eda4e86787b9bf1a2b09f) Translate README to English
- [`8d0488b`](https://github.com/adriancmiranda/glimpse.nvim/commit/8d0488bcd29cccc230df39bf324ba650d0044c31) Translate issue templates to English
- [`406e1d8`](https://github.com/adriancmiranda/glimpse.nvim/commit/406e1d8c3649a8ceddc88060cc9222a1b9a2af0a) Translate Neo-tree section to English, update config example

### 🎨 Styling

- [`59d85c4`](https://github.com/adriancmiranda/glimpse.nvim/commit/59d85c423a635be2d15afc9560098eab027549a1) Replace unicode arrow with ASCII in comment


## [1.0.3](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.2..v1.0.3) - 2026-05-19

### 🐛 Bug Fixes

- [`a82fd9e`](https://github.com/adriancmiranda/glimpse.nvim/commit/a82fd9efcd2ea8d9542df135f53749308eaab42c) Use unique image IDs per tmux pane to prevent placement leaks
- [`60ecf61`](https://github.com/adriancmiranda/glimpse.nvim/commit/60ecf61199e2e3aa2c9d849590d42af48a51a42b) Scope image IDs per tmux pane to prevent placement leaks

### 📚 Documentation

- [`1f2ec9a`](https://github.com/adriancmiranda/glimpse.nvim/commit/1f2ec9a02b85916fa3c246c8a82ac47b40acb1f8) Update CONTRIBUTING with video, wezterm socket, telescope info
- [`0e98c53`](https://github.com/adriancmiranda/glimpse.nvim/commit/0e98c53cd8634779e3247814d25fdbf82376e585) Fix Portuguese accents in CONTRIBUTING


## [1.0.2](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.1..v1.0.2) - 2026-05-19

### 🐛 Bug Fixes

- [`551cec4`](https://github.com/adriancmiranda/glimpse.nvim/commit/551cec44a3a326133684cd5b4058df3282f45b9b) Oil opens wrong directory after viewing image
- [`cb04ebb`](https://github.com/adriancmiranda/glimpse.nvim/commit/cb04ebb246f6b9d17771e5c8e10ec8b0cf0879b3) Restore correct directory when Oil reopens after image view


## [1.0.1](https://github.com/adriancmiranda/glimpse.nvim/compare/v1.0.0..v1.0.1) - 2026-05-18

### 🐛 Bug Fixes

- [`f6d3898`](https://github.com/adriancmiranda/glimpse.nvim/commit/f6d3898bafbb35b6e21a704618cf2ce3f6aed777) Auto-detect WezTerm socket inside tmux
- [`30bc7c3`](https://github.com/adriancmiranda/glimpse.nvim/commit/30bc7c37cd2f2189407ccee362ece810ebe4d6c3) Auto-detect WezTerm socket for tmux environments


## [1.0.0](https://github.com/adriancmiranda/glimpse.nvim/compare/..v1.0.0) - 2026-05-18

### 🚀 Features

- [`3ec8735`](https://github.com/adriancmiranda/glimpse.nvim/commit/3ec8735106af4e4ad8a3af9fb35a641475d62db4) Glimpse.nvim - image and video preview for Neovim

### 📚 Documentation

- [`40b90f7`](https://github.com/adriancmiranda/glimpse.nvim/commit/40b90f72da5a51424999430cbc507001cb23dbb4) Add WezTerm + tmux troubleshooting to README

