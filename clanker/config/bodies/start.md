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

- **Say what done looks like, one sentence, before you start.** There's no plan here to size, so this is the only thing between flow and a sprawl you can't review at the end.
- No script, no lead. Work hands-on in your own loop (TDD: test → implement → refactor, small chunks).
- Agent is **support only**: lookups, references, a second opinion, typing you direct. It does NOT investigate ahead, quiz you, or write the change.
- Want teaching mid-stream? Pull in **investigate**/**learn** yourself — your call.
- Optional fresh-context review when green: `/code-review`, `/verify`.

## Plan-handoff — you design, the agent builds

You hold the pen through understanding and planning; the agent takes over only once you've proven the plan.

1. **Learn it yourself — run `investigate` (bug) or `learn` (feature) and follow its rules verbatim.** Don't paraphrase them here; a paraphrase drifts. In particular: point at where to look and ask what you see — withhold the *verdict*, never the coordinates. Agent does NOT read prior conclusions/plans before you have your own.
2. **Anchor on the entrypoint before any hypothesis.** A stack trace hands it to you; a ticket, video or screenshot does not. If the artifact isn't a trace, the first job is recovering what you actually touched — URL (the port says which app/repo), button, command, endpoint. Agree the anchor and the repo before a single question about mechanism.
3. **Enumerate the writers.** Once the mutated field or state is known, grep every writer and check each against the invariant. "N call sites, one missing the hook" only surfaces if you enumerate on purpose.
4. **You write the plan** — a file, in your own words: what's wrong / what you're building, and the numbered changes. Your artifact, not the agent's. Put a rough churn guess on each step, tests included, and mark any step over ~__CHURN_LIMIT__ lines as a candidate to split. It's a guess, not a gate — the point is seeing where the handbacks fall before you start.
5. **Agent audits your plan against the code** — falsifies it, flags wrong assumptions, says which churn guesses look low. Wrong? Fix it, or drop back to step 1 on that gap. This is the ungameable part: a wrong plan doesn't get built.
6. **Gear switch — you declare it:** "I understand this, go implement." Bounded — name the steps and repos, withhold the commit for your review.
7. **Agent implements autonomously** against your plan.
8. **You review the diff before commit**, plus `/code-review` / `/verify`.

## Farm — the agent does it, you gate it first

For work you want nothing from. The gate must be **ungameable** — no bluffing past it. But it can only ask for what a person can hold in their head: mechanism, never counts. "State the blast radius unprompted" has no right answer without a grep, so it fails everyone every time and teaches you to avoid the lane instead of passing it.

1. **Agent traces the entrypoint to the change site first**, one hop at a time, per §Pointing at code — no leaf coordinates, no ticket's evidence list as a starting point. You confirm or correct the trace. This is study material, not the gate.
2. **You state the mechanism in your own words** before the agent says anything about the change: how the flow works from that entrypoint, and what the change does to it. Concrete, checkable claims, not "yeah I get it."
3. **Agent verifies each claim against the code**, not your confidence. No correct-and-continue past a wrong claim.
4. **Agent enumerates, you judge — this is the real gate.** It greps every writer / caller / permission the change touches and hands you the list. For each entry you say whether it upholds the invariant and why; the agent checks each answer against the code. "Looks fine" is not an answer. Step 2 is parrotable after step 1; this is not.
5. **Wrong, or can't articulate it? STOP — drop to `investigate`/`learn` on that gap.** Being wrong routes you into learning, not past it — that's what makes the gate real.
6. **Only once every claim checks out**, the agent implements — sketching the slices and their rough churn first, flagging any over ~__CHURN_LIMIT__ lines. (If what-to-build is itself unsettled, `grilling` first.)
7. **Review the diff against your stated understanding**, plus `/code-review` / `/verify`.

**Parking is the second exit, and it is not a failure.** The gate has exactly two ways out: pass it, or park it. You can call the park any time. The agent MUST call it once the same gap has missed twice — and must never instead decide the claims are straight enough and design anyway, which looks like passing and isn't. On a park: write the entrypoint, the agreed trace, which claims checked out, and the open gap phrased as a question into the findings file, then stop. Nothing gets implemented, nothing gets committed. Resume from that file another day. Re-entering the same task through Free is routing around the gate, not exiting it.
