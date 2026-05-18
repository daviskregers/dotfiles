---
description: Research a hypothesis — find evidence both for and against, papers first
---

Research hypothesis from both sides. Find evidence supporting AND contradicting it. User forms own opinion from sources.

Hypothesis: $ARGUMENTS

No hypothesis? Ask user what to investigate.

## Step 1: Decompose hypothesis

Break hypothesis into testable claims. Identify key terms, domain, and searchable angles for both sides.

## Step 2: Search for evidence

Run multiple web searches. Priority order:
1. **Research papers** — search Google Scholar, arXiv, SSRN, ACM, IEEE terms. Use queries like `site:scholar.google.com`, `site:arxiv.org`, `site:ssrn.com`.
2. **Industry reports** — surveys, meta-analyses, industry data
3. **Expert commentary** — blog posts from domain experts, conference talks, credible journalism

For EACH claim, search explicitly for:
- **Supporting evidence** — terms that would confirm the hypothesis
- **Contradicting evidence** — terms that would refute or complicate the hypothesis
- **Nuance** — terms that reveal conditions, caveats, or partial truth

Minimum: 3 searches supporting, 3 searches contradicting, per major claim. More if hypothesis is multi-faceted.

## Step 3: Evaluate sources

For each source found:
- Note author/institution credibility
- Note methodology (if research paper)
- Note sample size, date, limitations
- Flag if behind paywall (still include — user may have access)

Discard: opinion pieces without data, SEO content farms, sources that merely restate the claim without evidence.

## Step 4: Generate HTML report

Self-contained HTML. All CSS inline. Save to `.dk-notes/ai/hypothesis-{YYYY-MM-DD}-{slug}.html` where slug = 2-4 word kebab-case from hypothesis.

### Report structure

1. **Header** — "Hypothesis Research Report", date, hypothesis in blockquote

2. **Hypothesis Breakdown** — decomposed claims as bullet list

3. **Evidence For** — grouped by claim. Each source:
   - Title (linked)
   - Authors / publication / date
   - Key finding (1-3 sentences)
   - Methodology note if research paper
   - Relevance badge: 🔬 Research Paper | 📊 Industry Data | 💬 Expert Commentary

4. **Evidence Against** — same format as above

5. **Nuance & Complications** — evidence that partially supports/refutes, reveals boundary conditions, or reframes the question entirely

6. **Evidence Quality Summary** — table: claim, supporting sources count, contradicting sources count, strongest evidence side, confidence note

7. **Reading List** — all sources ranked by relevance and rigor. Research papers first. Each with one-line reason to read it.

8. **What's Missing** — gaps in available evidence, questions that remain unanswered, suggested further research angles

### Styling

Dark theme: bg `#0f0f23`, cards `#1a1a2e`, text `#e0e0e0`, accents — green `#4caf50` for supporting, red `#ff7043` for contradicting, blue `#64b5f6` for nuance. Max 900px centered. Cards with left border colored by evidence type.

## Step 5: Output

Chat: file path + one-line summary of balance (e.g., "3 papers support, 2 contradict, 1 reframes"). No HTML in chat.
