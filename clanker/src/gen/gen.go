// Package gen is the only clanker package that touches the filesystem: it renders
// every command with every target, writes the results under an output root, and
// prunes files for commands that were generated before but no longer exist.
package gen

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"clanker/src/spec"
	"clanker/src/target"
)

// ManifestPath records (relative to the output root) every file clanker generated
// last run, so any dropped artifact's stale file can be pruned without touching files
// clanker never managed.
const ManifestPath = "clanker/generated-manifest.json"

func Run(outRoot string, cmds []spec.Command, agents []spec.Agent, docs []spec.Doc, tools []spec.Tool, toolUtils []spec.ToolUtil, hooks []spec.Hook, hookUtils string, targets []target.Target) error {
	if err := validateRoot(outRoot, targets); err != nil {
		return err
	}
	if err := checkSkills(outRoot, agents); err != nil {
		return err
	}

	// Render everything first, then prune → write → merge → manifest. Collecting all
	// standalone files up front lets prune remove ANY dropped artifact (agent/tool/hook/
	// doc), not just commands — critical for opencode, which auto-runs a stale tool or
	// plugin file until it's deleted.
	files, merges := render(cmds, agents, docs, tools, toolUtils, hooks, hookUtils, targets)

	current := relPaths(files)
	prev, err := readManifest(outRoot)
	if err != nil {
		return err
	}
	if err := prune(outRoot, prev, current); err != nil {
		return err
	}

	for _, f := range files {
		if err := writeFile(outRoot, f); err != nil {
			return err
		}
		if strings.HasSuffix(f.RelPath, ".ts") {
			if err := formatTS(filepath.Join(outRoot, f.RelPath)); err != nil {
				return err
			}
		}
	}
	if err := applyConfigMerges(outRoot, merges); err != nil {
		return err
	}
	return writeManifest(outRoot, current)
}

// render produces every standalone generated file and every shared-config merge,
// without touching the filesystem. Hook registration (claude settings.json) uses the
// same merge mechanism as agents; opencode plugins/tools are auto-discovered so need none.
func render(cmds []spec.Command, agents []spec.Agent, docs []spec.Doc, tools []spec.Tool, toolUtils []spec.ToolUtil, hooks []spec.Hook, hookUtils string, targets []target.Target) ([]target.OutputFile, []target.ConfigMerge) {
	var files []target.OutputFile
	var merges []target.ConfigMerge

	for _, c := range cmds {
		for _, tg := range targets {
			files = append(files, tg.RenderCommand(c)...)
		}
	}
	for _, a := range agents {
		for _, tg := range targets {
			out := tg.RenderAgent(a)
			files = append(files, out.Files...)
			if out.Config != nil {
				merges = append(merges, *out.Config)
			}
		}
	}
	for _, d := range docs {
		for _, tg := range targets {
			files = append(files, tg.RenderDoc(d))
		}
	}
	// Tools, hooks (each target vendors its own shared runtime), and hook registrations
	// are all per-target — loop uniformly rather than naming Claude/Opencode.
	for _, tg := range targets {
		files = append(files, tg.RenderTools(tools, toolUtils)...)
		files = append(files, tg.RenderHooks(hooks, hookUtils)...)
		merges = append(merges, tg.RenderRegistrations(hooks)...)
	}
	return files, merges
}

func relPaths(files []target.OutputFile) []string {
	paths := make([]string, len(files))
	for i, f := range files {
		paths[i] = f.RelPath
	}
	return paths
}

// applyConfigMerges sets each merge's value into its shared JSON file, one
// read/write per file, preserving every key clanker does not manage.
func applyConfigMerges(outRoot string, merges []target.ConfigMerge) error {
	byFile := map[string][]target.ConfigMerge{}
	for _, m := range merges {
		byFile[m.File] = append(byFile[m.File], m)
	}
	for file, ms := range byFile {
		path := filepath.Join(outRoot, file)
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var root map[string]any
		if err := json.Unmarshal(b, &root); err != nil {
			return fmt.Errorf("gen: parse %s: %w", file, err)
		}
		for _, m := range ms {
			setPath(root, m.Path, m.Value)
		}
		out, err := json.MarshalIndent(root, "", "  ")
		if err != nil {
			return err
		}
		if err := os.WriteFile(path, append(out, '\n'), 0o644); err != nil {
			return err
		}
	}
	return nil
}

// setPath sets val at the nested key path in root, creating intermediate maps.
func setPath(root map[string]any, path []string, val any) {
	m := root
	for _, k := range path[:len(path)-1] {
		sub, ok := m[k].(map[string]any)
		if !ok {
			sub = map[string]any{}
			m[k] = sub
		}
		m = sub
	}
	m[path[len(path)-1]] = val
}

// checkSkills fails generation if any agent references a skill that isn't a real
// directory in clanker/skills/ — catching dead refs (a retired skill) before they
// ship into agent frontmatter. Skipped when the submodule isn't checked out (dir
// absent/empty): can't validate, so don't false-fail.
func checkSkills(outRoot string, agents []spec.Agent) error {
	entries, err := os.ReadDir(filepath.Join(outRoot, "clanker/skills"))
	if err != nil {
		return nil // submodule not present → skip
	}
	available := make(map[string]bool, len(entries))
	for _, e := range entries {
		if e.IsDir() {
			available[e.Name()] = true
		}
	}
	if len(available) == 0 {
		return nil
	}
	if missing := missingSkills(available, agents); len(missing) > 0 {
		return fmt.Errorf("gen: agents reference unknown skills (not in clanker/skills/): %s", strings.Join(missing, ", "))
	}
	return nil
}

// missingSkills returns the distinct skill names referenced by agents that are not
// in the available set, preserving first-seen order.
func missingSkills(available map[string]bool, agents []spec.Agent) []string {
	seen := map[string]bool{}
	var missing []string
	for _, a := range agents {
		for _, s := range a.Skills {
			if !available[s] && !seen[s] {
				seen[s] = true
				missing = append(missing, s)
			}
		}
	}
	return missing
}

// validateRoot guards against running from the wrong cwd: every target's command
// dir must already exist under outRoot.
func validateRoot(outRoot string, targets []target.Target) error {
	for _, tg := range targets {
		dir := filepath.Join(outRoot, tg.CommandDir())
		if info, err := os.Stat(dir); err != nil || !info.IsDir() {
			return fmt.Errorf("gen: %q is not a dotfiles root (missing %s)", outRoot, tg.CommandDir())
		}
	}
	return nil
}

// prune removes every file generated last run (by relative path) that isn't
// generated this run — across all artifact classes, so a dropped agent/tool/hook/doc
// leaves no orphan (an orphaned opencode tool/plugin would otherwise keep executing).
func prune(outRoot string, prev, current []string) error {
	live := make(map[string]bool, len(current))
	for _, p := range current {
		live[p] = true
	}
	for _, p := range prev {
		if live[p] {
			continue
		}
		if err := os.Remove(filepath.Join(outRoot, p)); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func readManifest(outRoot string) ([]string, error) {
	b, err := os.ReadFile(filepath.Join(outRoot, ManifestPath))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var names []string
	if err := json.Unmarshal(b, &names); err != nil {
		return nil, err
	}
	return names, nil
}

func writeManifest(outRoot string, names []string) error {
	b, err := json.Marshal(names)
	if err != nil {
		return err
	}
	path := filepath.Join(outRoot, ManifestPath)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0o644)
}

func writeFile(outRoot string, f target.OutputFile) error {
	path := filepath.Join(outRoot, f.RelPath)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(f.Content), 0o644)
}

// prettierVersion is pinned so formatting is deterministic across machines — an
// unpinned `bunx prettier` floats to latest and silently drifts generated != committed.
const prettierVersion = "3.9.5"

// formatTS normalizes a generated TypeScript file to the project's canonical
// style (prettier, printWidth 120, no semicolons) so generated == committed.
func formatTS(path string) error {
	cmd := exec.Command("bunx", "prettier@"+prettierVersion, "--print-width", "120", "--no-semi", "--tab-width", "4", "--parser", "typescript", "--write", path)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gen: prettier %s: %w", path, err)
	}
	return nil
}
