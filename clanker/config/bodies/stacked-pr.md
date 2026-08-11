Open a PR targeting the branch the current branch was stacked on — not the repo default.

Invoke the **create_stacked_pr** tool. Base override: {{.Args}} — if a branch name is given, pass it as the tool's `base`; otherwise let the tool detect the parent (closest-ancestor by merge-base). The tool pushes the current branch, verifies the base is on the remote, stamps AI attribution, and creates the PR. Relay the PR URL it returns; if it reports an ambiguous or undetectable parent, ask the user for the base and re-invoke with it.
