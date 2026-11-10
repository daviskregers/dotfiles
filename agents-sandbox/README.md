# agents-sandbox

Runs coding agents unattended in an [agents-sandbox](https://inoio.github.io/agents-sandbox/) microVM.
`make` links everything in `.config/agents-sandbox/` into `~/.config/agents-sandbox/`. Start a
session in the current repo with `asb` (alias in `common/.functions`), or `asb shell` for a shell.

## How a VM gets set up

- `config.yaml`: agent, resources, Docker, read-only dotfiles mount, network allowlist.
- `sandbox-startup.sh`: startup hook, runs as root on every VM start. Installs `make` (missing from
  the runner image), then runs `clanker-provision.sh` as `dev`.
- `clanker-provision.sh`: installs bun once per home volume, then runs the same
  `make install MODULE=claude|opencode` as on the host. Settings, hooks, skills and commands are
  links into the read-only mount, so the agent can't change them. `node_modules` for `mcp-tools`
  and the opencode plugins are installed into the VM home.
- `verify.sh`: run inside the VM to check secrets, network, Docker, resources and bun.

The VM home is a plain directory on the host:
`~/.local/share/agents-sandbox/msb/volumes/<project>-<agent>-<timestamp>/`.

## Auth

Secrets never go in the repo or in the VM. They live in `~/.config/agents-sandbox/env.secret.yaml`.
The VM only sees a placeholder (`$MSB_<NAME>`), which the host proxy swaps for the real value on
requests to the bound host.

1. Create a long-lived subscription token. This opens the same browser approval as `/login` and
   prints a one-year token. It isn't saved anywhere, so copy it.

   ```sh
   claude setup-token
   ```

2. Write the secrets file and lock it down:

   ```yaml
   # ~/.config/agents-sandbox/env.secret.yaml
   CLAUDE_CODE_OAUTH_TOKEN:
     value: "<token from step 1>"
     host: api.anthropic.com
   GH_TOKEN:
     value: "<output of gh auth token>"
     host: api.github.com
   ```

   ```sh
   chmod 600 ~/.config/agents-sandbox/env.secret.yaml
   ```

This token only makes model requests. claude.ai connectors (e.g. the Linear connector) don't load
inside the sandbox, so configure those MCP servers locally. Keep `ANTHROPIC_API_KEY` out of the
VM: it takes precedence over the OAuth token and would bill the API instead of the subscription.

`GH_TOKEN` bound to `api.github.com` covers `gh` and the GitHub MCP. `git push` over HTTPS goes to
`github.com`, so it would send the placeholder and get a 401.

## Gotchas

- **Network changes need a new VM.** Changes to `network:` aren't picked up by a restart. Run
  `asb stop && asb sandbox remove`, then start again. The home volume is kept.
- **DNS.** microsandbox's DNS forwarder fails on answers over 512 bytes ("decoding error: unexpected
  end of input" in `…/sandboxes/<name>/logs/runtime.log`). The home router pads answers past that,
  so `config.yaml` uses `1.1.1.1` instead.
- **Redirect targets need their own entry.** Registries and release downloads redirect to CDN or
  storage hosts (e.g. Docker Hub to `production.cloudfront.docker.com`).
- **Session history is per path.** In the VM every project is `/workspace`, so `/resume` there only
  shows VM sessions, and VM sessions don't show up on the host.

## Verify

From `~/.dotfiles`:

```sh
asb shell
bash agents-sandbox/.config/agents-sandbox/verify.sh
```
