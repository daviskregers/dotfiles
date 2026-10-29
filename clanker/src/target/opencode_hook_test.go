package target_test

import (
	"strings"
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

const sampleCore = `import type { HookResult, HookCtx, HookInput } from "./hook-utils"

export async function run(_input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    return { kind: "none" }
}`

func TestRenderOpencodeHook_isV2Definition(t *testing.T) {
	out, ok := target.RenderOpencodeHook(spec.Hook{Name: "sample", OpencodeEvent: spec.ToolExecuteBefore, Core: sampleCore})
	if !ok {
		t.Fatal("ok=false, want true")
	}
	for _, want := range []string{"export default {", `id: "sample"`, "async setup(ctx: any)"} {
		if !strings.Contains(out.Content, want) {
			t.Errorf("missing %q in:\n%s", want, out.Content)
		}
	}
}

func TestRenderOpencodeHook_perEvent(t *testing.T) {
	cases := []struct {
		event       spec.OpencodeEvent
		wantImport  string
		wantHandler string
	}{
		{spec.ToolExecuteBefore, "extractOpencodeBefore, applyOpencodeBefore", `ctx.tool.hook("execute.before"`},
		{spec.ToolExecuteAfter, "extractOpencodeAfter, applyOpencodeAfter", `ctx.tool.hook("execute.after"`},
		{spec.ChatMessage, "extractOpencodePrompt, applyOpencodePrompt", `ctx.session.hook("prompt"`},
		{spec.SessionIdle, "injectOnIdle", "ctx.event.subscribe("},
	}
	for _, c := range cases {
		out, ok := target.RenderOpencodeHook(spec.Hook{Name: "sample", OpencodeEvent: c.event, Core: sampleCore})
		if !ok {
			t.Fatalf("%s: ok=false, want true", c.event)
		}
		if out.RelPath != "opencode/.config/opencode/plugins/sample.ts" {
			t.Errorf("%s: RelPath = %q", c.event, out.RelPath)
		}
		if !strings.Contains(out.Content, c.wantImport) {
			t.Errorf("%s: missing adapter import %q", c.event, c.wantImport)
		}
		if !strings.Contains(out.Content, `from "../hook-lib/hook-utils"`) {
			t.Errorf("%s: import must point outside plugins/ (../hook-lib)", c.event)
		}
		if !strings.Contains(out.Content, c.wantHandler) {
			t.Errorf("%s: missing handler %q in:\n%s", c.event, c.wantHandler, out.Content)
		}
		if strings.Contains(out.Content, "export async function run") {
			t.Errorf("%s: core run not de-exported", c.event)
		}
	}
}

// The idle subscription outlives the call that registered it, so setup must hand back
// the cleanup that aborts it — otherwise the plugin owns a live stream past unload.
func TestRenderOpencodeHook_sessionIdleAbortsOnUnload(t *testing.T) {
	out, ok := target.RenderOpencodeHook(spec.Hook{Name: "sample", OpencodeEvent: spec.SessionIdle, Core: sampleCore})
	if !ok {
		t.Fatal("session.idle: ok=false, want true")
	}
	if !strings.Contains(out.Content, "return () => controller.abort()") {
		t.Errorf("session.idle: subscription not aborted by the setup cleanup, got:\n%s", out.Content)
	}
}

func TestRenderOpencodeHook_claudeOnlyReturnsNotOk(t *testing.T) {
	if _, ok := target.RenderOpencodeHook(spec.Hook{Name: "x", OpencodeEvent: spec.NoOpencodeEvent, Core: sampleCore}); ok {
		t.Fatal("NoOpencodeEvent should yield ok=false (no plugin emitted)")
	}
}
