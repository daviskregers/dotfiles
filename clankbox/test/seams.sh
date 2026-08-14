#!/usr/bin/env bash
# Tests the pure shell seams that need no sbx: agent resolution + allowlist assembly.
set -u
CLI="$(cd "$(dirname "$0")/.." && pwd)/clankbox"
fail=0
check() { # <label> <got> <want>
  if [ "$2" = "$3" ]; then echo "ok   - $1"
  else echo "FAIL - $1: want '$3' got '$2'"; fail=1; fi
}

# resolve_agent precedence, exercised in a clean temp cwd
tmp="$(mktemp -d)"; cd "$tmp"
check "default is claude"               "$(CLANKBOX_AGENT= "$CLI" _resolve-agent)"            "claude"
check "machine config beats default"    "$(CLANKBOX_AGENT=opencode "$CLI" _resolve-agent)"    "opencode"
mkdir -p .dk-notes; echo opencode > .dk-notes/.agent
check "project file beats machine"      "$(CLANKBOX_AGENT=claude "$CLI" _resolve-agent)"      "opencode"
check "flag beats everything"           "$(CLANKBOX_AGENT=claude "$CLI" _resolve-agent claude)" "claude"
echo bogus > .dk-notes/.agent
check "unsupported agent fails"          "$(CLANKBOX_AGENT= "$CLI" _resolve-agent 2>/dev/null || echo ERR)" "ERR"

# allowlist assembly (reads the real policy file; independent of cwd)
check "allowlist includes anthropic"    "$(CLANKBOX_HOST_MODELS= "$CLI" _allowlist | grep -c 'api\.anthropic\.com')" "1"
check "no comments leak through"        "$(CLANKBOX_HOST_MODELS= "$CLI" _allowlist | grep -c '#')" "0"
check "host models appended"            "$(CLANKBOX_HOST_MODELS=host.docker.internal:11434 "$CLI" _allowlist | grep -c '11434')" "1"

echo; [ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"; exit $fail
