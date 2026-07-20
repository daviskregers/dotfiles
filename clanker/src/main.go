// Command clanker generates the per-tool config from the single source of truth
// in the config package.
package main

import (
	"flag"
	"fmt"
	"os"

	"clanker/config"
	"clanker/src/gen"
	"clanker/src/target"
)

func main() {
	out := flag.String("out", "..", "dotfiles root to write generated files under")
	flag.Parse()

	targets := target.Registry()
	if err := gen.Run(*out, config.Commands, config.Agents, config.Docs, config.Tools, config.ToolUtils, config.Hooks, config.HookUtils, targets); err != nil {
		fmt.Fprintln(os.Stderr, "clanker:", err)
		os.Exit(1)
	}
	fmt.Printf("clanker: generated %d command(s) + %d agent(s) + %d doc(s) + %d hook(s) × %d target(s) under %s\n",
		len(config.Commands), len(config.Agents), len(config.Docs), len(config.Hooks), len(targets), *out)
}
