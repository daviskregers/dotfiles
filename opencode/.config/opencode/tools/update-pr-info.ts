import { tool } from "@opencode-ai/plugin"
import { execFile } from "child_process"
import { promisify } from "util"
import { parsePrUrl } from "./pr-utils"

const execFileAsync = promisify(execFile)

export default tool({
    description:
        "Update a GitHub pull request's title and/or body (description). At least one of title or body must be provided.",
    args: {
        prUrl: tool.schema
            .string()
            .describe("The full GitHub PR URL (e.g. https://github.com/org/repo/pull/123)"),
        title: tool.schema
            .string()
            .optional()
            .describe("New title for the PR. Empty strings are ignored — omit the field to leave the title unchanged."),
        body: tool.schema
            .string()
            .optional()
            .describe("New body/description for the PR (markdown). Empty strings are ignored — omit the field to leave the body unchanged."),
    },
    async execute(args) {
        if (!parsePrUrl(args.prUrl)) {
            return `Error: Invalid PR URL format. Expected https://github.com/<owner>/<repo>/pull/<number>`
        }

        if (!args.title && !args.body) {
            return `Error: At least one of 'title' or 'body' must be provided (empty strings are ignored)`
        }

        const ghArgs = ["pr", "edit", args.prUrl]

        if (args.title) {
            ghArgs.push("--title", args.title)
        }

        if (args.body) {
            ghArgs.push("--body", args.body)
        }

        try {
            const { stdout } = await execFileAsync("gh", ghArgs, {
                encoding: "utf8",
            })
            const updated = [
                args.title ? "title" : null,
                args.body ? "body" : null,
            ]
                .filter(Boolean)
                .join(" and ")
            return `Successfully updated ${updated} for ${args.prUrl}\n${stdout}`.trim()
        } catch (err: any) {
            return `Error updating PR: ${err.message}`
        }
    },
})
