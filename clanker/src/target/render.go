package target

import (
	"strings"

	"clanker/src/spec"
)

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

// argsToken is the neutral placeholder each target rewrites to its own form
// ($ARGUMENTS for claude, $1 for opencode).
const argsToken = "{{args}}"

func pick(override, fallback string) string {
	if override != "" {
		return override
	}
	return fallback
}

// fmField is one frontmatter entry, emitted in order and skipped when empty.
type fmField struct{ key, value string }

// renderFile assembles a command file: frontmatter, a blank line, then the body
// with argsToken rewritten to argForm.
func renderFile(fields []fmField, body, argForm string) string {
	var b strings.Builder
	b.WriteString("---\n")
	for _, f := range fields {
		if f.value == "" {
			continue
		}
		b.WriteString(f.key)
		b.WriteString(": ")
		b.WriteString(f.value)
		b.WriteString("\n")
	}
	b.WriteString("---\n\n")
	b.WriteString(strings.ReplaceAll(body, argsToken, argForm))
	return b.String()
}
