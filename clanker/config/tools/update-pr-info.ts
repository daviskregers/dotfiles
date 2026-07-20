import { execFileAsync } from "./shared"
import { parsePrUrl } from "./pr-utils"

export async function execute(
    args: { prUrl: string; title?: string; body?: string },
    ctx: { directory: string },
): Promise<string> {
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
}
