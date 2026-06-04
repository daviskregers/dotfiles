---
description: Capture a workflow friction — enrich with current context, then append via the capture tool
---

Capture a workflow friction — something about *how I work* that annoys me but that I'm not fixing now. **Capture only**: do NOT solve, propose fixes, diagnose, or start a task.

Gripe = $ARGUMENTS

1. From the current session + cwd, compose:
   - **title**: ≤6 words, specific.
   - **body**: ≤3 lines, in my voice. State the friction, plus concrete context you can actually see (the file/error/repo/PR/task it surfaced in, why it's friction). Don't invent — only add context you genuinely have.
2. Append it: run `capture friction -t "<title>" "<body>"`. It writes to the Friction log and errors if the capture dir isn't set — if it errors, surface that output verbatim and stop.
3. Output only the tool's `logged …` line. No summary, no next steps, no offer to fix.
