// Package spec defines the schema every clanker artifact must satisfy: the
// engine renders these types, the config package supplies instances.
package spec

// ArgStyle says how the {{args}} token in a body should render.
type ArgStyle int

const (
	ArgsAll             ArgStyle = iota // all invocation args ($ARGUMENTS)
	ArgsFirstPositional                 // the first positional arg (opencode $1)
)

// ClaudeOverlay holds claude-only values. Zero-valued fields inherit the shared spec.
type ClaudeOverlay struct {
	Description  string
	Body         string
	ArgumentHint string // frontmatter `argument-hint:`
	AllowedTools string // frontmatter `allowed-tools:` (raw value, verbatim)
}

// OpencodeOverlay holds opencode-only values. Zero-valued fields inherit the shared spec.
type OpencodeOverlay struct {
	Description string
	Body        string
	Agent       string // frontmatter `agent:` — subagent a command delegates to
}

// Overlays groups per-target overrides as fields, not map keys, so a mistyped
// target is a compile error and adding a target forces every consumer to handle it.
type Overlays struct {
	Claude   ClaudeOverlay
	Opencode OpencodeOverlay
}

type Command struct {
	Name        string
	Description string
	Body        string // {{args}} marks where invocation args go
	Args        ArgStyle
	Overlay     Overlays
}
