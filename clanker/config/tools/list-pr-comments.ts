import { fetchAllPrNodes, parsePrUrl, INVALID_PR_URL, THREADS_Q, REVIEWS_Q, CONV_Q } from "./pr-utils"

export async function execute(
    args: { prUrl: string; includeResolved?: boolean },
    ctx: { directory: string },
): Promise<string> {
    const parsed = parsePrUrl(args.prUrl)
    if (!parsed) return INVALID_PR_URL
    const { owner, repo, number: num } = parsed

    let pr: any
    try {
        const [threads, reviews, comments] = await Promise.all([
            fetchAllPrNodes(THREADS_Q, owner, repo, num, (p) => p.reviewThreads),
            fetchAllPrNodes(REVIEWS_Q, owner, repo, num, (p) => p.reviews),
            fetchAllPrNodes(CONV_Q, owner, repo, num, (p) => p.comments),
        ])
        pr = { reviewThreads: { nodes: threads }, reviews: { nodes: reviews }, comments: { nodes: comments } }
    } catch (err: any) {
        return `Error fetching PR comments: ${err.message}`
    }

    const items: any[] = []
    for (const t of pr.reviewThreads?.nodes ?? []) {
        if (t.isResolved && !args.includeResolved) continue
        const all = t.comments?.nodes ?? []
        const c = all[0]
        if (!c || !c.body?.trim()) continue
        items.push({
            kind: "inline",
            threadId: t.id,
            isResolved: t.isResolved,
            isOutdated: t.isOutdated,
            path: c.path,
            line: c.line,
            author: c.author?.login,
            body: c.body,
            url: c.url,
            replies: Math.max(0, all.length - 1),
            // Full thread context when there are replies, so triage sees follow-ups.
            ...(all.length > 1 ? { thread: all.map((n: any) => ({ author: n.author?.login, body: n.body })) } : {}),
        })
    }
    for (const r of pr.reviews?.nodes ?? []) {
        if (!r.body?.trim()) continue
        items.push({
            kind: "review",
            threadId: null,
            author: r.author?.login,
            body: r.body,
            state: r.state,
            url: r.url,
        })
    }
    for (const c of pr.comments?.nodes ?? []) {
        if (!c.body?.trim()) continue
        items.push({ kind: "conversation", threadId: null, author: c.author?.login, body: c.body, url: c.url })
    }
    items.forEach((it, i) => (it.index = i + 1))

    const skippedResolved = args.includeResolved
        ? 0
        : (pr.reviewThreads?.nodes ?? []).filter((t: any) => t.isResolved).length

    return JSON.stringify(
        { pr: { owner, repo, number: Number(num) }, total: items.length, skippedResolved, items },
        null,
        2,
    )
}
