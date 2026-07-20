package target

import (
	"strings"
	"text/template"

	"clanker/src/spec"
)

// docCtx is the template context: exactly one flag is true per target.
type docCtx struct {
	Claude   bool
	Opencode bool
}

func (Claude) RenderDoc(d spec.Doc) OutputFile {
	return OutputFile{
		RelPath: "claude/.claude/CLAUDE.md",
		Content: execDoc(d.Shared, docCtx{Claude: true}) + d.ClaudeTail,
	}
}

func (Opencode) RenderDoc(d spec.Doc) OutputFile {
	return OutputFile{
		RelPath: "opencode/.config/opencode/AGENTS.md",
		Content: execDoc(d.Shared, docCtx{Opencode: true}) + d.OpencodeTail,
	}
}

// execDoc renders the shared template. It panics on a bad template — the text is
// compile-time config, so an error is a bug to fix, not a runtime condition.
func execDoc(tmpl string, ctx docCtx) string {
	t := template.Must(template.New("doc").Parse(tmpl))
	var b strings.Builder
	if err := t.Execute(&b, ctx); err != nil {
		panic("target: render doc: " + err.Error())
	}
	return b.String()
}
