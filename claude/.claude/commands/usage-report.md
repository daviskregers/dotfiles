---
description: Analyze prompt effectiveness, teach improvements with real examples and quizzes
---

Generate HTML effectiveness report — review + coaching + quizzes using real prompt history.

## Step 1: Gather data

Run: `python3 ~/.claude/scripts/usage-stats.py $ARGUMENTS`

$ARGUMENTS = optional number of days (e.g. `7`, `30`). Empty = all history.

## Step 2: Check previous reports

Check `.dk-notes/ai/usage-report-*.html` for prior reports. If found, read most recent — extract trends_data for comparison in Step 3.

## Step 3: Generate HTML report

Self-contained HTML. All CSS/JS inline. Chart.js CDN for charts.

### Required sections (strict order, never skip, never reorder)

1. **Header** — "Claude Code Effectiveness Report", period, tasks analyzed, commits count.

2. **Effectiveness Dashboard** — 4 metric cards:
   - One-shot Rate (% tasks completed in ≤1 directive + 0 corrections)
   - Efficiency Ratio (commits per 10 prompts)
   - Context Score (% initiating prompts with file paths/pasted/code)
   - Methodology Score (avg of TDD + review + spec rates)
   Green >60%, yellow 30-60%, red <30%.

3. **Prompt Effectiveness** — charts:
   - Specificity distribution horizontal stacked bar (vague|moderate|specific|exemplary)
   - Task size distribution bar chart (1, 2-3, 4-6, 7-10, 10+ prompts per task)
   - Correction density gauge
   - Back-and-forth ratio indicator

4. **Your Best Prompts** — top 3-5 from `prompt_exemplars.best`. For each:
   - Full prompt text in styled blockquote
   - Green badge: specificity score + bucket
   - "Why this worked" — explain which signals present (file paths, structure, criteria, etc.)
   - Outcome: "N prompts, 0 corrections"
   
5. **Improvement Opportunities** — top 3-5 from `prompt_exemplars.worst`. For each:
   - Original prompt in styled blockquote
   - Red/orange badge: specificity score + bucket
   - If `is_cold_start: false`: show disclaimer — "Mid-session prompt — likely had conversational context that makes this appropriate. Shown here as a teaching example of how to make directives self-contained."
   - "What was missing" — list absent signals
   - **"Rewritten version"** — YOU rewrite the prompt applying missing techniques. Show the improved version in a green-bordered blockquote. Explain step by step what changed and why.
   - Reusable pattern/template derived from the rewrite
   
   **Disclaimer at section top**: "Limitation: history.jsonl only stores your prompts, not Claude's responses. Mid-session prompts may be perfectly clear in context. These are shown as teaching examples for the pattern, not as criticism."
   
   If `prompt_exemplars.worst` is empty: show "No under-specified cold-start prompts found — your session openers are well-structured." and skip the rewrite cards.

6. **Anti-Pattern Analysis** — table: pattern name, count, description, concrete fix.

7. **Methodology Assessment** — 3 gauges with coaching:
   - TDD Adherence — rate + "How to use: start tasks with 'Write a failing test for...'"
   - Review Discipline — rate + "Run /code-review before every /commit"
   - Spec-Driven Rate — rate + show spec template

8. **Score Card** — radar chart + 5 detail cards, each with strengths + weaknesses:
   - **Prompt Specificity** (key: specificity distribution)
   - **Context Provision** (key: context_provision_score)
   - **Methodology** (key: composite TDD + review + spec)
   - **Efficiency** (key: efficiency_ratio + one_shot_rate)
   - **Growth** (key: delta from previous report, or "Baseline" if first)

9. **Dynamic Recommendations** — top 3 from `recommendations`. Each rendered as teaching tutorial:
   - Pick a real prompt from worst_prompts or anti-pattern examples
   - Show original prompt
   - Show rewritten version applying the recommended technique
   - Step-by-step explanation of what changed and why
   - Reusable template/pattern
   For command recommendations: show scenario where command helps, walk through usage.

10. **Quizzes** — 2-3 interactive quizzes after teaching sections. Same mechanics as /explain HTML (radio/checkbox, green correct, red wrong + explanation). Types:
    - "Improve this prompt" — show weak prompt, 3-4 rewrite options (one correct), explain each
    - "What's missing?" — show prompt, checkbox for missing elements (file path? criteria? constraints?)
    - "Which command?" — describe scenario, pick best slash command
    All content from user's actual history. JS handles check/reveal.

11. **Per-Project Breakdown** — from `per_project`. Table: project, impl tasks, commits, vague%, avg specificity, one-shot rate, review rate. Color-code cells. Highlight best/worst project. Skip projects with <3 impl tasks.

12. **Workflow Highlights** — celebrate strong habits:
    - /comment workflow: count + explain why it's effective (review investigation → fix → commit is a mature pattern)
    - Review discipline: rate + breakdown of signals (/code-review, /comment, artifact refs)
    - Slash command table (de-emphasized)

13. **Within-Period Trends** — from `period_halves`. Compare first half vs second half: prompts, tasks, commits, one-shot rate, avg specificity, review rate. Show improvement/regression arrows. Even without prior report, reveals natural learning within the period.

14. **Trends** — if previous report: comparison table (metric, previous, current, delta, arrow). If first: target values table.

### Format consistency

Identical section order, headings, chart types every run. Never skip sections. "No data" placeholder if empty.

### Teaching rules

NEVER say "you should do X." Always show HOW with real examples from their history. Every recommendation = original prompt → rewritten prompt → step-by-step explanation → reusable pattern.

### Styling

Dark theme: bg `#0f0f23`, cards `#1a1a2e`, text `#e0e0e0`, accents `#64b5f6` / `#4caf50` / `#ff7043`. Max 1000px centered. Responsive grid. Smooth shadows. Score cards: color-coded 1-5 (red→yellow→green). Blockquotes: left border colored by quality (green=good, orange=weak, blue=rewrite). Quiz: bordered cards, green correct, red wrong + explanation.

### Chart.js

```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
```

## Step 4: Save report

Write HTML to `.dk-notes/ai/usage-report-{YYYY-MM-DD}.html`.
Chat output: file path + one-line summary only. No HTML in chat.
