PLENARY_PATH ?= $(firstword $(wildcard $(HOME)/.local/share/nvim/packages/plenary.nvim) $(wildcard $(HOME)/.local/share/nvim/packages/*/plenary.nvim) $(wildcard $(HOME)/.local/share/nvim/lazy/plenary.nvim))
MARKDOWNLINT_FILES ?= README.md CONTRIBUTING.md
MARKDOWNLINT_VERSION ?= 0.48.0

.PHONY: test bench setup-hooks docs lint lint-fix lint-changelog changelog changelog-check

test:
	@tmpfile="$$(mktemp)"; \
	trap 'rm -f "$$tmpfile"' EXIT; \
	env -u NVIM_LISTEN_ADDRESS XDG_CACHE_HOME=/tmp XDG_STATE_HOME=/tmp PLENARY_PATH="$(PLENARY_PATH)" nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}" >"$$tmpfile" 2>&1; \
	status="$$?"; \
	cat "$$tmpfile"; \
	if [ "$$status" -ne 0 ]; then \
		exit "$$status"; \
	fi; \
	if grep -Eq 'Failed :[[:space:]]+[1-9][0-9]*|Errors :[[:space:]]+[1-9][0-9]*' "$$tmpfile"; then \
		exit 1; \
	fi

bench:
	@env -u NVIM_LISTEN_ADDRESS nvim -l tests/bench.lua

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
