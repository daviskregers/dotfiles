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

// RenderOpencodeHook emits an opencode V2 plugin for a dual-targetable hook: an
// import of the shared runtime + the neutral core (de-exported, inlined) + a
// Plugin.define-shaped default export whose setup registers the mapped hook.
// V2 registers each hook on the domain that owns it and hands the callback one
// mutable event, so the adapter translates that event instead of an input/output
// pair. ok=false → claude-only.
func RenderOpencodeHook(h spec.Hook) (OutputFile, bool) {
	body, ok := opencodeHookHandler(h.OpencodeEvent)
	if !ok {
		return OutputFile{}, false
	}
	var b strings.Builder
	b.WriteString(`import { ` + opencodeAdapterImports(h.OpencodeEvent) + `, type HookResult, type HookCtx, type HookInput } from "../hook-lib/hook-utils"` + "\n\n")
	b.WriteString(inlineCore(h.Core))
	b.WriteString("\nexport default {\n")
	b.WriteString("    id: \"" + h.Name + "\",\n")
	b.WriteString("    async setup(ctx: any) {\n")
	b.WriteString(body)
	b.WriteString("    },\n}\n")
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
		return "extractOpencodePrompt, applyOpencodePrompt"
	case spec.SessionIdle:
		return "injectOnIdle"
	default:
		return ""
	}
}

// opencodeHookHandler is the event-registration body: thin plumbing delegating
// extraction and result-application to the (tested) adapters. Indentation is
// prettier's problem — gen formats every emitted .ts.
func opencodeHookHandler(ev spec.OpencodeEvent) (string, bool) {
	switch ev {
	case spec.ToolExecuteBefore:
		return `        await ctx.tool.hook("execute.before", async (event: any) => {
            applyOpencodeBefore(event, await run(extractOpencodeBefore(event), { directory: ctx.location.directory }))
        })
`, true
	case spec.ToolExecuteAfter:
		return `        await ctx.tool.hook("execute.after", async (event: any) => {
            applyOpencodeAfter(event, await run(extractOpencodeAfter(event), { directory: ctx.location.directory }))
        })
`, true
	case spec.ChatMessage:
		return `        await ctx.session.hook("prompt", async (event: any) => {
            applyOpencodePrompt(event, await run(extractOpencodePrompt(event), { directory: ctx.location.directory }))
        })
`, true
	case spec.SessionIdle:
		// session.idle arrives on the event stream, which cannot block or mutate the
		// turn that already ended — so a block/context result is injected as a prompt,
		// which re-activates the turn so the agent addresses it. setup returns the
		// cleanup that aborts the subscription on unload.
		return `        const controller = new AbortController()
        void (async () => {
            for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
                if (event.type !== "session.idle") continue
                await injectOnIdle(ctx, event.properties.sessionID, await run({}, { directory: ctx.location.directory }))
            }
        })()
        return () => controller.abort()
`, true
	default: // NoOpencodeEvent → claude-only
		return "", false
	}
}
