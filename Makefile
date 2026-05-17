PLENARY_PATH ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim

.PHONY: test bench setup-hooks docs

test:
	@nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

bench:
	@nvim -l tests/bench.lua

setup-hooks:
	git config core.hooksPath .githooks

docs:
	@mkdir -p doc
	@lemmy-help lua/glimpse/init.lua lua/glimpse/detect.lua lua/glimpse/util.lua > doc/glimpse.txt
	@echo "doc/glimpse.txt generated"
