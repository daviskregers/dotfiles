import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

export default tool({
  description:
    "Save a code review to the .dk-notes/reviews directory with a timestamped filename",
  args: {
    content: tool.schema.string().describe("The full review content to save"),
  },
  async execute(args, context) {
    const dir = path.join(context.directory, ".dk-notes/reviews")
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
    const suffix = Math.random().toString(36).slice(2, 6)

    const filePath = path.join(dir, `review_${timestamp}_${suffix}.md`)
    await fs.promises.writeFile(filePath, args.content, "utf-8")

    const relativePath = path.relative(context.directory, filePath)
    return `Review saved to ${relativePath}`
  },
})
