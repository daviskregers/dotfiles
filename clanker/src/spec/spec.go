// Package spec defines the schema every clanker artifact must satisfy: the
// engine renders these types, the config package supplies instances.
package spec

// ArgStyle says how the {{args}} token in a body should render.
type ArgStyle int

const (
	ArgsAll             ArgStyle = iota // all invocation args ($ARGUMENTS)
	ArgsFirstPositional                 // the first positional arg (opencode $1)
)

// ClaudeOverlay holds claude-only frontmatter values. Body divergence lives inline
// in the shared template ({{if .Claude}}), not here.
type ClaudeOverlay struct {
	Description  string
	ArgumentHint string // frontmatter `argument-hint:`
	AllowedTools string // frontmatter `allowed-tools:` (raw value, verbatim)
}

// OpencodeOverlay holds opencode-only frontmatter values. Body divergence lives
// inline in the shared template ({{if .Opencode}}), not here.
type OpencodeOverlay struct {
	Description string
}

// Overlays groups per-target overrides as fields, not map keys, so a mistyped
// target is a compile error and adding a target forces every consumer to handle it.
type Overlays struct {
	Claude   ClaudeOverlay
	Opencode OpencodeOverlay
}

// Delegation says a command hands off to a subagent. Agent alone sets opencode's
// `agent:` frontmatter (bodies stay authored). Task additionally GENERATES both
// bodies — claude "Use <name> agent to <task>", opencode the task as a prompt —
// so a simple delegator needs no authored body at all.
type Delegation struct {
	Agent *Agent
	Task  string
}

type Command struct {
	Name        string
	Description string
	Body        string // {{args}} marks where invocation args go
	Args        ArgStyle
	Delegates   *Delegation // nil = self-contained command
	Overlay     Overlays
}
