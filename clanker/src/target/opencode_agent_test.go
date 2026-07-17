package target_test

import (
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

func TestOpencodeRenderAgent_BashAgent(t *testing.T) {
	a := spec.Agent{
		Name:        "demo",
		Description: "Shared desc",
		Body:        "shared body\n",
		Bash:        []string{"git diff", "git commit"},
		Skills:      []string{"caveman", "caveman-commit"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that does it",
			Body:        "opencode body. Load `caveman` skills.\n",
		}},
	}

	out := target.Opencode{}.RenderAgent(a)

	// Prompt file uses the opencode overlay body verbatim (no auto-injection).
	if out.Files[0].RelPath != "opencode/.config/opencode/prompts/demo.md" {
		t.Errorf("prompt path: %q", out.Files[0].RelPath)
	}
	if out.Files[0].Content != "opencode body. Load `caveman` skills.\n" {
		t.Errorf("prompt: got %q", out.Files[0].Content)
	}

	// Config fragment for opencode.json agent.demo.
	if out.Config == nil || out.Config.File != "opencode/.config/opencode/opencode.json" {
		t.Fatalf("config: %+v", out.Config)
	}
	if got := out.Config.Path; len(got) != 2 || got[0] != "agent" || got[1] != "demo" {
		t.Fatalf("path: %v", got)
	}
	frag := out.Config.Value.(map[string]any)
	if frag["description"] != "Subagent that does it" { // overlay applied
		t.Errorf("description: %v", frag["description"])
	}
	if frag["mode"] != "subagent" || frag["prompt"] != "{file:./prompts/demo.md}" {
		t.Errorf("mode/prompt: %v / %v", frag["mode"], frag["prompt"])
	}
	tools := frag["tools"].(map[string]any)
	if tools["*"] != false || tools["bash"] != true {
		t.Errorf("tools: %v", tools)
	}
	bash := frag["permission"].(map[string]any)["bash"].(map[string]any)
	if bash["*"] != "deny" || bash["git diff*"] != "allow" || bash["git commit*"] != "allow" {
		t.Errorf("permission.bash: %v", bash)
	}
}
