package target_test

import (
	"strings"
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

// A bash agent: tools:Bash derived from Bash prefixes, skills list, and the
// PreToolUse validate-bash hook built from those prefixes.
func TestClaudeRenderAgent_BashAgent(t *testing.T) {
	a := spec.Agent{
		Name:        "demo",
		Description: "Demo agent",
		Model:       "sonnet",
		MaxTurns:    8,
		Bash:        []string{"git diff", "git commit"},
		Skills:      []string{"caveman", "caveman-commit"},
		Body:        "Do the thing.\n",
	}

	out := target.Claude{}.RenderAgent(a)

	want := "---\n" +
		"name: demo\n" +
		"description: Demo agent\n" +
		"tools: Bash\n" +
		"model: sonnet\n" +
		"maxTurns: 8\n" +
		"skills:\n  - caveman\n  - caveman-commit\n" +
		"hooks:\n  PreToolUse:\n    - matcher: \"Bash\"\n      hooks:\n" +
		"        - type: command\n" +
		"          command: \"bash ~/.claude/scripts/validate-bash.sh 'git diff' 'git commit'\"\n" +
		"---\n\nDo the thing.\n"

	if out.Config != nil {
		t.Errorf("claude agent should have no config merge, got %+v", out.Config)
	}
	if len(out.Files) != 1 {
		t.Fatalf("want 1 file, got %d", len(out.Files))
	}
	if out.Files[0].RelPath != "claude/.claude/agents/demo.md" {
		t.Errorf("path: got %q", out.Files[0].RelPath)
	}
	if out.Files[0].Content != want {
		t.Errorf("content:\n got %q\nwant %q", out.Files[0].Content, want)
	}
}

// A read-only agent: tools:Read, Grep, Glob, no hook, no skills.
func TestClaudeRenderAgent_ReadOnly(t *testing.T) {
	a := spec.Agent{Name: "tutor", Description: "Teach", Read: true, MaxTurns: 50, Body: "teach\n"}

	out := target.Claude{}.RenderAgent(a)

	want := "---\nname: tutor\ndescription: Teach\ntools: Read, Grep, Glob\nmaxTurns: 50\n---\n\nteach\n"
	if out.Files[0].Content != want {
		t.Errorf("content:\n got %q\nwant %q", out.Files[0].Content, want)
	}
}

// Denylist agent (pr-describer shape): disallowedTools + mcpServers, no tools allowlist.
func TestClaudeRenderAgent_Denylist(t *testing.T) {
	a := spec.Agent{
		Name: "pr-describer", Description: "PR", Model: "sonnet", MaxTurns: 10,
		Deny: []string{"Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"},
		MCP:  []string{"read-pr-info", "update-pr-info"},
		Body: "go\n",
	}

	got := target.Claude{}.RenderAgent(a).Files[0].Content

	want := "---\nname: pr-describer\ndescription: PR\n" +
		"disallowedTools: Read, Write, Edit, Bash, Glob, Grep, Agent\n" +
		"model: sonnet\nmaxTurns: 10\nmcpServers:\n  - custom-tools\n---\n\ngo\n"
	if got != want {
		t.Errorf("denylist agent:\n got %q\nwant %q", got, want)
	}
}

// Read + Write + Bash + MCP (code-reviewer shape): full allowlist + mcpServers + hook.
func TestClaudeRenderAgent_ReadWriteBashMCP(t *testing.T) {
	a := spec.Agent{
		Name: "code-reviewer", Description: "CR", Model: "sonnet", MaxTurns: 20,
		Read: true, Write: true, Bash: []string{"git diff"}, MCP: []string{"save-code-review"},
		Skills: []string{"artifact-output"}, Body: "go\n",
	}

	got := target.Claude{}.RenderAgent(a).Files[0].Content

	if !strings.Contains(got, "tools: Read, Grep, Glob, Bash, Write\n") ||
		!strings.Contains(got, "mcpServers:\n  - custom-tools\n") ||
		!strings.Contains(got, "validate-bash.sh 'git diff'") {
		t.Errorf("code-reviewer shape wrong:\n%s", got)
	}
}
