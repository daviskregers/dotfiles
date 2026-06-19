-- Compose a message to a background agent in a float. `@` (or <C-f>) opens a
-- telescope file picker and inserts an `@<relpath>` reference at the cursor —
-- the path stays valid inside the agent's worktree. `:w` sends, `:q` cancels
-- (mirrors review-notes' comment float).

local M = {}

-- Insert text at the cursor in the current window, leaving the cursor after it.
local function put_at_cursor(text)
  vim.api.nvim_put({ text }, "c", true, true)
end

-- Open telescope find_files; insert `@<relpath> ` for the chosen file.
local function pick_file_insert()
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then return vim.notify("telescope unavailable", vim.log.levels.WARN) end
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  builtin.find_files({
    prompt_title = "Insert @file reference",
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)               -- focus returns to the compose float
        if entry then
          local rel = vim.fn.fnamemodify(entry.path or entry.value, ":.")
          put_at_cursor("@" .. rel .. " ")
        end
        vim.cmd("startinsert")
      end)
      return true
    end,
  })
end

function M.compose(agent, on_send)
  local width = math.min(80, math.floor(vim.o.columns * 0.6))
  local height = math.max(8, math.floor(vim.o.lines * 0.4))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "wt-chat://" .. agent.id .. "/" .. tostring(buf))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal", border = "rounded",
    title = " chat → " .. agent.id .. "   (@ file · :w send · :q cancel) ",
    title_pos = "center",
  })
  vim.cmd("startinsert!")

  local closed = false
  local function finish(send)
    if closed then return end
    closed = true
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if send and text ~= "" then on_send(text) end
  end

  -- `@` is a trigger (not a literal) — opens the file picker. <C-f> too.
  vim.keymap.set({ "i", "n" }, "@", pick_file_insert, { buffer = buf, desc = "Insert @file" })
  vim.keymap.set("i", "<C-f>", pick_file_insert, { buffer = buf, desc = "Insert @file" })

  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = function() finish(true) end })
  vim.api.nvim_create_autocmd({ "BufUnload", "QuitPre" }, {
    buffer = buf, once = true, callback = function() finish(false) end,
  })
end

return M
