// Package config is the data fed into the generator: the command definitions and
// their embedded prompt bodies. Edit here to change what is generated, not how.
//
// Blank slate: the command/agent catalog, the global-rules doc, all tools, and every
// hook except dangerous-command-guard and ai-attribution have been wiped. Those two
// are retained deliberately — the guard blocks reflexive destructive shell, and the
// AI-generated marker ai-attribution stamps on commits/PRs is mandated by EU AI Act
// Art. 50. Redefine Agents/Commands/Docs/Tools/Hooks here to grow the catalog back.
package config

import (
	"embed"
	"fmt"

	"clanker/src/spec"
)

//go:embed hooks/*.ts
var hookFiles embed.FS

func hookFile(name string) string {
	b, err := hookFiles.ReadFile("hooks/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing hook file %q: %v", name, err))
	}
	return string(b)
}

//go:embed tools/*.ts
var toolFiles embed.FS

func toolFile(name string) string {
	b, err := toolFiles.ReadFile("tools/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing tool file %q: %v", name, err))
	}
	return string(b)
}

//go:embed bodies/*.md
var bodies embed.FS

// body returns an embedded markdown body, panicking if absent — the body set is
// fixed at compile time, so a missing file is a bug to fix, not a runtime case.
func body(name string) string {
	b, err := bodies.ReadFile("bodies/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing body %q: %v", name, err))
	}
	return string(b)
}

// HookUtils is the shared hook types module, inlined into each generated hook.
var HookUtils = hookFile("hook-utils.ts")

// Hooks retained through the blank-slate wipe: dangerous-command-guard (blocks
// reflexive destructive shell — e.g. rm -rf) and ai-attribution (stamps the
// AI-generated marker on commits/PRs, mandated by EU AI Act Art. 50). ai-attribution's
// matcher covers commits/PRs (Bash) + the structured Linear post tools + the restored
// resolve_pr_thread (its replyBody is stamped here); its FIELD_MAP matches each target's names.
var Hooks = []spec.Hook{
	{
		Name:          "dangerous-command-guard",
		Event:         spec.PreToolUse,
		Matcher:       "Bash",
		OpencodeEvent: spec.ToolExecuteBefore,
		Core:          hookFile("dangerous-command-guard.ts"),
	},
	{
		Name:          "ai-attribution",
		Event:         spec.PreToolUse,
		Matcher:       "Bash|mcp__claude_ai_Linear__save_comment|mcp__claude_ai_Linear__save_issue|mcp__custom-tools__resolve_pr_thread",
		OpencodeEvent: spec.ToolExecuteBefore,
		Core:          hookFile("ai-attribution.ts"),
	},
}

// ToolUtils are the shared helper modules emitted into the tool dir and imported by
// the generated tools: shared.ts (general) + pr-utils.ts (PR GraphQL + URL parsing).
var ToolUtils = []spec.ToolUtil{
	{Name: "shared.ts", Content: toolFile("shared.ts")},
	{Name: "pr-utils.ts", Content: toolFile("pr-utils.ts")},
}

// Tools is the custom-tool set clanker generates. The PR-triage subset restored from
// b941ea6 to back the /pr-comments command: list (fetch the triage queue), read (diff
// context per comment), resolve (reply + resolve a thread), submit (top-level reply).
// create_stacked_pr backs /stacked-pr: opens a PR against the current branch's parent.
var Tools = []spec.Tool{
	{
		Name:        "list_pr_comments",
		Description: "List a GitHub PR's review-thread, review-summary, and conversation comments as a normalized JSON triage queue. Skips resolved threads and empty bodies by default. Inline items carry a threadId for resolve_pr_thread.",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: spec.ArgString, Describe: "Full GitHub PR URL (https://github.com/owner/repo/pull/N)"},
			{Name: "includeResolved", Type: spec.ArgBoolean, Optional: true, Describe: "Include already-resolved review threads (default false)"},
		},
		Core: toolFile("list-pr-comments.ts"),
	},
	{
		Name:        "read_pr_info",
		Description: "Read a GitHub PR's metadata, diff, and commit history. Returns JSON.",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: spec.ArgString, Describe: "Full GitHub PR URL (https://github.com/owner/repo/pull/N)"},
			{Name: "lastCommitOnly", Type: spec.ArgBoolean, Optional: true, Describe: "Only include last commit's diff and message"},
		},
		Core: toolFile("read-pr-info.ts"),
	},
	{
		Name:        "resolve_pr_thread",
		Description: "Optionally post a reply to a PR review thread, then mark it resolved. Use threadId from list-pr-comments (inline items only).",
		Args: []spec.ToolArg{
			{Name: "threadId", Type: spec.ArgString, Describe: "Review thread node ID from list-pr-comments"},
			{Name: "replyBody", Type: spec.ArgString, Optional: true, Describe: "Markdown reply to post before resolving (omit to resolve silently)"},
		},
		Core: toolFile("resolve-pr-thread.ts"),
	},
	{
		Name:        "submit_pr_comment",
		Description: "Post a file as a comment on a GitHub PR (file sent directly, not read into conversation)",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: spec.ArgString, Describe: "Full GitHub PR URL"},
			{Name: "filePath", Type: spec.ArgString, Describe: "Path to file to post as comment (relative to cwd or absolute)"},
		},
		Core: toolFile("submit-pr-comment.ts"),
	},
	{
		Name:        "create_stacked_pr",
		Description: "Open a PR targeting the branch the current branch was stacked on (closest-ancestor parent, overridable), not the default branch. Pushes the branch, stamps AI attribution, and creates the PR.",
		Args: []spec.ToolArg{
			{Name: "base", Type: spec.ArgString, Optional: true, Describe: "Explicit base branch (skips parent detection)"},
			{Name: "title", Type: spec.ArgString, Optional: true, Describe: "PR title (default: last commit subject)"},
			{Name: "body", Type: spec.ArgString, Optional: true, Describe: "PR body markdown (default: the commit list); AI attribution is appended either way"},
			{Name: "draft", Type: spec.ArgBoolean, Optional: true, Describe: "Open the PR as a draft"},
		},
		Core: toolFile("create-stacked-pr.ts"),
	},
}

// Agents is the set clanker generates. Wiped to a blank slate — redefine here.
var Agents = []spec.Agent{}

// Commands is the set clanker generates. The Socratic pair — user holds the pen,
// the assistant only asks the questions that lead them to their own understanding
// (distilled from a real EDU-6483 investigation session). `learn` is the general
// tutor; `investigate` layers the artifact→hypothesis→verify-in-code→root-cause arc
// on top. Both are self-contained interactive commands (NOT subagents — the value is
// turn-by-turn dialogue with the user, which a subagent can't do) and bake in the
// user-owns-the-writeup review loop.
var Commands = []spec.Command{
	{
		Name:        "learn",
		Description: "Socratic learning buddy — leads you to understand a topic by questions, never hands the answer",
		Body:        body("learn.md"),
	},
	{
		Name:        "investigate",
		Description: "Socratic root-cause investigation — you drive from artifact to verified root cause, unbiased by existing theories",
		Body:        body("investigate.md"),
	},
	{
		Name:        "start",
		Description: "Start a piece of work — socratic understanding, then grill any open decisions, then implement via TDD",
		Body:        body("start.md"),
	},
	{
		Name:        "pr-comments",
		Description: "Socratic PR-comment triage — understand each review comment against the code before deciding, then reply/resolve and fan agreed fixes out to background subagents",
		Body:        body("pr-comments.md"),
	},
	{
		Name:        "stacked-pr",
		Description: "Open a PR targeting the branch the current branch was stacked on, not the default branch",
		Body:        body("stacked-pr.md"),
	},
}

// Docs is the shared global rules document, rendered to CLAUDE.md / AGENTS.md.
// Wiped to a blank slate — no global doc emitted until repopulated.
var Docs = []spec.Doc{}
