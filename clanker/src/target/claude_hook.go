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
