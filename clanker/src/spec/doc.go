package spec

// Doc is a shared rules document rendered into each tool's global file
// (CLAUDE.md / AGENTS.md). Body is a Go text/template whose inline
// {{if .Claude}}/{{if .Opencode}} spans carry every divergence — shared prose is
// the default, per-target content the inline exception.
type Doc struct {
	Body string
}
