---
description: Generate a visual HTML explanation with diagrams and quizzes for a topic from the current conversation
agent: explainer
---

Generate visual explanation. Create self-contained HTML page helping user understand concept. NEVER modify source code files.

## Input

- **Query**: $1

`$1` missing? Ask user what to explain and stop.

## Steps

1. Load `caveman` skill. Use **ultra** intensity for all output. Technically accurate but terse.
2. Review conversation context — understand what user working on, where stuck.
3. Focus on specific query — do NOT explain everything.
4. Generate self-contained HTML page per rules below.
5. Use `save-explanation` tool to save HTML. Pass short slug title from query.
6. Tell user file path + one-line summary. Do NOT output HTML in chat.

## HTML Page Structure

Single self-contained HTML file, all CSS/JS inline. Only external resource: Mermaid.js CDN.

Must include these sections in order:

### 1. Title & Overview

Clear heading + 2-3 sentence summary of what/why.

### 2. Sections (repeat per logical concept)

Break topic into logical sections, each self-contained:

#### 2a. Explanation

- Short paragraphs (2-3 sentences max)
- Code snippets in `<pre><code>` blocks
- Bold key terms on first use
- Callout boxes for important notes/warnings

#### 2b. Visual Diagram (if appropriate)

Choose best type: `flowchart TD/LR`, `sequenceDiagram`, `stateDiagram-v2`, `classDiagram`, `erDiagram`.

```html
<pre class="mermaid">
flowchart TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Action]
    B -->|No| D[Other Action]
</pre>
```

At least one diagram across page. Not every section needs one.

#### 2c. Section Quiz

After each section: 1-2 quiz questions testing that section's understanding.

Mix types: single-answer (radio), multiple-answer (checkboxes).

Each question MUST: have clear text, 3-4 options, show feedback on "Check Answer" (green=correct with why, red=wrong with why + correct answer). Client-side only.

```html
<div class="quiz-question" data-correct="b">
    <p class="quiz-prompt">1. What does X do?</p>
    <label class="quiz-option"><input type="radio" name="q1" value="a"> Option A</label>
    <label class="quiz-option"><input type="radio" name="q1" value="b"> Option B</label>
    <label class="quiz-option"><input type="radio" name="q1" value="c"> Option C</label>
    <button class="quiz-check" onclick="checkAnswer(this)">Check Answer</button>
    <div class="quiz-feedback correct">Correct! Option B is right because...</div>
    <div class="quiz-feedback wrong">Not quite. The correct answer is B because...</div>
</div>
```

Multiple-answer: `data-correct="a,c"` + checkbox inputs.

### 3. Summary

3-5 bullet point recap of key takeaways.

## Styling

Dark theme:
- System font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- Max width `800px`, centered
- Dark bg (`#1a1a2e`), light text (`#e0e0e0`)
- Generous whitespace, line-height 1.6+
- Code blocks: slightly lighter dark bg (`#16213e`)
- Mermaid diagrams centered, dark-compatible
- Links: accent color (`#64b5f6`)
- Quiz: bordered cards, hidden feedback shown on check, green (`#4caf50`) correct, red (`#ef5350`) wrong, smooth reveal
- Responsive

## Mermaid.js

```html
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>mermaid.initialize({ startOnLoad: true, theme: 'dark' });</script>
```
