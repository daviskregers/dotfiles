import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"
import { execFileAsync } from "./shared"

async function execute(args: { path: string }, ctx: { directory: string }): Promise<string> {
    if (!process.env.TMUX) {
        return "Error: not inside a tmux session ($TMUX unset) — no session to open a window in."
    }

    const abs = path.isAbsolute(args.path) ? args.path : path.resolve(ctx.directory, args.path)

    let stat: fs.Stats
    try {
        stat = await fs.promises.stat(abs)
    } catch {
        return `Error: no such directory: ${args.path} (resolved ${abs})`
    }
    if (!stat.isDirectory()) {
        return `Error: not a directory: ${abs}`
    }

    const name = `${path.basename(abs)}-nvim`
    try {
        // -d: create detached so opening several dirs in a row doesn't steal focus.
        await execFileAsync("tmux", ["neww", "-d", "-c", abs, "-n", name, "nvim"])
    } catch (err: any) {
        return `Error opening tmux window: ${err.message}`
    }
    return `Opened tmux window "${name}" → ${abs}`
}

export default tool({
    description:
        "Open a new detached tmux window running nvim at a directory, to review an agent's changes. Call once per distinct directory; requires running inside tmux. Path may be relative to the cwd or absolute.",
    args: {
        path: tool.schema.string().describe("Directory to open nvim in (relative to cwd or absolute)"),
    },
    execute,
})
