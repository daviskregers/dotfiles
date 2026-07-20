import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { z } from "zod"
import { execute as resolvePrThread } from "./resolve-pr-thread"
import { execute as saveCodeReview } from "./save-code-review"
import { execute as saveExplanation } from "./save-explanation"
import { execute as readPrInfo } from "./read-pr-info"
import { execute as updatePrInfo } from "./update-pr-info"
import { execute as submitPrComment } from "./submit-pr-comment"
import { execute as listPrComments } from "./list-pr-comments"
import { execute as requestCopilotReview } from "./request-copilot-review"
import { execute as waitForCopilotReview } from "./wait-for-copilot-review"

const PROJECT_DIR = process.env.PROJECT_DIR || process.cwd()

function text(msg: string) {
    return { content: [{ type: "text" as const, text: msg }] }
}

const server = new McpServer({ name: "claude-custom-tools", version: "1.0.0" })

server.tool(
    "resolve_pr_thread",
    "Optionally post a reply to a PR review thread, then mark it resolved. Use threadId from list-pr-comments (inline items only).",
    {
        threadId: z.string().describe("Review thread node ID from list-pr-comments"),
        replyBody: z.string().optional().describe("Markdown reply to post before resolving (omit to resolve silently)"),
    },
    async (args) => text(await resolvePrThread(args, { directory: PROJECT_DIR })),
)

server.tool(
    "save_code_review",
    "Save a code review to .dk-notes/reviews/ with timestamped filename",
    {
        content: z.string().describe("Full review markdown content"),
    },
    async (args) => text(await saveCodeReview(args, { directory: PROJECT_DIR })),
)

server.tool(
    "save_explanation",
    "Save an HTML explanation to .dk-notes/explanations/ and open in default browser",
    {
        content: z.string().describe("Full HTML content"),
        title: z.string().optional().describe("Short slug for filename (e.g. 'jwt-auth-flow')"),
    },
    async (args) => text(await saveExplanation(args, { directory: PROJECT_DIR })),
)

server.tool(
    "read_pr_info",
    "Read a GitHub PR's metadata, diff, and commit history. Returns JSON.",
    {
        prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
        lastCommitOnly: z.boolean().optional().describe("Only include last commit's diff and message"),
    },
    async (args) => text(await readPrInfo(args, { directory: PROJECT_DIR })),
)

server.tool(
    "update_pr_info",
    "Update a GitHub PR's title and/or body (description)",
    {
        prUrl: z.string().describe("Full GitHub PR URL"),
        title: z.string().optional().describe("New PR title (omit to leave unchanged)"),
        body: z.string().optional().describe("New PR body/description in markdown (omit to leave unchanged)"),
    },
    async (args) => text(await updatePrInfo(args, { directory: PROJECT_DIR })),
)

server.tool(
    "submit_pr_comment",
    "Post a file as a comment on a GitHub PR (file sent directly, not read into conversation)",
    {
        prUrl: z.string().describe("Full GitHub PR URL"),
        filePath: z.string().describe("Path to file to post as comment (relative to cwd or absolute)"),
    },
    async (args) => text(await submitPrComment(args, { directory: PROJECT_DIR })),
)

server.tool(
    "list_pr_comments",
    "List a GitHub PR's review-thread, review-summary, and conversation comments as a normalized JSON triage queue. Skips resolved threads and empty bodies by default. Inline items carry a threadId for resolve_pr_thread.",
    {
        prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
        includeResolved: z.boolean().optional().describe("Include already-resolved review threads (default false)"),
    },
    async (args) => text(await listPrComments(args, { directory: PROJECT_DIR })),
)

server.tool(
    "request_copilot_review",
    "Request a GitHub Copilot code review on a PR. Tries the native `gh pr edit --add-reviewer @copilot` and verifies it stuck; falls back to the requestReviews GraphQL mutation with the resolved Copilot bot id.",
    {
        prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
    },
    async (args) => text(await requestCopilotReview(args, { directory: PROJECT_DIR })),
)

server.tool(
    "wait_for_copilot_review",
    "Poll a PR until GitHub Copilot has posted its review (it submits a COMMENTED review, usually within ~30s–2min), then return. Use after request_copilot_review, before triaging comments.",
    {
        prUrl: z.string().describe("Full GitHub PR URL"),
        timeoutSec: z.number().optional().describe("Max seconds to wait (default 180)"),
        pollSec: z.number().optional().describe("Seconds between polls (default 10)"),
    },
    async (args) => text(await waitForCopilotReview(args, { directory: PROJECT_DIR })),
)

const transport = new StdioServerTransport()
await server.connect(transport)
