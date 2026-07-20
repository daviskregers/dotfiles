package target

import "clanker/src/spec"

func (Claude) RenderDoc(d spec.Doc) OutputFile {
	return OutputFile{
		RelPath: "claude/.claude/CLAUDE.md",
		Content: execBody(d.Body, renderCtx{Claude: true}),
	}
}

func (Opencode) RenderDoc(d spec.Doc) OutputFile {
	return OutputFile{
		RelPath: "opencode/.config/opencode/AGENTS.md",
		Content: execBody(d.Body, renderCtx{Opencode: true}),
	}
}
