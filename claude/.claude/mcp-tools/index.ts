import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { z } from "zod"
import { execute as listPrComments } from "./list-pr-comments"
import { execute as readPrInfo } from "./read-pr-info"
import { execute as resolvePrThread } from "./resolve-pr-thread"
import { execute as submitPrComment } from "./submit-pr-comment"
import { execute as createStackedPr } from "./create-stacked-pr"

const PROJECT_DIR = process.env.PROJECT_DIR || process.cwd()

function text(msg: string) {
    return { content: [{ type: "text" as const, text: msg }] }
}

const server = new McpServer({ name: "claude-custom-tools", version: "1.0.0" })

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
    "read_pr_info",
    "Read a GitHub PR's metadata, diff, and commit history. Returns JSON.",
    {
        prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
        lastCommitOnly: z.boolean().optional().describe("Only include last commit's diff and message"),
    },
    async (args) => text(await readPrInfo(args, { directory: PROJECT_DIR })),
)

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
    "submit_pr_comment",
    "Post a file as a comment on a GitHub PR (file sent directly, not read into conversation)",
    {
        prUrl: z.string().describe("Full GitHub PR URL"),
        filePath: z.string().describe("Path to file to post as comment (relative to cwd or absolute)"),
    },
    async (args) => text(await submitPrComment(args, { directory: PROJECT_DIR })),
)

server.tool(
    "create_stacked_pr",
    "Open a PR targeting the branch the current branch was stacked on (closest-ancestor parent, overridable), not the default branch. Pushes the branch, stamps AI attribution, and creates the PR.",
    {
        base: z.string().optional().describe("Explicit base branch (skips parent detection)"),
        title: z.string().optional().describe("PR title (default: last commit subject)"),
        body: z
            .string()
            .optional()
            .describe("PR body markdown (default: the commit list); AI attribution is appended either way"),
        draft: z.boolean().optional().describe("Open the PR as a draft"),
    },
    async (args) => text(await createStackedPr(args, { directory: PROJECT_DIR })),
)

const transport = new StdioServerTransport()
await server.connect(transport)
