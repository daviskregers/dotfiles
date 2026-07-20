package target_test

import (
	"strings"
	"testing"

	"clanker/src/spec"
	"clanker/src/target"
)

func TestRenderToolOpencode(t *testing.T) {
	tl := spec.Tool{
		Name:        "demo_tool",
		Description: "A demo",
		Args: []spec.ToolArg{
			{Name: "url", Type: "string", Describe: "the URL"},
			{Name: "count", Type: "number", Optional: true, Describe: "how many"},
		},
		Core: "import { x } from \"./shared\"\n\nexport async function execute(args: { url: string }): Promise<string> {\n    return x(args.url)\n}\n",
	}

	out := target.RenderToolOpencode(tl)

	if out.RelPath != "opencode/.config/opencode/tools/demo-tool.ts" { // snake → kebab filename
		t.Errorf("path: %q", out.RelPath)
	}
	c := out.Content
	checks := []string{
		`import { tool } from "@opencode-ai/plugin"`,
		`import { x } from "./shared"`,                  // core inlined verbatim
		"async function execute(args: { url: string })", // export stripped
		`description: "A demo",`,
		`url: tool.schema.string().describe("the URL"),`,
		`count: tool.schema.number().optional().describe("how many"),`,
		"execute,", // wrapper references the inlined function
	}
	for _, want := range checks {
		if !strings.Contains(c, want) {
			t.Errorf("missing %q in:\n%s", want, c)
		}
	}
	if strings.Contains(c, "export async function execute") {
		t.Error("the core's export should be stripped when inlined")
	}
}
