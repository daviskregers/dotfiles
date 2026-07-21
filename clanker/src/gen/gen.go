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

// ManifestPath records (relative to the output root) the commands clanker
// generated last run, so a dropped command's stale files can be pruned without
// touching files clanker never managed.
const ManifestPath = "clanker/generated-commands.json"

func Run(outRoot string, cmds []spec.Command, agents []spec.Agent, docs []spec.Doc, tools []spec.Tool, toolUtils []spec.ToolUtil, hooks []spec.Hook, hookUtils string, targets []target.Target) error {
	if err := validateRoot(outRoot, targets); err != nil {
		return err
	}
	if err := checkSkills(outRoot, agents); err != nil {
		return err
	}

	prev, err := readManifest(outRoot)
	if err != nil {
		return err
	}
	current := commandNames(cmds)
	if err := prune(outRoot, targets, prev, current); err != nil {
		return err
	}

	for _, c := range cmds {
		for _, tg := range targets {
			for _, f := range tg.RenderCommand(c) {
				if err := writeFile(outRoot, f); err != nil {
					return err
				}
			}
		}
	}
	var merges []target.ConfigMerge
	for _, a := range agents {
		for _, tg := range targets {
			out := tg.RenderAgent(a)
			for _, f := range out.Files {
				if err := writeFile(outRoot, f); err != nil {
					return err
				}
			}
			if out.Config != nil {
				merges = append(merges, *out.Config)
			}
		}
	}
	// Register hooks in claude's settings.json via the same surgical merge (preserves
	// unmanaged events like Notification). opencode plugins are auto-discovered, so
	// they need no registration.
	merges = append(merges, target.RenderClaudeHookSettings(hooks)...)
	if err := applyConfigMerges(outRoot, merges); err != nil {
		return err
	}

	for _, d := range docs {
		for _, tg := range targets {
			if err := writeFile(outRoot, tg.RenderDoc(d)); err != nil {
				return err
			}
		}
	}

	// Custom tools: generated for both targets from the same neutral cores. opencode
	// gets per-tool tool() wrappers; claude vendors the cores + a generated index.ts
	// registering them. Generated TS is prettier-formatted to the project's style.
	if len(tools) > 0 {
		toolFiles := append(target.OpencodeToolFiles(tools, toolUtils), target.ClaudeToolFiles(tools, toolUtils)...)
		if err := writeTS(outRoot, toolFiles); err != nil {
			return err
		}
	}

	// Hooks: the shared runtime (hook-utils) is emitted once per tree and imported by
	// each generated hook (claude entrypoint / opencode plugin) — not inlined. opencode's
	// copy lives outside plugins/ so its loader can't mistake the helpers for plugins.
	// settings.json registration is a separate step (see the hooks plan) so incremental
	// porting can't drop still-unported claude hook entries.
	if len(hooks) > 0 {
		hookFiles := []target.OutputFile{
			{RelPath: target.Claude{}.HookUtilsRel(), Content: hookUtils},
			{RelPath: target.Opencode{}.HookLibRel(), Content: hookUtils},
		}
		for _, h := range hooks {
			hookFiles = append(hookFiles, target.RenderClaudeHook(h))
			if f, ok := target.RenderOpencodeHook(h); ok {
				hookFiles = append(hookFiles, f)
			}
		}
		if err := writeTS(outRoot, hookFiles); err != nil {
			return err
		}
	}
	return writeManifest(outRoot, current)
}

// writeTS writes each TypeScript file then prettier-formats it in place.
func writeTS(outRoot string, files []target.OutputFile) error {
	for _, f := range files {
		if err := writeFile(outRoot, f); err != nil {
			return err
		}
		if err := formatTS(filepath.Join(outRoot, f.RelPath)); err != nil {
			return err
		}
	}
	return nil
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

// prune removes files for commands present last run but gone now.
func prune(outRoot string, targets []target.Target, prev, current []string) error {
	live := make(map[string]bool, len(current))
	for _, n := range current {
		live[n] = true
	}
	for _, n := range prev {
		if live[n] {
			continue
		}
		for _, tg := range targets {
			path := filepath.Join(outRoot, tg.CommandDir(), n+".md")
			if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
				return err
			}
		}
	}
	return nil
}

func commandNames(cmds []spec.Command) []string {
	names := make([]string, len(cmds))
	for i, c := range cmds {
		names[i] = c.Name
	}
	return names
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

// formatTS normalizes a generated TypeScript file to the project's canonical
// style (prettier, printWidth 120, no semicolons) so generated == committed.
func formatTS(path string) error {
	cmd := exec.Command("bunx", "prettier", "--print-width", "120", "--no-semi", "--tab-width", "4", "--parser", "typescript", "--write", path)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gen: prettier %s: %w", path, err)
	}
	return nil
}
