import type { HookResult, HookCtx, HookInput } from "./hook-utils"

// git/gh global options tolerated before the subcommand (git -C path, -c k=v, --long).
const GITX = String.raw`(?:-C\s+\S+\s+|-c\s+\S+\s+|--\S+\s+|-\w+\s+)*`

const DANGER: [RegExp, string][] = [
    [
        new RegExp(String.raw`\bgit\s+${GITX}push\b[^|;&\n]*(?:--force(?!-with-lease\b|-if-includes\b)|\s-f\b)`, "i"),
        "git force-push",
    ],
    [new RegExp(String.raw`\bgit\s+${GITX}reset\s+--hard\b`, "i"), "git reset --hard (discards work)"],
    [new RegExp(String.raw`\bgit\s+${GITX}clean\s+-\S*f`, "i"), "git clean -f (deletes untracked)"],
    [/\b(?:migrate:fresh|migrate:reset|db:wipe)\b/i, "destructive DB migration (drops all tables)"],
    [/\b(?:rails\s+db:drop|prisma\s+migrate\s+reset|sequelize\s+db:drop)\b/i, "destructive DB reset"],
    [/\bDROP\s+(?:TABLE|DATABASE|SCHEMA)\b|\bTRUNCATE\s+(?:TABLE\s+)?\w/i, "destructive SQL (DROP/TRUNCATE)"],
    [/\bdd\b[^|;&\n]*\bof=/i, "dd (raw disk/file overwrite)"],
    [/\bmkfs\b|>\s*\/dev\/(?:sd|nvme|disk)|\bof=\/dev\//i, "write to block device / format"],
    [/\bfind\b[^|;&\n]*(?:-delete\b|-exec\s+rm\b)/i, "find with -delete / -exec rm"],
    [/(?:curl|wget)\b[^|\n]*\|\s*(?:sudo\s+)?(?:sh|bash|zsh)\b/i, "pipe remote script into a shell"],
    [/\bterraform\s+destroy\b/i, "terraform destroy"],
    [/\bdocker\s+system\s+prune\b|\bdocker\s+volume\s+rm\b/i, "docker destructive prune / volume rm"],
    [/(?:^|[\s;&|(\\`])(?:\S*\/)?aws(?=\s|$)/i, "the AWS CLI — disallowed for the agent (run it yourself if needed)"],
    [/:\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:/, "fork bomb"],
]

const MSG_FLAG = /(?:-m|--message|--body)(?:=|\s+)(?:"(?:[^"\\]|\\.)*"|'[^']*'|\S+)/g
const SUBST = /\$\(([^)]*)\)|`([^`]*)`|\$\{([^}]*)\}/g

const stripMessageFlags = (cmd: string) => cmd.replace(MSG_FLAG, " ")

function substitutions(cmd: string): string {
    const out: string[] = []
    for (const m of cmd.matchAll(SUBST)) for (const g of [m[1], m[2], m[3]]) if (g) out.push(g)
    return out.join(" ")
}

const base = (t: string) => t.split("/").pop() ?? t

// An `rm` whose flags include BOTH recursive and force, any order (not `git rm`).
function rmRecursiveForce(text: string): boolean {
    const toks = text.split(/\s+/).filter(Boolean)
    for (let i = 0; i < toks.length; i++) {
        if (base(toks[i]) !== "rm") continue
        if (i > 0 && base(toks[i - 1]) === "git") continue
        let short = ""
        const longs: string[] = []
        for (const t of toks.slice(i + 1)) {
            if (t.startsWith("--")) longs.push(t)
            else if (t.startsWith("-") && t.length > 1) short += t.slice(1)
            else break
        }
        const hasR = short.toLowerCase().includes("r") || longs.includes("--recursive")
        const hasF = short.toLowerCase().includes("f") || longs.includes("--force")
        if (hasR && hasF) return true
    }
    return false
}

function chmod777Recursive(text: string): boolean {
    const toks = text.split(/\s+/).filter(Boolean)
    for (let i = 0; i < toks.length; i++) {
        if (base(toks[i]) !== "chmod") continue
        const rest = toks.slice(i + 1)
        const recursive = rest.some(
            (x) => x === "--recursive" || (x.startsWith("-") && !x.startsWith("--") && x.includes("R")),
        )
        const mode = rest.some((x) => x === "777" || x === "0777" || x === "a+rwx")
        if (recursive && mode) return true
    }
    return false
}

function scan(text: string): string | null {
    if (rmRecursiveForce(text)) return "recursive force delete (rm -rf)"
    if (chmod777Recursive(text)) return "chmod -R 777"
    for (const [rx, label] of DANGER) if (rx.test(text)) return label
    return null
}

export async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    const cmd = input.command
    if (typeof cmd !== "string" || !cmd.trim()) return { kind: "none" }
    for (const text of [stripMessageFlags(cmd), substitutions(cmd)]) {
        if (!text.trim()) continue
        const label = scan(text)
        if (label) {
            return {
                kind: "deny",
                reason: `Blocked by the command guard — ${label}. Denied so it can't run on a reflexive approval. If you genuinely intend it, run it yourself via the \`!\` prefix, or restate it explicitly and I'll explain exactly what it does first.`,
            }
        }
    }
    return { kind: "none" }
}
