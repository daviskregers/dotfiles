package target_test

import (
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
	a := spec.Agent{Name: "tutor", Description: "Teach", ReadOnly: true, MaxTurns: 50, Body: "teach\n"}

	out := target.Claude{}.RenderAgent(a)

	want := "---\nname: tutor\ndescription: Teach\ntools: Read, Grep, Glob\nmaxTurns: 50\n---\n\nteach\n"
	if out.Files[0].Content != want {
		t.Errorf("content:\n got %q\nwant %q", out.Files[0].Content, want)
	}
}
