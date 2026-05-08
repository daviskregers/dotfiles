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

      -- ── P4 provider keymaps: load / push / fix-via-agent ─────────────

      local function load_markdown_path(path)
        if not path or path == "" then return end
        path = vim.fn.expand(path)
        local n = rn.load("markdown", path)
        vim.notify(string.format("Loaded %d note(s) from %s", n, path), vim.log.levels.INFO)
      end

      local function prompt_custom_path()
        vim.ui.input({ prompt = "Markdown path: ", default = "~/", completion = "file" }, load_markdown_path)
      end

      local function prompt_pr_ref()
        vim.ui.input({ prompt = "PR URL or #N: " }, function(ref)
          if not ref or ref == "" then return end
          local n = rn.load("pr", ref)
          vim.notify(string.format("Loaded %d comment(s) from %s", n, ref), vim.log.levels.INFO)
        end)
      end

      vim.keymap.set("n", "<leader>rl", function()
        local dir = rn.get_export_dir() or ".dk-notes/reviews"
        if vim.fn.isdirectory(dir) ~= 1 then
          vim.notify(dir .. " not found — choose another source", vim.log.levels.INFO)
          return vim.ui.select(
            { "Custom markdown path", "PR URL or #N" },
            { prompt = "Load notes from:" },
            function(c)
              if c == "Custom markdown path" then prompt_custom_path()
              elseif c == "PR URL or #N" then prompt_pr_ref() end
            end
          )
        end

        local entries = {}
        for name, type in vim.fs.dir(dir, { depth = 10 }) do
          if type == "file" and name:match("%.md$") then
            local path = dir .. "/" .. name
            local stat = vim.uv.fs_stat(path)
            if stat then table.insert(entries, { path = path, name = name, mtime = stat.mtime.sec }) end
          end
        end
        table.sort(entries, function(a, b) return a.mtime > b.mtime end)

        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        local previewers = require("telescope.previewers")

        pickers.new({}, {
          prompt_title = "Review markdown — <CR> load · <C-o> custom path · <C-p> PR",
          finder = finders.new_table({
            results = entries,
            entry_maker = function(e)
              return {
                value = e, display = e.name, ordinal = e.name, filename = e.path, path = e.path,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          previewer = previewers.vim_buffer_cat.new({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              local sel = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if sel then load_markdown_path(sel.value.path) end
            end)
            map({ "i", "n" }, "<C-o>", function()
              actions.close(prompt_bufnr); prompt_custom_path()
            end)
            map({ "i", "n" }, "<C-p>", function()
              actions.close(prompt_bufnr); prompt_pr_ref()
            end)
            return true
          end,
        }):find()
      end, { desc = "Review: load notes (Telescope; <C-o> custom path, <C-p> PR)" })

      vim.keymap.set("n", "<leader>rL", prompt_pr_ref, { desc = "Review: load PR comments" })

      vim.keymap.set("n", "<leader>rp", function()
        local sinks = { "markdown (file)", "pr (PR URL)", "quickfix", "agent (active slot)" }
        vim.ui.select(sinks, { prompt = "Push notes to:" }, function(choice)
          if not choice then return end
          if choice:match("^markdown") then
            local res = rn.push("markdown")
            if res.ok and res.path then vim.notify("Wrote " .. res.path, vim.log.levels.INFO)
            elseif not res.ok then vim.notify("Markdown export failed: " .. (res.err or ""), vim.log.levels.ERROR) end
          elseif choice:match("^pr") then
            vim.ui.input({ prompt = "PR URL: ", default = rn.get_source_pr() or "" }, function(pr)
              if not pr or pr == "" then return end
              local res = rn.push("pr", { pr = pr })
              if res.ok then
                vim.notify(string.format("Pushed %d note(s) to %s", res.count, pr), vim.log.levels.INFO)
              else
                vim.notify("PR push failed: " .. (res.err or "unknown"), vim.log.levels.ERROR)
              end
            end)
          elseif choice:match("^quickfix") then
            local res = rn.push("quickfix", { open = true })
            if res.count == 0 then vim.notify("No notes to send to quickfix", vim.log.levels.INFO) end
          elseif choice:match("^agent") then
            local res = rn.push("agent")
            if res.ok and res.count > 0 then vim.notify(string.format("Sent %d note(s) to active agent", res.count), vim.log.levels.INFO) end
          end
        end)
      end, { desc = "Review: push notes (output picker)" })

      vim.keymap.set("n", "<leader>rk", function() rn.peek_note_at_cursor() end,
        { desc = "Review: peek full note at cursor" })

      vim.keymap.set("n", "<leader>rc", function()
        local ctx = rn.resolve_buffer_context(0)
        if not ctx then return vim.notify("Not a reviewable buffer", vim.log.levels.WARN) end
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local notes = rn.get_notes_at_line(ctx.file, line, ctx.side)
        if #notes == 0 then return vim.notify("No note at cursor", vim.log.levels.INFO) end

        local function choose_action(note)
          local names = vim.tbl_keys(rn.actions)
          table.sort(names)
          vim.ui.select(names, { prompt = "Action for note:" }, function(choice)
            if choice and rn.actions[choice] then rn.actions[choice](note) end
          end)
        end

        if #notes == 1 then
          choose_action(notes[1])
        else
          vim.ui.select(notes, {
            prompt = "Pick note:",
            format_item = function(n)
              local first_line = (n.text or ""):match("^[^\n]*") or ""
              return string.format("[%s] %s", n.kind or "note", first_line:sub(1, 70))
            end,
          }, function(picked) if picked then choose_action(picked) end end)
        end
      end, { desc = "Review: code actions for note at cursor" })

      vim.keymap.set("n", "<leader>rf", function()
        local ctx = rn.resolve_buffer_context(0)
        if not ctx then return vim.notify("Not a reviewable buffer", vim.log.levels.WARN) end
        local line = vim.api.nvim_win_get_cursor(0)[1]
        local note = rn.get_note_at_line(ctx.file, line, ctx.side)
        if not note then return vim.notify("No note at cursor", vim.log.levels.INFO) end
        require("custom.review.outputs.agent").push({ note })
        vim.notify("Sent note to active agent", vim.log.levels.INFO)
      end, { desc = "Review: send note-at-cursor to agent" })


      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(ev)
          local ctx = rn.resolve_buffer_context(ev.buf)
          if ctx then rn.refresh_extmarks(ev.buf, ctx.file, ctx.side) end
        end,
      })
    end,
  },
}
