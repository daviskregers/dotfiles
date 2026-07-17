// Package config is the data fed into the generator: the command definitions and
// their embedded prompt bodies. Edit here to change what is generated, not how.
package config

import (
	"embed"
	"fmt"

	"clanker/src/spec"
)

//go:embed bodies/*.md
var bodies embed.FS

// body returns an embedded markdown body, panicking if absent — the body set is
// fixed at compile time, so a missing file is a bug to fix, not a runtime case.
func body(name string) string {
	b, err := bodies.ReadFile("bodies/" + name)
	if err != nil {
		panic(fmt.Sprintf("config: missing body %q: %v", name, err))
	}
	return string(b)
}

var Commands = []spec.Command{
	{
		Name:        "commit",
		Description: "Commit staged changes with a conventional commit message",
		Body:        body("commit.md"),
		Overlay: spec.Overlays{
			// opencode inlines the full steps and delegates to its git-committer agent.
			Opencode: spec.OpencodeOverlay{Agent: "git-committer", Body: body("commit.opencode.md")},
		},
	},
}
