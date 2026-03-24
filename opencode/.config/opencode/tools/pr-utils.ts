export const PR_URL_RE = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/(\d+)\/?$/

/**
 * Parse a validated GitHub PR URL into its components.
 * Returns null if the URL doesn't match.
 */
export function parsePrUrl(url: string): { ownerRepo: string; number: string } | null {
    const m = url.match(PR_URL_RE)
    if (!m) return null
    return { ownerRepo: m[1], number: m[2] }
}
