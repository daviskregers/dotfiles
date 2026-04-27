#!/bin/bash
# validate-bash.sh — Restrict bash commands to allowed prefixes for subagents.
# Usage: validate-bash.sh 'prefix1' 'prefix2' ...
# Reads PreToolUse hook JSON from stdin, checks command against allowed patterns.
# Exit 0 = allow, Exit 2 = block (message shown to agent).

set -euo pipefail

INPUT=$(cat)

# Extract command — handle both nested (tool_input.command) and flat (command) formats
COMMAND=$(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
ti = data.get('tool_input', data)
print(ti.get('command', ''))
" "$INPUT" 2>/dev/null)

if [ -z "$COMMAND" ]; then
    echo "BLOCKED: Could not parse command from hook input" >&2
    exit 2
fi

# Reject shell chaining / injection operators
# Note: single pipe | deliberately blocked — agents should not need piped commands
for meta in '&&' '||' ';' '|' '$(' '`'; do
    if [[ "$COMMAND" == *"$meta"* ]]; then
        echo "BLOCKED: Shell operator '$meta' not allowed in restricted agent" >&2
        exit 2
    fi
done

# Check command against allowed prefix patterns
# Matches exact command OR command followed by space+args
# Prevents prefix collisions: "git diff" won't match "git diff-tree"
for pattern in "$@"; do
    if [[ "$COMMAND" == "$pattern" || "$COMMAND" == "$pattern "* ]]; then
        exit 0
    fi
done

echo "BLOCKED: '$COMMAND' not in allowed list: $*" >&2
exit 2
