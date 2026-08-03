// Package config is the data fed into the generator: the command definitions and
// their embedded prompt bodies. Edit here to change what is generated, not how.
//
// Blank slate: the command/agent catalog, the global-rules doc, all tools, and every
// hook except dangerous-command-guard and ai-attribution have been wiped. Those two
// are retained deliberately — the guard blocks reflexive destructive shell, and the
// AI-generated marker ai-attribution stamps on commits/PRs is mandated by EU AI Act
// Art. 50. Redefine Agents/Commands/Docs/Tools/Hooks here to grow the catalog back.
package config

import (
	"embed"
	"fmt"

	"clanker/src/spec"
)

//go:embed hooks/*.ts
var hookFiles embed.FS

func hookFile(name string) string {
	b, err := hookFiles.ReadFile("hooks/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing hook file %q: %v", name, err))
	}
	return string(b)
}

// HookUtils is the shared hook types module, inlined into each generated hook.
var HookUtils = hookFile("hook-utils.ts")

// Hooks retained through the blank-slate wipe: dangerous-command-guard (blocks
// reflexive destructive shell — e.g. rm -rf) and ai-attribution (stamps the
// AI-generated marker on commits/PRs, mandated by EU AI Act Art. 50). ai-attribution's
// matcher covers commits/PRs (Bash) + the structured Linear post tools; its FIELD_MAP
// matches each target's names. (The custom PR tools it also matched are wiped.)
var Hooks = []spec.Hook{
	{
		Name:          "dangerous-command-guard",
		Event:         spec.PreToolUse,
		Matcher:       "Bash",
		OpencodeEvent: spec.ToolExecuteBefore,
		Core:          hookFile("dangerous-command-guard.ts"),
	},
	{
		Name:          "ai-attribution",
		Event:         spec.PreToolUse,
		Matcher:       "Bash|mcp__claude_ai_Linear__save_comment|mcp__claude_ai_Linear__save_issue",
		OpencodeEvent: spec.ToolExecuteBefore,
		Core:          hookFile("ai-attribution.ts"),
	},
}

// ToolUtils is the shared helper set emitted into the tool dir. Wiped — no tools.
var ToolUtils = []spec.ToolUtil{}

// Tools is the custom-tool set clanker generates. Wiped to a blank slate.
var Tools = []spec.Tool{}

// Agents is the set clanker generates. Wiped to a blank slate — redefine here.
var Agents = []spec.Agent{}

// Commands is the set clanker generates. Wiped to a blank slate — redefine here.
var Commands = []spec.Command{}

// Docs is the shared global rules document, rendered to CLAUDE.md / AGENTS.md.
// Wiped to a blank slate — no global doc emitted until repopulated.
var Docs = []spec.Doc{}
