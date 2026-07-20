package target_test

import (
	"strings"
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

func TestRenderClaudeIndex(t *testing.T) {
	tools := []spec.Tool{{
		Name:        "save_code_review",
		Description: "Save a review",
		Args:        []spec.ToolArg{{Name: "content", Type: "string", Describe: "the content"}},
	}}

	out := target.RenderClaudeIndex(tools)

	if out.RelPath != "claude/.claude/mcp-tools/index.ts" {
		t.Errorf("path: %q", out.RelPath)
	}
	c := out.Content
	checks := []string{
		`import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"`,
		`import { z } from "zod"`,
		`import { execute as saveCodeReview } from "./save-code-review"`, // snake→camel alias, kebab path
		`const PROJECT_DIR = process.env.PROJECT_DIR || process.cwd()`,
		`server.tool(`,
		`"save_code_review",`,
		`content: z.string().describe("the content"),`,
		`async (args) => text(await saveCodeReview(args, { directory: PROJECT_DIR })),`, // text() wrap + dir inject
		`await server.connect(transport)`,
	}
	for _, want := range checks {
		if !strings.Contains(c, want) {
			t.Errorf("missing %q in:\n%s", want, c)
		}
	}
}
