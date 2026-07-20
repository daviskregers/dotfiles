Pipeline: local review → verify → pause → commit → push → draft PR → Copilot → PR-comment triage.
`--no-review` skips review + verify + PR-comment phases (plain commit → push → PR → Copilot).

## Input

Target base branch (+ optional `--ready`, `--no-review`, title/context): {{.Args}} — no base given? Ask.
Load `git-commit` (commit message) + `driver-gate` (triage loop, Phases A & D) + `probe` (Phase A2 verify).

## Phase A — Local review (pre-commit; skip if `--no-review`)

1. Review the **working tree** (`git diff` + `git diff --cached`; both empty → last commit): spawn `code-review-analysis` agent → structured findings. Then run the `driver-gate` **triage loop** over them: per finding, triage (trivial → fast; load-bearing → show anchors, **withhold AI verdict, user commits their read + why first**, reveal + challenge symmetrically) → **STOP** → fix (TDD) / skip via `SKIP:`. Don't commit here — that's Phase C.

## Phase A2 — Verify (probe triage; skip if `--no-review`)

Run the `probe` skill **triage** over the changeset → eyes-on ACs (integrations, uploads/imports, rendering, auth boundaries, migrations). For each: AI preps (env, seed, fixtures, ready `.http`/deep-link) but **withholds its expected result**; **you predict, run, and judge** — never AI self-certifying. Confirmed → ✅; not run → `UNVERIFIED: <reason>`. Green-safe ACs recorded as such. Build the **verification ledger** (each eyes-on AC: ✅ verified / ⚠️ UNVERIFIED) — carried into the PR body in Phase C. Mismatch → TDD fix before proceeding.

## Phase B — Validate (pause)

2. Summarize: changed files, findings handled, what's staged vs unstaged.
   **STOP. Wait for user to stage what they want and confirm it's commit-worthy.** Do not commit before this.

## Phase C — Ship

3. **Commit** (staged-only, main session — never spawn a subagent to commit):
   - `git diff --cached --stat`. Staged → conventional message per `git-commit`, `git commit`.
   - Nothing staged but branch has unpushed commits → skip to push. Nothing at all → stop: "Nothing to ship."
4. **Push**: `git push -u origin $(git branch --show-current)`. Never force-push.
5. **PR**: branch already has a PR? (`gh pr view --json url,number`) → reuse. Else `gh pr create --base <BASE> --draft --title WIP --body _pending_`. **`--ready` gate:** drop `--draft` (or ready an existing PR) ONLY if the verify phase ran (A2) AND no eyes-on AC is `UNVERIFIED`. Zero eyes-on ACs (triage honestly found all green-safe) may ready — but the PR body must state "no eyes-on ACs — all green-safe" so the absence is visible, not silent. `--ready` + `--no-review` (A2 skipped, no ledger) → CANNOT auto-ready: keep draft, tell the user to run verification first. Any UNVERIFIED → keep draft, report which ACs block ready. Ship-to-draft is always allowed. **Then delegate title/body to the `pr-describer` agent** (pass PR URL + the Phase-A2 ledger incl. any UNVERIFIED lines — required whenever A2 ran; under `--no-review` there's no verification section) — it authors title + body (mermaid per `diagram` skill) and includes the **verification ledger** section, via `update_pr_info`. Never write the description inline.
6. **Copilot review**: call `request_copilot_review` with the PR URL.

## Phase D — PR-comment triage (skip if `--no-review`)

7. `wait_for_copilot_review` (PR URL), then `list_pr_comments` → queue of Copilot + human/existing comments.
8. **Triage + close** per `/comments` Phases 2–4: one-at-a-time fix with a per-fix user-reviewed commit → single `git push` → reply + resolve each thread. Triage does NOT change the PR's ready/draft state (whatever Phase C set stands).
9. **Report**: findings/comments handled, fixed/skipped, PR URL, and the PR's actual state (draft or ready). 1–2 lines.

## Rules

- Base branch is explicit (arg) — if missing, ask; never guess.
- Local review happens BEFORE commit; always pause (Phase B) for user validation before committing.
- Staged-only commit. Don't stage extra files.
- Triage is one-at-a-time (driver-gate) — never batch verdicts; load-bearing items withhold AI's verdict until the user commits their read.
- Verification: AI preps probes, user runs + judges — AI never self-certifies an eyes-on AC. `--ready` is gated on zero UNVERIFIED eyes-on ACs; ship-to-draft is never blocked. Never auto-ready otherwise.
- Halt the chain on any step failure (commit hook, push reject, PR error); report + stop, don't retry blindly.
