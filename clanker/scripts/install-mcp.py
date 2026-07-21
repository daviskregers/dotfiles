#!/usr/bin/env python3
"""Merge clanker's generated MCP registration into ~/.claude.json.

claude has no committed-global MCP config (settings.json can't hold servers; a
committed .mcp.json is project-scoped only), so the registration is single-sourced as
a generated fragment and applied here. Backs up first; expands $HOME to an absolute
path because MCP server args are NOT shell-expanded at spawn. Only touches the
mcpServers key — every other setting/project/auth in the file is preserved.
"""
import json
import os
import pathlib
import sys

home = os.path.expanduser("~")
claude_json = pathlib.Path(home) / ".claude.json"
frag_path = pathlib.Path(__file__).resolve().parents[2] / "claude/.claude/mcp-tools/mcp-registration.json"

frag = json.loads(frag_path.read_text())
for server in frag.values():
    server["args"] = [a.replace("$HOME", home) for a in server.get("args", [])]

if not claude_json.exists():
    print(f"{claude_json} not found — is Claude Code installed?", file=sys.stderr)
    sys.exit(1)

data = json.loads(claude_json.read_text())
pathlib.Path(str(claude_json) + ".bak").write_text(json.dumps(data))
data.setdefault("mcpServers", {}).update(frag)
claude_json.write_text(json.dumps(data, indent=2))

print("registered mcpServers in ~/.claude.json:", ", ".join(frag))
print("backup written to ~/.claude.json.bak")
