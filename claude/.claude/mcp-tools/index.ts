import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "child_process";
import { promisify } from "util";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const execFileAsync = promisify(execFile);
const MAX_BUFFER = 10 * 1024 * 1024;
const MAX_COMMENT_BYTES = 60_000;

const ATTRIBUTION_NOTICE = "🤖 Generated with AI";
const BRANDED_LINE =
  /^[ \t>]*(?:co-authored-by:.*|.*generated with (?:claude code|opencode).*)\s*$/gim;
// A notice line already present, in either the bare or "(model)" form.
const NOTICE_PRESENT = new RegExp(`^[ \\t>]*${ATTRIBUTION_NOTICE}\\b`, "im");

// Append the AI-attribution notice as the final line, stripping tool-branded
// attribution (Co-Authored-By, "Generated with Claude Code/opencode"). Idempotent —
// leaves an existing notice (bare or with model name) untouched.
function withAttribution(text: string): string {
  const stripped = text
    .replace(BRANDED_LINE, "")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/\s+$/, "");
  if (NOTICE_PRESENT.test(stripped)) return stripped;
  return stripped ? `${stripped}\n\n${ATTRIBUTION_NOTICE}` : ATTRIBUTION_NOTICE;
}

// Project directory: prefer PROJECT_DIR env var, fall back to cwd.
// Claude Code sets cwd to project root when launching MCP servers,
// but in symlinked dotfile setups the resolved path may differ.
const PROJECT_DIR = process.env.PROJECT_DIR || process.cwd();

const PR_URL_RE = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/(\d+)\/?$/;

function parsePrUrl(url: string) {
  const m = url.match(PR_URL_RE);
  if (!m) return null;
  return { ownerRepo: m[1], number: m[2] };
}

function timestamp(): string {
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  return [
    now.getUTCFullYear(), "-", pad(now.getUTCMonth() + 1), "-", pad(now.getUTCDate()),
    "_", pad(now.getUTCHours()), "-", pad(now.getUTCMinutes()), "-", pad(now.getUTCSeconds()),
  ].join("");
}

function text(msg: string) {
  return { content: [{ type: "text" as const, text: msg }] };
}

async function ensureNotesDir(kind: string): Promise<string> {
  const dir = path.join(PROJECT_DIR, ".dk-notes", kind);
  await fs.promises.mkdir(dir, { recursive: true });
  return dir;
}

const server = new McpServer({
  name: "claude-custom-tools",
  version: "1.0.0",
});

// ── save_code_review ────────────────────────────────────────────────
server.tool(
  "save_code_review",
  "Save a code review to .dk-notes/reviews/ with timestamped filename",
  { content: z.string().describe("Full review markdown content") },
  async ({ content }) => {
    const dir = await ensureNotesDir("reviews");
    const suffix = Math.random().toString(36).slice(2, 6);
    const filePath = path.join(dir, `review_${timestamp()}_${suffix}.md`);
    await fs.promises.writeFile(filePath, content, "utf-8");
    return text(`Review saved to ${path.relative(process.cwd(), filePath)}`);
  },
);

// ── save_explanation ────────────────────────────────────────────────
server.tool(
  "save_explanation",
  "Save an HTML explanation to .dk-notes/explanations/ and open in default browser",
  {
    content: z.string().describe("Full HTML content"),
    title: z.string().optional().describe("Short slug for filename (e.g. 'jwt-auth-flow')"),
  },
  async ({ content, title }) => {
    const dir = await ensureNotesDir("explanations");
    const slug =
      (title ?? "explanation")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 60) || "explanation";

    const filePath = path.join(dir, `explanation_${timestamp()}_${slug}.html`);
    await fs.promises.writeFile(filePath, content, "utf-8");
    const rel = path.relative(process.cwd(), filePath);

    let opened = false;
    try {
      const cmd = process.platform === "darwin" ? "open" : "xdg-open";
      await execFileAsync(cmd, [filePath]);
      opened = true;
    } catch {}

    return text(
      opened
        ? `Explanation saved to ${rel} and opened in browser`
        : `Explanation saved to ${rel} (could not open browser)`,
    );
  },
);

// ── read_pr_info ────────────────────────────────────────────────────
server.tool(
  "read_pr_info",
  "Read a GitHub PR's metadata, diff, and commit history. Returns JSON.",
  {
    prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
    lastCommitOnly: z.boolean().optional().describe("Only include last commit's diff and message"),
  },
  async ({ prUrl, lastCommitOnly }) => {
    const parsed = parsePrUrl(prUrl);
    if (!parsed) return text("Error: Invalid PR URL. Expected https://github.com/<owner>/<repo>/pull/<number>");

    const results: Record<string, string> = {};

    // Fetch metadata
    try {
      const { stdout } = await execFileAsync(
        "gh",
        ["pr", "view", prUrl, "--json", "title,body,baseRefName,headRefName,commits,files,additions,deletions,labels"],
        { encoding: "utf8", maxBuffer: MAX_BUFFER },
      );
      results.meta = stdout;
    } catch (err: any) {
      return text(`Error fetching PR metadata: ${err.message}`);
    }

    // Fetch diff
    try {
      if (lastCommitOnly) {
        let metaObj: any;
        try {
          metaObj = JSON.parse(results.meta);
        } catch {
          return text("Error: Failed to parse PR metadata as JSON");
        }

        const commits = metaObj.commits ?? [];
        if (commits.length === 0) return text("Error: PR has no commits");
        const lastSha = commits[commits.length - 1].oid;

        try {
          const { stdout } = await execFileAsync(
            "gh",
            ["api", `repos/${parsed.ownerRepo}/commits/${lastSha}`, "--jq", ".commit.message"],
            { encoding: "utf8", maxBuffer: MAX_BUFFER },
          );
          results.lastCommitMessage = stdout.trim();
        } catch {
          results.lastCommitMessage = commits[commits.length - 1].messageHeadline;
          results.note = "Could not fetch full commit message from API; using headline";
        }

        try {
          const { stdout } = await execFileAsync(
            "gh",
            ["api", `repos/${parsed.ownerRepo}/commits/${lastSha}`, "-H", "Accept: application/vnd.github.diff"],
            { encoding: "utf8", maxBuffer: MAX_BUFFER },
          );
          results.diff = stdout;
        } catch {
          try {
            const { stdout } = await execFileAsync("gh", ["pr", "diff", prUrl], {
              encoding: "utf8",
              maxBuffer: MAX_BUFFER,
            });
            results.diff = stdout;
            results.note =
              (results.note ? results.note + ". " : "") +
              "Could not isolate last commit diff; showing full PR diff";
          } catch (e: any) {
            return text(`Error fetching diff: ${e.message}`);
          }
        }
      } else {
        const { stdout } = await execFileAsync("gh", ["pr", "diff", prUrl], {
          encoding: "utf8",
          maxBuffer: MAX_BUFFER,
        });
        results.diff = stdout;
      }
    } catch (err: any) {
      return text(`Error fetching diff: ${err.message}`);
    }

    return text(JSON.stringify(results, null, 2));
  },
);

// ── update_pr_info ──────────────────────────────────────────────────
server.tool(
  "update_pr_info",
  "Update a GitHub PR's title and/or body (description)",
  {
    prUrl: z.string().describe("Full GitHub PR URL"),
    title: z.string().optional().describe("New PR title (omit to leave unchanged)"),
    body: z.string().optional().describe("New PR body/description in markdown (omit to leave unchanged)"),
  },
  async ({ prUrl, title, body }) => {
    if (!parsePrUrl(prUrl)) return text("Error: Invalid PR URL format");
    if (!title && !body) return text("Error: At least one of title or body required");

    const args = ["pr", "edit", prUrl];
    if (title) args.push("--title", title);
    if (body) args.push("--body", body);

    try {
      const { stdout } = await execFileAsync("gh", args, { encoding: "utf8" });
      const updated = [title ? "title" : null, body ? "body" : null].filter(Boolean).join(" and ");
      return text(`Updated ${updated} for ${prUrl}\n${stdout}`.trim());
    } catch (err: any) {
      return text(`Error updating PR: ${err.message}`);
    }
  },
);

// ── submit_pr_comment ───────────────────────────────────────────────
server.tool(
  "submit_pr_comment",
  "Post a file as a comment on a GitHub PR (file sent directly, not read into conversation)",
  {
    prUrl: z.string().describe("Full GitHub PR URL"),
    filePath: z.string().describe("Path to file to post as comment (relative to cwd or absolute)"),
  },
  async ({ prUrl, filePath }) => {
    if (!PR_URL_RE.test(prUrl)) return text("Error: Invalid PR URL format");

    const resolved = path.isAbsolute(filePath) ? filePath : path.join(PROJECT_DIR, filePath);

    let stat: fs.Stats;
    try {
      stat = await fs.promises.stat(resolved);
    } catch {
      return text(`Error: File not found: ${filePath}`);
    }
    if (stat.size === 0) return text("Error: File is empty");
    if (stat.size > MAX_COMMENT_BYTES) {
      return text(`Error: File too large (${stat.size} bytes, max ${MAX_COMMENT_BYTES})`);
    }

    let body: string;
    try {
      body = withAttribution(await fs.promises.readFile(resolved, "utf-8"));
    } catch (err: any) {
      return text(`Error reading file: ${err.message}`);
    }

    const tmp = path.join(os.tmpdir(), `pr-comment-${Date.now()}.md`);
    try {
      await fs.promises.writeFile(tmp, body, "utf-8");
      const { stdout } = await execFileAsync("gh", ["pr", "comment", prUrl, "--body-file", tmp], {
        encoding: "utf8",
      });
      return text(`Comment posted to ${prUrl}\n${stdout}`.trim());
    } catch (err: any) {
      return text(`Error posting comment: ${err.message}`);
    } finally {
      fs.promises.unlink(tmp).catch(() => {});
    }
  },
);

// ── list_pr_comments ────────────────────────────────────────────────
const THREADS_Q =
  `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
  `reviewThreads(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated comments(first:20){nodes{author{login} path line body url}}}}}}}`;
const REVIEWS_Q =
  `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
  `reviews(first:50,after:$after){pageInfo{hasNextPage endCursor} nodes{author{login} body state url}}}}}`;
const CONV_Q =
  `query($owner:String!,$repo:String!,$num:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$num){` +
  `comments(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{author{login} body url}}}}}`;

// Page through one PR connection following hasNextPage. `pick` selects the connection off pullRequest.
async function fetchAllPrNodes(
  query: string,
  owner: string,
  repo: string,
  num: string,
  pick: (pr: any) => any,
): Promise<any[]> {
  const nodes: any[] = [];
  let after: string | undefined;
  for (;;) {
    const args = ["api", "graphql", "-f", `query=${query}`, "-f", `owner=${owner}`, "-f", `repo=${repo}`, "-F", `num=${num}`];
    if (after) args.push("-f", `after=${after}`);
    const { stdout } = await execFileAsync("gh", args, { encoding: "utf8", maxBuffer: MAX_BUFFER });
    const pr = JSON.parse(stdout)?.data?.repository?.pullRequest;
    if (!pr) throw new Error("PR not found or no data returned");
    const conn = pick(pr);
    nodes.push(...(conn?.nodes ?? []));
    if (!conn?.pageInfo?.hasNextPage) break;
    after = conn.pageInfo.endCursor;
  }
  return nodes;
}

server.tool(
  "list_pr_comments",
  "List a GitHub PR's review-thread, review-summary, and conversation comments as a normalized JSON triage queue. Skips resolved threads and empty bodies by default. Inline items carry a threadId for resolve_pr_thread.",
  {
    prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)"),
    includeResolved: z.boolean().optional().describe("Include already-resolved review threads (default false)"),
  },
  async ({ prUrl, includeResolved }) => {
    const parsed = parsePrUrl(prUrl);
    if (!parsed) return text("Error: Invalid PR URL. Expected https://github.com/<owner>/<repo>/pull/<number>");
    const [owner, repo] = parsed.ownerRepo.split("/");

    let pr: any;
    try {
      const [threads, reviews, comments] = await Promise.all([
        fetchAllPrNodes(THREADS_Q, owner, repo, parsed.number, (p) => p.reviewThreads),
        fetchAllPrNodes(REVIEWS_Q, owner, repo, parsed.number, (p) => p.reviews),
        fetchAllPrNodes(CONV_Q, owner, repo, parsed.number, (p) => p.comments),
      ]);
      pr = { reviewThreads: { nodes: threads }, reviews: { nodes: reviews }, comments: { nodes: comments } };
    } catch (err: any) {
      return text(`Error fetching PR comments: ${err.message}`);
    }

    const items: any[] = [];
    for (const t of pr.reviewThreads?.nodes ?? []) {
      if (t.isResolved && !includeResolved) continue;
      const all = t.comments?.nodes ?? [];
      const c = all[0];
      if (!c || !c.body?.trim()) continue;
      items.push({
        kind: "inline",
        threadId: t.id,
        isResolved: t.isResolved,
        isOutdated: t.isOutdated,
        path: c.path,
        line: c.line,
        author: c.author?.login,
        body: c.body,
        url: c.url,
        replies: Math.max(0, all.length - 1),
        // Full thread context when there are replies, so triage sees follow-ups.
        ...(all.length > 1 ? { thread: all.map((n: any) => ({ author: n.author?.login, body: n.body })) } : {}),
      });
    }
    for (const r of pr.reviews?.nodes ?? []) {
      if (!r.body?.trim()) continue;
      items.push({ kind: "review", threadId: null, author: r.author?.login, body: r.body, state: r.state, url: r.url });
    }
    for (const c of pr.comments?.nodes ?? []) {
      if (!c.body?.trim()) continue;
      items.push({ kind: "conversation", threadId: null, author: c.author?.login, body: c.body, url: c.url });
    }
    items.forEach((it, i) => (it.index = i + 1));

    const skippedResolved = includeResolved
      ? 0
      : (pr.reviewThreads?.nodes ?? []).filter((t: any) => t.isResolved).length;

    return text(
      JSON.stringify(
        { pr: { owner, repo, number: Number(parsed.number) }, total: items.length, skippedResolved, items },
        null,
        2,
      ),
    );
  },
);

// ── resolve_pr_thread ───────────────────────────────────────────────
const REPLY_MUT =
  `mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{id url}}}`;
const RESOLVE_MUT = `mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}`;

server.tool(
  "resolve_pr_thread",
  "Optionally post a reply to a PR review thread, then mark it resolved. Use threadId from list_pr_comments (inline items only).",
  {
    threadId: z.string().describe("Review thread node ID from list_pr_comments"),
    replyBody: z.string().optional().describe("Markdown reply to post before resolving (omit to resolve silently)"),
  },
  async ({ threadId, replyBody }) => {
    const done: string[] = [];
    if (replyBody?.trim()) {
      try {
        await execFileAsync(
          "gh",
          ["api", "graphql", "-f", `query=${REPLY_MUT}`, "-f", `t=${threadId}`, "-f", `b=${replyBody}`],
          { encoding: "utf8", maxBuffer: MAX_BUFFER },
        );
        done.push("replied");
      } catch (err: any) {
        return text(`Error posting reply: ${err.message}`);
      }
    }
    try {
      const { stdout } = await execFileAsync(
        "gh",
        ["api", "graphql", "-f", `query=${RESOLVE_MUT}`, "-f", `id=${threadId}`],
        { encoding: "utf8", maxBuffer: MAX_BUFFER },
      );
      const resolved = JSON.parse(stdout)?.data?.resolveReviewThread?.thread?.isResolved;
      done.push(resolved ? "resolved" : "resolve returned unexpected response");
    } catch (err: any) {
      return text(`Error resolving thread: ${err.message}`);
    }
    return text(`Thread ${threadId}: ${done.join(", ")}`);
  },
);

// ── request_copilot_review ──────────────────────────────────────────
// Primary: native `gh pr edit --add-reviewer @copilot` (gh 2.88+). Verify it
// landed in reviewRequests (gh can silently no-op). Fallback: GraphQL
// requestReviews with the repo-specific Copilot bot node id resolved from
// assignableUsers. `--add-reviewer Copilot` (no @) and the REST endpoint both
// fail/no-op, so don't use them.
const COPILOT_LOOKUP =
  `query($owner:String!,$repo:String!){repository(owner:$owner,name:$repo){assignableUsers(first:100,query:"copilot"){nodes{login id}}}}`;
const REQUEST_REVIEW_MUT =
  `mutation($prId:ID!,$uid:ID!){requestReviews(input:{pullRequestId:$prId,userIds:[$uid],union:true}){pullRequest{number}}}`;

// Throws on gh/parse failure so the caller can distinguish "not requested"
// (false) from "couldn't check" (auth/network error) instead of masking it.
async function copilotIsRequested(prUrl: string): Promise<boolean> {
  const { stdout } = await execFileAsync("gh", ["pr", "view", prUrl, "--json", "reviewRequests"], {
    encoding: "utf8",
    maxBuffer: MAX_BUFFER,
  });
  const reqs = JSON.parse(stdout)?.reviewRequests ?? [];
  return reqs.some((r: any) => /copilot/i.test(r.login ?? r.name ?? r.slug ?? ""));
}

server.tool(
  "request_copilot_review",
  "Request a GitHub Copilot code review on a PR. Tries the native `gh pr edit --add-reviewer @copilot` and verifies it stuck; falls back to the requestReviews GraphQL mutation with the resolved Copilot bot id.",
  { prUrl: z.string().describe("Full GitHub PR URL (https://github.com/owner/repo/pull/N)") },
  async ({ prUrl }) => {
    const parsed = parsePrUrl(prUrl);
    if (!parsed) return text("Error: Invalid PR URL. Expected https://github.com/<owner>/<repo>/pull/<number>");
    const [owner, repo] = parsed.ownerRepo.split("/");

    // 1. Native @copilot (gh 2.88+)
    try {
      await execFileAsync("gh", ["pr", "edit", prUrl, "--add-reviewer", "@copilot"], {
        encoding: "utf8",
        maxBuffer: MAX_BUFFER,
      });
    } catch {
      /* fall through to GraphQL */
    }
    try {
      if (await copilotIsRequested(prUrl)) {
        return text(`Copilot review requested on PR #${parsed.number} (${owner}/${repo}) via @copilot`);
      }
    } catch (err: any) {
      return text(`Error verifying Copilot reviewer (gh pr view): ${err.message}`);
    }

    // 2. GraphQL fallback — resolve Copilot bot node id
    let botId: string | undefined;
    try {
      const { stdout } = await execFileAsync(
        "gh",
        ["api", "graphql", "-f", `query=${COPILOT_LOOKUP}`, "-f", `owner=${owner}`, "-f", `repo=${repo}`],
        { encoding: "utf8", maxBuffer: MAX_BUFFER },
      );
      const nodes = JSON.parse(stdout)?.data?.repository?.assignableUsers?.nodes ?? [];
      const bot =
        nodes.find((n: any) => n.login?.toLowerCase() === "copilot") ??
        nodes.find((n: any) => /copilot/i.test(n.login ?? ""));
      botId = bot?.id;
    } catch (err: any) {
      return text(`Error resolving Copilot reviewer: ${err.message}`);
    }
    if (!botId) {
      return text(
        `Error: @copilot reviewer did not stick and no copilot user found in assignableUsers for ${owner}/${repo}. ` +
          `Confirm Copilot code review is enabled for the repo, then retry.`,
      );
    }

    // 3. Resolve PR node id + requestReviews
    let prId: string;
    try {
      const { stdout } = await execFileAsync("gh", ["pr", "view", prUrl, "--json", "id", "--jq", ".id"], {
        encoding: "utf8",
        maxBuffer: MAX_BUFFER,
      });
      prId = stdout.trim();
    } catch (err: any) {
      return text(`Error resolving PR node id: ${err.message}`);
    }
    if (!prId) return text("Error: Could not resolve PR node id");

    try {
      const { stdout } = await execFileAsync(
        "gh",
        ["api", "graphql", "-f", `query=${REQUEST_REVIEW_MUT}`, "-F", `prId=${prId}`, "-F", `uid=${botId}`],
        { encoding: "utf8", maxBuffer: MAX_BUFFER },
      );
      const num = JSON.parse(stdout)?.data?.requestReviews?.pullRequest?.number;
      return text(`Copilot review requested on PR #${num ?? parsed.number} (${owner}/${repo}) via GraphQL`);
    } catch (err: any) {
      return text(`Error requesting Copilot review: ${err.message}`);
    }
  },
);

// ── wait_for_copilot_review ─────────────────────────────────────────
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

server.tool(
  "wait_for_copilot_review",
  "Poll a PR until GitHub Copilot has posted its review (it submits a COMMENTED review, usually within ~30s–2min), then return. Use after request_copilot_review, before triaging comments.",
  {
    prUrl: z.string().describe("Full GitHub PR URL"),
    timeoutSec: z.number().optional().describe("Max seconds to wait (default 180)"),
    pollSec: z.number().optional().describe("Seconds between polls (default 10)"),
  },
  async ({ prUrl, timeoutSec, pollSec }) => {
    if (!parsePrUrl(prUrl)) return text("Error: Invalid PR URL format");
    const timeout = (timeoutSec ?? 180) * 1000;
    const poll = (pollSec ?? 10) * 1000;
    const start = Date.now();
    let errs = 0;

    while (Date.now() - start < timeout) {
      try {
        const { stdout } = await execFileAsync("gh", ["pr", "view", prUrl, "--json", "reviews"], {
          encoding: "utf8",
          maxBuffer: MAX_BUFFER,
        });
        const reviews = JSON.parse(stdout)?.reviews ?? [];
        const copilot = reviews.filter((r: any) => /copilot/i.test(r.author?.login ?? ""));
        if (copilot.length > 0) {
          const elapsed = Math.round((Date.now() - start) / 1000);
          return text(`Copilot review posted after ~${elapsed}s (${copilot.length} review event(s)). Ready to triage.`);
        }
        errs = 0;
      } catch (err: any) {
        if (++errs >= 3) return text(`Error polling PR reviews (3 consecutive failures): ${err.message}`);
      }
      await sleep(poll);
    }
    return text(`Timed out after ${timeoutSec ?? 180}s — Copilot review not yet posted. Re-run or triage what's there.`);
  },
);

// ── start ───────────────────────────────────────────────────────────
const transport = new StdioServerTransport();
await server.connect(transport);
