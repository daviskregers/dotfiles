package target

import (
	"strings"

	"clanker/src/spec"
)

// PluginDir is opencode's plugin directory, relative to the dotfiles root.
func (Opencode) PluginDir() string { return "opencode/.config/opencode/plugins" }

// HookLibRel is the shared runtime module, emitted OUTSIDE plugins/ so opencode's
// loader (which treats every named export in plugins/*.ts as a plugin candidate)
// can't mistake the runtime's helpers for plugins. Plugins import it by relative path.
func (Opencode) HookLibRel() string { return "opencode/.config/opencode/hook-lib/hook-utils.ts" }

// RenderHooks emits opencode's hook files: the shared runtime (outside plugins/ so
// the loader can't mistake it for a plugin) + one plugin per dual-targetable hook.
func (Opencode) RenderHooks(hooks []spec.Hook, hookUtils string) []OutputFile {
	if len(hooks) == 0 {
		return nil
	}
	files := []OutputFile{{RelPath: Opencode{}.HookLibRel(), Content: hookUtils}}
	for _, h := range hooks {
		if f, ok := RenderOpencodeHook(h); ok {
			files = append(files, f)
		}
	}
	return files
}

// RenderRegistrations is empty for opencode — plugins are auto-discovered from plugins/.
func (Opencode) RenderRegistrations([]spec.Hook) []ConfigMerge { return nil }

// RenderOpencodeHook emits an opencode plugin for a dual-targetable hook: an import
// of the shared runtime + the neutral core (de-exported, inlined) + a plugin factory
// wiring the core to the mapped event and translating HookResult (deny→throw,
// allow→mutate args, context→append, idle→client inject). ok=false → claude-only.
func RenderOpencodeHook(h spec.Hook) (OutputFile, bool) {
	body, ok := opencodeHookHandler(h.OpencodeEvent)
	if !ok {
		return OutputFile{}, false
	}
	var b strings.Builder
	b.WriteString(`import { ` + opencodeAdapterImports(h.OpencodeEvent) + `, type HookResult, type HookCtx, type HookInput } from "../hook-lib/hook-utils"` + "\n\n")
	b.WriteString(inlineCore(h.Core))
	b.WriteString("\nexport const " + camel(strings.ReplaceAll(h.Name, "-", "_")) + " = async (" + opencodeFactoryParams(h.OpencodeEvent) + ") => ({\n")
	b.WriteString(body)
	b.WriteString("})\n")
	return OutputFile{RelPath: Opencode{}.PluginDir() + "/" + h.Name + ".ts", Content: b.String()}, true
}

// opencodeAdapterImports is the runtime adapters a given event's handler references.
func opencodeAdapterImports(ev spec.OpencodeEvent) string {
	switch ev {
	case spec.ToolExecuteBefore:
		return "extractOpencodeBefore, applyOpencodeBefore"
	case spec.ToolExecuteAfter:
		return "extractOpencodeAfter, applyOpencodeAfter"
	case spec.ChatMessage:
		return "extractOpencodeMessage, applyOpencodeMessage"
	case spec.SessionIdle:
		return "injectOnIdle"
	default:
		return ""
	}
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
	case spec.SessionIdle:
		// The `event` hook can't block or mutate — so on session.idle we run the core
		// and inject any block/context result as a prompt via the client.
		return `    event: async (input: any) => {
        if (input.event?.type !== "session.idle") return
        await injectOnIdle(client, input.event.properties.sessionID, await run({}, { directory }))
    },
`, true
	default: // NoOpencodeEvent → claude-only
		return "", false
	}
}

// opencodeFactoryParams is the plugin factory's destructured PluginInput — session.idle
// hooks need the SDK `client` to inject; the rest need only `directory`.
func opencodeFactoryParams(ev spec.OpencodeEvent) string {
	if ev == spec.SessionIdle {
		return "{ directory, client }: { directory: string; client: any }"
	}
	return "{ directory }: { directory: string }"
}
