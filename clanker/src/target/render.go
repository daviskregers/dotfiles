package target

import (
	"strings"
	"text/template"

	"clanker/src/spec"
)

// renderCtx is the template context for every body: exactly one target flag is
// true, and Args is that target's argument token ($ARGUMENTS / $1) for commands.
type renderCtx struct {
	Claude   bool
	Opencode bool
	Args     string
}

// execBody renders a body template. It panics on a bad template — bodies are
// compile-time config, so an error is a bug to fix, not a runtime condition.
func execBody(tmpl string, c renderCtx) string {
	t := template.Must(template.New("body").Parse(tmpl))
	var b strings.Builder
	if err := t.Execute(&b, c); err != nil {
		panic("target: render body: " + err.Error())
	}
	return b.String()
}

// generatesBody reports whether a command's bodies are generated from its
// delegation (Task set) rather than authored.
func generatesBody(c spec.Command) bool {
	return c.Delegates != nil && c.Delegates.Task != ""
}

// overrideBool returns *o when set, else base — for per-target capability overrides.
func overrideBool(o *bool, base bool) bool {
	if o != nil {
		return *o
	}
	return base
}

// capFirst upper-cases the first byte (tasks are ASCII verb phrases).
func capFirst(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

func pick(override, fallback string) string {
	if override != "" {
		return override
	}
	return fallback
}

// fmField is one frontmatter entry, emitted in order and skipped when empty.
type fmField struct{ key, value string }

// renderFile assembles a file: frontmatter, a blank line, then the rendered body.
func renderFile(fields []fmField, body string, c renderCtx) string {
	var b strings.Builder
	b.WriteString("---\n")
	for _, f := range fields {
		if f.value == "" {
			continue
		}
		b.WriteString(f.key + ": " + f.value + "\n")
	}
	b.WriteString("---\n\n")
	b.WriteString(execBody(body, c))
	return b.String()
}

// --- shared string helpers (used across targets) ---

// camel converts snake_case to camelCase (tool core import aliases).
func camel(name string) string {
	parts := strings.Split(name, "_")
	for i := 1; i < len(parts); i++ {
		if parts[i] != "" {
			parts[i] = strings.ToUpper(parts[i][:1]) + parts[i][1:]
		}
	}
	return strings.Join(parts, "")
}

// kebab converts snake_case to kebab-case (opencode filenames).
func kebab(name string) string { return strings.ReplaceAll(name, "_", "-") }

// deExporter drops a hook core's top-level `export ` keywords when it's inlined into a
// generated file: the wrapper references `run` in file scope, and a stray export would
// look like a plugin to opencode's loader.
var deExporter = strings.NewReplacer(
	"export async function", "async function",
	"export function", "function",
	"export const", "const",
	"export type", "type",
)

func deExport(s string) string { return deExporter.Replace(s) }

// inlineCore returns a neutral hook core with its `import … from "./hook-utils"` line
// removed (the generated file imports the runtime itself) and its exports dropped.
func inlineCore(core string) string {
	var keep []string
	for _, l := range strings.Split(core, "\n") {
		if strings.Contains(l, `from "./hook-utils"`) {
			continue
		}
		keep = append(keep, l)
	}
	return deExport(strings.Join(keep, "\n"))
}
