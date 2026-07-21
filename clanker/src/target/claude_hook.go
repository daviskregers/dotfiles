package target

import (
	"strings"

	"clanker/src/spec"
)

// HookDir is claude's hooks directory, relative to the dotfiles root.
func (Claude) HookDir() string { return "claude/.claude/hooks" }

// HookUtilsRel is the shared runtime module, emitted once into claude's hooks dir.
// Claude never auto-scans this dir (it runs only the paths settings.json names), so
// a non-hook module sitting beside the hooks is inert.
func (Claude) HookUtilsRel() string { return Claude{}.HookDir() + "/hook-utils.ts" }

// RenderHooks emits claude's hook files: the shared runtime (vendored beside the
// hooks — claude runs only settings.json paths, never scans the dir) + one entrypoint
// per hook.
func (Claude) RenderHooks(hooks []spec.Hook, hookUtils string) []OutputFile {
	if len(hooks) == 0 {
		return nil
	}
	files := []OutputFile{{RelPath: Claude{}.HookUtilsRel(), Content: hookUtils}}
	for _, h := range hooks {
		files = append(files, RenderClaudeHook(h))
	}
	return files
}

// RenderRegistrations registers the hooks in settings.json (surgical merge).
func (Claude) RenderRegistrations(hooks []spec.Hook) []ConfigMerge {
	return RenderClaudeHookSettings(hooks)
}

// RenderClaudeHook emits a `bun` hook: an import of the shared runtime + the neutral
// core (de-exported, inlined) + a generated entrypoint that reads the stdin event,
// runs the core, serializes HookResult to claude's stdout schema, exit 0 (fail-open).
func RenderClaudeHook(h spec.Hook) OutputFile {
	var b strings.Builder
	b.WriteString(`import { extractClaudeInput, serializeClaudeResult, type HookResult, type HookCtx, type HookInput } from "./hook-utils"` + "\n\n")
	b.WriteString(inlineCore(h.Core))
	b.WriteString("\n" + claudeHookEntrypoint(h.Event))
	return OutputFile{RelPath: Claude{}.HookDir() + "/" + h.Name + ".ts", Content: b.String()}
}

// SettingsFile is claude's settings file, relative to the dotfiles root.
func (Claude) SettingsFile() string { return "claude/.claude/settings.json" }

// claudeHookCommand is the settings.json command that runs a hook. $HOME is shell-
// expanded (claude runs the command through a shell), so the path stays portable.
func claudeHookCommand(name string) string { return `bun "$HOME/.claude/hooks/` + name + `.ts"` }

// RenderClaudeHookSettings produces surgical merges registering the hooks in
// settings.json: one hooks.<event> array per event, grouping hooks by matcher (in
// first-seen order) exactly as claude expects. setPath replaces only these event
// keys, leaving unmanaged events (Notification) and other settings untouched.
func RenderClaudeHookSettings(hooks []spec.Hook) []ConfigMerge {
	type group struct {
		matcher string
		names   []string
	}
	type event struct {
		name   spec.HookEvent
		groups []group
	}
	// Ordered list of events, each holding matcher-grouped hook names, preserving
	// first-seen order. Index maps avoid a pointer-to-slice dance.
	var events []event
	eventAt := map[spec.HookEvent]int{}
	for _, h := range hooks {
		ei, ok := eventAt[h.Event]
		if !ok {
			ei = len(events)
			eventAt[h.Event] = ei
			events = append(events, event{name: h.Event})
		}
		e := &events[ei]
		gi := -1
		for i := range e.groups {
			if e.groups[i].matcher == h.Matcher {
				gi = i
				break
			}
		}
		if gi < 0 {
			e.groups = append(e.groups, group{matcher: h.Matcher})
			gi = len(e.groups) - 1
		}
		e.groups[gi].names = append(e.groups[gi].names, h.Name)
	}

	var merges []ConfigMerge
	for _, e := range events {
		var arr []any
		for _, g := range e.groups {
			var cmds []any
			for _, n := range g.names {
				cmds = append(cmds, map[string]any{"type": "command", "command": claudeHookCommand(n)})
			}
			arr = append(arr, map[string]any{"matcher": g.matcher, "hooks": cmds})
		}
		merges = append(merges, ConfigMerge{File: Claude{}.SettingsFile(), Path: []string{"hooks", string(e.name)}, Value: arr})
	}
	return merges
}

// claudeHookEntrypoint is thin plumbing: read stdin, delegate extraction/serialization
// to the (tested) adapters, write stdout, always exit 0 (fail-open via .catch).
func claudeHookEntrypoint(event spec.HookEvent) string {
	e := `"` + string(event) + `"`
	return "async function main() {\n" +
		"    const data = JSON.parse(await Bun.stdin.text())\n" +
		"    const r = await run(extractClaudeInput(" + e + ", data), { directory: process.env.PROJECT_DIR || process.cwd() })\n" +
		"    const out = serializeClaudeResult(" + e + ", r)\n" +
		"    if (out) process.stdout.write(out)\n" +
		"}\n" +
		"main().catch(() => {})\n"
}
