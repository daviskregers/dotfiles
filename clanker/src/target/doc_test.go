package target_test

import (
	"strings"
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

func TestRenderDoc_ConditionalsAndTail(t *testing.T) {
	d := spec.Doc{
		Shared:       "Rule.{{if .Claude}} (hook.){{end}}\n\n",
		ClaudeTail:   "## Claude tail\n",
		OpencodeTail: "## Opencode tail\n",
	}

	cl := target.Claude{}.RenderDoc(d)
	if cl.RelPath != "claude/.claude/CLAUDE.md" {
		t.Errorf("claude path: %q", cl.RelPath)
	}
	if cl.Content != "Rule. (hook.)\n\n## Claude tail\n" {
		t.Errorf("claude content: %q", cl.Content)
	}

	oc := target.Opencode{}.RenderDoc(d)
	if oc.RelPath != "opencode/.config/opencode/AGENTS.md" {
		t.Errorf("opencode path: %q", oc.RelPath)
	}
	if oc.Content != "Rule.\n\n## Opencode tail\n" { // claude-only span dropped
		t.Errorf("opencode content: %q", oc.Content)
	}
	if strings.Contains(oc.Content, "hook") {
		t.Error("opencode should not contain the claude-only hook span")
	}
}
