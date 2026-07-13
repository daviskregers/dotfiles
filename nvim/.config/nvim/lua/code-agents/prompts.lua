-- Prompt builders for code-agents read verbs. Pure + tested. The search prompt
-- is a contract with core.parse_search_results — it MUST dictate the exact
-- `path:line:col: reason` line shape the parser consumes.

local M = {}

function M.search(question)
  return table.concat({
    "Search this repository to answer the question below.",
    "Return ONLY matching locations, one per line, in the exact format:",
    "  path:line:col: reason",
    "Paths relative to repo root. No prose, no preamble, no code fences.",
    "Prefer ripgrep (`rg`) for searching.",
    "",
    "Question: " .. (question or ""),
  }, "\n")
end

function M.ask(question, context)
  return table.concat({
    "Answer this question about the repository. Be brief — lead with the answer,",
    "no preamble. Cite your sources as path:line for each claim you make.",
    "",
    "Question: " .. (question or ""),
    context or "",
  }, "\n")
end

function M.command(task, context)
  return table.concat({
    "Make the following change to this repository, editing files directly with",
    "your Write/Edit tools (edits are reviewed before they merge to the working",
    "tree). You're an autonomous background agent: work without pausing to ask",
    "for confirmation or feedback, and end with a one- or two-sentence summary —",
    "the diff is the record.",
    "",
    "Work surgically:",
    "- Prefer the Read/Grep/Glob tools over bash (grep/cat/find) and worktree-",
    "  relative paths — those run without approval. Bash that mutates, runs outside",
    "  the worktree, or isn't a plain read stalls waiting for me, so avoid it unless",
    "  the task needs it. Read a whole file in one call, not ranges; batch reads.",
    "- Change only what the task needs — no abstractions, helpers, or error",
    "  handling that weren't asked for. Tests for the change are part of it, not",
    "  extra.",
    "",
    "Task: " .. (task or ""),
    context or "",
  }, "\n")
end

-- Prepend the session focus/goal as a block above `prompt`. Pure. Returns
-- `prompt` unchanged when focus is nil/empty/whitespace — so the empty-focus
-- path is byte-identical to today. Sits above search's parser-contract format
-- instructions and introduces no `path:line:col`-shaped lines.
function M.inject_focus(prompt, focus)
  if not focus or vim.trim(focus) == "" then return prompt end
  return table.concat({
    "Session focus (applies to this task):",
    vim.trim(focus),
    "",
    prompt or "",
  }, "\n")
end

function M.explain(selection, fname, sl, el)
  local header = string.format("%s:%d-%d", fname, sl, el)
  return table.concat({
    "Explain the following code at one abstraction below — what it does,",
    "complexity, cost, side effects, what the runtime actually does.",
    "Be brief: lead with the answer, no preamble, no restating the code.",
    "",
    header,
    "```",
    selection or "",
    "```",
  }, "\n")
end

return M
