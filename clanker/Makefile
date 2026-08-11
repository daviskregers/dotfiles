.PHONY: gen test test-go test-ts check lint lint-go lint-ts doctor bootstrap install-mcp

# Install the TS dependencies that are gitignored out of the repo: the claude MCP
# server's runtime deps (without which the custom-tools server fails to launch and
# every mcp__custom-tools__* tool silently vanishes) + the hook/tool test deps.
# Run once after cloning.
bootstrap:
	cd config/hooks && bun install
	cd config/tools && bun install
	cd ../claude/.claude/mcp-tools && bun install
	$(MAKE) install-mcp

# Merge the generated MCP registration into ~/.claude.json (the only global location
# claude reads it from). Backs up first; safe to re-run (idempotent).
install-mcp:
	python3 scripts/install-mcp.py

# Preflight for a new machine. The generated hooks run via `bun`; a missing bun
# silently disables ALL of them — including dangerous-command-guard, which fails OPEN
# (no deny emitted → the command runs). Run this after cloning so that gap is loud.
doctor:
	@command -v bun >/dev/null || { echo "MISSING bun — hooks won't run; dangerous-command-guard fails OPEN"; exit 1; }
	@command -v go  >/dev/null || { echo "MISSING go — cannot regenerate configs"; exit 1; }
	@echo "ok: bun $$(bun --version), $$(go version | awk '{print $$3}')"

# Regenerate all configs into the dotfiles root.
gen:
	go run ./src -out ..

# Drift gate (CI runs this on a clean checkout): lint, regenerate, fail if committed
# output differs, then test. Guarantees "generated == committed" — the promise that
# clanker's output works for people who don't run it. Run locally only on a clean tree.
check: lint gen
	@git -C .. diff --exit-code -- claude opencode clanker/generated-manifest.json \
		|| { echo "ERROR: generated output is stale — run 'make gen' and commit the result"; exit 1; }
	$(MAKE) test

# Lint both languages. Go: vet + gofmt. TS: typecheck (tsc) + format-check (prettier,
# same style gen emits). Source cores only — generated output is checked by `check`.
lint: lint-go lint-ts

lint-go:
	go vet ./...
	@unformatted="$$(gofmt -l src config)"; test -z "$$unformatted" || { echo "gofmt needs: $$unformatted"; exit 1; }

lint-ts:
	@for d in config/hooks config/tools; do \
		echo "lint ($$d)"; \
		(cd $$d && bunx tsc --noEmit) || exit 1; \
		bunx prettier@3.9.5 --check --print-width 120 --no-semi --tab-width 4 "$$d/*.ts" "$$d/tests/*.ts" || exit 1; \
	done

# Run the full suite: Go engine tests + TypeScript core tests (bun).
test: test-go test-ts

test-go:
	go test ./...

# TS cores (tools/hooks) carry their own bun tests under tests/. Run bun only in
# dirs that actually have tests, so an untested core dir isn't a failure.
test-ts:
	@for d in config/hooks config/tools; do \
		if ls $$d/tests/*.test.ts >/dev/null 2>&1; then echo "bun test ($$d)"; (cd $$d && bun test) || exit 1; fi; \
	done
