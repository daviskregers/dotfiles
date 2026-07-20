import {
    extractOpencodeAfter,
    applyOpencodeAfter,
    type HookResult,
    type HookCtx,
    type HookInput,
} from "../hook-lib/hook-utils"

import { execFile } from "node:child_process"
import { promisify } from "node:util"

const exec = promisify(execFile)

// After a `git push`, if the branch has an open PR, remind to refresh its stale
// title/body via the pr-describer agent. Reminder only, never blocks. FAIL-OPEN:
// any error (no gh, no PR, not a repo) → none.

const PUSH = /\bgit\s+push\b/

function isGitPush(cmd: string): boolean {
    return PUSH.test(cmd)
}

function refreshContext(url: string): string {
    return (
        `Push landed and this branch has an open PR (${url}). Its diff changed, ` +
        `so the description is now stale — delegate a refresh of the title/body ` +
        `to the \`pr-describer\` agent (never edit the description inline).`
    )
}

async function run(input: HookInput, ctx: HookCtx): Promise<HookResult> {
    const cmd = input.command
    if (typeof cmd !== "string" || !isGitPush(cmd)) return { kind: "none" }
    try {
        const { stdout } = await exec("gh", ["pr", "view", "--json", "url,number"], {
            cwd: ctx.directory,
            timeout: 15000,
        })
        const url = JSON.parse(stdout).url
        return url ? { kind: "context", text: refreshContext(url) } : { kind: "none" }
    } catch {
        return { kind: "none" }
    }
}

export const prRefreshReminder = async ({ directory }: { directory: string }) => ({
    "tool.execute.after": async (input: any, output: any) =>
        applyOpencodeAfter(output, await run(extractOpencodeAfter(input, output), { directory })),
})
