package spec

// Doc is a shared rules document rendered into each tool's global file
// (CLAUDE.md / AGENTS.md). Shared is a Go text/template whose inline
// {{if .Claude}}/{{if .Opencode}} spans carry the small wording/hook divergences;
// each target's tail holds its target-only trailing sections.
type Doc struct {
	Shared       string
	ClaudeTail   string
	OpencodeTail string
}
