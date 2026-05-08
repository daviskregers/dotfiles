return {
  {
    dir = vim.fn.stdpath("config") .. "/lua/custom",
    name = "review-notes",
    config = function()
      local rn = require("custom.review-notes")
      rn.setup({
        context_radius = 3,
        export_dir = ".dk-notes/reviews",
        sign_text = "RN",
      })

      rn.load_from_disk()

      local function with_context(fn)
        return function()
          local ctx = rn.resolve_buffer_context(0)
          if not ctx then
            vim.notify("Not a reviewable buffer", vim.log.levels.WARN)
            return
          end
          fn(ctx)
        end
      end

      vim.keymap.set("n", "<leader>ra", with_context(function(ctx)
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local buf = vim.api.nvim_get_current_buf()
        local before, target, after = rn.get_context_lines(buf, line, line, 3)
        local preview = {}
        for _, l in ipairs(before) do table.insert(preview, l) end
        table.insert(preview, ">>> " .. target[1])
        for _, l in ipairs(after) do table.insert(preview, l) end

        rn.open_comment_float({
          preview_lines = preview,
          on_confirm = function(text)
            rn.add_note({
              bufnr = buf, file = ctx.file, side = ctx.side,
              start_line = line, end_line = line, text = text,
            })
            rn.refresh_extmarks(buf, ctx.file, ctx.side)
          end,
        })
      end), { desc = "Review: add note" })

      vim.keymap.set("v", "<leader>ra", function()
        -- Capture visual range before exiting visual mode
        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end
        -- Exit visual mode so float can open cleanly
        vim.cmd("normal! \\<Esc>")
        local ctx = rn.resolve_buffer_context(0)
        if not ctx then
          vim.notify("Not a reviewable buffer", vim.log.levels.WARN)
          return
        end
        local buf = vim.api.nvim_get_current_buf()
        local before, target, after = rn.get_context_lines(buf, start_line, end_line, 3)
        local preview = {}
        for _, l in ipairs(before) do table.insert(preview, l) end
        for _, l in ipairs(target) do table.insert(preview, ">>> " .. l) end
        for _, l in ipairs(after) do table.insert(preview, l) end

        rn.open_comment_float({
          preview_lines = preview,
          on_confirm = function(text)
            rn.add_note({
              bufnr = buf, file = ctx.file, side = ctx.side,
              start_line = start_line, end_line = end_line, text = text,
            })
            rn.refresh_extmarks(buf, ctx.file, ctx.side)
          end,
        })
      end, { desc = "Review: add note (range)" })

      vim.keymap.set("n", "<leader>rd", with_context(function(ctx)
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local note = rn.get_note_at_line(ctx.file, line, ctx.side)
        if note then
          rn.delete_note(note.id)
          rn.refresh_extmarks(vim.api.nvim_get_current_buf(), ctx.file, ctx.side)
        else
          vim.notify("No note at cursor", vim.log.levels.INFO)
        end
      end), { desc = "Review: delete note" })

      vim.keymap.set("n", "<leader>ri", with_context(function(ctx)
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local note = rn.get_note_at_line(ctx.file, line, ctx.side)
        if not note then
          vim.notify("No note at cursor", vim.log.levels.INFO)
          return
        end
        rn.open_comment_float({
          preview_lines = note.context_line,
          initial_text = note.text,
          on_confirm = function(text)
            rn.edit_note(note.id, text)
            rn.refresh_extmarks(vim.api.nvim_get_current_buf(), ctx.file, ctx.side)
          end,
        })
      end), { desc = "Review: edit note" })

      vim.keymap.set("n", "<leader>rn", function()
        local notes = rn.get_notes()
        if #notes == 0 then
          vim.notify("No review notes", vim.log.levels.INFO)
          return
        end
        local ok, telescope = pcall(require, "telescope.pickers")
        if ok then
          local finders = require("telescope.finders")
          local conf = require("telescope.config").values
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          telescope.new({}, {
            prompt_title = "Review Notes",
            finder = finders.new_table({
              results = notes,
              entry_maker = function(note)
                local display = string.format("[%s] %s:%d — %s", note.side, note.file, note.start_line, note.text:sub(1, 60))
                return { value = note, display = display, ordinal = display, filename = note.file, lnum = note.start_line }
              end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                if entry then
                  rn.goto_note(entry.value)
                end
              end)
              return true
            end,
          }):find()
        else
          local items = {}
          local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
          for _, note in ipairs(notes) do
            table.insert(items, {
              filename = git_root .. "/" .. note.file,
              lnum = note.start_line,
              col = 1,
              text = string.format("[%s] %s", note.side, note.text:sub(1, 80)),
            })
          end
          vim.fn.setqflist({}, "r", { title = "Review Notes", items = items })
          vim.cmd("copen")
        end
      end, { desc = "Review: list notes" })

      vim.keymap.set("n", "<leader>rw", function() rn.export({ keep = false }) end, { desc = "Review: export & clear" })
      vim.keymap.set("n", "<leader>rW", function() rn.export({ keep = true }) end, { desc = "Review: export & keep" })
      vim.keymap.set("n", "<leader>rx", function()
        vim.ui.select({ "Yes", "No" }, { prompt = "Clear all review notes?" }, function(choice)
          if choice == "Yes" then rn.clear_all() end
        end)
      end, { desc = "Review: clear all" })


      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(ev)
          local ctx = rn.resolve_buffer_context(ev.buf)
          if ctx then rn.refresh_extmarks(ev.buf, ctx.file, ctx.side) end
        end,
      })
    end,
  },
}
