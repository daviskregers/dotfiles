package target

import (
	"strconv"
	"strings"

	"clanker/src/spec"
)

// ToolDir is opencode's custom-tools directory, relative to the dotfiles root.
func (Opencode) ToolDir() string { return "opencode/.config/opencode/tools" }

// RenderTools emits opencode's custom-tool files (nil when there are none).
func (Opencode) RenderTools(tools []spec.Tool, utils []spec.ToolUtil) []OutputFile {
	if len(tools) == 0 {
		return nil
	}
	return OpencodeToolFiles(tools, utils)
}

// OpencodeToolFiles is everything opencode's tools dir needs: the shared util
// modules (vendored verbatim) + each tool wrapped as a tool() export.
func OpencodeToolFiles(tools []spec.Tool, utils []spec.ToolUtil) []OutputFile {
	dir := Opencode{}.ToolDir()
	var files []OutputFile
	for _, u := range utils {
		files = append(files, OutputFile{RelPath: dir + "/" + u.Name, Content: u.Content})
	}
	for _, t := range tools {
		files = append(files, RenderToolOpencode(t))
	}
	return files
}

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
		RelPath: Opencode{}.ToolDir() + "/" + kebab(t.Name) + ".ts",
		Content: b.String(),
	}
}

// kebab converts a snake_case tool name to the kebab-case opencode filename.
func kebab(name string) string { return strings.ReplaceAll(name, "_", "-") }
