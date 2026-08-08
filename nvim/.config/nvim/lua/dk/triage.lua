local M = {}

local RECS = {
    assistant = "Assistant",
    agent = "Agent",
    tutor = "Tutor",
    dump = "Dump (dispatch + checklist)",
}

local MODE_AGENT = "agent"
local MODE_ASSISTANT = "assistant"
local MODE_DUMP = "dump"
local MODE_TUTOR = "tutor"

local CHOICE_YES = "Yes"
local CHOICE_NO = "No"

local CHOICES_BOOL = { CHOICE_YES, CHOICE_NO }

local function done(mode)
    vim.notify(RECS[mode], vim.log.levels.INFO, { title = "Triage" })
end

local function ask(prompt, choices, next)
    vim.ui.select(choices, { prompt = prompt }, function(choice)
        if choice then next(choice) end
    end)
end

local function triage()
    ask("Prod-critical or security-sensitive?", CHOICES_BOOL, function(high)
        if high == CHOICE_YES then
            ask("Can you explain the domain?", CHOICES_BOOL, function(b)
                done(b == CHOICE_YES and MODE_ASSISTANT or MODE_TUTOR)
            end)
            return
        end
        ask("Can you explain the data path?", CHOICES_BOOL, function(a)
            if a == CHOICE_NO then
                ask("Can you explain the domain?", CHOICES_BOOL, function(b)
                    if b == CHOICE_YES then
                        done(MODE_ASSISTANT)
                    else
                        ask("Do you want to learn it?", CHOICES_BOOL, function(c)
                            done(c == CHOICE_YES and MODE_TUTOR or MODE_DUMP)
                        end)
                    end
                end)
            else
                ask("Without looking?", CHOICES_BOOL, function(d)
                    done(d == CHOICE_YES and MODE_AGENT or MODE_ASSISTANT)
                end)
            end
        end)
    end)
end


M.run = triage

vim.api.nvim_create_user_command("Triage", triage, { desc = "Mode self-assessment" })
vim.api.nvim_create_user_command("Bump", function()
    vim.notify("Dropped to lower mode. Re-assess with :Triage.", vim.log.levels.WARN, { title = "Triage" })
end, { desc = "Panic: drop to lower mode and re-assess" })

return M
