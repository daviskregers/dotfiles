Entry ritual for starting a piece of work. Context: {{.Args}} — none? Ask what they're starting on. Pick the lane (§0) first — it decides everything after. Do NOT run ahead to code.

## 0. Pick the lane

Two questions — **who designs** (holds the plan) and **who implements** (types it) — not how important the task is:

|                  | You implement    | Agent implements |
| ---------------- | ---------------- | ---------------- |
| **You design**   | Free             | Plan-handoff     |
| **Agent designs**| Practice         | Farm             |

- **Free** — you design, you implement. Craft/flow/explore; agent supports only, never implements. → §Free
- **Plan-handoff** — you design, agent implements. You learn it, write the plan, then hand off. → §Plan-handoff
- **Farm** — agent designs, agent implements. You want nothing from the task; you gate and review. → §Farm
- **Practice** — agent designs, you implement. Learn by doing: it directs and reviews, hints never code. A separate skill (`practice`), usable on its own too — hand off to it. Output ships if you want it to.

When unsure, keep cognition (Free / Plan-handoff / Practice over Farm). Cost is asymmetric: keeping cognition you didn't need wastes minutes; shedding cognition you needed erodes the skill — Practice is the one that *builds* it.

## Free — you do it, the agent supports

- No script, no lead. Work hands-on in your own loop (TDD: test → implement → refactor, small chunks).
- Agent is **support only**: lookups, references, a second opinion, typing you direct. It does NOT investigate ahead, quiz you, or write the change.
- Want teaching mid-stream? Pull in **investigate**/**learn** yourself — your call.
- Optional fresh-context review when green: `/code-review`, `/verify`.

## Plan-handoff — you design, the agent builds

You hold the pen through understanding and planning; the agent takes over only once you've proven the plan.

1. **Learn it yourself.** Socratic — agent leads by questions, withholds answers *and* locations, and does NOT read any prior conclusions/plans that would bias you. You find where to look and reason out the root cause.
2. **You write the plan** — a file, in your own words: what's wrong / what you're building, and the numbered changes. Your artifact, not the agent's.
3. **Agent audits your plan against the code** — falsifies it, flags wrong assumptions. Wrong? Fix it, or drop back to step 1 on that gap. This is the ungameable part: a wrong plan doesn't get built.
4. **Gear switch — you declare it:** "I understand this, go implement." Bounded — name the steps and repos, withhold the commit for your review.
5. **Agent implements autonomously** against your plan.
6. **You review the diff before commit**, plus `/code-review` / `/verify`.

## Farm — the agent does it, you gate it first

For work you want nothing from. The gate must be **ungameable** — no bluffing past it.

1. **State your understanding, unprompted** — how it works, the change, the blast radius. Concrete, checkable claims, not "yeah I get it."
2. **Agent verifies each claim against the code**, not your confidence. No correct-and-continue past a wrong claim.
3. **Wrong, or can't articulate it? STOP — drop to `investigate`/`learn` on that gap.** Being wrong routes you into learning, not past it — that's what makes the gate real.
4. **Only once every claim checks out**, the agent implements. (If what-to-build is itself unsettled, `grilling` first.)
5. **Review the diff against your stated understanding**, plus `/code-review` / `/verify`.
