# clanker

Config generator: define each command/agent/tool ONCE (type-safe Go), emit per-tool configs (claude, opencode; later pi). Kills manual dual-sync. Full design: `../.dk-notes/plans/config-builder.md`.

## Layout — engine vs data, strict split

- `src/` = generator source (engine). `config/` = the data it consumes.
- **Engine NEVER imports `config`.** One-way deps: `config → src/spec`; `src/{target,gen,main} → src/spec`. Adding a second data set never touches the engine.
- `src/spec` — schema types only (no data, no IO). `src/target` — pure renderers. `src/gen` — the ONLY package doing IO. `src/main.go` — thin CLI wiring.

## Spec authoring (`config/`)

- Specs are Go values (`spec.Command`), not parsed text — compiler enforces shape. NO YAML parsing anywhere; we only *emit* frontmatter.
- Bodies live as markdown under `config/bodies/*.md`, pulled via `go:embed` + `body("x.md")` (backtick-heavy prose can't be Go string literals). Per-target override body = `<name>.<target>.md` (e.g. `commit.opencode.md`).
- `{{args}}` in a body is the neutral args token → `$ARGUMENTS` (claude) / `$1` (opencode).
- Per-target divergence goes in `Overlay`; zero-valued field inherits shared. `model` is NOT neutral — always per-target overlay (no anthropic on opencode).
- Reconcile trivial drift (typos, wording) to one canonical value; represent INTENTIONAL divergence as an overlay (keep round-trip byte-faithful).

## Adding a target

New file in `src/target` implementing `Target` + one line in `Registry()`. Targets are struct FIELDS in `spec.Overlays` (not map keys) — so adding one is a compile error until every consumer handles it. That's the pluggable seam; keep it.

## TDD (mandatory)

Red→green→refactor, tests alongside. Renderers tested directly (pure: Command in → OutputFile out); `gen` via temp dir. Keep renderers pure — no IO leaks into `src/target`.

## Verify

Regenerate + confirm round-trip against committed configs (byte-identical except intended reconciliations):

```
go run ./src -out ..     # from clanker/
```

## Conventions

- Comments: load-bearing "why" only; never restate code.
- Commit BOTH source and generated output (`claude/`, `opencode/`) — generated files must work for people who don't run clanker.
- `clanker` is excluded from stow (build tool, not `$HOME` config).
