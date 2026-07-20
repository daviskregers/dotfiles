import { execFileAsync, MAX_BUFFER } from "./shared"
import { copilotIsRequested, COPILOT_LOOKUP, REQUEST_REVIEW_MUT } from "./pr-utils"

const PR_URL_RE = /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)\/?$/

export async function execute(
    args: { prUrl: string },
    ctx: { directory: string },
): Promise<string> {
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
}
