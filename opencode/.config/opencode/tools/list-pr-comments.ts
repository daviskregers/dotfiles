import { tool } from "@opencode-ai/plugin"
import { execFile } from "child_process"
import { promisify } from "util"

const execFileAsync = promisify(execFile)
const MAX_BUFFER = 10 * 1024 * 1024

const PR_URL_RE = /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)\/?$/

const THREADS_Q =
    `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
    `reviewThreads(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated comments(first:20){nodes{author{login} path line body url}}}}}}}`
const REVIEWS_Q =
    `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
    `reviews(first:50,after:$after){pageInfo{hasNextPage endCursor} nodes{author{login} body state url}}}}}`
const CONV_Q =
    `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
    `comments(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{author{login} body url}}}}}`

// Page through one PR connection following hasNextPage. `pick` selects the connection off pullRequest.
async function fetchAllPrNodes(
    query: string,
    owner: string,
    repo: string,
    num: string,
    pick: (pr: any) => any,
): Promise<any[]> {
    const nodes: any[] = []
    let after: string | undefined
    for (;;) {
        const a = ["api", "graphql", "-f", `query=${query}`, "-f", `owner=${owner}`, "-f", `repo=${repo}`, "-F", `num=${num}`]
        if (after) a.push("-f", `after=${after}`)
        const { stdout } = await execFileAsync("gh", a, { encoding: "utf8", maxBuffer: MAX_BUFFER })
        const pr = JSON.parse(stdout)?.data?.repository?.pullRequest
        if (!pr) throw new Error("PR not found or no data returned")
        const conn = pick(pr)
        nodes.push(...(conn?.nodes ?? []))
        if (!conn?.pageInfo?.hasNextPage) break
        after = conn.pageInfo.endCursor
    }
    return nodes
}

export default tool({
    description:
        "List a GitHub PR's review-thread, review-summary, and conversation comments as a normalized JSON triage queue. Skips resolved threads and empty bodies by default. Inline items carry a threadId for resolve-pr-thread.",
    args: {
        prUrl: tool.schema
            .string()
            .describe("The full GitHub PR URL (e.g. https://github.com/org/repo/pull/123)"),
        includeResolved: tool.schema
            .boolean()
            .optional()
            .describe("Include already-resolved review threads (default false)"),
    },
    async execute(args) {
        const m = args.prUrl.match(PR_URL_RE)
        if (!m) {
            return `Error: Invalid PR URL format. Expected https://github.com/<owner>/<repo>/pull/<number>`
        }
        const [, owner, repo, num] = m

        let pr: any
        try {
            const [threads, reviews, comments] = await Promise.all([
                fetchAllPrNodes(THREADS_Q, owner, repo, num, (p) => p.reviewThreads),
                fetchAllPrNodes(REVIEWS_Q, owner, repo, num, (p) => p.reviews),
                fetchAllPrNodes(CONV_Q, owner, repo, num, (p) => p.comments),
            ])
            pr = { reviewThreads: { nodes: threads }, reviews: { nodes: reviews }, comments: { nodes: comments } }
        } catch (err: any) {
            return `Error fetching PR comments: ${err.message}`
        }

        const items: any[] = []
        for (const t of pr.reviewThreads?.nodes ?? []) {
            if (t.isResolved && !args.includeResolved) continue
            const all = t.comments?.nodes ?? []
            const c = all[0]
            if (!c || !c.body?.trim()) continue
            items.push({
                kind: "inline",
                threadId: t.id,
                isResolved: t.isResolved,
                isOutdated: t.isOutdated,
                path: c.path,
                line: c.line,
                author: c.author?.login,
                body: c.body,
                url: c.url,
                replies: Math.max(0, all.length - 1),
                // Full thread context when there are replies, so triage sees follow-ups.
                ...(all.length > 1 ? { thread: all.map((n: any) => ({ author: n.author?.login, body: n.body })) } : {}),
            })
        }
        for (const r of pr.reviews?.nodes ?? []) {
            if (!r.body?.trim()) continue
            items.push({ kind: "review", threadId: null, author: r.author?.login, body: r.body, state: r.state, url: r.url })
        }
        for (const c of pr.comments?.nodes ?? []) {
            if (!c.body?.trim()) continue
            items.push({ kind: "conversation", threadId: null, author: c.author?.login, body: c.body, url: c.url })
        }
        items.forEach((it, i) => (it.index = i + 1))

        const skippedResolved = args.includeResolved
            ? 0
            : (pr.reviewThreads?.nodes ?? []).filter((t: any) => t.isResolved).length

        return JSON.stringify(
            { pr: { owner, repo, number: Number(num) }, total: items.length, skippedResolved, items },
            null,
            2,
        )
    },
})
