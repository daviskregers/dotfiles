import { tool } from "@opencode-ai/plugin"
import { execFile } from "child_process"
import { promisify } from "util"

const execFileAsync = promisify(execFile)
const MAX_BUFFER = 10 * 1024 * 1024

const PR_URL_RE = /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)\/?$/

// Primary: native `gh pr edit --add-reviewer @copilot` (gh 2.88+). Verify it
// landed in reviewRequests (gh can silently no-op). Fallback: GraphQL
// requestReviews with the repo-specific Copilot bot node id resolved from
// assignableUsers. `--add-reviewer Copilot` (no @) and the REST endpoint both
// fail/no-op, so don't use them.
const COPILOT_LOOKUP =
    `query($owner:String!,$repo:String!){repository(owner:$owner,name:$repo){assignableUsers(first:100,query:"copilot"){nodes{login id}}}}`
const REQUEST_REVIEW_MUT =
    `mutation($prId:ID!,$uid:ID!){requestReviews(input:{pullRequestId:$prId,userIds:[$uid],union:true}){pullRequest{number}}}`

// Throws on gh/parse failure so the caller can distinguish "not requested"
// (false) from "couldn't check" (auth/network error) instead of masking it.
async function copilotIsRequested(prUrl: string): Promise<boolean> {
    const { stdout } = await execFileAsync(
        "gh",
        ["pr", "view", prUrl, "--json", "reviewRequests"],
        { encoding: "utf8", maxBuffer: MAX_BUFFER },
    )
    const reqs = JSON.parse(stdout)?.reviewRequests ?? []
    return reqs.some((r: any) => /copilot/i.test(r.login ?? r.name ?? r.slug ?? ""))
}

export default tool({
    description:
        "Request a GitHub Copilot code review on a PR. Tries the native `gh pr edit --add-reviewer @copilot` and verifies it stuck; falls back to the requestReviews GraphQL mutation with the resolved Copilot bot id.",
    args: {
        prUrl: tool.schema
            .string()
            .describe("The full GitHub PR URL (e.g. https://github.com/org/repo/pull/123)"),
    },
    async execute(args) {
        const m = args.prUrl.match(PR_URL_RE)
        if (!m) {
            return `Error: Invalid PR URL format. Expected https://github.com/<owner>/<repo>/pull/<number>`
        }
        const [, owner, repo, number] = m

        // 1. Native @copilot (gh 2.88+)
        try {
            await execFileAsync("gh", ["pr", "edit", args.prUrl, "--add-reviewer", "@copilot"], {
                encoding: "utf8",
                maxBuffer: MAX_BUFFER,
            })
        } catch {
            /* fall through to GraphQL */
        }
        try {
            if (await copilotIsRequested(args.prUrl)) {
                return `Copilot review requested on PR #${number} (${owner}/${repo}) via @copilot`
            }
        } catch (err: any) {
            return `Error verifying Copilot reviewer (gh pr view): ${err.message}`
        }

        // 2. GraphQL fallback — resolve Copilot bot node id
        let botId: string | undefined
        try {
            const { stdout } = await execFileAsync(
                "gh",
                ["api", "graphql", "-f", `query=${COPILOT_LOOKUP}`, "-f", `owner=${owner}`, "-f", `repo=${repo}`],
                { encoding: "utf8", maxBuffer: MAX_BUFFER },
            )
            const nodes = JSON.parse(stdout)?.data?.repository?.assignableUsers?.nodes ?? []
            const bot =
                nodes.find((n: any) => n.login?.toLowerCase() === "copilot") ??
                nodes.find((n: any) => /copilot/i.test(n.login ?? ""))
            botId = bot?.id
        } catch (err: any) {
            return `Error resolving Copilot reviewer: ${err.message}`
        }
        if (!botId) {
            return (
                `Error: @copilot reviewer did not stick and no copilot user found in assignableUsers for ${owner}/${repo}. ` +
                `Confirm Copilot code review is enabled for the repo, then retry.`
            )
        }

        // 3. Resolve PR node id + requestReviews
        let prId: string
        try {
            const { stdout } = await execFileAsync(
                "gh",
                ["pr", "view", args.prUrl, "--json", "id", "--jq", ".id"],
                { encoding: "utf8", maxBuffer: MAX_BUFFER },
            )
            prId = stdout.trim()
        } catch (err: any) {
            return `Error resolving PR node id: ${err.message}`
        }
        if (!prId) return `Error: Could not resolve PR node id`

        try {
            const { stdout } = await execFileAsync(
                "gh",
                ["api", "graphql", "-f", `query=${REQUEST_REVIEW_MUT}`, "-F", `prId=${prId}`, "-F", `uid=${botId}`],
                { encoding: "utf8", maxBuffer: MAX_BUFFER },
            )
            const num = JSON.parse(stdout)?.data?.requestReviews?.pullRequest?.number
            return `Copilot review requested on PR #${num ?? number} (${owner}/${repo}) via GraphQL`
        } catch (err: any) {
            return `Error requesting Copilot review: ${err.message}`
        }
    },
})
