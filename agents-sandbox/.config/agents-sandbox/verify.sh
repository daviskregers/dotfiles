#!/usr/bin/env bash
# Run INSIDE the sandbox (agents-sandbox shell) to check each requirement.
# Never prints secret values: a bug that leaks the real token would end up in your scrollback.
set -u

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
check() { if eval "$2" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

# curl prints 000 when the connection never completes (blocked or unreachable).
http_code() { curl -s -o /dev/null -m 5 -w '%{http_code}' "$1"; }

echo "secrets"
check "CLAUDE_CODE_OAUTH_TOKEN is a placeholder, not the real token" \
  '[[ ${CLAUDE_CODE_OAUTH_TOKEN:-} == \$MSB_* ]]'

echo "network"
check "api.anthropic.com reachable" '[[ $(http_code https://api.anthropic.com) != 000 ]]'
check "example.com blocked"         '[[ $(http_code https://example.com) == 000 ]]'

echo "docker"
check "docker run hello-world" 'docker run --rm hello-world'

echo "resources"
echo "  cpus:   $(nproc)"
echo "  memory: $(awk '/MemTotal/ { printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo)"

echo "clanker"
check "bun on PATH (hooks are silently off without it)" 'command -v bun'
