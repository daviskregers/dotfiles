import {
    extractOpencodeMessage,
    applyOpencodeMessage,
    type HookResult,
    type HookCtx,
    type HookInput,
} from "../hook-lib/hook-utils"

// When the user replies with a BARE approval, remind to confirm scope before
// executing — so a reflexive "yes" doesn't rubber-stamp a bundled/consequential
// set. Pure heuristic → context (never blocks). Affirmation list calibrated from
// the Conversations archive.

const AFFIRM =
    /^(ye|yes|yep|yup|yeah|ya|sure|ok|okay|proceed|go|go ahead|do it|sounds good|lgtm|ship it|please|yes please|go for it|👍)\b/i

const REMINDER =
    "Bare approval detected. Before executing: confirm this 'yes' wasn't a bundled " +
    "or consequential set. If my previous turn asked for more than one thing, or " +
    "included an irreversible/outward-facing action (commit, push, delete, send, " +
    "publish), restate exactly what this approves and confirm the rest per-item — " +
    "don't run the whole batch on one yes."

// Drop quoted (>) lines, trim; a bare approval is short and opens with an affirmation.
function isBareApproval(prompt: string): boolean {
    const clean = prompt
        .split(/\r?\n/)
        .filter((l) => !l.trim().startsWith(">"))
        .join("\n")
        .trim()
    if (!clean || clean.split(/\s+/).length > 6) return false
    return AFFIRM.test(clean)
}

async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    const prompt = input.prompt
    if (typeof prompt !== "string" || !isBareApproval(prompt)) return { kind: "none" }
    return { kind: "context", text: REMINDER }
}

export const approvalScope = async ({ directory }: { directory: string }) => ({
    "chat.message": async (input: any, output: any) =>
        applyOpencodeMessage(output, await run(extractOpencodeMessage(input, output), { directory })),
})
