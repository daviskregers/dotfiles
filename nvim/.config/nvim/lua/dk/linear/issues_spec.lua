local issues = require("dk.linear.issues")

-- Build a raw GraphQL node the way the Linear API returns it: `favorite` is
-- either a Favorite object or JSON null, which vim.json.decode gives us as
-- vim.NIL rather than nil.
local function node(opts)
    return {
        id = opts.id or ("uuid-" .. (opts.identifier or "X-1")),
        identifier = opts.identifier or "X-1",
        title = opts.title or "a title",
        url = opts.url or "https://linear.app/x/issue/X-1",
        branchName = opts.branchName or "dk/x-1",
        description = opts.description or vim.NIL,
        favorite = opts.favorite and { id = "fav-1" } or vim.NIL,
        state = {
            name = opts.state_name or "Todo",
            type = opts.state_type or "unstarted",
            position = opts.position or 0,
        },
    }
end

local function identifiers(list)
    return vim.tbl_map(function(i)
        return i.identifier
    end, list)
end

describe("issues.normalize", function()
    it("turns vim.NIL favorite/description into false and nil, so callers never see vim.NIL", function()
        local plain = issues.normalize(node({ identifier = "ENG-1" }))
        assert.are.equal(false, plain.favorite)
        assert.are.equal(nil, plain.description)

        local starred = issues.normalize(node({ identifier = "ENG-2", favorite = true }))
        assert.are.equal(true, starred.favorite)
    end)

    it("flattens the fields the picker needs off the raw node", function()
        local i = issues.normalize(node({
            identifier = "ENG-7",
            title = "Fix the thing",
            url = "https://linear.app/acme/issue/ENG-7",
            branchName = "dk/eng-7-fix-the-thing",
            state_name = "In Progress",
            state_type = "started",
            position = 3,
        }))
        assert.are.equal("ENG-7", i.identifier)
        assert.are.equal("Fix the thing", i.title)
        assert.are.equal("https://linear.app/acme/issue/ENG-7", i.url)
        assert.are.equal("dk/eng-7-fix-the-thing", i.branch)
        assert.are.equal("In Progress", i.state_name)
        assert.are.equal("started", i.state_type)
        assert.are.equal(3, i.state_position)
    end)
end)

describe("issues.dedupe", function()
    it("keeps one copy of an issue that is both assigned to me and favorited", function()
        local list = {
            issues.normalize(node({ id = "a", identifier = "ENG-1" })),
            issues.normalize(node({ id = "b", identifier = "ENG-2" })),
            issues.normalize(node({ id = "a", identifier = "ENG-1", favorite = true })),
        }
        local deduped = issues.dedupe(list)
        assert.are.same({ "ENG-1", "ENG-2" }, identifiers(deduped))
    end)

    it("keeps the copy that knows the issue is favorited, whichever list it came from", function()
        -- The assigned query and the favourites query both return `favorite`,
        -- but only ever merge one of them into the final list — take the
        -- truthful one rather than whichever happened to arrive first.
        local deduped = issues.dedupe({
            issues.normalize(node({ id = "a", identifier = "ENG-1", favorite = false })),
            issues.normalize(node({ id = "a", identifier = "ENG-1", favorite = true })),
        })
        assert.are.equal(1, #deduped)
        assert.is_true(deduped[1].favorite)
    end)
end)

describe("issues.sort", function()
    it("puts every favorite above every non-favorite, whatever their status", function()
        -- The favorite is the most-backlogged issue here; it still wins.
        local sorted = issues.sort({
            issues.normalize(node({ identifier = "ENG-1", state_type = "started" })),
            issues.normalize(node({ identifier = "ENG-2", state_type = "backlog", favorite = true })),
            issues.normalize(node({ identifier = "ENG-3", state_type = "unstarted" })),
        })
        assert.are.same({ "ENG-2", "ENG-1", "ENG-3" }, identifiers(sorted))
    end)

    it("orders by state type: started, triage, unstarted, backlog", function()
        local sorted = issues.sort({
            issues.normalize(node({ identifier = "ENG-1", state_type = "backlog" })),
            issues.normalize(node({ identifier = "ENG-2", state_type = "unstarted" })),
            issues.normalize(node({ identifier = "ENG-3", state_type = "triage" })),
            issues.normalize(node({ identifier = "ENG-4", state_type = "started" })),
        })
        assert.are.same({ "ENG-4", "ENG-3", "ENG-2", "ENG-1" }, identifiers(sorted))
    end)

    it("sinks completed and canceled below backlog, since favorited ones can now reach the list", function()
        -- A favorited issue is included whatever its state, so a finished
        -- favorite must not outrank live work inside the favorites block.
        local sorted = issues.sort({
            issues.normalize(node({ identifier = "ENG-1", state_type = "canceled" })),
            issues.normalize(node({ identifier = "ENG-2", state_type = "completed" })),
            issues.normalize(node({ identifier = "ENG-3", state_type = "backlog" })),
        })
        assert.are.same({ "ENG-3", "ENG-2", "ENG-1" }, identifiers(sorted))
    end)

    it("breaks a state-type tie with the workflow position, so 'In Review' sits where the team put it", function()
        local sorted = issues.sort({
            issues.normalize(node({ identifier = "ENG-1", state_name = "In Review", state_type = "started", position = 4 })),
            issues.normalize(node({ identifier = "ENG-2", state_name = "In Progress", state_type = "started", position = 2 })),
        })
        assert.are.same({ "ENG-2", "ENG-1" }, identifiers(sorted))
    end)

    it("breaks a full tie on identifier, counting the number numerically so ENG-45 precedes ENG-123", function()
        local sorted = issues.sort({
            issues.normalize(node({ identifier = "ENG-123" })),
            issues.normalize(node({ identifier = "OPS-2" })),
            issues.normalize(node({ identifier = "ENG-45" })),
        })
        assert.are.same({ "ENG-45", "ENG-123", "OPS-2" }, identifiers(sorted))
    end)

    it("does not mutate the list it was given", function()
        local input = {
            issues.normalize(node({ identifier = "ENG-1", state_type = "backlog" })),
            issues.normalize(node({ identifier = "ENG-2", state_type = "started" })),
        }
        issues.sort(input)
        assert.are.same({ "ENG-1", "ENG-2" }, identifiers(input))
    end)

    it("sorts an unknown state type last rather than erroring", function()
        local sorted = issues.sort({
            issues.normalize(node({ identifier = "ENG-1", state_type = "something-new" })),
            issues.normalize(node({ identifier = "ENG-2", state_type = "backlog" })),
        })
        assert.are.same({ "ENG-2", "ENG-1" }, identifiers(sorted))
    end)
end)

describe("issues.rows", function()
    it("pads identifier and state to the widest in the list so the columns line up", function()
        local rows = issues.rows({
            issues.normalize(node({ identifier = "ENG-1", state_name = "In Progress", title = "short" })),
            issues.normalize(node({ identifier = "PLATFORM-123", state_name = "Todo", title = "long" })),
        })
        assert.are.equal("  ENG-1         In Progress  short", rows[1].display)
        assert.are.equal("  PLATFORM-123  Todo         long", rows[2].display)
    end)

    it("marks favorites with a star in the leading column", function()
        local rows = issues.rows({
            issues.normalize(node({ identifier = "ENG-1", favorite = true, state_name = "Todo", title = "t" })),
        })
        assert.are.equal("★ ENG-1  Todo  t", rows[1].display)
    end)

    it("makes identifier, state and title all fuzzy-matchable via the ordinal", function()
        local rows = issues.rows({
            issues.normalize(node({ identifier = "ENG-9", state_name = "In Review", title = "Fix login" })),
        })
        assert.are.equal("ENG-9 In Review Fix login", rows[1].ordinal)
        assert.are.equal("ENG-9", rows[1].issue.identifier)
    end)
end)

describe("issues.slug", function()
    -- Linear already slugifies the title for us in branchName
    -- (<user>/<team>-<n>-<slug>), so we never have to guess at punctuation,
    -- casing or non-ASCII — we take theirs.
    it("takes the slug Linear put in branchName", function()
        assert.are.equal("fix-the-thing", issues.slug("davis/edu-123-fix-the-thing", "EDU-123"))
    end)

    it("copes with a workspace that omits the username prefix", function()
        assert.are.equal("fix-the-thing", issues.slug("edu-123-fix-the-thing", "EDU-123"))
    end)

    it("splits on the last slash, so a username with its own dashes is fine", function()
        assert.are.equal("thing", issues.slug("davis-k/edu-123-thing", "EDU-123"))
    end)

    it("is empty when the branch is nothing but the identifier", function()
        assert.are.equal("", issues.slug("davis/edu-123", "EDU-123"))
    end)
end)

describe("issues.notes_dirname", function()
    it("keeps the identifier's own casing and appends Linear's slug", function()
        assert.are.equal("EDU-123-fix-the-thing", issues.notes_dirname("EDU-123", "davis/edu-123-fix-the-thing"))
    end)

    it("is just the identifier when the branch carries no slug", function()
        assert.are.equal("EDU-123", issues.notes_dirname("EDU-123", "davis/edu-123"))
    end)
end)

describe("issues.notes_template", function()
    -- The prose itself is not pinned here — it is copy, and asserting thirty
    -- lines of it would break on every wording tweak. What matters is the shape.
    local function template()
        return issues.notes_template("EDU-6649")
    end

    it("heads the file with the issue identifier", function()
        assert.are.equal("# EDU-6649", template()[1])
        assert.are.equal("## Unknowns", template()[2])
    end)

    it("carries Unknowns, then Predictions, then Score", function()
        local text = table.concat(template(), "\n")
        local unknowns = text:find("## Unknowns", 1, true)
        local predictions = text:find("## Predictions", 1, true)
        local score = text:find("## Score", 1, true)
        assert.is_truthy(unknowns)
        assert.is_truthy(predictions)
        assert.is_truthy(score)
        assert.is_true(unknowns < predictions)
        assert.is_true(predictions < score)
    end)

    it("asks for exactly three numbered claims", function()
        local claims = 0
        for _, line in ipairs(template()) do
            if line:match("^%d%. %*%*") then
                claims = claims + 1
            end
        end
        assert.are.equal(3, claims)
    end)

    it("gives every claim its own unchecked boxes, with two on claim 2", function()
        -- Each claim is checked a different way, so the boxes have to hang off
        -- the claim rather than sit in one shared list. Claim 2 gets two: me
        -- first with grep/LSP, then a fresh agent for the cross-component
        -- callers my tools miss.
        local boxes, claim = {}, nil
        for _, line in ipairs(template()) do
            local n = line:match("^(%d)%. %*%*")
            if n then
                claim = tonumber(n)
                boxes[claim] = 0
            elseif claim and line:match("^%s*%- %[ %]") then
                boxes[claim] = boxes[claim] + 1
            end
        end
        assert.are.equal(1, boxes[1])
        assert.are.equal(2, boxes[2])
        assert.are.equal(1, boxes[3])
    end)

    it("returns one line per element, since writefile takes an array", function()
        for _, line in ipairs(template()) do
            assert.is_nil(line:find("\n", 1, true))
        end
    end)

    it("does not end on a blank line", function()
        local lines = template()
        assert.is_truthy(lines[#lines]:match("%S"))
    end)
end)

describe("issues.notes_path", function()
    it("puts notes.md inside the issue's own directory", function()
        assert.are.equal(
            "/repo/.dk-notes/EDU-123-fix-the-thing/notes.md",
            issues.notes_path("/repo/.dk-notes", "EDU-123-fix-the-thing")
        )
    end)
end)
