// Package config is the data fed into the generator: the command definitions and
// their embedded prompt bodies. Edit here to change what is generated, not how.
package config

import (
	"embed"
	"fmt"

	"clanker/src/spec"
)

//go:embed bodies/*.md
var bodies embed.FS

//go:embed tools/*.ts
var toolFiles embed.FS

func toolFile(name string) string {
	b, err := toolFiles.ReadFile("tools/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing tool file %q: %v", name, err))
	}
	return string(b)
}

//go:embed hooks/*.ts
var hookFiles embed.FS

func hookFile(name string) string {
	b, err := hookFiles.ReadFile("hooks/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing hook file %q: %v", name, err))
	}
	return string(b)
}

// HookUtils is the shared hook types module, inlined into each generated hook.
var HookUtils = hookFile("hook-utils.ts")

// Hooks are single-sourced hooks, all dual-target. Per-target event mapping absorbs
// capability gaps (e.g. comprehension-nudge blocks claude's Stop but injects via the
// client on opencode's session.idle). ai-attribution lands last (its own slice —
// compliance-critical, cross-target tool-name mapping).
var Hooks = []spec.Hook{
	{
		Name:          "dangerous-command-guard",
		Event:         spec.PreToolUse,
		Matcher:       "Bash",
		OpencodeEvent: spec.ToolExecuteBefore,
		Core:          hookFile("dangerous-command-guard.ts"),
	},
	{
		// claude nudges before the edit; opencode appends the reminder to the write's
		// output after it (before-hooks can't inject non-blocking context).
		Name:          "tdd-reminder",
		Event:         spec.PreToolUse,
		Matcher:       "Write|Edit",
		OpencodeEvent: spec.ToolExecuteAfter,
		Core:          hookFile("tdd-reminder.ts"),
	},
	{
		Name:          "pr-refresh-reminder",
		Event:         spec.PostToolUse,
		Matcher:       "Bash",
		OpencodeEvent: spec.ToolExecuteAfter,
		Core:          hookFile("pr-refresh-reminder.ts"),
	},
	{
		Name:          "offloading-nudge",
		Event:         spec.UserPromptSubmit,
		Matcher:       "",
		OpencodeEvent: spec.ChatMessage,
		Core:          hookFile("offloading-nudge.ts"),
	},
	{
		Name:          "approval-scope",
		Event:         spec.UserPromptSubmit,
		Matcher:       "",
		OpencodeEvent: spec.ChatMessage,
		Core:          hookFile("approval-scope.ts"),
	},
	{
		// claude blocks the Stop event; opencode can't block a turn end, so on
		// session.idle it injects the checkpoint as a prompt via the SDK client.
		Name:          "comprehension-nudge",
		Event:         spec.Stop,
		Matcher:       "",
		OpencodeEvent: spec.SessionIdle,
		Core:          hookFile("comprehension-nudge.ts"),
	},
	{
		// Compliance (EU AI Act Art. 50). Matcher covers commits/PRs (Bash) + the
		// structured post tools; the core's merged FIELD_MAP matches each target's names.
		Name:          "ai-attribution",
		Event:         spec.PreToolUse,
		Matcher:       "Bash|mcp__claude_ai_Linear__save_comment|mcp__claude_ai_Linear__save_issue|mcp__custom-tools__update_pr_info|mcp__custom-tools__resolve_pr_thread",
		OpencodeEvent: spec.ToolExecuteBefore,
		Core:          hookFile("ai-attribution.ts"),
	},
}

// body returns an embedded markdown body, panicking if absent — the body set is
// fixed at compile time, so a missing file is a bug to fix, not a runtime case.
func body(name string) string {
	b, err := bodies.ReadFile("bodies/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing body %q: %v", name, err))
	}
	return string(b)
}

// Agents are package vars so commands can delegate to them by reference (type-safe:
// a nonexistent agent won't compile), not by a stringly-typed name.
var (
	gitCommitter = spec.Agent{
		Name:        "git-committer",
		Description: "Commit staged changes with conventional commit message. git diff/commit/status only.",
		Body:        body("git-committer.md"),
		Model:       "sonnet",
		MaxTurns:    8,
		Bash:        []string{"git diff", "git commit", "git status"},
		Skills:      []string{"git-commit"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that commits staged changes with a conventional commit message",
		}},
	}

	gitStasher = spec.Agent{
		Name:        "git-stasher",
		Description: "Stash changes with conventional-commit-style name. git stash/diff/status only.",
		Body:        body("git-stasher.md"),
		Model:       "sonnet",
		MaxTurns:    6,
		Bash:        []string{"git stash", "git diff", "git status"},
		Skills:      []string{"git-commit"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that stashes changes with a meaningful name",
		}},
	}

	explainer = spec.Agent{
		Name:        "explainer",
		Description: "Generate HTML explanations (reusing the `report` scaffold) with diagrams/quizzes. Saves to .dk-notes/explanations/.",
		Body:        body("explainer.md"),
		Model:       "sonnet",
		MaxTurns:    15,
		Read:        true,
		MCP:         []string{"save-explanation"},
		Skills:      []string{"artifact-output", "diagram"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that generates visual HTML explanations with diagrams and quizzes",
		}},
	}

	prDescriber = spec.Agent{
		Name:        "pr-describer",
		Description: "Write PR title/description from diff analysis. MCP tools only.",
		Body:        body("pr-describer.md"),
		Model:       "sonnet",
		MaxTurns:    10,
		Deny:        []string{"Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"},
		MCP:         []string{"read-pr-info", "update-pr-info"},
		Skills:      []string{"diagram"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that reads PR changes and writes a title and description",
		}},
	}

	tutor = spec.Agent{
		Name:        "tutor",
		Description: "Teaching agent. Read-only, question-based, no writes/bash.",
		Body:        body("tutor.md"),
		MaxTurns:    50,
		Mode:        "primary",
		Read:        true,
		Webfetch:    true,
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "tutor based on https://www.theneuron.ai/explainer-articles/your-brain-on-ai-is-literally-shrinking-and-how-to-fix-it",
		}},
	}

	codeReviewAnalysis = spec.Agent{
		Name:        "code-review-analysis",
		Description: "Analysis half of code review — findings grouped by concern, code snippets, assessment.",
		Body:        body("code-review-analysis.md"),
		Model:       "sonnet",
		MaxTurns:    15,
		Read:        true,
		Bash:        []string{"git diff", "git log", "git status", "git rev-parse", "git show", "gh pr view", "gh pr diff"},
		Skills:      []string{"code-review-rules"},
	}

	codeReviewComprehension = spec.Agent{
		Name:        "code-review-comprehension",
		Description: "Comprehension half of code review — explains changeset via summary, flow diagram, walkthrough.",
		Body:        body("code-review-comprehension.md"),
		Model:       "sonnet",
		MaxTurns:    15,
		Read:        true,
		Bash:        []string{"git diff", "git log", "git status", "git rev-parse", "git show", "gh pr view", "gh pr diff"},
		Skills:      []string{"code-review-comprehension"},
	}

	codeReviewer = spec.Agent{
		Name:        "code-reviewer",
		Description: "Read-only code review. Saves to .dk-notes/reviews/. No source modifications.",
		Body:        body("code-reviewer.md"),
		Model:       "sonnet",
		MaxTurns:    20,
		Read:        true,
		Write:       true, // claude writes the review file directly...
		Bash:        []string{"git diff", "git log", "git status", "git rev-parse", "git show", "gh pr view", "gh pr diff", "mkdir -p .dk-notes/reviews"},
		MCP:         []string{"save-code-review"},
		Skills:      []string{"code-review-rules", "artifact-output"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Read-only code review subagent with restricted tool access",
			Write:       ptr(false), // ...but opencode saves via the save-code-review tool, no write
		}},
	}

	prCommentSubmitter = spec.Agent{
		Name:        "pr-comment-submitter",
		Description: "Post file as PR comment. MCP + Read only.",
		Body:        body("pr-comment-submitter.md"),
		Model:       "sonnet",
		MaxTurns:    5,
		Read:        true, // opencode also grants grep/glob; claude's denylist forbids them (accepted)
		Deny:        []string{"Write", "Edit", "Bash", "Glob", "Grep", "Agent"},
		MCP:         []string{"submit-pr-comment"},
	}
)

// ptr returns a pointer to v — for per-target overrides like Write.
func ptr[T any](v T) *T { return &v }

// Docs is the shared global rules document, rendered to CLAUDE.md / AGENTS.md.
var Docs = []spec.Doc{{Body: body("global.md")}}

// ToolUtils are the shared helper modules emitted into the tool dir and imported
// by the generated tools: shared.ts (general) + pr-utils.ts (PR-specific).
var ToolUtils = []spec.ToolUtil{
	{Name: "shared.ts", Content: toolFile("shared.ts")},
	{Name: "pr-utils.ts", Content: toolFile("pr-utils.ts")},
}

// Tools are the custom tools (opencode side; claude's monolithic index.ts is ported later).
var Tools = []spec.Tool{
	{
		Name:        "resolve_pr_thread",
		Description: "Optionally post a reply to a PR review thread, then mark it resolved. Use threadId from list-pr-comments (inline items only).",
		Args: []spec.ToolArg{
			{Name: "threadId", Type: "string", Describe: "Review thread node ID from list-pr-comments"},
			{Name: "replyBody", Type: "string", Optional: true, Describe: "Markdown reply to post before resolving (omit to resolve silently)"},
		},
		Core: toolFile("resolve-pr-thread.ts"),
	},
	{
		Name:        "save_code_review",
		Description: "Save a code review to .dk-notes/reviews/ with timestamped filename",
		Args:        []spec.ToolArg{{Name: "content", Type: "string", Describe: "Full review markdown content"}},
		Core:        toolFile("save-code-review.ts"),
	},
	{
		Name:        "save_explanation",
		Description: "Save an HTML explanation to .dk-notes/explanations/ and open in default browser",
		Args: []spec.ToolArg{
			{Name: "content", Type: "string", Describe: "Full HTML content"},
			{Name: "title", Type: "string", Optional: true, Describe: "Short slug for filename (e.g. 'jwt-auth-flow')"},
		},
		Core: toolFile("save-explanation.ts"),
	},
	{
		Name:        "read_pr_info",
		Description: "Read a GitHub PR's metadata, diff, and commit history. Returns JSON.",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: "string", Describe: "Full GitHub PR URL (https://github.com/owner/repo/pull/N)"},
			{Name: "lastCommitOnly", Type: "boolean", Optional: true, Describe: "Only include last commit's diff and message"},
		},
		Core: toolFile("read-pr-info.ts"),
	},
	{
		Name:        "update_pr_info",
		Description: "Update a GitHub PR's title and/or body (description)",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: "string", Describe: "Full GitHub PR URL"},
			{Name: "title", Type: "string", Optional: true, Describe: "New PR title (omit to leave unchanged)"},
			{Name: "body", Type: "string", Optional: true, Describe: "New PR body/description in markdown (omit to leave unchanged)"},
		},
		Core: toolFile("update-pr-info.ts"),
	},
	{
		Name:        "submit_pr_comment",
		Description: "Post a file as a comment on a GitHub PR (file sent directly, not read into conversation)",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: "string", Describe: "Full GitHub PR URL"},
			{Name: "filePath", Type: "string", Describe: "Path to file to post as comment (relative to cwd or absolute)"},
		},
		Core: toolFile("submit-pr-comment.ts"),
	},
	{
		Name:        "list_pr_comments",
		Description: "List a GitHub PR's review-thread, review-summary, and conversation comments as a normalized JSON triage queue. Skips resolved threads and empty bodies by default. Inline items carry a threadId for resolve_pr_thread.",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: "string", Describe: "Full GitHub PR URL (https://github.com/owner/repo/pull/N)"},
			{Name: "includeResolved", Type: "boolean", Optional: true, Describe: "Include already-resolved review threads (default false)"},
		},
		Core: toolFile("list-pr-comments.ts"),
	},
	{
		Name:        "request_copilot_review",
		Description: "Request a GitHub Copilot code review on a PR. Tries the native `gh pr edit --add-reviewer @copilot` and verifies it stuck; falls back to the requestReviews GraphQL mutation with the resolved Copilot bot id.",
		Args:        []spec.ToolArg{{Name: "prUrl", Type: "string", Describe: "Full GitHub PR URL (https://github.com/owner/repo/pull/N)"}},
		Core:        toolFile("request-copilot-review.ts"),
	},
	{
		Name:        "wait_for_copilot_review",
		Description: "Poll a PR until GitHub Copilot has posted its review (it submits a COMMENTED review, usually within ~30s–2min), then return. Use after request_copilot_review, before triaging comments.",
		Args: []spec.ToolArg{
			{Name: "prUrl", Type: "string", Describe: "Full GitHub PR URL"},
			{Name: "timeoutSec", Type: "number", Optional: true, Describe: "Max seconds to wait (default 180)"},
			{Name: "pollSec", Type: "number", Optional: true, Describe: "Seconds between polls (default 10)"},
		},
		Core: toolFile("wait-for-copilot-review.ts"),
	},
}

// Agents is the set clanker generates.
var Agents = []spec.Agent{
	gitCommitter, gitStasher, explainer, prDescriber, tutor,
	codeReviewAnalysis, codeReviewComprehension, codeReviewer, prCommentSubmitter,
}

var Commands = []spec.Command{
	{
		Name:        "bug",
		Description: "Fix bug using TDD — failing test first, then fix",
		Body:        body("bug.md"),
		Args:        spec.ArgsFirstPositional,
	},
	{
		// Bodies fully diverge: claude fans out review agents; opencode inlines the
		// steps and delegates to its code-reviewer agent.
		Name:        "code-review",
		Description: "Review current code changes (read-only, saves to .dk-notes/reviews/)",
		Body:        body("code-review.md"),
		Delegates:   &spec.Delegation{Agent: &codeReviewer},
		Overlay: spec.Overlays{Opencode: spec.OpencodeOverlay{
			Description: "Review current code changes and list any issues (read-only, no modifications)",
		}},
	},
	{
		Name:        "comment",
		Description: "Investigate code review comment — you commit your own read first, then AI reveals + TDD-fixes if confirmed",
		Body:        body("comment.md"),
		Args:        spec.ArgsFirstPositional,
	},
	{
		Name:        "comments",
		Description: "Bulk-read all PR comments, then investigate each via /comment one-at-a-time",
		Body:        body("comments.md"),
		Args:        spec.ArgsFirstPositional,
	},
	{
		// Simple delegator: both bodies generated from the delegation; detail lives
		// in the git-committer agent (prompt), not duplicated here.
		Name:        "commit",
		Description: "Commit staged changes with a conventional commit message",
		Delegates:   &spec.Delegation{Agent: &gitCommitter, Task: "commit staged changes"},
	},
	{
		// claude delegates to the explainer agent (+ auto-open); opencode inlines the
		// full HTML-spec body.
		Name:        "explain",
		Description: "Generate visual HTML explanation with diagrams and quizzes",
		Body:        body("explain.md"),
		Delegates:   &spec.Delegation{Agent: &explainer},
		Overlay: spec.Overlays{Opencode: spec.OpencodeOverlay{
			Description: "Generate a visual HTML explanation with diagrams and quizzes for a topic from the current conversation",
		}},
	},
	{
		Name:        "friction",
		Description: "Capture a workflow friction — enrich with current context, then append via the capture tool",
		Body:        body("friction.md"),
		Overlay: spec.Overlays{Claude: spec.ClaudeOverlay{
			ArgumentHint: "<what's bugging you about how you work right now>",
			AllowedTools: "Bash(capture:*)",
		}},
	},
	{
		Name:        "idea",
		Description: "Capture a random idea — enrich with current context, then append via the capture tool",
		Body:        body("idea.md"),
		Overlay: spec.Overlays{Claude: spec.ClaudeOverlay{
			ArgumentHint: "<the idea / spark>",
			AllowedTools: "Bash(capture:*)",
		}},
	},
	{
		Name:        "refactor",
		Description: "Refactor safely — validate tests first, refactor, verify pass",
		Body:        body("refactor.md"),
		Args:        spec.ArgsFirstPositional,
	},
	{
		// claude has argument-hint/allowed-tools; bodies diverge on CLAUDE.md vs
		// AGENTS.md references and the dual-sync steps.
		Name:        "reflect-tune",
		Description: "Turn a reflection's root cause into proposed Claude-config guardrails — propose diffs, you approve, then dual-sync",
		Body:        body("reflect-tune.md"),
		Overlay: spec.Overlays{Claude: spec.ClaudeOverlay{
			ArgumentHint: "[path to a Reflections note — defaults to the latest]",
			AllowedTools: "Read, Edit, Write, Bash, Glob, Grep, AskUserQuestion",
		}},
	},
	{
		Name:        "ship",
		Description: "Local review → validate → commit → push → draft PR → Copilot review → triage",
		Body:        body("ship.md"),
		Args:        spec.ArgsFirstPositional,
	},
	{
		// Simple delegator: bodies generated; detail lives in the git-stasher agent.
		Name:        "stash",
		Description: "Stash changes with conventional-commit-style name",
		Delegates:   &spec.Delegation{Agent: &gitStasher, Task: "stash working tree changes with a descriptive name"},
		Overlay: spec.Overlays{Opencode: spec.OpencodeOverlay{
			Description: "Stash current changes with a meaningful name",
		}},
	},
	{
		Name:        "tdd",
		Description: "Build feature/change using TDD — test first, verify fail, minimal impl to pass",
		Body:        body("tdd.md"),
		Args:        spec.ArgsFirstPositional,
	},
	{
		Name:        "usage-report",
		Description: "Analyze prompt effectiveness, teach improvements with real examples and quizzes",
		Body:        body("usage-report.md"),
	},
}
