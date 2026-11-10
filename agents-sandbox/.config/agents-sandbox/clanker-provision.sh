#!/usr/bin/env bash
# Startup hook, runs as `dev` on every VM start. Links the clanker-generated claude/opencode
# configs from the read-only dotfiles mount into the VM home, the same way `make` does on the host.
# Fails loudly: the hooks fail open, so a half-provisioned VM would look like a working one.
set -euo pipefail

dotfiles="$HOME/.dotfiles"
fail() { echo "clanker-provision: $*" >&2; exit 1; }

# Fail with the host's name instead of an installer's vague error when DNS or egress is broken
# (e.g. microsandbox's forwarder can't parse DNS answers over 512 bytes).
wait_for_host() {
  local waited
  for waited in $(seq 0 30); do
    curl -s -o /dev/null -m 2 "https://$1/" && { echo "clanker-provision: $1 ready after ${waited}s"; return; }
    sleep 1
  done
  fail "no egress to $1 after 30s"
}

for cmd in make python3 git curl unzip; do
  command -v "$cmd" >/dev/null || fail "runner image is missing $cmd"
done
[[ -f $dotfiles/Makefile ]] || fail "$dotfiles is not mounted"

# The mount is owned by the host's uid, so git refuses it as "dubious ownership" without this.
git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$dotfiles" \
  || git config --global --add safe.directory "$dotfiles"

# The home volume persists, so bun is installed once per project VM.
if [[ ! -x $HOME/.bun/bin/bun ]]; then
  # The installer fetches from bun.sh, then a GitHub release that redirects to release-assets.
  for host in bun.sh github.com release-assets.githubusercontent.com; do wait_for_host "$host"; done
  curl -fsSL https://bun.sh/install | bash
fi
# Hooks are registered as `bun ...`, so bun must be on the agent's PATH, not just this script's.
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.bun/bin/bun" "$HOME/.local/bin/bun"

# The modules' POST_INSTALL runs `bun install` in ~/.claude/mcp-tools and ~/.config/opencode. Those are
# real dirs in the VM home (dotctl links files, not dirs), so node_modules lands there, not in the mount.
export PATH="$HOME/.bun/bin:$PATH"
wait_for_host registry.npmjs.org

# NEED_GEN= : no Go in the VM, and the generated output is committed anyway.
# FORCE=1 : files the agent wrote into the home volume before provisioning get backed up, not block it.
for module in claude opencode; do
  make -C "$dotfiles" install MODULE="$module" NEED_GEN= FORCE=1
done

# install-mcp.py exits if ~/.claude.json is missing, which it is before Claude Code's first run.
[[ -f $HOME/.claude.json ]] || echo '{}' >"$HOME/.claude.json"
make -C "$dotfiles/clanker" install-mcp
