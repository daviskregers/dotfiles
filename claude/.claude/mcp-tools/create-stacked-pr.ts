import { execFileAsync, MAX_BUFFER, withAttribution } from "./shared"

// One candidate parent branch and how many commits HEAD carries since it diverged
// from that branch (rev-list --count merge-base(B,HEAD)..HEAD).
export type Candidate = { branch: string; count: number }

/**
 * Pick the branch HEAD was stacked on: the closest local ancestor, i.e. the one
 * sharing the MOST history with HEAD — the smallest POSITIVE divergence count. A
 * count of 0 means the branch is identical to or a descendant of HEAD (not a parent),
 * so it's excluded. A tie at the minimum is genuinely ambiguous — the caller must ask
 * rather than guess. Pure so the ranking is unit-tested without touching git.
 */
export function pickParent(cands: Candidate[]): { parent?: string; tied?: string[] } {
    const positive = cands.filter((c) => c.count > 0).sort((a, b) => a.count - b.count)
    if (positive.length === 0) return {}
    const min = positive[0].count
    const atMin = positive.filter((c) => c.count === min)
    if (atMin.length > 1) return { tied: atMin.map((c) => c.branch) }
    return { parent: positive[0].branch }
}

async function git(cwd: string, args: string[]): Promise<string> {
    const { stdout } = await execFileAsync("git", args, { cwd, encoding: "utf8", maxBuffer: MAX_BUFFER })
    return stdout.trim()
}

/**
 * Open a PR whose base is the branch the current branch was stacked on, not the repo
 * default. Detects the parent by merge-base ranking (overridable via `base`), pushes
 * the current branch, and creates the PR. Attribution is injected HERE with
 * withAttribution because this is an MCP tool — it bypasses the Bash ai-attribution
 * hook, so the EU AI Act Art. 50 notice must be stamped in-process.
 */
export async function execute(
    args: { base?: string; title?: string; body?: string; draft?: boolean },
    ctx: { directory: string },
): Promise<string> {
    const cwd = ctx.directory

    let current: string
    try {
        current = await git(cwd, ["branch", "--show-current"])
    } catch (err: any) {
        return `Error: not a git repo or cannot read current branch: ${err.message}`
    }
    if (!current) return "Error: detached HEAD — checkout a branch before creating a stacked PR."

    // 1. Resolve base — explicit override, else detect the closest-ancestor parent.
    let base = args.base?.trim()
    if (!base) {
        let branches: string[]
        try {
            const out = await git(cwd, ["for-each-ref", "--format=%(refname:short)", "refs/heads/"])
            branches = out.split("\n").filter((b) => b && b !== current)
        } catch (err: any) {
            return `Error listing local branches: ${err.message}`
        }
        const cands: Candidate[] = []
        for (const b of branches) {
            try {
                const mb = await git(cwd, ["merge-base", b, "HEAD"])
                const count = parseInt(await git(cwd, ["rev-list", "--count", `${mb}..HEAD`]), 10)
                cands.push({ branch: b, count: Number.isFinite(count) ? count : 0 })
            } catch {
                // Unrelated/broken ref (no common ancestor) — not a parent candidate.
            }
        }
        const pick = pickParent(cands)
        if (pick.tied) {
            return `Ambiguous parent — these branches are equidistant from "${current}": ${pick.tied.join(
                ", ",
            )}. Re-run with an explicit base.`
        }
        if (!pick.parent) {
            return `Could not detect a parent branch for "${current}". Re-run with an explicit base (the branch this was stacked on).`
        }
        base = pick.parent
    }

    if (base === current) return `Error: base "${base}" is the current branch — a PR can't target itself.`

    // 2. Push the current branch so gh has a head to open the PR from.
    try {
        await execFileAsync("git", ["push", "-u", "origin", "HEAD"], { cwd, encoding: "utf8", maxBuffer: MAX_BUFFER })
    } catch (err: any) {
        return `Error pushing "${current}" to origin: ${err.message}`
    }

    // 3. The base must exist on the remote or gh can't target it.
    try {
        const remote = await git(cwd, ["ls-remote", "--heads", "origin", base])
        if (!remote) {
            return `Base branch "${base}" is not on origin — push it (open its own PR/branch) first, then re-run.`
        }
    } catch (err: any) {
        return `Error checking base "${base}" on origin: ${err.message}`
    }

    // 4. Title + body. Default the body to the commit list so the PR isn't empty;
    //    stamp attribution regardless of whether the caller supplied a body.
    let title = args.title?.trim()
    if (!title) {
        try {
            title = await git(cwd, ["log", "-1", "--format=%s", "HEAD"])
        } catch {
            title = current
        }
    }
    let bodyText = args.body?.trim() ?? ""
    if (!bodyText) {
        try {
            const commits = await git(cwd, ["log", `${base}..HEAD`, "--format=- %s", "--reverse"])
            bodyText = commits ? `## Commits\n\n${commits}` : ""
        } catch {
            // No body derivable — attribution alone still gets stamped below.
        }
    }
    const body = withAttribution(bodyText)

    // 5. Create the PR against the parent branch.
    const ghArgs = ["pr", "create", "--base", base, "--head", current, "--title", title, "--body", body]
    if (args.draft) ghArgs.push("--draft")
    let url: string
    try {
        const { stdout } = await execFileAsync("gh", ghArgs, { cwd, encoding: "utf8", maxBuffer: MAX_BUFFER })
        url = stdout.trim()
    } catch (err: any) {
        return `Error creating PR (gh pr create): ${err.message}`
    }

    // 6. Open the PR in the browser. Non-fatal — the PR exists regardless, so a
    //    headless/no-browser environment still gets a successful result.
    let opened = ""
    try {
        await execFileAsync("gh", ["pr", "view", url, "--web"], { cwd, encoding: "utf8", maxBuffer: MAX_BUFFER })
        opened = "\n  opened in browser"
    } catch (err: any) {
        opened = `\n  (could not open browser: ${err.message})`
    }
    return `Stacked PR created: ${url}\n  base: ${base}  ←  head: ${current}${opened}`
}
