package target

import (
	"strconv"
	"strings"

	"clanker/src/spec"
)

// ToolDir is claude's MCP-server directory, relative to the dotfiles root. Unlike
// opencode's per-tool wrappers, claude vendors the neutral cores here verbatim and
// registers them all from a generated index.ts.
func (Claude) ToolDir() string { return "claude/.claude/mcp-tools" }

// ClaudeToolFiles is everything claude's MCP server needs: the shared util
// modules + each tool's neutral core (both vendored verbatim) + the generated
// index.ts that registers them.
func ClaudeToolFiles(tools []spec.Tool, utils []spec.ToolUtil) []OutputFile {
	dir := Claude{}.ToolDir()
	var files []OutputFile
	for _, u := range utils {
		files = append(files, OutputFile{RelPath: dir + "/" + u.Name, Content: u.Content})
	}
	for _, t := range tools {
		files = append(files, OutputFile{RelPath: dir + "/" + kebab(t.Name) + ".ts", Content: t.Core})
	}
	return append(files, RenderClaudeIndex(tools))
}

// RenderClaudeIndex generates the MCP server entrypoint: it imports each tool
// core's execute (aliased to avoid the shared `execute` name colliding) and
// registers it on an McpServer, wrapping the string return in text() and
// injecting PROJECT_DIR as the base directory.
func RenderClaudeIndex(tools []spec.Tool) OutputFile {
	var b strings.Builder
	b.WriteString(`import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"` + "\n")
	b.WriteString(`import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"` + "\n")
	b.WriteString(`import { z } from "zod"` + "\n")
	for _, t := range tools {
		b.WriteString("import { execute as " + camel(t.Name) + ` } from "./` + kebab(t.Name) + `"` + "\n")
	}
	b.WriteString("\nconst PROJECT_DIR = process.env.PROJECT_DIR || process.cwd()\n\n")
	b.WriteString("function text(msg: string) {\n\treturn { content: [{ type: \"text\" as const, text: msg }] }\n}\n\n")
	b.WriteString("const server = new McpServer({ name: \"claude-custom-tools\", version: \"1.0.0\" })\n\n")
	for _, t := range tools {
		b.WriteString("server.tool(\n")
		b.WriteString("\t" + strconv.Quote(t.Name) + ",\n")
		b.WriteString("\t" + strconv.Quote(t.Description) + ",\n")
		b.WriteString("\t{\n")
		for _, a := range t.Args {
			b.WriteString("\t\t" + a.Name + ": z." + a.Type + "()")
			if a.Optional {
				b.WriteString(".optional()")
			}
			b.WriteString(".describe(" + strconv.Quote(a.Describe) + "),\n")
		}
		b.WriteString("\t},\n")
		b.WriteString("\tasync (args) => text(await " + camel(t.Name) + "(args, { directory: PROJECT_DIR })),\n")
		b.WriteString(")\n\n")
	}
	b.WriteString("const transport = new StdioServerTransport()\n")
	b.WriteString("await server.connect(transport)\n")
	return OutputFile{RelPath: Claude{}.ToolDir() + "/index.ts", Content: b.String()}
}

// camel converts a snake_case tool name to a camelCase import alias.
func camel(name string) string {
	parts := strings.Split(name, "_")
	for i := 1; i < len(parts); i++ {
		if parts[i] != "" {
			parts[i] = strings.ToUpper(parts[i][:1]) + parts[i][1:]
		}
	}
	return strings.Join(parts, "")
}
