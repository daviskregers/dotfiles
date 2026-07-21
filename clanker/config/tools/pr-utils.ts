import { execFileAsync, MAX_BUFFER } from "./shared"

export const PR_URL_RE = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/(\d+)\/?$/

/**
 * Parse a validated GitHub PR URL into its components.
 * Returns null if the URL doesn't match.
 */
export function parsePrUrl(url: string): { ownerRepo: string; number: string } | null {
    const m = url.match(PR_URL_RE)
    if (!m) return null
    return { ownerRepo: m[1], number: m[2] }
}

export const THREADS_Q =
    `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
    `reviewThreads(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated comments(first:20){nodes{author{login} path line body url}}}}}}}`
export const REVIEWS_Q =
    `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
    `reviews(first:50,after:$after){pageInfo{hasNextPage endCursor} nodes{author{login} body state url}}}}}`
export const CONV_Q =
    `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
    `comments(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{author{login} body url}}}}}`

// Page through one PR connection following hasNextPage. `pick` selects the connection off pullRequest.
export async function fetchAllPrNodes(
    query: string,
    owner: string,
    repo: string,
    num: string,
    pick: (pr: any) => any,
): Promise<any[]> {
    const nodes: any[] = []
    let after: string | undefined
    for (;;) {
        const a = [
            "api",
            "graphql",
            "-f",
            `query=${query}`,
            "-f",
            `owner=${owner}`,
            "-f",
            `repo=${repo}`,
            "-F",
            `num=${num}`,
        ]
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

// Primary: native `gh pr edit --add-reviewer @copilot` (gh 2.88+). Verify it
// landed in reviewRequests (gh can silently no-op). Fallback: GraphQL
// requestReviews with the repo-specific Copilot bot node id resolved from
// assignableUsers. `--add-reviewer Copilot` (no @) and the REST endpoint both
// fail/no-op, so don't use them.
export const COPILOT_LOOKUP = `query($owner:String!,$repo:String!){repository(owner:$owner,name:$repo){assignableUsers(first:100,query:"copilot"){nodes{login id}}}}`
export const REQUEST_REVIEW_MUT = `mutation($prId:ID!,$uid:ID!){requestReviews(input:{pullRequestId:$prId,userIds:[$uid],union:true}){pullRequest{number}}}`

// Throws on gh/parse failure so the caller can distinguish "not requested"
// (false) from "couldn't check" (auth/network error) instead of masking it.
export async function copilotIsRequested(prUrl: string): Promise<boolean> {
    const { stdout } = await execFileAsync("gh", ["pr", "view", prUrl, "--json", "reviewRequests"], {
        encoding: "utf8",
        maxBuffer: MAX_BUFFER,
    })
    const reqs = JSON.parse(stdout)?.reviewRequests ?? []
    return reqs.some((r: any) => /copilot/i.test(r.login ?? r.name ?? r.slug ?? ""))
}
