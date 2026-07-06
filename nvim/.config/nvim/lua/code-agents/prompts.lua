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
    "Make the following change to this repository. Edit files directly with your",
    "Write/Edit tools (each edit will be approved in the editor). Be surgical —",
    "change only what the task requires.",
    "",
    "Task: " .. (task or ""),
    context or "",
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
