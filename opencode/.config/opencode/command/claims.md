---
description: Test the Predictions you wrote in an issue's notes file — claim 1 as a blind executable test, claim 3 pinned as characterization — then score them
---

Test the Predictions the user wrote in an issue's notes file, so they find out how wrong they were. Notes file: $ARGUMENTS — none? Resolve from cwd: `.dk-notes/<ID>-<slug>/notes.md`, most recently modified. Several candidates → ask which; none → stop, there is nothing to score.

Claims 1 and 3 only. Claim 2 ("who else touches this") is grep/LSP then a fresh agent — a test asserting a caller count tests grep, not the system. Leave its boxes alone and say you skipped it.

## The rule the whole command rests on

Write claim 1's assertion from the user's SENTENCE, before opening the implementation. Read the code first and you write a test that passes by construction — the user learns only that you can read. Order: extract claim → write test → run → THEN read code to explain the result.

Open the session by naming which files you have not opened yet. If you have already read the implementation this session, say so — the blind test is compromised and the score is worth less.

## Arc

1. **Extract.** Read `## Predictions`. Quote claims 1 and 3 back verbatim. Too vague for any assertion to follow ("the flow works", "I understand it") → say so and stop. An untestable claim IS the finding; do not repair it for them.
2. **Claim 1 → executable test.** One named input, one observable. Use the repo's existing framework and conventions — find them, never invent a harness. The test asserts what the USER said, not what is true.
3. **Run it.** Red = claim wrong. Green = claim right. Paste the real output. Never summarise a failure into a sentence.
4. **Claim 3 → characterization test.** Pin the behaviour the claim says would break, as it behaves TODAY. Verifies nothing now — it fires when the change lands. Say that plainly; do not let it read as a third score.
5. **Explain.** Only now open the implementation. Red claim → what actually happens, `path:line`, plus the entrypoint that reaches it. A coordinate with no route in gets ignored.
6. **Write the score.** Rewrite `## Score` in the notes file: verdict per claim, evidence, what the code actually does where the claim missed.

## Boxes are the user's

Never tick a checkbox. Claim 1's box says the user ran it and read the output themselves; you running it does not satisfy that sentence. Report, hand back, let them tick.

## Afterwards

- Delete the claim-1 scratch test — it encodes a guess, not a requirement.
- Characterization test: ask before keeping, offer the path it would live at.
- 2+ claims wrong → say it flat. No working model yet; read the code before handing an agent a large slice.
