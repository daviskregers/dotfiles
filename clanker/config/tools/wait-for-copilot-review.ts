import { execFileAsync, MAX_BUFFER, sleep } from "./shared"

const PR_URL_RE = /^https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+\/?$/

export async function execute(
    args: { prUrl: string; timeoutSec?: number; pollSec?: number },
    ctx: { directory: string },
): Promise<string> {
    if (!PR_URL_RE.test(args.prUrl)) return `Error: Invalid PR URL format`
    const timeout = (args.timeoutSec ?? 180) * 1000
    const poll = (args.pollSec ?? 10) * 1000
    const start = Date.now()
    let errs = 0

    while (Date.now() - start < timeout) {
        try {
            const { stdout } = await execFileAsync("gh", ["pr", "view", args.prUrl, "--json", "reviews"], {
                encoding: "utf8",
                maxBuffer: MAX_BUFFER,
            })
            const reviews = JSON.parse(stdout)?.reviews ?? []
            const copilot = reviews.filter((r: any) => /copilot/i.test(r.author?.login ?? ""))
            if (copilot.length > 0) {
                const elapsed = Math.round((Date.now() - start) / 1000)
                return `Copilot review posted after ~${elapsed}s (${copilot.length} review event(s)). Ready to triage.`
            }
            errs = 0
        } catch (err: any) {
            if (++errs >= 3) return `Error polling PR reviews (3 consecutive failures): ${err.message}`
        }
        await sleep(poll)
    }
    return `Timed out after ${args.timeoutSec ?? 180}s — Copilot review not yet posted. Re-run or triage what's there.`
}
