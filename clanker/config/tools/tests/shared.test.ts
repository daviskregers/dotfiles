import { test, expect, describe } from "bun:test"
import { withAttribution, ATTRIBUTION_NOTICE } from "../shared"

// Compliance-critical (EU AI Act) + duplicated from the hook tree's ensureNotice —
// this asserts the tool copy behaves identically so the two can't drift silently.
describe("withAttribution", () => {
    test("appends the notice to a plain body", () => {
        expect(withAttribution("summary")).toBe(`summary\n\n${ATTRIBUTION_NOTICE}`)
    })
    test("idempotent — bare notice already present", () => {
        const t = `done\n\n${ATTRIBUTION_NOTICE}`
        expect(withAttribution(t)).toBe(t)
    })
    test("idempotent — (model) form present", () => {
        const t = `done\n\n${ATTRIBUTION_NOTICE} (opus)`
        expect(withAttribution(t)).toBe(t)
    })
    test("empty → just the notice", () => {
        expect(withAttribution("")).toBe(ATTRIBUTION_NOTICE)
    })
    test("strips Co-Authored-By trailer then attributes", () => {
        expect(withAttribution("msg\n\nCo-Authored-By: Claude <x@y>")).toBe(`msg\n\n${ATTRIBUTION_NOTICE}`)
    })
    test("strips tool-branded 'Generated with Claude Code' line", () => {
        expect(withAttribution("body\n\n🤖 Generated with Claude Code")).toBe(`body\n\n${ATTRIBUTION_NOTICE}`)
    })
})
