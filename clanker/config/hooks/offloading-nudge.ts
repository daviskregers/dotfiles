import type { HookResult, HookCtx, HookInput } from "./hook-utils"

// Nudge when a prompt looks like a bare problem dump: references an artifact
// (URL or error/log paste), states NO hypothesis, and is short enough to be a
// dump rather than a considered report. Pure heuristic → context (never blocks).

const URL = /https?:\/\//i
const ERROR_MARKER = /\b(error|exception|traceback|stack ?trace|failed|failing|fatal|panic)\b/i
// Markers that the user has already done some thinking / posed a question.
const HYPOTHESIS =
    /(\?|\bi think\b|\bi suspect\b|\bi bet\b|\bbecause\b|\bhypothes|\brule[d]? out\b|\bmaybe\b|\bcould be\b|\bmight be\b|\bmy guess\b|\bseems like\b|\bprobably\b|\bwhy\b)/i

const NUDGE =
    "This prompt looks like a bare problem dump (artifact/link, no stated " +
    "hypothesis). Per the shared-reasoning rule: if the diagnosis is non-trivial, " +
    "open with your candidate hypotheses + the cheapest discriminating check and " +
    "invite a prediction before handing back a fix — keep me in the loop. If it's " +
    "genuinely trivial/mechanical, just do it."

// True when the prompt trips the dump heuristic (artifact present, no hypothesis, short).
export function isBareDump(prompt: string): boolean {
    if (!prompt.trim()) return false
    if (prompt.trim().split(/\s+/).length > 120) return false // long, considered report
    if (!(URL.test(prompt) || ERROR_MARKER.test(prompt))) return false // no artifact
    if (HYPOTHESIS.test(prompt)) return false // already posed a hypothesis/question
    return true
}

export async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    const prompt = input.prompt
    if (typeof prompt !== "string" || !isBareDump(prompt)) return { kind: "none" }
    return { kind: "context", text: NUDGE }
}
