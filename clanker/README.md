# clanker

A config generator that defines each AI-assistant artifact **once** (in type-safe Go)
and emits per-tool configs for both [Claude Code](https://claude.com/claude-code) and
[opencode](https://opencode.ai). It kills the manual dual-maintenance of two parallel
config trees.

## The problem

The dotfiles carry two config trees for two CLIs that do the same jobs differently:

```
claude/.claude/            opencode/.config/opencode/
  commands/*.md              command/*.md          # $ARGUMENTS vs $1, different frontmatter
  agents/*.md                prompts/*.md + opencode.json
  hooks/*.ts + settings.json plugins/*.ts          # stdin/stdout vs plugin API
  mcp-tools/ (MCP server)    tools/ (tool() exports)
  CLAUDE.md                  AGENTS.md
```

Every command/agent/hook/tool used to be hand-copied between them and drift silently.
clanker makes each artifact a single Go value + a neutral body/core, and generates
both trees. ~99% is shared; genuine per-tool differences are expressed as inline
`{{if .Claude}}` / `{{if .Opencode}}` template spans or typed overlay fields.

## How it works

```
config/  ──────►  src/spec  ◄──  src/target  ◄──  src/gen  ◄──  main.go
(data)            (schema)       (pure renderers)  (only IO)     (CLI)
```

- **One-way dependencies.** The engine (`src/`) never imports `config/`; adding a
  second data set never touches the engine.
- `src/spec` — schema types only (`Command`, `Agent`, `Hook`, `Tool`, `Doc`), with
  typed enums (`HookEvent`, `OpencodeEvent`, `ArgType`, `AgentMode`) so a bad value is
  a compile error, not a silent mis-generation.
- `src/target` — **pure** renderers (spec in → files out, no IO). One file per target
  implementing the `Target` interface; `Registry()` lists them.
- `src/gen` — the **only** package that touches the filesystem: render everything,
  prune files no longer generated, write, merge shared JSON (`settings.json`,
  `opencode.json`), write the manifest.
- `config/` — the data: Go values in `config.go`, prompt bodies in `bodies/*.md`, and
  TS cores in `hooks/*.ts` + `tools/*.ts` (pulled in via `go:embed`).

Generated output is **committed** — it works for people who don't run clanker.

## Usage

```sh
make gen        # regenerate both trees into the dotfiles root
make test       # go test ./... + bun tests (hook & tool cores)
make lint       # go vet + gofmt, tsc + prettier
make check      # lint + gen + fail on any drift vs committed + test  (what CI runs)
```

### Fresh machine

```sh
make doctor     # verify bun + go are on PATH (a missing bun silently disables hooks)
make bootstrap  # bun install the gitignored deps + register the MCP server in ~/.claude.json
```

## Adding an artifact

Everything is authored in `config/`:

| Artifact | Define in | Body/logic |
|----------|-----------|------------|
| Command  | `spec.Command` in `config.go` | `bodies/<name>.md` (`{{.Args}}` token; `<name>.<target>.md` overrides) |
| Agent    | `spec.Agent` in `config.go`   | `bodies/<name>.md` |
| Hook     | `spec.Hook` in `config.go`    | `hooks/<name>.ts` — exports `run(input, ctx): HookResult` |
| Tool     | `spec.Tool` in `config.go`    | `tools/<name>.ts` — exports `execute(args, ctx): Promise<string>` |
| Doc      | `spec.Doc` in `config.go`     | `bodies/<name>.md` |

Then `make gen` and commit **both** the source and the generated output. Per-tool
divergence goes in inline `{{if}}` spans or the spec's `Overlay` fields — never by
hand-editing a generated file. See `CLAUDE.md` for the authoring conventions (TDD,
overlays vs conditionals, hook event mapping, the opencode plugin-loader gotcha).

## Adding a target

Add a file in `src/target` implementing the `Target` interface + one line in
`Registry()`. Because targets are struct fields (not map keys) throughout the spec,
the compiler flags every place that must handle the new target.

## Skills

Skills are a single git submodule at `clanker/skills`, symlinked into both trees —
commit in the submodule and bump the one pointer (no per-tool clones).
