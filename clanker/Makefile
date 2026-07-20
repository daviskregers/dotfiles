.PHONY: gen test test-go test-ts

# Regenerate all configs into the dotfiles root.
gen:
	go run ./src -out ..

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
