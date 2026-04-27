import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "child_process";
import { promisify } from "util";
import * as fs from "fs";
import * as path from "path";

const execFileAsync = promisify(execFile);
const MAX_BUFFER = 10 * 1024 * 1024;
const MAX_COMMENT_BYTES = 60_000;

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

async function ensureArtifactsDir(): Promise<string> {
  const dir = path.join(PROJECT_DIR, ".ai-artifacts");
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
  "Save a code review to .ai-artifacts/ with timestamped filename",
  { content: z.string().describe("Full review markdown content") },
  async ({ content }) => {
    const dir = await ensureArtifactsDir();
    const suffix = Math.random().toString(36).slice(2, 6);
    const filePath = path.join(dir, `review_${timestamp()}_${suffix}.md`);
    await fs.promises.writeFile(filePath, content, "utf-8");
    return text(`Review saved to ${path.relative(process.cwd(), filePath)}`);
  },
);

// ── save_explanation ────────────────────────────────────────────────
server.tool(
  "save_explanation",
  "Save an HTML explanation to .ai-artifacts/ and open in default browser",
  {
    content: z.string().describe("Full HTML content"),
    title: z.string().optional().describe("Short slug for filename (e.g. 'jwt-auth-flow')"),
  },
  async ({ content, title }) => {
    const dir = await ensureArtifactsDir();
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

    try {
      const { stdout } = await execFileAsync("gh", ["pr", "comment", prUrl, "--body-file", resolved], {
        encoding: "utf8",
      });
      return text(`Comment posted to ${prUrl}\n${stdout}`.trim());
    } catch (err: any) {
      return text(`Error posting comment: ${err.message}`);
    }
  },
);

// ── start ───────────────────────────────────────────────────────────
const transport = new StdioServerTransport();
await server.connect(transport);
