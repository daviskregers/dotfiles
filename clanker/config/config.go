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

	// Referenced by delegating commands but not yet ported (rendered). Fleshed out
	// with full tool/skill config when the agent class extends to them.
	codeReviewer = spec.Agent{Name: "code-reviewer"}
	explainer    = spec.Agent{Name: "explainer"}
)

// Agents is the set clanker generates. (codeReviewer/explainer are referenced-only
// until ported — add them here when their full definitions land.)
var Agents = []spec.Agent{gitCommitter, gitStasher}

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
