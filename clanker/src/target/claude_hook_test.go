package target_test

import (
	"strings"
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

func TestRenderClaudeHook_importsRuntimeAndDeExportsCore(t *testing.T) {
	core := `import type { HookResult, HookCtx, HookInput } from "./hook-utils"

export async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    return { kind: "none" }
}`
	out := target.RenderClaudeHook(spec.Hook{Name: "sample", Event: spec.PreToolUse, Core: core})

	if out.RelPath != "claude/.claude/hooks/sample.ts" {
		t.Fatalf("RelPath = %q", out.RelPath)
	}
	c := out.Content
	if !strings.HasPrefix(c, `import { extractClaudeInput, serializeClaudeResult,`) {
		t.Errorf("missing runtime import header:\n%s", c[:80])
	}
	if strings.Count(c, `from "./hook-utils"`) != 1 {
		t.Errorf("core's own hook-utils import not stripped (want exactly 1, the header): \n%s", c)
	}
	if strings.Contains(c, "export async function run") {
		t.Error("core's run not de-exported")
	}
	if !strings.Contains(c, "async function run") {
		t.Error("run should remain in file scope")
	}
	if !strings.Contains(c, "main().catch(() => {})") {
		t.Error("entrypoint not appended")
	}
}

func TestRenderClaudeHookSettings_groupsByEventThenMatcher(t *testing.T) {
	hooks := []spec.Hook{
		{Name: "ai-attribution", Event: spec.PreToolUse, Matcher: "Bash|X"},
		{Name: "tdd-reminder", Event: spec.PreToolUse, Matcher: "Write|Edit"},
		{Name: "dangerous-command-guard", Event: spec.PreToolUse, Matcher: "Bash"},
		{Name: "offloading-nudge", Event: spec.UserPromptSubmit, Matcher: ""},
		{Name: "approval-scope", Event: spec.UserPromptSubmit, Matcher: ""},
	}
	merges := target.RenderClaudeHookSettings(hooks)

	// One merge per event, in first-seen order (PreToolUse, then UserPromptSubmit).
	if len(merges) != 2 {
		t.Fatalf("want 2 event merges, got %d", len(merges))
	}
	if got := merges[0].Path; got[0] != "hooks" || got[1] != "PreToolUse" {
		t.Fatalf("first merge path = %v, want [hooks PreToolUse]", got)
	}
	if merges[0].File != (target.Claude{}).SettingsFile() {
		t.Fatalf("merge file = %q", merges[0].File)
	}

	// PreToolUse: 3 distinct matchers → 3 entries ("Bash|X" and "Bash" are distinct).
	pre := merges[0].Value.([]any)
	if len(pre) != 3 {
		t.Fatalf("PreToolUse want 3 matcher groups, got %d", len(pre))
	}
	first := pre[0].(map[string]any)
	if first["matcher"] != "Bash|X" {
		t.Fatalf("first matcher = %v", first["matcher"])
	}
	cmd := first["hooks"].([]any)[0].(map[string]any)["command"]
	if cmd != `bun "$HOME/.claude/hooks/ai-attribution.ts"` {
		t.Fatalf("command = %v", cmd)
	}

	// UserPromptSubmit: same "" matcher → ONE group holding both hooks in order.
	ups := merges[1].Value.([]any)
	if len(ups) != 1 {
		t.Fatalf("UserPromptSubmit want 1 matcher group, got %d", len(ups))
	}
	upsHooks := ups[0].(map[string]any)["hooks"].([]any)
	if len(upsHooks) != 2 {
		t.Fatalf("UserPromptSubmit group want 2 hooks, got %d", len(upsHooks))
	}
	if c := upsHooks[1].(map[string]any)["command"]; c != `bun "$HOME/.claude/hooks/approval-scope.ts"` {
		t.Fatalf("second UPS command = %v", c)
	}
}
