import { test, expect, describe } from "bun:test"
import { parsePrUrl, PR_URL_RE } from "../pr-utils"

// parsePrUrl is the pure gatekeeper every PR tool runs first. The gh-calling
// wrappers (fetchAllPrNodes pagination, copilotIsRequested matching) are exercised
// by the live /ship + /comments smoke-tests — mocking the ./shared exec seam leaks
// across bun's global module registry, so they're intentionally integration-covered.
describe("parsePrUrl", () => {
    test.each([
        ["https://github.com/o/r/pull/42", "o/r", "42"],
        ["https://github.com/my-org/my.repo/pull/7/", "my-org/my.repo", "7"],
    ])("parses %s", (url, ownerRepo, number) => {
        expect(parsePrUrl(url)).toEqual({ ownerRepo, number })
    })

    test.each([
        ["wrong path segment", "https://github.com/o/r/issues/42"],
        ["not github", "https://gitlab.com/o/r/pull/1"],
        ["not a url", "not a url"],
        ["missing number", "https://github.com/o/r/pull/"],
        ["http not https", "http://github.com/o/r/pull/1"],
    ])("rejects %s", (_label, url) => {
        expect(parsePrUrl(url)).toBeNull()
    })

    test("regex is anchored (no trailing garbage)", () => {
        expect(PR_URL_RE.test("https://github.com/o/r/pull/1/files")).toBe(false)
    })
})
