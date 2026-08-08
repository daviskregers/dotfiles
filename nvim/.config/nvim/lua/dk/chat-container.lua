-- Lightweight Docker container for read-only AI chat (Tutor/Assistant).
-- Mounts: project (ro), opencode data+config (rw for logs), claude config (ro).
-- Does NOT mount ~/.aws, ~/.ssh, or anything else.
-- Container persists between chats for fast re-open; cleaned up on VimExit.
--
-- opencode config is overridden inside the container to auto-approve all permissions.
-- The container IS the sandbox — no permission prompts needed.

local M = {}

local CONTAINER_PREFIX = "dk-chat-"

-- Hash the project path to a short container name (avoid name collisions between projects)
local function container_name()
    local cwd = vim.fn.getcwd()
    local hash = 0
    for i = 1, #cwd do
        hash = (hash * 31 + string.byte(cwd, i)) % 100000
    end
    return CONTAINER_PREFIX .. hash
end

-- Resolve which ACP command to run inside the container.
local function resolve_agent()
    local function read_agent_file(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local line = f:read("*l")
        f:close()
        return line and vim.trim(line) or nil
    end
    local project = vim.fs.find(".dk-notes", { upward = true, type = "directory" })[1]
    if project then
        local agent = read_agent_file(project .. "/.agent")
        if agent and agent ~= "" then return agent end
    end
    local global = read_agent_file(vim.fn.stdpath("config") .. "/.agent")
    if global and global ~= "" then return global end
    return "opencode"
end

-- opencode config that auto-approves everything — the container IS the sandbox.
local OPENCODE_CONFIG = [[
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "permission": {
        "bash": "allow",
        "edit": "allow"
      }
    }
  },
  "model": "opencode-go/glm-5.2"
}
]]

-- Get the docker exec command for ACP. Returns the command array.
function M.acp_command()
    local name = container_name()
    local agent = resolve_agent()

    -- Ensure container is running before returning the command
    M.ensure_running()

    local cmd
    if agent == "claude_code" then
        cmd = { "docker", "exec", "-i", name, "claude", "acp" }
    else
        cmd = { "docker", "exec", "-i", name, "opencode", "acp" }
    end
    return cmd
end

-- Ensure the container is running. Starts it if not.
function M.ensure_running()
    local name = container_name()

    -- Check if container is already running
    local result = vim.system({ "docker", "inspect", "-f", "{{.State.Running}}", name }, { text = true }):wait()
    if result.stdout and vim.trim(result.stdout) == "true" then
        return true
    end

    -- Check if container exists but is stopped — remove it so we start fresh
    if result.stdout and vim.trim(result.stdout) == "false" then
        vim.system({ "docker", "rm", name }, { text = true }):wait()
    end

    -- Start the container
    local cwd = vim.fn.getcwd()
    local home = os.getenv("HOME")

    -- Write the sandbox opencode config to a temp dir (mount the dir, not the file —
    -- docker creates a directory if a file mount target doesn't exist)
    local config_dir = vim.fn.stdpath("data") .. "/dk-chat-config"
    vim.fn.mkdir(config_dir, "p")
    local config_path = config_dir .. "/opencode.json"
    local f = io.open(config_path, "w")
    if f then
        f:write(OPENCODE_CONFIG)
        f:close()
    end

    local args = {
        "docker", "run", "-d",
        "--name", name,
        "-v", cwd .. ":" .. cwd .. ":ro",
        "-v", home .. "/.local/share/opencode:/root/.local/share/opencode",
        "-v", config_dir .. ":/root/.config/opencode",
        "-v", home .. "/.claude.json:/root/.claude.json:ro",
        "-v", home .. "/.claude:/root/.claude:ro",
        "-w", cwd,
        "dk-chat",
        "sleep", "infinity",
    }
    local run = vim.system(args, { text = true }):wait()
    if run.code ~= 0 then
        vim.notify("Failed to start chat container: " .. (run.stderr or ""), vim.log.levels.ERROR)
        return false
    end
    -- Health check: verify opencode acp responds to initialize.
    -- Runs in a separate docker exec (the container's sleep infinity keeps running).
    local ready = false
    for _ = 1, 10 do
        local check = vim.system({
            "docker", "exec", "-i", name, "opencode", "acp",
        }, {
            stdin = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientInfo":{"name":"dk-healthcheck","version":"1.0.0"}}}',
            text = true,
        }):wait()
        if check.stdout and check.stdout:match('"protocolVersion"') then
            ready = true
            break
        end
        vim.wait(200)
    end
    if not ready then
        vim.notify("Chat container started but ACP didn't respond", vim.log.levels.ERROR)
        return false
    end
    return true
end

-- Stop and remove the container (called on VimExit or manually)
function M.cleanup()
    local name = container_name()
    vim.system({ "docker", "stop", name }, { text = true }):wait()
    vim.system({ "docker", "rm", name }, { text = true }):wait()
end

-- Register cleanup on exit
vim.api.nvim_create_autocmd("VimLeave", {
    callback = function() M.cleanup() end,
})

return M