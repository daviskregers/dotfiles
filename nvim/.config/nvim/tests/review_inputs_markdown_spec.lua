local md = require("custom.review.inputs.markdown")

describe("review.inputs.markdown.parse", function()
  it("extracts path:line: msg from a single line", function()
    local notes = md.parse("src/foo.lua:42: fix this")
    assert.equals(1, #notes)
    assert.equals("src/foo.lua", notes[1].file)
    assert.equals(42, notes[1].start_line)
    assert.equals(42, notes[1].end_line)
    assert.equals("fix this", notes[1].text)
  end)

  it("extracts multiple findings from multi-line input", function()
    local input = "src/foo.lua:42: fix this\nlib/bar.go:7: refactor"
    local notes = md.parse(input)
    assert.equals(2, #notes)
    assert.equals("lib/bar.go", notes[2].file)
    assert.equals(7, notes[2].start_line)
    assert.equals("refactor", notes[2].text)
  end)

  it("parses path:start-end: msg as a range", function()
    local notes = md.parse("src/foo.lua:10-12: complex block")
    assert.equals(10, notes[1].start_line)
    assert.equals(12, notes[1].end_line)
    assert.equals("complex block", notes[1].text)
  end)

  it("ignores prose and headings", function()
    local input = table.concat({
      "# Review",
      "",
      "Some intro paragraph.",
      "src/x.lua:1: real finding",
      "## Section",
      "More prose without colon-line pattern.",
    }, "\n")
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.equals("src/x.lua", notes[1].file)
  end)

  it("returns empty list for empty input", function()
    assert.are.same({}, md.parse(""))
  end)

  it("trims surrounding whitespace from text", function()
    local notes = md.parse("a/b.c:3:    spaced message   ")
    assert.equals("spaced message", notes[1].text)
  end)

  it("ignores lines with non-numeric line component (e.g. URLs)", function()
    local input = "https://example.com:8080: not a finding\nsrc/y.lua:5: real"
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.equals("src/y.lua", notes[1].file)
  end)

  it("strips leading list/bullet markers from path", function()
    -- /code-review may emit findings as `- src/foo.lua:42: msg`
    local notes = md.parse("- src/foo.lua:42: with bullet")
    assert.equals(1, #notes)
    assert.equals("src/foo.lua", notes[1].file)
    assert.equals("with bullet", notes[1].text)
  end)

  it("parses caveman-review format (#### emoji `path:line` — text)", function()
    local input = "#### 🟡 `app/Foo.php:42` — fix this"
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.equals("app/Foo.php", notes[1].file)
    assert.equals(42, notes[1].start_line)
    assert.equals("fix this", notes[1].text)
  end)

  it("parses caveman-review format with absolute path", function()
    local input = "#### 🔵 `/Users/x/proj/app/Bar.php:151` — `campaign_id` not filtered"
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.equals("/Users/x/proj/app/Bar.php", notes[1].file)
    assert.equals(151, notes[1].start_line)
    assert.matches("campaign_id", notes[1].text)
  end)

  it("parses caveman-review format with line range", function()
    local input = "#### 🔴 `lib/baz.go:10-15` — extract block"
    local notes = md.parse(input)
    assert.equals(10, notes[1].start_line)
    assert.equals(15, notes[1].end_line)
  end)

  it("parses caveman-review without emoji", function()
    local input = "#### `src/x.lua:5` — note"
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.equals("src/x.lua", notes[1].file)
  end)

  it("captures severity from emoji (red=high)", function()
    local input = "#### 🔴 `src/x.lua:1` — critical"
    assert.equals("high", md.parse(input)[1].severity)
  end)

  it("captures severity from emoji (yellow=medium)", function()
    local input = "#### 🟡 `src/x.lua:1` — warning"
    assert.equals("medium", md.parse(input)[1].severity)
  end)

  it("captures severity from emoji (blue=low)", function()
    local input = "#### 🔵 `src/x.lua:1` — info"
    assert.equals("low", md.parse(input)[1].severity)
  end)

  it("severity is nil when no emoji present", function()
    local input = "src/x.lua:1: plain finding"
    assert.is_nil(md.parse(input)[1].severity)
  end)

  it("captures body paragraphs and code blocks under a caveman heading", function()
    local input = table.concat({
      "#### 🟡 `app/Foo.php:154` — heading text",
      "",
      "```php",
      "$x = $items->keyBy('id');",
      "```",
      "",
      "Worth confirming the DB has a UNIQUE id index.",
      "",
      "**Affects:** behavior changes if duplicate exists.",
    }, "\n")
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.matches("heading text", notes[1].text)
    assert.matches("UNIQUE id", notes[1].text)
    assert.matches("php", notes[1].text)
    assert.matches("Affects:", notes[1].text)
  end)

  it("ends a finding's body at the next caveman heading", function()
    local input = table.concat({
      "#### 🟡 `a.lua:1` — first",
      "body of first",
      "#### 🔵 `b.lua:2` — second",
      "body of second",
    }, "\n")
    local notes = md.parse(input)
    assert.equals(2, #notes)
    assert.matches("body of first", notes[1].text)
    assert.is_falsy(notes[1].text:find("body of second"))
    assert.matches("body of second", notes[2].text)
  end)

  it("ends body at higher-level heading (## or ###)", function()
    local input = table.concat({
      "#### 🟡 `a.lua:1` — finding",
      "finding body",
      "## Next section",
      "section content",
    }, "\n")
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.is_falsy(notes[1].text:find("section content"))
    assert.is_falsy(notes[1].text:find("Next section"))
  end)

  it("ignores prose before any finding", function()
    local input = table.concat({
      "Intro paragraph that should be ignored.",
      "",
      "#### 🟡 `a.lua:1` — actual",
      "body",
    }, "\n")
    local notes = md.parse(input)
    assert.equals(1, #notes)
    assert.is_falsy(notes[1].text:find("Intro paragraph"))
  end)
end)

describe("review.inputs.markdown.load", function()
  it("reads a file from disk and parses it", function()
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w")
    f:write("src/foo.lua:1: from file\n")
    f:close()
    local notes = md.load(path)
    assert.equals(1, #notes)
    assert.equals("from file", notes[1].text)
    vim.fn.delete(path)
  end)

  it("returns empty list when file missing", function()
    local notes = md.load("/nonexistent/path/that-does-not-exist.md")
    assert.are.same({}, notes)
  end)
end)
