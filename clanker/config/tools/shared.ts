import path from "path"
import fs from "fs"
import { execFile } from "child_process"
import { promisify } from "util"

export const execFileAsync = promisify(execFile)
export const MAX_BUFFER = 10 * 1024 * 1024
export const MAX_COMMENT_BYTES = 60_000

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

export const ATTRIBUTION_NOTICE = "🤖 Generated with AI"

const BRANDED_LINE =
    /^[ \t>]*(?:co-authored-by:.*|.*generated with (?:claude code|opencode).*)\s*$/gim

// A notice line already present, in either the bare or "(model)" form.
const NOTICE_PRESENT = new RegExp(`^[ \\t>]*${ATTRIBUTION_NOTICE}\\b`, "im")

/**
 * Append the AI-attribution notice as the final line, stripping any tool-branded
 * attribution (Co-Authored-By, "Generated with Claude Code/opencode"). Idempotent —
 * leaves an existing notice (bare or with model name) untouched.
 */
export function withAttribution(text: string): string {
    const stripped = text
        .replace(BRANDED_LINE, "")
        .replace(/\n{3,}/g, "\n\n")
        .replace(/\s+$/, "")
    if (NOTICE_PRESENT.test(stripped)) return stripped
    return stripped ? `${stripped}\n\n${ATTRIBUTION_NOTICE}` : ATTRIBUTION_NOTICE
}

export function timestamp(): string {
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  return [
    now.getUTCFullYear(), "-", pad(now.getUTCMonth() + 1), "-", pad(now.getUTCDate()),
    "_", pad(now.getUTCHours()), "-", pad(now.getUTCMinutes()), "-", pad(now.getUTCSeconds()),
  ].join("");
}

// Ensure .dk-notes/<kind> exists under the given base directory; returns its path.
export async function ensureNotesDir(directory: string, kind: string): Promise<string> {
  const dir = path.join(directory, ".dk-notes", kind);
  await fs.promises.mkdir(dir, { recursive: true });
  return dir;
}
