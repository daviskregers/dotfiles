import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"
import { execFile, exec } from "child_process"
import { promisify } from "util"

const execFileAsync = promisify(execFile)
const execAsync = promisify(exec)

export default tool({
    description:
        "Save an HTML explanation page to the .ai-artifacts directory with a timestamped filename and open it in the default browser.",
    args: {
        content: tool.schema.string().describe("The full HTML content to save"),
        title: tool.schema
            .string()
            .optional()
            .describe("Short title for the filename slug (e.g. 'jwt-auth-flow'). Defaults to 'explanation'."),
    },
    async execute(args, context) {
        const dir = path.join(context.directory, ".ai-artifacts")
        await fs.promises.mkdir(dir, { recursive: true })

        const now = new Date()
        const pad = (n: number) => String(n).padStart(2, "0")
        const timestamp = [
            now.getUTCFullYear(),
            "-",
            pad(now.getUTCMonth() + 1),
            "-",
            pad(now.getUTCDate()),
            "_",
            pad(now.getUTCHours()),
            "-",
            pad(now.getUTCMinutes()),
            "-",
            pad(now.getUTCSeconds()),
        ].join("")

        const slug =
            (args.title ?? "explanation")
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, "-")
                .replace(/^-|-$/g, "")
                .slice(0, 60) || "explanation"

        const filePath = path.join(dir, `explanation_${timestamp}_${slug}.html`)
        await fs.promises.writeFile(filePath, args.content, "utf-8")

        const relativePath = path.relative(context.directory, filePath)

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
    },
})
