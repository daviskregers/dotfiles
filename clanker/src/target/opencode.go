package target

import "clanker/src/spec"

type Opencode struct{}

func (Opencode) Name() string { return "opencode" }

func (Opencode) CommandDir() string { return "opencode/.config/opencode/command" }

func (Opencode) RenderCommand(c spec.Command) []OutputFile {
	o := c.Overlay.Opencode
	content := renderFile(
		[]fmField{
			{"description", pick(o.Description, c.Description)},
			{"agent", o.Agent},
		},
		pick(o.Body, c.Body),
		opencodeArgForm(c.Args),
	)
	return []OutputFile{{
		RelPath: Opencode{}.CommandDir() + "/" + c.Name + ".md",
		Content: content,
	}}
}

// opencodeArgForm maps the neutral arg style to opencode's token: all args are
// $ARGUMENTS, a first positional is $1.
func opencodeArgForm(a spec.ArgStyle) string {
	if a == spec.ArgsFirstPositional {
		return "$1"
	}
	return "$ARGUMENTS"
}
