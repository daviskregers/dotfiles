---
description: Start a piece of work — will you own it, and what do you want out of it; then trace, enumerate, slice, and explain the diff before it commits
---

Entry ritual for starting a piece of work. Context: $ARGUMENTS — none? Ask what they're starting on. Ask §0, then run the floor (§1) whatever the answer. Do NOT run ahead to code.

## 0. Two questions, in order

**Will you own this?** Not "is it important" — will it be in a repo you maintain tomorrow. Spike, scratch script, something you'll delete: no. Lands on a branch someone else pulls: yes.

- **No** — nothing below applies. Say what done looks like in one sentence, let the agent run. No trace, no enumeration, no diff explanation.
- **Yes** — the floor (§1) applies whatever you answer next.

Said no and the change ends up staged in a tracked project repo? The claim was wrong: say so, stop, re-enter at §1. The only answer here that can be checked rather than trusted.

**What do you want out of it?** Only asked when you own it. About what you want today, not who's better at the task — answer honestly, "nothing" included. The floor doesn't move, so a cheap answer is safe: it buys you out of designing and typing, never out of the trace or the diff.

- **Nothing** — you want the change to exist. Agent designs and implements. → §2
- **The mechanism** — you want to own it properly. You design, agent implements. → §3
- **The muscle** — you want to have built it. You implement, coached or solo. → §4

## 1. The floor — every answer except "won't own it"

1. **Agent traces the entrypoint to the change site**, one hop at a time, per §Pointing at code. Not the ticket's evidence list — leaves whoever wrote it landed on. You confirm or correct. Cheap, and it's the study material everything below needs.
2. **Agent states what else writes the state being changed** — greps every writer / caller / permission the change touches, one line each on whether it upholds the invariant. Wrong scope is where the real bugs are, and it only surfaces if you enumerate on purpose.
3. **Slices of ≤250 lines, each one red→green.** Sketch them with churn guesses before any code; over the limit = candidate to split. Test-first per slice, no exceptions — see `tdd`.
4. **Before each commit, whoever didn't write the code checks it.** Agent wrote it → you explain that diff back: what it changes, what else touches this state, what breaks if it's wrong. Agent checks each answer against the code, not your confidence; wrong = no commit, drop to `investigate`/`learn` on that gap. You wrote it → `/code-review` against the step-1 trace. Either way: a question about the diff in front of you, never a quiz on the whole system.

## 2. Nothing — agent designs and implements

Runs the floor, nothing else. You state no understanding up front; step 4 is the entire gate. (What-to-build itself unsettled? `grilling` first.)

## 3. The mechanism — you design, agent builds

Between floor steps 2 and 3:

1. **Learn it yourself — run `investigate` (bug) or `learn` (feature), follow its rules verbatim.** Don't paraphrase them here; a paraphrase drifts. Agent does NOT read prior conclusions or plans before you have your own.
2. **You write the plan** — a file, your words: what's wrong / what you're building, numbered changes, churn guess per step, tests included. Your artifact, not the agent's.
3. **Agent audits the plan against the code** — falsifies it, flags wrong assumptions, says which churn guesses look low. Wrong? Fix it, or drop back to step 1 on that gap. A wrong plan doesn't get built.
4. **Gear switch — you declare it:** "I understand this, go implement." Bounded — name the steps and repos, withhold the commit for your review.

## 4. The muscle — you implement

- **Coached** — hand to `practice`: agent directs and reviews, hints never code. Usable on its own too. Output ships if you want it to.
- **Solo** — say what done looks like in one sentence, then work your own loop (TDD: test → implement → refactor, small chunks). Agent is **support only**: lookups, references, second opinion, typing you direct. It does NOT investigate ahead, quiz you, or write the change. Teaching mid-stream? Pull in `investigate`/`learn` yourself.

## 5. Parking is an exit, not a failure

Not landing? Either party can call a park; the agent MUST call it once the same gap has missed twice — never instead decide you're close enough and carry on, which looks like passing and isn't. On a park: write the entrypoint, the agreed trace, what's settled, and the open gap phrased as a question into the findings file, then stop. Nothing implemented, nothing committed. Resume from that file another day. Re-entering the same task by claiming a cheaper answer at §0 is routing around the floor, not exiting it.
