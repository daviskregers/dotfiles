package target

import "clanker/src/spec"

type Claude struct{}

func (Claude) Name() string { return "claude" }

func (Claude) CommandDir() string { return "claude/.claude/commands" }

func (Claude) RenderCommand(c spec.Command) []OutputFile {
	o := c.Overlay.Claude
	body := c.Body
	if generatesBody(c) {
		body = "Use " + c.Delegates.Agent.Name + " agent to " + c.Delegates.Task + ".\n\n{{.Args}}\n"
	}
	content := renderFile(
		[]fmField{
			{"description", pick(o.Description, c.Description)},
			{"argument-hint", o.ArgumentHint},
			{"allowed-tools", o.AllowedTools},
		},
		body,
		// claude has one arg token regardless of spec.ArgStyle — only opencode
		// distinguishes a first positional ($1) from all args ($ARGUMENTS).
		renderCtx{Claude: true, Args: "$ARGUMENTS"},
	)
	return []OutputFile{{
		RelPath: Claude{}.CommandDir() + "/" + c.Name + ".md",
		Content: content,
	}}
}
