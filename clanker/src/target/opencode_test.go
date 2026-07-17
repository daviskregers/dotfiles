package target_test

import (
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

// Default ArgStyle (ArgsAll) renders {{args}} as $ARGUMENTS on opencode.
func TestOpencodeRenderCommand_ArgsAll(t *testing.T) {
	cmd := spec.Command{
		Name:        "demo",
		Description: "Do a thing",
		Body:        "Run it.\n\n{{args}}\n",
	}

	got := target.Opencode{}.RenderCommand(cmd)

	want := []target.OutputFile{{
		RelPath: "opencode/.config/opencode/command/demo.md",
		Content: "---\ndescription: Do a thing\n---\n\nRun it.\n\n$ARGUMENTS\n",
	}}
	assertFiles(t, got, want)
}

// ArgsFirstPositional renders {{args}} as $1 on opencode.
func TestOpencodeRenderCommand_ArgsFirstPositional(t *testing.T) {
	cmd := spec.Command{
		Name:        "ship",
		Description: "Ship",
		Body:        "base: {{args}}\n",
		Args:        spec.ArgsFirstPositional,
	}

	got := target.Opencode{}.RenderCommand(cmd)

	if got[0].Content != "---\ndescription: Ship\n---\n\nbase: $1\n" {
		t.Fatalf("ArgsFirstPositional should use $1: %q", contentOf(got))
	}
}

func TestOpencodeRenderCommand_Agent(t *testing.T) {
	cmd := spec.Command{
		Name:        "commit",
		Description: "Commit",
		Body:        "go\n",
		Overlay:     spec.Overlays{Opencode: spec.OpencodeOverlay{Agent: "git-committer"}},
	}

	got := target.Opencode{}.RenderCommand(cmd)

	want := "---\ndescription: Commit\nagent: git-committer\n---\n\ngo\n"
	if len(got) != 1 || got[0].Content != want {
		t.Fatalf("agent frontmatter wrong:\n got %q\nwant %q", contentOf(got), want)
	}
}

func TestOpencodeRenderCommand_BodyOverlay(t *testing.T) {
	cmd := spec.Command{
		Name:        "commit",
		Description: "Commit",
		Body:        "shared body\n",
		Overlay:     spec.Overlays{Opencode: spec.OpencodeOverlay{Body: "opencode-only body\n"}},
	}

	got := target.Opencode{}.RenderCommand(cmd)

	want := "---\ndescription: Commit\n---\n\nopencode-only body\n"
	if len(got) != 1 || got[0].Content != want {
		t.Fatalf("overlay body not applied:\n got %q\nwant %q", contentOf(got), want)
	}
}
