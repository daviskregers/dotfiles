Open a tmux window with nvim in each directory an agent worked in, so you can review the changes without leaving the session.

Targets: {{.Args}} — if paths are given, use them verbatim. Otherwise infer the distinct directories the subagents / workflow agents in THIS session were dispatched to work on (e.g. you sent one to `../frontend`). Can't tell which? Ask; don't guess.

Dedupe, then call **open_nvim_window** once per distinct directory (the calls run concurrently). It resolves the path, opens a detached tmux window (no focus steal), and reports what it opened — relay that. If it errors (not in tmux, path missing), surface the message.
