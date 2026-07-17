// Package gen is the only clanker package that touches the filesystem: it renders
// every command with every target, writes the results under an output root, and
// prunes files for commands that were generated before but no longer exist.
package gen

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"clanker/src/spec"
	"clanker/src/target"
)

// ManifestPath records (relative to the output root) the commands clanker
// generated last run, so a dropped command's stale files can be pruned without
// touching files clanker never managed.
const ManifestPath = "clanker/generated-commands.json"

func Run(outRoot string, cmds []spec.Command, targets []target.Target) error {
	if err := validateRoot(outRoot, targets); err != nil {
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
	return writeManifest(outRoot, current)
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
