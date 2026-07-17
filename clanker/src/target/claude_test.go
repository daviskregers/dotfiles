package target_test

import (
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

func TestClaudeRenderCommand_HappyPath(t *testing.T) {
	cmd := spec.Command{
		Name:        "demo",
		Description: "Do a thing",
		Body:        "Run it.\n\n{{args}}\n",
	}

	got := target.Claude{}.RenderCommand(cmd)

	want := []target.OutputFile{{
		RelPath: "claude/.claude/commands/demo.md",
		Content: "---\ndescription: Do a thing\n---\n\nRun it.\n\n$ARGUMENTS\n",
	}}
	assertFiles(t, got, want)
}

func TestClaudeRenderCommand_DescriptionOverlay(t *testing.T) {
	cmd := spec.Command{
		Name:        "demo",
		Description: "shared",
		Body:        "body\n",
		Overlay:     spec.Overlays{Claude: spec.ClaudeOverlay{Description: "claude-specific"}},
	}

	got := target.Claude{}.RenderCommand(cmd)

	if len(got) != 1 || got[0].Content != "---\ndescription: claude-specific\n---\n\nbody\n" {
		t.Fatalf("overlay description not applied: %+v", got)
	}
}

// argument-hint and allowed-tools are claude-only frontmatter, emitted after
// description in that order, and only when set.
func TestClaudeRenderCommand_ExtraFrontmatter(t *testing.T) {
	cmd := spec.Command{
		Name:        "friction",
		Description: "Capture friction",
		Body:        "go\n",
		Overlay: spec.Overlays{Claude: spec.ClaudeOverlay{
			ArgumentHint: "[path — defaults to latest]",
			AllowedTools: "Bash(capture:*)",
		}},
	}

	got := target.Claude{}.RenderCommand(cmd)

	want := "---\ndescription: Capture friction\n" +
		"argument-hint: [path — defaults to latest]\n" +
		"allowed-tools: Bash(capture:*)\n---\n\ngo\n"
	if len(got) != 1 || got[0].Content != want {
		t.Fatalf("extra frontmatter wrong:\n got %q\nwant %q", contentOf(got), want)
	}
}

// ArgsFirstPositional still renders $ARGUMENTS on claude (claude has no positional form).
func TestClaudeRenderCommand_ArgStyleIgnored(t *testing.T) {
	cmd := spec.Command{Name: "demo", Description: "d", Body: "{{args}}\n", Args: spec.ArgsFirstPositional}

	got := target.Claude{}.RenderCommand(cmd)

	if got[0].Content != "---\ndescription: d\n---\n\n$ARGUMENTS\n" {
		t.Fatalf("claude should always use $ARGUMENTS: %q", contentOf(got))
	}
}
