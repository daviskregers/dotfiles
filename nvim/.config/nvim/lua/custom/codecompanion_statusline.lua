local M = {}
local state = {}    -- [bufnr] = { model, tokens_est }
local last_bufnr = nil

M.setup = function()
  local group = vim.api.nvim_create_augroup("CodeCompanionStatusline", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatModel",
    callback = function(ev)
      local d = ev.data
      if not (d and d.bufnr) then return end
      state[d.bufnr] = state[d.bufnr] or {}
      if d.model then
        state[d.bufnr].model = d.model
        last_bufnr = d.bufnr
      end
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatDone",
    callback = function(ev)
      local d = ev.data
      if not (d and d.bufnr) then return end
      last_bufnr = d.bufnr
      local ok, Chat = pcall(require, "codecompanion.interactions.chat")
      if not ok then return end
      local chat = Chat.buf_get_chat(d.bufnr)
      if not chat then return end
      state[d.bufnr] = state[d.bufnr] or {}
      state[d.bufnr].tokens_est = require("codecompanion.utils.tokens").get_tokens(chat.messages)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatClosed",
    callback = function(ev)
      local d = ev.data
      if not (d and d.bufnr) then return end
      state[d.bufnr] = nil
      if last_bufnr == d.bufnr then
        last_bufnr = next(state)
      end
    end,
  })
end

local function shorten_model(id)
  if not id or id == "" or id == "default" then return id end
  -- strip "claude-" prefix and date suffix like "-20251001"
  local s = id:gsub("^claude%-", ""):gsub("%-%d%d%d%d%d%d%d%d$", "")
  return s:sub(1, 1):upper() .. s:sub(2)
end

local function fmt_tokens(n)
  if n >= 1000000 then return string.format("%.1fM", n / 1000000)
  elseif n >= 1000 then return string.format("%.0fk", math.floor(n / 1000))
  end
  return tostring(n)
end

M.get = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local s = state[bufnr] or (last_bufnr and state[last_bufnr])
  if not s then return "" end

  local parts = {}
  if s.model then
    parts[#parts + 1] = "[" .. shorten_model(s.model) .. "]"
  end
  if s.tokens_est and s.tokens_est > 0 then
    parts[#parts + 1] = "~" .. fmt_tokens(s.tokens_est)
  end
  if #parts == 0 then return "" end
  return table.concat(parts, " ")
end

return M
