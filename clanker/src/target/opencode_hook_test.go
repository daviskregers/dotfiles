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

func TestRenderOpencodeHook_perEvent(t *testing.T) {
	cases := []struct {
		event       spec.OpencodeEvent
		wantImport  string
		wantFactory string
		wantHandler string
	}{
		{spec.ToolExecuteBefore, "extractOpencodeBefore, applyOpencodeBefore", "{ directory }", `"tool.execute.before"`},
		{spec.ToolExecuteAfter, "extractOpencodeAfter, applyOpencodeAfter", "{ directory }", `"tool.execute.after"`},
		{spec.ChatMessage, "extractOpencodeMessage, applyOpencodeMessage", "{ directory }", `"chat.message"`},
		{spec.SessionIdle, "injectOnIdle", "{ directory, client }", "event:"},
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
		if !strings.Contains(out.Content, c.wantFactory) {
			t.Errorf("%s: missing factory params %q", c.event, c.wantFactory)
		}
		if !strings.Contains(out.Content, c.wantHandler) {
			t.Errorf("%s: missing handler %q", c.event, c.wantHandler)
		}
		if strings.Contains(out.Content, "export async function run") {
			t.Errorf("%s: core run not de-exported", c.event)
		}
	}
}

func TestRenderOpencodeHook_claudeOnlyReturnsNotOk(t *testing.T) {
	if _, ok := target.RenderOpencodeHook(spec.Hook{Name: "x", OpencodeEvent: spec.NoOpencodeEvent, Core: sampleCore}); ok {
		t.Fatal("NoOpencodeEvent should yield ok=false (no plugin emitted)")
	}
}
