package target_test

import (
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

// Default ArgStyle (ArgsAll) renders {{.Args}} as $ARGUMENTS on opencode.
func TestOpencodeRenderCommand_ArgsAll(t *testing.T) {
	cmd := spec.Command{
		Name:        "demo",
		Description: "Do a thing",
		Body:        "Run it.\n\n{{.Args}}\n",
	}

	got := target.Opencode{}.RenderCommand(cmd)

	want := []target.OutputFile{{
		RelPath: "opencode/.config/opencode/command/demo.md",
		Content: "---\ndescription: Do a thing\n---\n\nRun it.\n\n$ARGUMENTS\n",
	}}
	assertFiles(t, got, want)
}

// ArgsFirstPositional renders {{.Args}} as $1 on opencode.
func TestOpencodeRenderCommand_ArgsFirstPositional(t *testing.T) {
	cmd := spec.Command{
		Name:        "ship",
		Description: "Ship",
		Body:        "base: {{.Args}}\n",
		Args:        spec.ArgsFirstPositional,
	}

	got := target.Opencode{}.RenderCommand(cmd)

	if got[0].Content != "---\ndescription: Ship\n---\n\nbase: $1\n" {
		t.Fatalf("ArgsFirstPositional should use $1: %q", contentOf(got))
	}
}

// Agent-only delegation (no Task): sets `agent:` frontmatter, body stays authored.
func TestOpencodeRenderCommand_Agent(t *testing.T) {
	cmd := spec.Command{
		Name:        "commit",
		Description: "Commit",
		Body:        "go\n",
		Delegates:   &spec.Delegation{Agent: &spec.Agent{Name: "git-committer"}},
	}

	got := target.Opencode{}.RenderCommand(cmd)

	want := "---\ndescription: Commit\nagent: git-committer\n---\n\ngo\n"
	if len(got) != 1 || got[0].Content != want {
		t.Fatalf("agent frontmatter wrong:\n got %q\nwant %q", contentOf(got), want)
	}
}

// Full delegation (Task set): both bodies are generated from the delegation.
func TestRenderCommand_DelegationGeneratesBodies(t *testing.T) {
	cmd := spec.Command{
		Name:        "commit",
		Description: "Commit staged changes",
		Delegates:   &spec.Delegation{Agent: &spec.Agent{Name: "git-committer"}, Task: "commit staged changes"},
	}

	cl := target.Claude{}.RenderCommand(cmd)[0].Content
	wantCl := "---\ndescription: Commit staged changes\n---\n\nUse git-committer agent to commit staged changes.\n\n$ARGUMENTS\n"
	if cl != wantCl {
		t.Errorf("claude:\n got %q\nwant %q", cl, wantCl)
	}

	oc := target.Opencode{}.RenderCommand(cmd)[0].Content
	wantOc := "---\ndescription: Commit staged changes\nagent: git-committer\n---\n\nCommit staged changes.\n\n$ARGUMENTS\n"
	if oc != wantOc {
		t.Errorf("opencode:\n got %q\nwant %q", oc, wantOc)
	}
}

// Body divergence is expressed inline via {{if}} spans, not a whole-body overlay.
func TestRenderCommand_InlineConditionalBody(t *testing.T) {
	cmd := spec.Command{Name: "x", Description: "X", Body: "base{{if .Opencode}} oc-only{{end}}\n"}

	oc := target.Opencode{}.RenderCommand(cmd)[0].Content
	if oc != "---\ndescription: X\n---\n\nbase oc-only\n" {
		t.Errorf("opencode: %q", oc)
	}
	cl := target.Claude{}.RenderCommand(cmd)[0].Content
	if cl != "---\ndescription: X\n---\n\nbase\n" {
		t.Errorf("claude: %q", cl)
	}
}
