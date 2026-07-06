-- Floating single-line input. Robust vs background agent callbacks that interrupt
-- the cmdline-based vim.ui.input (which delivered nil mid-stream). Returns
-- { buf, win, submit, cancel } so callers — and tests — can drive it.
local M = {}

-- `@` trigger: pick a repo file and insert `@<relpath> ` at the cursor (the agent
-- reads referenced files). Falls back to a literal `@` if telescope is absent.
local function pick_file_insert()
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then return vim.api.nvim_put({ "@" }, "c", true, true) end
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  builtin.find_files({
    prompt_title = "@ file reference",
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        if entry then
          vim.api.nvim_put({ "@" .. vim.fn.fnamemodify(entry.path or entry.value, ":.") .. " " }, "c", true, true)
        end
        vim.cmd("startinsert")
      end)
      return true
    end,
  })
end

function M.prompt(title, on_submit)
  local origin = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.") -- file you're in, before the scratch buf
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  local w = math.max(40, math.floor(vim.o.columns * 0.5))
  local hint = origin ~= "" and "  @ file · ^F current " or "  @ file "
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = 1,
    row = math.floor(vim.o.lines / 2), col = math.floor((vim.o.columns - w) / 2),
    style = "minimal", border = "rounded", title = " " .. title .. hint, title_pos = "center",
  })
  vim.cmd("startinsert")
  local done = false
  local function finish(submit)
    if done then return end
    done = true
    vim.cmd("stopinsert") -- leave insert so downstream views open in normal mode
    local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] or ""
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if submit and text ~= "" then on_submit(text) end
  end
  local h = { buf = buf, win = win }
  h.submit = function() finish(true) end
  h.cancel = function() finish(false) end
  vim.keymap.set({ "i", "n" }, "<CR>", h.submit, { buffer = buf, nowait = true })
  vim.keymap.set({ "i", "n" }, "<Esc>", h.cancel, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", h.cancel, { buffer = buf, nowait = true })
  vim.keymap.set("i", "@", pick_file_insert, { buffer = buf, desc = "@ file reference" })
  if origin ~= "" then
    -- <C-f> not '%' — '%' collides with normal text (e.g. "95%").
    vim.keymap.set("i", "<C-f>", function() vim.api.nvim_put({ "@" .. origin .. " " }, "c", true, true) end,
      { buffer = buf, desc = "@ current file" })
  end
  return h
end

return M
