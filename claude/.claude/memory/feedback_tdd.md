---
name: TDD approach preferred
description: Global rule — all changes via TDD: failing test first, then implement. Bugs reproduced with test before fix. All projects/languages. Plans must be TDD-structured.
type: feedback
---

Always use TDD workflow. No exceptions.

**Why:** User wants every change driven by tests — features AND bugs. Explicit global rule, not project-specific.

**How to apply:**
- New feature: write failing test → run it, confirm failure → implement → run test, confirm pass.
- Bug fix: write test that reproduces bug → run it, confirm failure → fix implementation → run test, confirm pass.
- Planning mode: structure all plans around TDD steps — each task should specify what test to write first, expected failure, then implementation.
- Apply across all projects and languages.
