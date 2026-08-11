import { tool } from "@opencode-ai/plugin"
import { execFileAsync, MAX_BUFFER } from "./shared"
import { parsePrUrl, INVALID_PR_URL } from "./pr-utils"

async function execute(args: { prUrl: string; lastCommitOnly?: boolean }, ctx: { directory: string }): Promise<string> {
    const parsed = parsePrUrl(args.prUrl)
    if (!parsed) {
        return INVALID_PR_URL
    }

    const results: Record<string, string> = {}

    try {
        const { stdout: meta } = await execFileAsync(
            "gh",
            [
                "pr",
                "view",
                args.prUrl,
                "--json",
                "title,body,baseRefName,headRefName,commits,files,additions,deletions,labels",
            ],
            { encoding: "utf8", maxBuffer: MAX_BUFFER },
        )
        results.meta = meta
    } catch (err: any) {
        return `Error fetching PR metadata: ${err.message}`
    }

    try {
        if (args.lastCommitOnly) {
            let metaObj: any
            try {
                metaObj = JSON.parse(results.meta)
            } catch {
                return `Error: Failed to parse PR metadata as JSON`
            }

            const commits = metaObj.commits ?? []
            if (commits.length === 0) {
                return `Error: PR has no commits`
            }
            const lastSha = commits[commits.length - 1].oid

            try {
                const { stdout: singleCommit } = await execFileAsync(
                    "gh",
                    ["api", `repos/${parsed.ownerRepo}/commits/${lastSha}`, "--jq", ".commit.message"],
                    { encoding: "utf8", maxBuffer: MAX_BUFFER },
                )
                results.lastCommitMessage = singleCommit.trim()
            } catch {
                results.lastCommitMessage = commits[commits.length - 1].messageHeadline
                results.note = "Could not fetch full commit message from API; using headline from PR metadata"
            }

            try {
                const { stdout: singleDiff } = await execFileAsync(
                    "gh",
                    [
                        "api",
                        `repos/${parsed.ownerRepo}/commits/${lastSha}`,
                        "-H",
                        "Accept: application/vnd.github.diff",
                    ],
                    { encoding: "utf8", maxBuffer: MAX_BUFFER },
                )
                results.diff = singleDiff
            } catch {
                // Fallback: fetch the full PR diff when the single-commit diff fails
                try {
                    const { stdout: fullDiff } = await execFileAsync("gh", ["pr", "diff", args.prUrl], {
                        encoding: "utf8",
                        maxBuffer: MAX_BUFFER,
                    })
                    results.diff = fullDiff
                    results.note =
                        (results.note ? results.note + ". " : "") +
                        "Could not isolate last commit diff; showing full PR diff instead"
                } catch (diffErr: any) {
                    return `Error fetching PR diff: ${diffErr.message}`
                }
            }
        } else {
            const { stdout: diff } = await execFileAsync("gh", ["pr", "diff", args.prUrl], {
                encoding: "utf8",
                maxBuffer: MAX_BUFFER,
            })
            results.diff = diff
        }
    } catch (err: any) {
        return `Error fetching PR diff: ${err.message}`
    }

    return JSON.stringify(results, null, 2)
}

export default tool({
    description: "Read a GitHub PR's metadata, diff, and commit history. Returns JSON.",
    args: {
        prUrl: tool.schema.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
        lastCommitOnly: tool.schema.boolean().optional().describe("Only include last commit's diff and message"),
    },
    execute,
})
