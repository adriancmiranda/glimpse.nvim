PLENARY_PATH ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim
MARKDOWNLINT_FILES ?= README.md CONTRIBUTING.md
MARKDOWNLINT_VERSION ?= 0.48.0

.PHONY: test bench setup-hooks docs lint lint-fix lint-changelog changelog changelog-check

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

lint:
	@npx --yes markdownlint-cli@$(MARKDOWNLINT_VERSION) $(MARKDOWNLINT_FILES)

lint-fix:
	@npx --yes markdownlint-cli@$(MARKDOWNLINT_VERSION) --fix README.md CONTRIBUTING.md

lint-changelog:
	@npx --yes markdownlint-cli@$(MARKDOWNLINT_VERSION) CHANGELOG.md

changelog:
	@git cliff -o CHANGELOG.md

changelog-check:
	@git cliff -o /tmp/CHANGELOG.md
