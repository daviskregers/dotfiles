---
description: Capture a random idea — enrich with current context, then append via the capture tool
argument-hint: <the idea / spark>
allowed-tools: Bash(capture:*)
---

Capture a random idea — a spark for something to build/try/explore later. **Capture only**: do NOT build it, plan it, evaluate feasibility, or start a task.

Idea = $ARGUMENTS

1. From the current session + cwd, compose:
   - **title**: ≤6 words, specific.
   - **body**: ≤3 lines, in my voice. State the idea, plus any concrete context you can actually see (what prompted it, where it'd apply). Don't invent or expand the scope — only add context you genuinely have.
2. Append it: run `capture idea -t "<title>" "<body>"`. It writes to the Idea log and errors if the capture dir isn't set — if it errors, surface that output verbatim and stop.
3. Output only the tool's `logged …` line. No summary, no next steps, no offer to build.
