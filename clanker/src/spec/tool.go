package spec

// Tool is the single source for one custom tool. Its logic (ExecuteBody, in
// TypeScript) and helper set live once; the target adapters wrap them — opencode
// as a `tool()` export, claude as an McpServer registration. ExecuteBody is a
// function body over (args, ctx) returning a string; each adapter injects ctx and
// wraps the return (opencode passes it through, claude wraps in text()).
type Tool struct {
	Name        string    // snake_case logical name (claude tool name); opencode file is kebab-case
	Description string    // LLM-facing description
	Args        []ToolArg // primitives only (string/boolean/number), optional + describe
	Core        string    // a valid standalone TS module: imports + helpers + `export async function execute(args): Promise<string>`
}

// ToolArg is one tool argument.
type ToolArg struct {
	Name     string
	Type     string // "string" | "boolean" | "number"
	Optional bool
	Describe string
}
