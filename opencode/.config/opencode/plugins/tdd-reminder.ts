import {
    extractOpencodeAfter,
    applyOpencodeAfter,
    type HookResult,
    type HookCtx,
    type HookInput,
} from "../hook-lib/hook-utils"

import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { statSync } from "node:fs"
import { dirname, extname } from "node:path"

const exec = promisify(execFile)

// Soft TDD nudge: editing a source file (code ext, not a test) in a git repo where
// NO test file is currently modified/staged → remind to follow red-green-refactor.
// NUDGES, never blocks. FAIL-OPEN: any error → none.

const SRC_EXT = new Set([
    ".py",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".vue",
    ".go",
    ".rb",
    ".php",
    ".rs",
    ".java",
    ".kt",
    ".swift",
    ".c",
    ".cc",
    ".cpp",
    ".h",
    ".hpp",
    ".cs",
    ".scala",
    ".ex",
    ".exs",
    ".m",
    ".mm",
    ".lua",
])
// Match test/spec as path SEGMENTS, not substrings (latest.py isn't a test).
const TEST_RE = /(^|[/_.\-])(tests?|specs?|__tests__)([/_.\-]|$)/i

const REMINDER =
    "TDD is default (global rule): before changing this source, there should be " +
    "a failing test that exercises the new/changed behavior — no test file is " +
    "currently modified in this repo. Red-green-refactor + rollback + contract-" +
    "migration mechanics live in the `tdd` skill; load it before proceeding, or " +
    "confirm this change is genuinely exempt (pure rename, generated code, config)."

function isTestPath(p: string): boolean {
    return TEST_RE.test(p)
}

function isSourceExt(p: string): boolean {
    return SRC_EXT.has(extname(p).toLowerCase())
}

// A test file appears among the porcelain-status paths (strip the XY status prefix).
function hasTestInStatus(porcelain: string): boolean {
    for (const line of porcelain.split("\n")) {
        const path = line.slice(3).trim()
        if (path && isTestPath(path)) return true
    }
    return false
}

function isDir(p: string): boolean {
    try {
        return statSync(p).isDirectory()
    } catch {
        return false
    }
}

async function repoRoot(path: string): Promise<string | null> {
    const d = isDir(path) ? path : dirname(path) || "."
    try {
        const { stdout } = await exec("git", ["-C", d, "rev-parse", "--show-toplevel"], { timeout: 5000 })
        return stdout.trim() || null
    } catch {
        return null // not a git repo → no nudge
    }
}

async function hasModifiedTests(root: string): Promise<boolean> {
    try {
        const { stdout } = await exec("git", ["-C", root, "status", "--porcelain"], { timeout: 5000 })
        return hasTestInStatus(stdout)
    } catch {
        return true // can't tell → assume yes, stay quiet (fail-open)
    }
}

async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    const path = input.filePath
    if (typeof path !== "string" || !path) return { kind: "none" }
    if (!isSourceExt(path) || isTestPath(path)) return { kind: "none" }
    const root = await repoRoot(path)
    if (!root || (await hasModifiedTests(root))) return { kind: "none" }
    return { kind: "context", text: REMINDER }
}

export const tddReminder = async ({ directory }: { directory: string }) => ({
    "tool.execute.after": async (input: any, output: any) =>
        applyOpencodeAfter(output, await run(extractOpencodeAfter(input, output), { directory })),
})
