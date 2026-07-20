package spec

// Agent is the single source for one subagent. Its behavior (tools, bash access,
// skills) is expressed semantically and translated to each tool's dialect:
// claude frontmatter + a bash-validation hook, opencode a tools/permission map.
type Agent struct {
	Name        string
	Description string
	Body        string   // shared system prompt
	Model       string   // claude frontmatter model (per-target; opencode omits)
	MaxTurns    int      // claude-only turn cap; 0 = omit
	Mode        string   // opencode agent mode: "" = subagent (default), or "primary"
	Read        bool     // Read/Grep/Glob tools
	Write       bool     // Write tool
	Webfetch    bool     // opencode webfetch tool
	Bash        []string // allowed bash prefixes ("git diff"); nil = no bash
	MCP         []string // custom-tools this agent may use; non-empty → claude mcpServers: [custom-tools]
	Deny        []string // claude `disallowedTools:` denylist; when set, overrides the derived allowlist
	Skills      []string // claude `skills:` frontmatter; opencode carries "Load X" in the prompt
	Overlay     AgentOverlays
}

type AgentOverlay struct {
	Description string
	Body        string
	Write       *bool // per-target override of Agent.Write (nil = inherit)
}

type AgentOverlays struct {
	Claude   AgentOverlay
	Opencode AgentOverlay
}
