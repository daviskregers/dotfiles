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
