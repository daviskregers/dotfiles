// Package target renders a spec.Command into the files each tool expects.
// Targets are pure (no IO); add a tool by adding a Target and listing it in Registry.
package target

import "clanker/src/spec"

type OutputFile struct {
	RelPath string // relative to the dotfiles root
	Content string
}

type Target interface {
	Name() string
	// CommandDir is the target's command directory, relative to the dotfiles root.
	CommandDir() string
	RenderCommand(spec.Command) []OutputFile
}

func Registry() []Target {
	return []Target{Claude{}, Opencode{}}
}
