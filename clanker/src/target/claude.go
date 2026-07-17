package target

import "clanker/src/spec"

type Claude struct{}

func (Claude) Name() string { return "claude" }

func (Claude) CommandDir() string { return "claude/.claude/commands" }

func (Claude) RenderCommand(c spec.Command) []OutputFile {
	o := c.Overlay.Claude
	content := renderFile(
		[]fmField{
			{"description", pick(o.Description, c.Description)},
			{"argument-hint", o.ArgumentHint},
			{"allowed-tools", o.AllowedTools},
		},
		pick(o.Body, c.Body),
		"$ARGUMENTS",
	)
	return []OutputFile{{
		RelPath: Claude{}.CommandDir() + "/" + c.Name + ".md",
		Content: content,
	}}
}
