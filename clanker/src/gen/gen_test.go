package gen_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"clanker/src/gen"
	"clanker/src/spec"
	"clanker/src/target"
)

// dotfilesRoot makes a temp dir that looks like the dotfiles root: the command
// directory for every target already exists (that is what Run validates).
func dotfilesRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	for _, tg := range target.Registry() {
		if err := os.MkdirAll(filepath.Join(root, tg.CommandDir()), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func TestRun_WritesEachTargetFile(t *testing.T) {
	root := dotfilesRoot(t)
	cmds := []spec.Command{{Name: "demo", Description: "Do", Body: "b\n"}}

	if err := gen.Run(root, cmds, nil, nil, nil, nil, nil, "", target.Registry()); err != nil {
		t.Fatalf("Run: %v", err)
	}

	assertFileContent(t, filepath.Join(root, "claude/.claude/commands/demo.md"),
		"---\ndescription: Do\n---\n\nb\n")
	assertFileContent(t, filepath.Join(root, "opencode/.config/opencode/command/demo.md"),
		"---\ndescription: Do\n---\n\nb\n")
}

// A command dropped from the config has its previously-generated files removed,
// while files clanker never managed (not in the manifest) are left alone.
func TestRun_PrunesDroppedCommands(t *testing.T) {
	root := dotfilesRoot(t)
	// Previously clanker managed "old" and "commit".
	writeManifest(t, root, `["old","commit"]`)
	for _, tg := range target.Registry() {
		seed(t, root, tg.CommandDir(), "old.md", "stale\n")
		seed(t, root, tg.CommandDir(), "keep.md", "hand-authored\n") // never managed
	}

	cmds := []spec.Command{{Name: "commit", Description: "Commit", Body: "go\n"}}
	if err := gen.Run(root, cmds, nil, nil, nil, nil, nil, "", target.Registry()); err != nil {
		t.Fatalf("Run: %v", err)
	}

	for _, tg := range target.Registry() {
		dir := filepath.Join(root, tg.CommandDir())
		assertAbsent(t, filepath.Join(dir, "old.md"))
		assertPresent(t, filepath.Join(dir, "keep.md"))
		assertPresent(t, filepath.Join(dir, "commit.md"))
	}
	assertFileContent(t, filepath.Join(root, gen.ManifestPath), `["commit"]`+"\n")
}

// An agent's opencode.json fragment is merged in without clobbering keys clanker
// doesn't manage (provider, other agents).
func TestRun_MergesAgentIntoOpencodeJSON(t *testing.T) {
	root := dotfilesRoot(t)
	seed(t, root, "opencode/.config/opencode", "opencode.json",
		`{"provider":{"x":1},"agent":{"plan":{"disable":false},"git-committer":{"old":true}}}`)

	agents := []spec.Agent{{Name: "git-committer", Description: "d", Body: "b\n", Bash: []string{"git diff"}}}
	if err := gen.Run(root, nil, agents, nil, nil, nil, nil, "", target.Registry()); err != nil {
		t.Fatalf("Run: %v", err)
	}

	raw, _ := os.ReadFile(filepath.Join(root, "opencode/.config/opencode/opencode.json"))
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatalf("parse result: %v", err)
	}
	if _, ok := m["provider"]; !ok {
		t.Error("provider (unmanaged) was clobbered")
	}
	agent := m["agent"].(map[string]any)
	if _, ok := agent["plan"]; !ok {
		t.Error("plan agent (unmanaged) was clobbered")
	}
	gc := agent["git-committer"].(map[string]any)
	if gc["mode"] != "subagent" {
		t.Errorf("git-committer not regenerated: %v", gc)
	}
	if _, ok := gc["old"]; ok {
		t.Error("managed agent should be replaced wholesale, not deep-merged")
	}
}

func TestRun_ErrorsWhenNotDotfilesRoot(t *testing.T) {
	root := t.TempDir() // no target command dirs

	err := gen.Run(root, []spec.Command{{Name: "x"}}, nil, nil, nil, nil, nil, "", target.Registry())
	if err == nil {
		t.Fatal("expected error when target dirs are absent, got nil")
	}
	if _, statErr := os.Stat(filepath.Join(root, "claude")); statErr == nil {
		t.Error("Run wrote files despite invalid root")
	}
}

func TestRun_FirstRunWithoutManifest(t *testing.T) {
	root := dotfilesRoot(t)

	if err := gen.Run(root, []spec.Command{{Name: "demo", Description: "D", Body: "b\n"}}, nil, nil, nil, nil, nil, "", target.Registry()); err != nil {
		t.Fatalf("Run: %v", err)
	}
	assertPresent(t, filepath.Join(root, "claude/.claude/commands/demo.md"))
	assertFileContent(t, filepath.Join(root, gen.ManifestPath), `["demo"]`+"\n")
}

// --- helpers ---

func writeManifest(t *testing.T, root, json string) {
	t.Helper()
	path := filepath.Join(root, gen.ManifestPath)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(json+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
}

func seed(t *testing.T, root, dir, name, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(root, dir, name), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func assertFileContent(t *testing.T, path, want string) {
	t.Helper()
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if string(got) != want {
		t.Errorf("%s:\n got %q\nwant %q", path, got, want)
	}
}

func assertPresent(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); err != nil {
		t.Errorf("expected %s to exist: %v", path, err)
	}
}

func assertAbsent(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); err == nil {
		t.Errorf("expected %s to be pruned, still present", path)
	}
}
