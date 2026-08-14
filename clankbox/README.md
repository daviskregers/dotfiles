# clankbox

Run claude/opencode in a disposable microVM sandbox so the agent runs unattended
without touching the host's real credentials or filesystem, with egress locked to an
allowlist. Thin wrapper over [Docker Sandboxes (`sbx`)](https://docs.docker.com/ai/sandboxes/);
sbx does the isolation, clankbox picks the agent + image + session mode.

Design and rationale: [`.dk-notes/plans/clankbox.md`](../.dk-notes/plans/clankbox.md).

## Why

`sbx` gives each session its own kernel, private docker daemon, own filesystem, and a
default-deny egress proxy. So a poisoned dependency or prompt injection can't read your
`~/.aws`/`~/.ssh` (never in the box) or phone home off the allowlist. clankbox adds the
workflow: one shared image with both agents, a curated allowlist, and short commands for
the two session modes.

## Prerequisites

- Docker running.
- `sbx` installed — macOS: `brew install docker/tap/sbx`; Arch: AUR `docker-sbx-bin`.
- `sbx login` (one-time Docker auth).
- `jq` and `rsync` on the host (used to merge settings and copy plugins in).

## Install

```sh
sbx login                                     # one-time Docker auth
make install                                  # symlink ./clankbox into ~/.bin
cp config.example ~/.config/clankbox/config   # set CLANKBOX_AGENT / host models per machine
clankbox setup                                # init default-deny policy + apply allowlist
clankbox build                                # docker build -> save -> sbx template load
```

`setup` is idempotent host prep and owns the sbx `policy init` step, so a fresh machine
runs one command instead of rediscovering it. Colleagues: copy this `clankbox/` dir and
run the same five lines — nothing is pushed or pulled from a registry, each machine
builds locally.

## Use

```sh
clankbox write [PATH] [--agent A] [--name N] [-d]   # editable session
clankbox read  [PATH] [--agent A] [--name N]        # read-only Q&A session
clankbox attach [NAME|N]                            # re-attach to a session
clankbox diff  [NAME|N]                             # show the agent's changes
clankbox pull  [NAME|N]                             # apply them to your host tree
clankbox log [NAME]                                 # egress allow/deny log (tripwire)
clankbox ls | rm NAME
```

- **Naming & multiple sessions.** Sessions auto-name `clankbox-<repo>-<n>` (the leading
  dot in a repo like `.dotfiles` is stripped), so you can run several on one repo —
  each `cbw` takes the next free number. Give a memorable one with `--name refactor`
  (→ `clankbox-refactor`). `diff`/`pull`/`attach` default to **this repo's** session
  (matched by workspace, not name); with several, they print a numbered list — pass a
  number (`clankbox pull 2`) or a name (`clankbox pull refactor`).
- **diff / pull** read the box's working tree directly, so they capture the agent's
  changes **even when it didn't `git commit`** (untracked files included) — a plain
  `git fetch` of the clone would miss those. `pull` applies the changes to your host
  tree uncommitted; you review and commit yourself. If the host tree has diverged and
  the patch won't apply, it's saved as `.clankbox-<name>.patch` for you to handle.

`PATH` defaults to the current directory. Shorthands (symlinked by `install`):
**`cbw` = write, `cbr` = read** — so `cbw` in a repo starts a write session on the cwd.

- **write** uses `sbx --clone`: your working tree is mounted **read-only** (resolved to
  the repo root, so it works from any subdir), the agent edits a private in-container
  clone. On exit clankbox prints how to review its commits (`git fetch sandbox-<name>`
  then `diff HEAD FETCH_HEAD`) — you commit yourself. Nothing the agent did can execute
  on the host until you've read the diff.
- **read** mounts the workspace `:ro` — the agent physically cannot write. For chatting
  about code.
- **agent** is chosen by: `--agent` flag > project `.dk-notes/.agent` > `CLANKBOX_AGENT`
  (machine config) > `claude`.

## Your setup inside the sandbox

The box is fresh, so clankbox copies your **non-secret** config in at session start
(never `~/.claude.json`, sessions, or cloud/SSH creds). What's brought in, per agent,
is configurable in `~/.config/clankbox/config`:

- **`CLANKBOX_INJECT_CLAUDE`** (default `CLAUDE.md commands agents hooks`) — copied as-is.
  Hooks run via `bun` (baked into the image), so `dangerous-command-guard` /
  `ai-attribution` fire inside the box too.
- **settings.json is merged, not copied.** The sbx kit writes a `settings.json` that puts
  the agent in `bypassPermissions` (YOLO) mode; clankbox merges *your* `model`, `hooks`,
  and `permissions` over it while the kit's YOLO keys always win. Host-coupled bits are
  dropped: the macOS `afplay` notification hook, the host-path `statusLine`, and
  marketplace `plugins`/`extraKnownMarketplaces` (those are re-added selectively below).
  Merge rules live in [`lib/merge-settings.jq`](lib/merge-settings.jq).
- **`CLANKBOX_INJECT_PLUGINS`** (e.g. `edurio-core@edurio-plugins`) — marketplace plugins
  copied in **offline**: the plugin cache + marketplace (minus `.git`) are copied and the
  two manifests are path-rewritten to `/home/agent`, then the plugins are enabled in
  settings. **Private marketplaces work with no gh token / network in the box** — the
  files are already on your disk. Verify with `claude plugin details <plugin>` inside.
- **Skills (claude)** are synced separately via `sbx skills import --force` (run
  automatically at the start of each `write`/`read`). sbx bind-mounts its shared skills
  store over `~/.claude/skills`, so skills can't just be copied there — import is the
  supported path. It scans `~/.claude/skills` (symlinks followed), so your clanker skills
  + `/grilling` etc. show up. `--force` re-installs from host truth each session.

### opencode

opencode reads different paths than claude, so its injection is separate (and sbx's
skills store is claude-only). At session start clankbox brings in:

- **Skills** → copied to `~/.config/opencode/skills` (following the `clanker/skills`
  symlink); sbx doesn't mount skills for opencode.
- **`auth.json`** → copied to `~/.local/share/opencode/auth.json` so all your
  subscription models (github-copilot, OpenCode Zen `opencode/*`, anthropic, openai)
  work without logging in per sandbox. Set `CLANKBOX_INJECT_OPENCODE_AUTH=0` to instead
  `opencode auth login` interactively each time (no creds in the box, more friction).
- **`opencode.json`** → your `model` + `agent` (the yolo/permission agent) merged over
  the kit's config; host-coupled `provider` (local model URLs), `plugin`, and `mcp` are
  dropped. `AGENTS.md` + `command` are copied as-is.
- Egress: `opencode.ai` is on the default allowlist for the Zen API.

Injected files are chowned back to the `agent` user (matching the kit's own design, so
claude can manage its settings) — scoped to exactly what was copied, never the whole
`.claude` (which would recurse into the skills bind-mount).

Not brought in (host-coupled, would break in-box): the `statusLine`, and the
codex/plannotator plugins. Add any of those yourself if you have a reason to.

## Allowing more hosts

The default allowlist (`policy.d/default.conf`) covers agent APIs + package/image
registries + github. When the agent legitimately needs a new host, `clankbox log` shows
the drop; allow it with:

```sh
sbx policy allow network some.host.com                 # global
sbx policy allow network --sandbox <name> some.host    # just that session
```

Local model endpoints (ollama/lmstudio) are per-machine: set `CLANKBOX_HOST_MODELS` in
`~/.config/clankbox/config` only where they run.

## Test

```sh
make test   # exercises agent resolution + allowlist assembly; no sbx needed
```
