import { tool } from "@opencode-ai/plugin"
import { execFile } from "child_process"
import { promisify } from "util"

const execFileAsync = promisify(execFile)
const MAX_BUFFER = 10 * 1024 * 1024

const REPLY_MUT = `mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{id url}}}`
const RESOLVE_MUT = `mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}`

async function execute(args: { threadId: string; replyBody?: string }): Promise<string> {
  const done: string[] = []
  if (args.replyBody?.trim()) {
    try {
      await execFileAsync(
        "gh",
        ["api", "graphql", "-f", `query=${REPLY_MUT}`, "-f", `t=${args.threadId}`, "-f", `b=${args.replyBody}`],
        { encoding: "utf8", maxBuffer: MAX_BUFFER },
      )
      done.push("replied")
    } catch (err: any) {
      return `Error posting reply: ${err.message}`
    }
  }
  try {
    const { stdout } = await execFileAsync(
      "gh",
      ["api", "graphql", "-f", `query=${RESOLVE_MUT}`, "-f", `id=${args.threadId}`],
      { encoding: "utf8", maxBuffer: MAX_BUFFER },
    )
    const resolved = JSON.parse(stdout)?.data?.resolveReviewThread?.thread?.isResolved
    done.push(resolved ? "resolved" : "resolve returned unexpected response")
  } catch (err: any) {
    return `Error resolving thread: ${err.message}`
  }
  return `Thread ${args.threadId}: ${done.join(", ")}`
}

export default tool({
  description:
    "Optionally post a reply to a PR review thread, then mark it resolved. Use threadId from list-pr-comments (inline items only).",
  args: {
    threadId: tool.schema.string().describe("Review thread node ID from list-pr-comments"),
    replyBody: tool.schema
      .string()
      .optional()
      .describe("Markdown reply to post before resolving (omit to resolve silently)"),
  },
  execute,
})
