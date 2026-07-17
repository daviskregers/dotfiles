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
	ReadOnly    bool     // no write/edit
	Bash        []string // allowed bash prefixes ("git diff"); nil = no bash
	Skills      []string // claude `skills:` frontmatter; opencode injects "Load X" in prompt
	Overlay     AgentOverlays
}

type AgentOverlay struct {
	Description string
	Body        string
}

type AgentOverlays struct {
	Claude   AgentOverlay
	Opencode AgentOverlay
}
