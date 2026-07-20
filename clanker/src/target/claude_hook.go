package target

import (
	"strings"

	"clanker/src/spec"
)

// HookDir is claude's hooks directory, relative to the dotfiles root.
func (Claude) HookDir() string { return "claude/.claude/hooks" }

// RenderClaudeHook emits a self-contained `bun` hook: the shared types + the neutral
// core (its ./hook-utils import stripped, types inlined) + a generated entrypoint
// that reads the stdin event, runs the core, serializes HookResult to claude's
// stdout schema, and always exits 0 (fail-open).
func RenderClaudeHook(hookUtils string, h spec.Hook) OutputFile {
	var b strings.Builder
	b.WriteString(inlineHookRuntime(hookUtils))
	b.WriteString(inlineCore(h.Core))
	b.WriteString("\n" + claudeHookEntrypoint(h.Event))
	return OutputFile{RelPath: Claude{}.HookDir() + "/" + h.Name + ".ts", Content: b.String()}
}

// deExport drops top-level `export ` keywords so a module can be inlined into a
// generated file without re-exporting. A stray export would look like a second
// plugin to opencode's loader; and the core's `run` must stay in file scope for
// the wrapper without being exported.
var deExporter = strings.NewReplacer(
	"export async function", "async function",
	"export function", "function",
	"export const", "const",
	"export type", "type",
)

func deExport(s string) string { return deExporter.Replace(s) }

// inlineHookRuntime returns the hook-utils runtime (types + adapters), de-exported.
func inlineHookRuntime(hookUtils string) string { return deExport(hookUtils) + "\n" }

// inlineCore returns the neutral core with its `import … from "./hook-utils"` line
// removed (types are inlined) and its exports dropped (kept in file scope only).
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
