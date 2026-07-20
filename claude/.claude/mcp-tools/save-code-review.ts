import path from "path"
import fs from "fs"
import { ensureNotesDir, timestamp } from "./shared"

export async function execute(args: { content: string }, ctx: { directory: string }): Promise<string> {
    const dir = await ensureNotesDir(ctx.directory, "reviews")

    const suffix = Math.random().toString(36).slice(2, 6)

    const filePath = path.join(dir, `review_${timestamp()}_${suffix}.md`)
    await fs.promises.writeFile(filePath, args.content, "utf-8")

    const relativePath = path.relative(ctx.directory, filePath)
    return `Review saved to ${relativePath}`
}
