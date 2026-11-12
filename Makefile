include tools/mod.mk

# This repo's own targets and hooks go below. Document targets with "## text" so
# `make help` lists them; hooks use double colons (test-extra:: and so on, see tools/mod.mk).

gradients: ## Regenerate the picker gradient PNGs in src/ColorsPlus/Assets
	node tools/generate-picker-gradients.mjs src/ColorsPlus/Assets

test-extra:: ## (checks the gradient PNGs when node is installed)
	@if command -v node >/dev/null; then node tools/generate-picker-gradients.mjs --check src/ColorsPlus/Assets; \
	else echo "node not found: skipped the gradient check"; fi
