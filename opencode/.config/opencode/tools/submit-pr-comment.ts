import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"
import { execFile } from "child_process"
import { promisify } from "util"

const execFileAsync = promisify(execFile)

const PR_URL_RE = /^https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+\/?$/

export default tool({
    description:
        "Post a file as a comment on a GitHub pull request. The file is sent directly to `gh pr comment` without being read into the conversation.",
    args: {
        prUrl: tool.schema
            .string()
            .describe("The full GitHub PR URL (e.g. https://github.com/org/repo/pull/123)"),
        filePath: tool.schema
            .string()
            .describe("Path to the file to post as a comment (relative to cwd or absolute)"),
    },
    async execute(args, context) {
        if (!PR_URL_RE.test(args.prUrl)) {
            return `Error: Invalid PR URL format. Expected https://github.com/<owner>/<repo>/pull/<number>`
        }

        const resolved = path.isAbsolute(args.filePath)
            ? args.filePath
            : path.join(context.directory, args.filePath)

        const MAX_COMMENT_BYTES = 60_000

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

        try {
            const { stdout } = await execFileAsync(
                "gh",
                ["pr", "comment", args.prUrl, "--body-file", resolved],
                { encoding: "utf8" },
            )
            return `Comment posted to ${args.prUrl}\n${stdout}`.trim()
        } catch (err: any) {
            return `Error posting comment: ${err.message}`
        }
    },
})
