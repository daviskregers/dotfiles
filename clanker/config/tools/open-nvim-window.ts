import path from "path"
import fs from "fs"
import { execFileAsync } from "./shared"

export async function execute(args: { path: string }, ctx: { directory: string }): Promise<string> {
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
