-- The only thing here that touches the network.
--
-- Two queries, because the list is a union: issues assigned to me, plus issues
-- I have favorited. A favorite is not necessarily assigned to me, and Linear has
-- no single filter for "either", so we fetch both and merge.

local M = {}

local API_URL = "https://api.linear.app/graphql"
local PAGE_SIZE = 100

-- `favorite` is the viewer's Favorite record for the issue (null when not
-- favorited); `state.type`/`state.position` give the status order.
local ISSUE_FIELDS = [[
        id
        identifier
        title
        url
        branchName
        description
        favorite { id }
        state { name type position }
]]

-- Completed and canceled are filtered server-side here: my own work list is
-- current work, not history. Favorites are deliberately not filtered — if I
-- starred something I want to see it whatever state it is in.
local ASSIGNED_QUERY = [[
query AssignedIssues($after: String) {
  viewer {
    assignedIssues(
      first: ]] .. PAGE_SIZE .. [[

      after: $after
      filter: { state: { type: { nin: ["completed", "canceled"] } } }
    ) {
      nodes {
]] .. ISSUE_FIELDS .. [[
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}
]]

-- `favorites` is a root query field, not something hanging off viewer, and a
-- Favorite can point at a project/document/view instead of an issue.
local FAVORITES_QUERY = [[
query FavoriteIssues($after: String) {
  favorites(first: ]] .. PAGE_SIZE .. [[, after: $after) {
    nodes {
      id
      issue {
]] .. ISSUE_FIELDS .. [[
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}
]]

--- @return string? key, string? err
function M.api_key()
    local key = vim.env.LINEAR_API_KEY
    if not key or vim.trim(key) == "" then
        return nil, "$LINEAR_API_KEY is not set. Create a personal API key at "
            .. "https://linear.app/settings/account/security and export it."
    end
    return vim.trim(key)
end

local function body(query, cursor)
    -- vim.NIL rather than nil: an absent key would encode `variables` as an
    -- empty array, which the API rejects.
    return vim.json.encode({ query = query, variables = { after = cursor or vim.NIL } })
end

--- @param cursor string?
--- @return string json
function M.assigned_body(cursor)
    return body(ASSIGNED_QUERY, cursor)
end

--- @param cursor string?
--- @return string json
function M.favorites_body(cursor)
    return body(FAVORITES_QUERY, cursor)
end

--- Decode a Linear response and reject the failure shapes. Linear answers 200
--- with an `errors` array for auth and query failures, so status is not enough.
--- @return table? data, string? err
local function decode(raw)
    local ok, data = pcall(vim.json.decode, raw)
    if not ok or type(data) ~= "table" then
        return nil, "Could not parse the Linear response: " .. tostring(raw):sub(1, 200)
    end
    if type(data.errors) == "table" and #data.errors > 0 then
        local messages = vim.tbl_map(function(e)
            return e.message or vim.inspect(e)
        end, data.errors)
        return nil, "Linear API error: " .. table.concat(messages, "; ")
    end
    return data
end

local function page_of(connection)
    local info = connection.pageInfo or {}
    return {
        nodes = connection.nodes,
        has_next = info.hasNextPage == true,
        cursor = info.endCursor ~= vim.NIL and info.endCursor or nil,
    }
end

--- @param raw string
--- @return table? page { nodes, has_next, cursor }, string? err
function M.parse_assigned(raw)
    local data, err = decode(raw)
    if not data then
        return nil, err
    end
    local connection = vim.tbl_get(data, "data", "viewer", "assignedIssues")
    if type(connection) ~= "table" or type(connection.nodes) ~= "table" then
        return nil, "Linear response had no assigned issues in it: " .. tostring(raw):sub(1, 200)
    end
    return page_of(connection)
end

--- @param raw string
--- @return table? page { nodes, has_next, cursor }, string? err
function M.parse_favorites(raw)
    local data, err = decode(raw)
    if not data then
        return nil, err
    end
    local connection = vim.tbl_get(data, "data", "favorites")
    if type(connection) ~= "table" or type(connection.nodes) ~= "table" then
        return nil, "Linear response had no favorites in it: " .. tostring(raw):sub(1, 200)
    end

    local page = page_of(connection)
    local issues = {}
    for _, favorite in ipairs(page.nodes) do
        -- Projects, documents, views and cycles can be favorited too; those come
        -- back with issue: null.
        if type(favorite.issue) == "table" then
            issues[#issues + 1] = favorite.issue
        end
    end
    page.nodes = issues
    return page
end

local function post(key, request_body, callback)
    vim.system({
        "curl", "--silent", "--show-error", "--fail-with-body",
        "--max-time", "20",
        "--request", "POST",
        "--header", "Content-Type: application/json",
        "--header", "Authorization: " .. key,
        "--data", "@-",
        API_URL,
    }, { stdin = request_body, text = true }, function(out)
        vim.schedule(function()
            if out.code ~= 0 and (out.stdout == nil or out.stdout == "") then
                return callback(nil, "curl failed (exit " .. out.code .. "): " .. (out.stderr or ""))
            end
            callback(out.stdout)
        end)
    end)
end

--- Walk every page of one query, accumulating nodes. Recurses through the
--- callback rather than looping, since each request is async.
local function fetch_all(key, make_body, parse, callback)
    local nodes = {}
    local function page(cursor)
        post(key, make_body(cursor), function(raw, post_err)
            if post_err then
                return callback(nil, post_err)
            end
            local result, parse_err = parse(raw)
            if not result then
                return callback(nil, parse_err)
            end
            vim.list_extend(nodes, result.nodes)
            if result.has_next and result.cursor then
                return page(result.cursor)
            end
            callback(nodes)
        end)
    end
    page(nil)
end

--- Fetch assigned + favorited issues off the main thread, all pages of each.
--- `callback(nodes, err)` runs on the main loop, so it is safe to open windows
--- from it. Nodes are raw GraphQL and may contain the same issue twice — the
--- caller dedupes.
--- @param callback fun(nodes: table?, err: string?)
function M.fetch(callback)
    local key, key_err = M.api_key()
    if not key then
        return callback(nil, key_err)
    end

    fetch_all(key, M.assigned_body, M.parse_assigned, function(assigned, assigned_err)
        if not assigned then
            return callback(nil, assigned_err)
        end
        fetch_all(key, M.favorites_body, M.parse_favorites, function(favorited, favorited_err)
            if not favorited then
                return callback(nil, favorited_err)
            end
            callback(vim.list_extend(assigned, favorited))
        end)
    end)
end

return M
