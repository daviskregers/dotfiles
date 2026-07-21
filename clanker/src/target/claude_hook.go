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

// deExport drops the core's top-level `export ` keywords: the wrapper references
// `run` in file scope, and a stray export would look like a plugin to opencode's
// loader. (Types/adapters come from the imported shared runtime, not the core.)
var deExporter = strings.NewReplacer(
	"export async function", "async function",
	"export function", "function",
	"export const", "const",
	"export type", "type",
)

func deExport(s string) string { return deExporter.Replace(s) }

// inlineCore returns the neutral core with its `import … from "./hook-utils"` line
// removed (the generated file imports the runtime itself) and its exports dropped.
func inlineCore(core string) string {
	var keep []string
	for _, l := range strings.Split(core, "\n") {
		if strings.Contains(l, `from "./hook-utils"`) {
			continue
		}
		keep = append(keep, l)
	}
	return deExport(strings.Join(keep, "\n"))
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
	groups := map[spec.HookEvent]*[]group{}
	var order []spec.HookEvent
	for _, h := range hooks {
		gs, ok := groups[h.Event]
		if !ok {
			gs = &[]group{}
			groups[h.Event] = gs
			order = append(order, h.Event)
		}
		idx := -1
		for i := range *gs {
			if (*gs)[i].matcher == h.Matcher {
				idx = i
				break
			}
		}
		if idx < 0 {
			*gs = append(*gs, group{matcher: h.Matcher})
			idx = len(*gs) - 1
		}
		(*gs)[idx].names = append((*gs)[idx].names, h.Name)
	}

	var merges []ConfigMerge
	for _, ev := range order {
		var arr []any
		for _, g := range *groups[ev] {
			var cmds []any
			for _, n := range g.names {
				cmds = append(cmds, map[string]any{"type": "command", "command": claudeHookCommand(n)})
			}
			arr = append(arr, map[string]any{"matcher": g.matcher, "hooks": cmds})
		}
		merges = append(merges, ConfigMerge{File: Claude{}.SettingsFile(), Path: []string{"hooks", string(ev)}, Value: arr})
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
