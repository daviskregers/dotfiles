---
description: Generate a visual HTML explanation with diagrams and quizzes for a topic from the current conversation
agent: explainer
---

You are about to generate a visual explanation. Your job is to create a self-contained HTML page that helps the user understand a concept they are struggling with. You must NEVER modify any source code files.

## Input

- **Query**: $1

If `$1` is missing, ask the user what they'd like explained and stop.

## Steps

1. Review the current conversation context to understand what the user has
   been working on and where they are stuck.
2. Focus on the specific query the user provided — do NOT explain
   everything, only what was asked.
3. Generate a self-contained HTML page following the rules below.
4. Use the `save-explanation` tool to save the HTML and open it in the
   browser. Pass a short slug title derived from the query.
5. Tell the user the file path and a one-line summary. Do NOT output the
   HTML in the chat.

## HTML Page Structure

Generate a **single, self-contained HTML file** with all CSS and JS inline. The only external resource allowed is the Mermaid.js CDN for diagrams.

The page MUST include these sections in order:

### 1. Title & Overview

A clear heading and 2-3 sentence summary of what this explanation covers and why it matters.

### 2. Sections (repeat for each logical concept)

Break the topic into as many logical sections as the complexity warrants, each self-contained. For each section:

#### 2a. Explanation

Explain the concept for this section. Use:
- Short paragraphs (2-3 sentences max per point)
- Code snippets in `<pre><code>` blocks where relevant
- Bold key terms on first use
- Callout boxes for important notes or warnings

#### 2b. Visual Diagram (if appropriate)

If a diagram helps illustrate this section, include one immediately after the explanation. Choose the most appropriate diagram type:

- `flowchart TD/LR` — for processes, decision trees, request flows
- `sequenceDiagram` — for interactions between components/services over time
- `stateDiagram-v2` — for state machines and lifecycle
- `classDiagram` — for class/type relationships
- `erDiagram` — for data models and entity relationships

Each diagram must have a descriptive heading above it. Use this pattern:

```html
<pre class="mermaid">
flowchart TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Action]
    B -->|No| D[Other Action]
</pre>
```

Include **at least one diagram** across the page. Not every section needs one.

#### 2c. Section Quiz

After each section's explanation and diagram, include **1-2 quiz questions** that test understanding of that specific section. The quiz acts as a checkpoint — the user should feel confident answering before moving on.

Mix question types:

- **Single-answer** (radio buttons) — for questions with one correct answer
- **Multiple-answer** (checkboxes) — for "select all that apply" questions

Each question MUST:
- Have a clear question text
- Have 3-4 answer options
- Show feedback when the user clicks "Check Answer":
  - Correct answers turn green with a brief explanation of WHY it's correct
  - Wrong answers turn red with an explanation of WHY it's wrong and what the correct answer is
- Work entirely client-side with no external dependencies

Use this HTML/JS pattern for quizzes:

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

For multiple-answer questions, use `data-correct="a,c"` and checkbox inputs.

### 3. Summary

A brief recap of the key takeaways (3-5 bullet points).

## Styling Requirements

Use a dark theme design:

- System font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- Max content width: `800px`, centered
- Dark background (`#1a1a2e` or similar), light text (`#e0e0e0`)
- Generous whitespace and line-height (1.6+)
- Code blocks with a slightly lighter dark background (`#16213e`)
- Mermaid diagrams centered with a dark-compatible background
- Links in a visible accent color (e.g. `#64b5f6`)
- Quiz styling:
  - Questions in bordered cards with subtle dark borders
  - Feedback hidden by default, shown on check
  - Green (`#4caf50`) for correct, red (`#ef5350`) for wrong
  - Smooth reveal animation
- Responsive — readable on mobile

## Mermaid.js Integration

Include this in the `<head>`:

```html
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>mermaid.initialize({ startOnLoad: true, theme: 'dark' });</script>
```
