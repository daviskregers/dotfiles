local client = require("dk.linear.client")

local function assigned_body(nodes, page)
    return vim.json.encode({
        data = { viewer = { assignedIssues = { nodes = nodes, pageInfo = page or { hasNextPage = false } } } },
    })
end

local function favorites_body(nodes, page)
    return vim.json.encode({
        data = { favorites = { nodes = nodes, pageInfo = page or { hasNextPage = false } } },
    })
end

describe("client.api_key", function()
    local saved

    before_each(function()
        saved = vim.env.LINEAR_API_KEY
    end)

    after_each(function()
        vim.env.LINEAR_API_KEY = saved
    end)

    it("reads $LINEAR_API_KEY", function()
        vim.env.LINEAR_API_KEY = "lin_api_abc123"
        assert.are.equal("lin_api_abc123", client.api_key())
    end)

    it("names the variable in the error when it is unset, so the fix is obvious", function()
        vim.env.LINEAR_API_KEY = nil
        local key, err = client.api_key()
        assert.is_nil(key)
        assert.is_truthy(err:find("LINEAR_API_KEY"))
    end)

    it("treats a blank value as unset rather than sending an empty Authorization header", function()
        vim.env.LINEAR_API_KEY = "   "
        local key, err = client.api_key()
        assert.is_nil(key)
        assert.is_truthy(err)
    end)
end)

describe("client.assigned_body", function()
    it("asks for both sort keys, so favourites and status never silently flatten", function()
        -- Drop `favorite` from the query and every issue reads as unfavorited;
        -- drop state type/position and the status order collapses. Pin them.
        local body = vim.json.decode(client.assigned_body())
        assert.is_truthy(body.query:find("favorite"))
        assert.is_truthy(body.query:find("type"))
        assert.is_truthy(body.query:find("position"))
    end)

    it("filters out completed and canceled issues server-side", function()
        local body = vim.json.decode(client.assigned_body())
        assert.is_truthy(body.query:find("completed"))
        assert.is_truthy(body.query:find("canceled"))
    end)

    it("sends the page cursor as a variable, and null on the first page", function()
        assert.are.equal(vim.NIL, vim.json.decode(client.assigned_body()).variables.after)
        assert.are.equal("cursor-2", vim.json.decode(client.assigned_body("cursor-2")).variables.after)
    end)
end)

describe("client.favorites_body", function()
    it("reads favourites off the root query, not off viewer", function()
        -- `favorites` is a root field; `viewer.favorites` does not exist.
        local body = vim.json.decode(client.favorites_body())
        assert.is_truthy(body.query:find("favorites"))
        assert.is_nil(body.query:find("viewer"))
    end)

    it("pulls the same issue fields nested under each favourite", function()
        local body = vim.json.decode(client.favorites_body())
        assert.is_truthy(body.query:find("issue"))
        assert.is_truthy(body.query:find("identifier"))
        assert.is_truthy(body.query:find("branchName"))
    end)
end)

describe("client.parse_assigned", function()
    it("returns the nodes plus whether there is another page", function()
        local page, err = client.parse_assigned(assigned_body(
            { { identifier = "ENG-1" }, { identifier = "ENG-2" } },
            { hasNextPage = true, endCursor = "abc" }
        ))
        assert.is_nil(err)
        assert.are.equal(2, #page.nodes)
        assert.is_true(page.has_next)
        assert.are.equal("abc", page.cursor)
    end)

    it("surfaces GraphQL errors as a message instead of an empty list", function()
        -- A 200 with an `errors` array is how Linear reports a bad API key.
        local page, err = client.parse_assigned(vim.json.encode({
            errors = { { message = "Authentication required" }, { message = "second problem" } },
        }))
        assert.is_nil(page)
        assert.is_truthy(err:find("Authentication required"))
        assert.is_truthy(err:find("second problem"))
    end)

    it("reports unparseable bodies rather than throwing", function()
        local page, err = client.parse_assigned("<html>502 Bad Gateway</html>")
        assert.is_nil(page)
        assert.is_truthy(err)
    end)

    it("reports a well-formed response that is missing the nodes we expect", function()
        local page, err = client.parse_assigned(vim.json.encode({ data = { viewer = vim.NIL } }))
        assert.is_nil(page)
        assert.is_truthy(err)
    end)

    it("returns an empty list, not an error, when nothing is assigned", function()
        local page, err = client.parse_assigned(assigned_body({}))
        assert.is_nil(err)
        assert.are.same({}, page.nodes)
        assert.is_false(page.has_next)
    end)
end)

describe("client.parse_favorites", function()
    it("unwraps the issue out of each favourite", function()
        local page, err = client.parse_favorites(favorites_body({
            { id = "f1", issue = { identifier = "ENG-1" } },
            { id = "f2", issue = { identifier = "ENG-2" } },
        }))
        assert.is_nil(err)
        assert.are.equal("ENG-1", page.nodes[1].identifier)
        assert.are.equal("ENG-2", page.nodes[2].identifier)
    end)

    it("drops favourites that are not issues", function()
        -- You can favourite projects, documents, views and cycles too; those
        -- come back with issue: null and must not reach the picker.
        local page = client.parse_favorites(favorites_body({
            { id = "f1", issue = vim.NIL },
            { id = "f2", issue = { identifier = "ENG-2" } },
            { id = "f3", issue = vim.NIL },
        }))
        assert.are.equal(1, #page.nodes)
        assert.are.equal("ENG-2", page.nodes[1].identifier)
    end)

    it("carries pagination the same way the assigned query does", function()
        local page = client.parse_favorites(favorites_body({}, { hasNextPage = true, endCursor = "next" }))
        assert.is_true(page.has_next)
        assert.are.equal("next", page.cursor)
    end)

    it("surfaces GraphQL errors here too", function()
        local page, err = client.parse_favorites(vim.json.encode({ errors = { { message = "nope" } } }))
        assert.is_nil(page)
        assert.is_truthy(err:find("nope"))
    end)
end)
