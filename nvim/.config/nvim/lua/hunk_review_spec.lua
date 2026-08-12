local hunk_review = require("hunk_review")

local function keys(hunks)
	return vim.tbl_map(function(h)
		return h.key
	end, hunks)
end

describe("hunk_review registry", function()
	it("returns hunks ordered by first-seen sequence, regardless of input order or round", function()
		local reg = hunk_review.new_registry()

		local first = reg:update({ { key = "a" }, { key = "b" } })
		assert.are.same({ "a", "b" }, keys(first))

		-- 'a' and 'b' were seen first; 'c' is new. Input order is shuffled,
		-- but the result must stay in first-seen order: a, b, c.
		local second = reg:update({ { key = "b" }, { key = "c" }, { key = "a" } })
		assert.are.same({ "a", "b", "c" }, keys(second))
	end)
end)

describe("hunk_review.hunk_key", function()
	it("keys by path plus +/- content, ignoring @@ line numbers and context lines", function()
		local a = { file = "foo.lua", lines = { "@@ -1,3 +1,4 @@", " ctx", "-old", "+new" } }
		-- same path, same +/- content, but different @@ header and context lines
		local slid = { file = "foo.lua", lines = { "@@ -50,3 +60,4 @@", " other ctx", "-old", "+new" } }
		assert.are.equal(hunk_review.hunk_key(a), hunk_review.hunk_key(slid))

		-- different +/- content -> different key
		local changed = { file = "foo.lua", lines = { "@@ -1,3 +1,4 @@", " ctx", "-old", "+changed" } }
		assert.are_not.equal(hunk_review.hunk_key(a), hunk_review.hunk_key(changed))

		-- same content in a different file -> different key
		local other_file = { file = "bar.lua", lines = { "@@ -1,3 +1,4 @@", " ctx", "-old", "+new" } }
		assert.are_not.equal(hunk_review.hunk_key(a), hunk_review.hunk_key(other_file))
	end)
end)

describe("hunk_review.parse_diff", function()
	it("splits unified diff into per-hunk objects tagged with file and new-file start line", function()
		local diff = table.concat({
			"diff --git a/foo.lua b/foo.lua",
			"index 1234567..89abcde 100644",
			"--- a/foo.lua",
			"+++ b/foo.lua",
			"@@ -1,3 +1,4 @@",
			" ctx",
			"-old",
			"+new",
			"@@ -10,2 +11,3 @@",
			" more",
			"+added",
			"diff --git a/bar.lua b/bar.lua",
			"index 000000..1111111 100644",
			"--- a/bar.lua",
			"+++ b/bar.lua",
			"@@ -5,1 +5,2 @@",
			"+lonely",
		}, "\n")

		local hunks = hunk_review.parse_diff(diff)

		assert.are.equal(3, #hunks)

		assert.are.equal("foo.lua", hunks[1].file)
		assert.are.equal(2, hunks[1].lnum) -- start 1 + 1 leading context line (" ctx")
		assert.are.same({ "@@ -1,3 +1,4 @@", " ctx", "-old", "+new" }, hunks[1].lines)

		assert.are.equal("foo.lua", hunks[2].file)
		assert.are.equal(12, hunks[2].lnum) -- start 11 + 1 leading context line (" more")

		assert.are.equal("bar.lua", hunks[3].file)
		assert.are.equal(5, hunks[3].lnum)
	end)

	it("points lnum at the first changed line, past leading context", function()
		-- git's default 3 lines of context: header starts at 15, but the real
		-- change is at line 18. lnum must skip the context and land on 18.
		local diff = table.concat({
			"diff --git a/factory.ex b/factory.ex",
			"--- a/factory.ex",
			"+++ b/factory.ex",
			"@@ -15,6 +15,6 @@ line 14",
			" line 15",
			" line 16",
			" line 17",
			"-line 18",
			"+line 18 CHANGED",
			" line 19",
			" line 20",
		}, "\n")

		local hunks = hunk_review.parse_diff(diff)
		assert.are.equal(18, hunks[1].lnum)
	end)
end)

describe("hunk_review.collect", function()
	-- The primary hunk set comes from `git diff HEAD` (working tree vs HEAD),
	-- which is invariant under staging; the --cached diff only labels status.
	it("keys hunks from the HEAD diff, labels S when the key is also staged, folds untracked as U", function()
		local head = table.concat({
			"diff --git a/foo.lua b/foo.lua",
			"--- a/foo.lua",
			"+++ b/foo.lua",
			"@@ -1,3 +1,4 @@",
			" ctx",
			"+new",
			"diff --git a/bar.lua b/bar.lua",
			"--- a/bar.lua",
			"+++ b/bar.lua",
			"@@ -1,1 +1,2 @@",
			"+staged line",
		}, "\n")
		-- bar.lua's change is staged: the same hunk appears in --cached
		local staged = table.concat({
			"diff --git a/bar.lua b/bar.lua",
			"--- a/bar.lua",
			"+++ b/bar.lua",
			"@@ -1,1 +1,2 @@",
			"+staged line",
		}, "\n")
		local untracked = { "new_file.lua", "sub/dir/other.lua" }

		local hunks = hunk_review.collect(head, staged, untracked)

		assert.are.equal(4, #hunks)

		-- foo.lua: in HEAD diff, not staged -> content key, status U
		assert.are.equal("foo.lua", hunks[1].file)
		assert.are.equal(2, hunks[1].lnum) -- start 1 + 1 leading context line (" ctx")
		assert.are.equal("U", hunks[1].status)
		assert.are.equal(hunk_review.hunk_key(hunks[1]), hunks[1].key)

		-- bar.lua: key also present in the staged diff -> status S
		assert.are.equal("bar.lua", hunks[2].file)
		assert.are.equal("S", hunks[2].status)

		-- untracked files: whole-file, path-keyed, jump to line 1, status U
		assert.are.equal("new_file.lua", hunks[3].file)
		assert.are.equal(1, hunks[3].lnum)
		assert.are.equal("new_file.lua", hunks[3].key)
		assert.are.equal("U", hunks[3].status)
		assert.are.equal("sub/dir/other.lua", hunks[4].key)
	end)

	it("gives a tracked hunk the same key whether it is staged or not, so staging never moves it", function()
		-- `git diff HEAD` output is identical regardless of staging state, so the
		-- key is stable; staging only flips the status.
		local head = table.concat({
			"diff --git a/ctrl.ex b/ctrl.ex",
			"--- a/ctrl.ex",
			"+++ b/ctrl.ex",
			"@@ -10,3 +10,3 @@ context",
			" a",
			"-old",
			"+new",
			" b",
		}, "\n")

		local unstaged = hunk_review.collect(head, "", {})
		local staged = hunk_review.collect(head, head, {})

		assert.are.equal(unstaged[1].key, staged[1].key)
		assert.are.equal("U", unstaged[1].status)
		assert.are.equal("S", staged[1].status)
	end)

	it("labels a hunk P when only some of its changed lines are staged", function()
		-- The bug this fixes: git coalesces staged + unstaged edits into one big
		-- HEAD hunk, while --cached shows only the staged subset. Whole-hunk-key
		-- matching never reconciles the two (different content -> different key),
		-- so every partially-staged hunk wrongly read U. Line-level membership
		-- sees that some — not all — changed lines are staged.
		local head = table.concat({
			"diff --git a/ctrl.ex b/ctrl.ex",
			"--- a/ctrl.ex",
			"+++ b/ctrl.ex",
			"@@ -1,1 +1,3 @@",
			" ctx",
			"+staged addition",
			"+unstaged addition",
		}, "\n")
		-- only the first addition is in the index
		local staged = table.concat({
			"diff --git a/ctrl.ex b/ctrl.ex",
			"--- a/ctrl.ex",
			"+++ b/ctrl.ex",
			"@@ -1,1 +1,2 @@",
			" ctx",
			"+staged addition",
		}, "\n")

		local hunks = hunk_review.collect(head, staged, {})

		assert.are.equal(1, #hunks)
		assert.are.equal("P", hunks[1].status)
	end)

	it("keys new-file hunks by path, so staging an untracked file keeps its identity", function()
		-- untracked file: keyed by path
		local untracked_hunks = hunk_review.collect("", "", { "n1.txt" })
		assert.are.equal("n1.txt", untracked_hunks[1].key)

		-- once `git add`-ed, the file appears in BOTH the HEAD diff and the
		-- --cached diff as a new-file hunk (old side /dev/null). It must get the
		-- SAME path key as its untracked form, not a content hash.
		local newfile = table.concat({
			"diff --git a/n1.txt b/n1.txt",
			"new file mode 100644",
			"index 0000000..1234567",
			"--- /dev/null",
			"+++ b/n1.txt",
			"@@ -0,0 +1,1 @@",
			"+aaa",
		}, "\n")
		local staged_hunks = hunk_review.collect(newfile, newfile, {})
		assert.are.equal("n1.txt", staged_hunks[1].key)
		assert.are.equal("S", staged_hunks[1].status)
		assert.are.equal(untracked_hunks[1].key, staged_hunks[1].key)
	end)
end)

describe("hunk_review.to_qf_items", function()
	it("maps hunks to quickfix entries with a [S]/[U] status prefix and first-changed-line preview", function()
		local hunks = {
			{ file = "foo.lua", lnum = 12, status = "U", lines = { "@@ -12,2 +12,3 @@", " ctx", "-old", "+new line" } },
			{ file = "new.lua", lnum = 1, status = "S", lines = { "@@ new file @@" } },
		}

		local items = hunk_review.to_qf_items(hunks)

		assert.are.same({
			-- unstaged: [U] prefix, first changed line as preview
			{ filename = "foo.lua", lnum = 12, text = "[U] +new line" },
			-- staged: [S] prefix, header fallback when there is no +/- line
			{ filename = "new.lua", lnum = 1, text = "[S] @@ new file @@" },
		}, items)
	end)
end)
