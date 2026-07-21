// Package target renders a spec.Command into the files each tool expects.
// Targets are pure (no IO); add a tool by adding a Target and listing it in Registry.
package target

import "clanker/src/spec"

type OutputFile struct {
	RelPath string // relative to the dotfiles root
	Content string
}

// AgentOutput is what a target produces for one agent: file(s) to write, plus an
// optional merge into a shared config file (opencode.json) rather than a standalone file.
type AgentOutput struct {
	Files  []OutputFile
	Config *ConfigMerge
}

// ConfigMerge sets Value at Path within a shared JSON config File (relative to the
// dotfiles root), leaving the rest of that file untouched.
type ConfigMerge struct {
	File  string
	Path  []string
	Value any
}

type Target interface {
	Name() string
	// CommandDir is the target's command directory, relative to the dotfiles root.
	CommandDir() string
	RenderCommand(spec.Command) []OutputFile
	RenderAgent(spec.Agent) AgentOutput
	RenderDoc(spec.Doc) OutputFile
	// RenderTools/RenderHooks return this target's files for the whole set (incl. any
	// shared runtime it vendors). RenderRegistrations returns merges into shared config
	// (claude: settings.json hook entries; opencode: none — plugins auto-discover).
	RenderTools(tools []spec.Tool, utils []spec.ToolUtil) []OutputFile
	RenderHooks(hooks []spec.Hook, hookUtils string) []OutputFile
	RenderRegistrations(hooks []spec.Hook) []ConfigMerge
}

func Registry() []Target {
	return []Target{Claude{}, Opencode{}}
}
