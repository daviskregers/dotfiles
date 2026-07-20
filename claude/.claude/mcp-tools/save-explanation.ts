import path from "path"
import fs from "fs"
import { exec } from "child_process"
import { promisify } from "util"
import { ensureNotesDir, execFileAsync, timestamp } from "./shared"

const execAsync = promisify(exec)

export async function execute(args: { content: string; title?: string }, ctx: { directory: string }): Promise<string> {
    const dir = await ensureNotesDir(ctx.directory, "explanations")

    const slug =
        (args.title ?? "explanation")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/^-|-$/g, "")
            .slice(0, 60) || "explanation"

    const filePath = path.join(dir, `explanation_${timestamp()}_${slug}.html`)
    await fs.promises.writeFile(filePath, args.content, "utf-8")

    const relativePath = path.relative(ctx.directory, filePath)

    let opened = false
    try {
        if (process.platform === "win32") {
            // `start` is a cmd.exe built-in, so it needs a shell
            await execAsync(`start "" "${filePath}"`)
        } else {
            const cmd = process.platform === "darwin" ? "open" : "xdg-open"
            await execFileAsync(cmd, [filePath])
        }
        opened = true
    } catch {
        // Browser open is best-effort; report below
    }

    return opened
        ? `Explanation saved to ${relativePath} and opened in browser`
        : `Explanation saved to ${relativePath} (could not open browser automatically)`
}
