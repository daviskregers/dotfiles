# Global Rules

- Before refactoring any code, ensure the existing behavior is fully covered by tests. Never proceed with a refactor until tests are in place that verify the current functionality is preserved.
- When implementing to make a test pass, write the absolute minimum code necessary — no more than what the test requires.

## When in plan mode

- Break work into small, focused steps — each step should represent a single logical change that can be implemented and verified independently.
- Provide concrete code samples for each step showing the expected changes, not just abstract descriptions.
- Each step should be small enough that it can be reviewed in isolation without needing full context of the entire plan.
- Prefer incremental steps that build on each other over large sweeping changes.
- When a step involves modifying existing code, show both the before and after to make the change clear.
- When a step involves testable behavior, write the tests first and verify they fail before proceeding to the implementation.

## When in build mode

- When implementing to make a test pass, write the absolute minimum code necessary — no more than what the test requires.

