package target

import (
	"strings"

	"clanker/src/spec"
)

// PluginDir is opencode's plugin directory, relative to the dotfiles root.
func (Opencode) PluginDir() string { return "opencode/.config/opencode/plugins" }

// RenderOpencodeHook emits a self-contained opencode plugin for a dual-targetable
// hook: shared types + neutral core (types inlined) + a plugin factory wiring the
// core to the mapped event and translating HookResult (deny→throw, allow→mutate
// args, context→append). Returns ok=false for a claude-only hook (no plugin).
func RenderOpencodeHook(hookUtils string, h spec.Hook) (OutputFile, bool) {
	body, ok := opencodeHookHandler(h.OpencodeEvent)
	if !ok {
		return OutputFile{}, false
	}
	var b strings.Builder
	b.WriteString(inlineHookRuntime(hookUtils))
	b.WriteString(inlineCore(h.Core))
	b.WriteString("\nexport const " + camel(strings.ReplaceAll(h.Name, "-", "_")) + " = async ({ directory }: { directory: string }) => ({\n")
	b.WriteString(body)
	b.WriteString("})\n")
	return OutputFile{RelPath: Opencode{}.PluginDir() + "/" + h.Name + ".ts", Content: b.String()}, true
}

// opencodeHookHandler is the event-handler body: thin plumbing delegating extraction
// and result-application to the (tested) adapters.
func opencodeHookHandler(ev spec.OpencodeEvent) (string, bool) {
	switch ev {
	case spec.ToolExecuteBefore:
		return `    "tool.execute.before": async (input: any, output: any) =>
        applyOpencodeBefore(output, await run(extractOpencodeBefore(input, output), { directory })),
`, true
	case spec.ToolExecuteAfter:
		return `    "tool.execute.after": async (input: any, output: any) =>
        applyOpencodeAfter(output, await run(extractOpencodeAfter(input, output), { directory })),
`, true
	case spec.ChatMessage:
		return `    "chat.message": async (input: any, output: any) =>
        applyOpencodeMessage(output, await run(extractOpencodeMessage(input, output), { directory })),
`, true
	default: // NoOpencodeEvent → claude-only
		return "", false
	}
}
