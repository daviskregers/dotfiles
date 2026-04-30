---
description: Analyze Claude Code usage patterns, strengths, and improvement areas
---

Generate HTML usage report with charts, scores, and recommendations.

## Step 1: Gather data

Run: `python3 ~/.claude/scripts/usage-stats.py $ARGUMENTS`

$ARGUMENTS = optional number of days (e.g. `7`, `30`). Empty = all history.

## Step 2: Check previous reports

Check `.ai-artifacts/usage-report-*.html` for prior reports. If found, read most recent — compare trends in Step 3.

## Step 3: Generate HTML report

Build self-contained HTML file. All CSS/JS inline. Use Chart.js CDN for charts.

### Required sections

1. **Header** — title "Claude Code Usage Report", date range, generation timestamp.

2. **Overview Cards** — grid of stat cards: total prompts, sessions, active days, avg prompts/day, avg prompts/session. Color-coded.

3. **Activity Charts**
   - Daily activity bar chart (Chart.js)
   - Day of week bar chart
   - Peak hours bar chart
   - Project distribution doughnut chart

4. **Workflow Analysis**
   - Task categories horizontal bar chart
   - Slash command usage table with counts and percentages
   - Commands per project breakdown table
   - Session size distribution

5. **Prompt Quality Metrics**
   - Prompt length distribution (pie chart: short/medium/long/very long)
   - Correction rate gauge/indicator
   - Pasted content usage rate
   - Top short responses table

6. **Score Card** — radar chart + detailed per-aspect cards. Rate 1-5 each:
   - **Prompt Precision**: correction rate, prompt lengths, specificity
   - **Tooling Sophistication**: slash command variety, custom commands, plugins
   - **Workflow Efficiency**: commit patterns, command usage, task focus
   - **Session Management**: session size distribution, throwaway vs productive
   - **Context Quality**: pasted content usage, prompt detail level

   Each aspect card MUST contain:
   - Score (1-5) with color coding (1=red, 2=orange, 3=yellow, 4=green, 5=bright green)
   - **Strengths**: 2-3 bullet points — what data shows user does well in this aspect
   - **Weaknesses**: 2-3 bullet points — what data shows needs improvement
   - **Key metric**: primary number driving score
   - Score rationale: one sentence explaining why this score, not higher/lower

7. **Overall Strengths** — top 4-6 cross-cutting strengths derived from all data.

8. **Improvement Areas** — top 4-6 concrete, actionable suggestions. Prioritized. Each with: problem statement, supporting data, specific action to take.

9. **Trends** — if previous report exists, show comparison table: metric, previous value, current value, delta, direction arrow. If no previous report, show target metrics for next report.

### Format consistency

Report MUST follow identical section order, headings, chart types, and table structures every run. This ensures trend comparison works. Never skip sections. Never reorder. If data is missing for a section, show "No data" placeholder — don't omit section.

### Styling

Dark theme: bg `#0f0f23`, cards `#1a1a2e`, text `#e0e0e0`, accents `#64b5f6` / `#4caf50` / `#ff7043`. Max 1000px centered. Responsive grid. Smooth shadows. Score card: color-coded 1-5 (red→yellow→green).

### Chart.js

```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
```

## Step 4: Save report

Write HTML to `.ai-artifacts/usage-report-{YYYY-MM-DD}.html`.
Chat output: file path + one-line summary only. No HTML in chat.
