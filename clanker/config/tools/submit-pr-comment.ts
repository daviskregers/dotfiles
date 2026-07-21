import path from "path"
import os from "os"
import fs from "fs"
import { execFileAsync, withAttribution, MAX_COMMENT_BYTES } from "./shared"

const PR_URL_RE = /^https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+\/?$/

export async function execute(args: { prUrl: string; filePath: string }, ctx: { directory: string }): Promise<string> {
    if (!PR_URL_RE.test(args.prUrl)) {
        return `Error: Invalid PR URL format. Expected https://github.com/<owner>/<repo>/pull/<number>`
    }

    const resolved = path.isAbsolute(args.filePath) ? args.filePath : path.join(ctx.directory, args.filePath)

    let stat: fs.Stats
    try {
        stat = await fs.promises.stat(resolved)
    } catch {
        return `Error: File not found: ${args.filePath}`
    }

    if (stat.size === 0) {
        return `Error: File is empty: ${args.filePath}`
    }

    if (stat.size > MAX_COMMENT_BYTES) {
        return `Error: File is too large (${stat.size} bytes). GitHub comments are limited to ${MAX_COMMENT_BYTES} bytes.`
    }

    let body: string
    try {
        body = withAttribution(await fs.promises.readFile(resolved, "utf-8"))
    } catch (err: any) {
        return `Error reading file: ${err.message}`
    }

    const tmp = path.join(os.tmpdir(), `pr-comment-${Date.now()}.md`)
    try {
        await fs.promises.writeFile(tmp, body, "utf-8")
        const { stdout } = await execFileAsync("gh", ["pr", "comment", args.prUrl, "--body-file", tmp], {
            encoding: "utf8",
        })
        return `Comment posted to ${args.prUrl}\n${stdout}`.trim()
    } catch (err: any) {
        return `Error posting comment: ${err.message}`
    } finally {
        fs.promises.unlink(tmp).catch(() => {})
    }
}
