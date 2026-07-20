import { execFileAsync } from "./shared"
import { parsePrUrl } from "./pr-utils"

export async function execute(
    args: { prUrl: string; lastCommitOnly?: boolean },
    ctx: { directory: string },
): Promise<string> {
    const parsed = parsePrUrl(args.prUrl)
    if (!parsed) {
        return `Error: Invalid PR URL format. Expected https://github.com/<owner>/<repo>/pull/<number>`
    }

    const results: Record<string, string> = {}

    try {
        const { stdout: meta } = await execFileAsync(
            "gh",
            [
                "pr", "view", args.prUrl,
                "--json", "title,body,baseRefName,headRefName,commits,files,additions,deletions,labels",
            ],
            { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
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
                    ["api", `repos/${parsed.ownerRepo}/commits/${lastSha}`,
                        "--jq", ".commit.message"],
                    { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
                )
                results.lastCommitMessage = singleCommit.trim()
            } catch {
                results.lastCommitMessage = commits[commits.length - 1].messageHeadline
                results.note = "Could not fetch full commit message from API; using headline from PR metadata"
            }

            try {
                const { stdout: singleDiff } = await execFileAsync(
                    "gh",
                    ["api", `repos/${parsed.ownerRepo}/commits/${lastSha}`,
                        "-H", "Accept: application/vnd.github.diff"],
                    { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
                )
                results.diff = singleDiff
            } catch {
                // Fallback: fetch the full PR diff when the single-commit diff fails
                try {
                    const { stdout: fullDiff } = await execFileAsync(
                        "gh",
                        ["pr", "diff", args.prUrl],
                        { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
                    )
                    results.diff = fullDiff
                    results.note = (results.note ? results.note + ". " : "")
                        + "Could not isolate last commit diff; showing full PR diff instead"
                } catch (diffErr: any) {
                    return `Error fetching PR diff: ${diffErr.message}`
                }
            }
        } else {
            const { stdout: diff } = await execFileAsync(
                "gh",
                ["pr", "diff", args.prUrl],
                { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
            )
            results.diff = diff
        }
    } catch (err: any) {
        return `Error fetching PR diff: ${err.message}`
    }

    return JSON.stringify(results, null, 2)
}
