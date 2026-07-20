package target

import (
	"strconv"
	"strings"

	"clanker/src/spec"
)

// RenderToolOpencode emits an opencode custom-tool file: the shared preamble
// (imports + helper consts) followed by a `tool()` export wrapping the neutral
// execute body. The execute return (a string) passes through unchanged.
func RenderToolOpencode(t spec.Tool) OutputFile {
	// Inline the neutral core module (its `execute` becomes a local function), then
	// wrap it in opencode's tool() export. prettier normalizes the final layout.
	core := strings.Replace(t.Core, "export async function execute", "async function execute", 1)

	var b strings.Builder
	b.WriteString(`import { tool } from "@opencode-ai/plugin"` + "\n")
	b.WriteString(strings.TrimRight(core, "\n") + "\n\n")
	b.WriteString("export default tool({\n")
	b.WriteString("    description: " + strconv.Quote(t.Description) + ",\n")
	b.WriteString("    args: {\n")
	for _, a := range t.Args {
		line := "        " + a.Name + ": tool.schema." + a.Type + "()"
		if a.Optional {
			line += ".optional()"
		}
		line += ".describe(" + strconv.Quote(a.Describe) + "),\n"
		b.WriteString(line)
	}
	b.WriteString("    },\n")
	b.WriteString("    execute,\n")
	b.WriteString("})\n")
	return OutputFile{
		RelPath: "opencode/.config/opencode/tools/" + kebab(t.Name) + ".ts",
		Content: b.String(),
	}
}

// kebab converts a snake_case tool name to the kebab-case opencode filename.
func kebab(name string) string { return strings.ReplaceAll(name, "_", "-") }
