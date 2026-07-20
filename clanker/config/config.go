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
		Skills:      []string{"caveman", "caveman-commit"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that commits staged changes with a conventional commit message",
			// opencode announces skills in the prompt; claude uses the skills frontmatter.
			Body: body("git-committer.opencode.md"),
		}},
	}

	gitStasher = spec.Agent{
		Name:        "git-stasher",
		Description: "Stash changes with conventional-commit-style name. git stash/diff/status only.",
		Body:        body("git-stasher.md"),
		Model:       "sonnet",
		MaxTurns:    6,
		Bash:        []string{"git stash", "git diff", "git status"},
		Skills:      []string{"caveman", "caveman-commit"},
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
			Body:        body("explainer.opencode.md"),
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
		Skills:      []string{"caveman", "diagram"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Subagent that reads PR changes and writes a title and description",
			Body:        body("pr-describer.opencode.md"),
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
		Skills:      []string{"code-review-rules", "caveman-review"},
	}

	codeReviewComprehension = spec.Agent{
		Name:        "code-review-comprehension",
		Description: "Comprehension half of code review — explains changeset via summary, flow diagram, walkthrough.",
		Body:        body("code-review-comprehension.md"),
		Model:       "sonnet",
		MaxTurns:    15,
		Read:        true,
		Bash:        []string{"git diff", "git log", "git status", "git rev-parse", "git show", "gh pr view", "gh pr diff"},
		Skills:      []string{"code-review-comprehension", "caveman-review"},
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
		Skills:      []string{"code-review-rules", "caveman-review", "artifact-output"},
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Description: "Read-only code review subagent with restricted tool access",
			Body:        body("code-reviewer.opencode.md"),
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
		Overlay: spec.AgentOverlays{Opencode: spec.AgentOverlay{
			Body: body("pr-comment-submitter.opencode.md"),
		}},
	}
)

// ptr returns a pointer to v — for per-target overrides like Write.
func ptr[T any](v T) *T { return &v }

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
			Body:        body("code-review.opencode.md"),
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
			Body:        body("explain.opencode.md"),
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
		Overlay: spec.Overlays{
			Claude: spec.ClaudeOverlay{
				ArgumentHint: "[path to a Reflections note — defaults to the latest]",
				AllowedTools: "Read, Edit, Write, Bash, Glob, Grep, AskUserQuestion",
			},
			Opencode: spec.OpencodeOverlay{Body: body("reflect-tune.opencode.md")},
		},
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
