TDD bug fix. Load `tdd` skill — red-green cycle + rollback protocol.

## Input

Bug: {{.Args}} — none? Ask user.

## Steps

1. **Understand** — read code, reproduce mentally, root cause.
2. **Failing test** — capture buggy behavior. Run → confirm fails.
3. **Fix** — minimal change. Run → confirm passes.
4. **Regressions** — full suite for affected area.

Test change during impl → follow `tdd` rollback protocol.

## Output

- Root cause: ≤2 lines, with `path:line`.
- Test/fix/regressions: 1 line each.
- No diff or test body restatement in chat.
