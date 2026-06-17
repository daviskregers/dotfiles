export const PR_URL_RE = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/(\d+)\/?$/

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

/**
 * Parse a validated GitHub PR URL into its components.
 * Returns null if the URL doesn't match.
 */
export function parsePrUrl(url: string): { ownerRepo: string; number: string } | null {
    const m = url.match(PR_URL_RE)
    if (!m) return null
    return { ownerRepo: m[1], number: m[2] }
}
