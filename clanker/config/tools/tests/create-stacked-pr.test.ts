import { expect, test } from "bun:test"
import { pickParent } from "../create-stacked-pr"

test("picks the branch with the smallest positive divergence (closest ancestor)", () => {
    expect(
        pickParent([
            { branch: "main", count: 5 },
            { branch: "feat-a", count: 1 },
            { branch: "old", count: 9 },
        ]),
    ).toEqual({
        parent: "feat-a",
    })
})

test("excludes count-0 branches (identical/descendant of HEAD, not a parent)", () => {
    expect(
        pickParent([
            { branch: "child", count: 0 },
            { branch: "feat-a", count: 4 },
        ]),
    ).toEqual({ parent: "feat-a" })
})

test("reports a tie at the minimum as ambiguous rather than guessing", () => {
    expect(
        pickParent([
            { branch: "feat-a", count: 2 },
            { branch: "feat-b", count: 2 },
            { branch: "main", count: 6 },
        ]),
    ).toEqual({
        tied: ["feat-a", "feat-b"],
    })
})

test("returns no parent when there are no positive candidates", () => {
    expect(pickParent([{ branch: "child", count: 0 }])).toEqual({})
    expect(pickParent([])).toEqual({})
})
