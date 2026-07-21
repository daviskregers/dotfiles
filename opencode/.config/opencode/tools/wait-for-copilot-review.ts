import { tool } from "@opencode-ai/plugin"
import { execFileAsync, MAX_BUFFER, sleep } from "./shared"
import { parsePrUrl, INVALID_PR_URL } from "./pr-utils"

async function execute(
    args: { prUrl: string; timeoutSec?: number; pollSec?: number },
    ctx: { directory: string },
): Promise<string> {
    if (!parsePrUrl(args.prUrl)) return INVALID_PR_URL
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

export default tool({
    description:
        "Poll a PR until GitHub Copilot has posted its review (it submits a COMMENTED review, usually within ~30s–2min), then return. Use after request_copilot_review, before triaging comments.",
    args: {
        prUrl: tool.schema.string().describe("Full GitHub PR URL"),
        timeoutSec: tool.schema.number().optional().describe("Max seconds to wait (default 180)"),
        pollSec: tool.schema.number().optional().describe("Seconds between polls (default 10)"),
    },
    execute,
})
