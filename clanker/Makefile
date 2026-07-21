.PHONY: gen test test-go test-ts check

# Regenerate all configs into the dotfiles root.
gen:
	go run ./src -out ..

# Drift gate (CI runs this on a clean checkout): regenerate, fail if committed output
# differs, then test. Guarantees "generated == committed" — the promise that clanker's
# output works for people who don't run it. Run locally only on a clean tree.
check: gen
	@git -C .. diff --exit-code -- claude opencode clanker/generated-commands.json \
		|| { echo "ERROR: generated output is stale — run 'make gen' and commit the result"; exit 1; }
	$(MAKE) test

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
