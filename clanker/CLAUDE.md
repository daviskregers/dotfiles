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

## Hooks (`config/hooks/`)

One `spec.Hook` per hook; typed `HookEvent`/`OpencodeEvent` (mistyped event = compile error). Each hook = neutral **core** (`<name>.ts`, exports `run(input: HookInput, ctx): HookResult`) + a thin per-target wrapper the generator builds.

- **Shared runtime** (`hook-utils.ts` = types + adapters that extract input / translate `HookResult`): emitted ONCE per tree and IMPORTED, not inlined. Claude hooks import `./hook-utils`; opencode plugins import `../hook-lib/hook-utils` — OUTSIDE `plugins/`, because opencode auto-discovers `plugins/*.ts` and treats every named export as a plugin candidate. Cores are per-hook → inlined + de-exported (a stray `export` in a plugin file looks like a second plugin to opencode).
- **Per-target event mapping absorbs capability gaps** — `Event` (claude) and `OpencodeEvent` diverge freely. No hook is single-target: e.g. tdd-reminder = claude PreToolUse (before) / opencode `tool.execute.after` (append — before-hooks can't inject non-blocking context); comprehension-nudge = claude `Stop` block / opencode `session.idle` → `client.session.prompt` inject (opencode can't block a turn end).
- **Test the logic, not the wiring.** Extract each core's real logic into pure exported helpers (`isBareDump`, `rewriteCommand`, `parseNumstat`…) + unit-test them (`tests/*.ts`, bun); the generated wrapper stays too thin to test. Adapters covered in `hook-utils.test.ts`. FAIL-OPEN always — a hook bug never blocks/breaks a tool.
- **Registration:** claude via `RenderClaudeHookSettings` → surgical `settings.json` merge (preserves unmanaged events like Notification); command = `bun "$HOME/.claude/hooks/<name>.ts"` (shell-expanded). opencode plugins are auto-discovered — no registration.

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
