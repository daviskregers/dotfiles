package config

import (
	"regexp"
	"strings"
)

// churnLimitToken is the placeholder bodies use where the threshold belongs. Deliberately
// not `{{...}}` — bodies are Go templates, so a template-shaped token would be resolved
// (and fail) by the renderer instead of here.
const churnLimitToken = "__CHURN_LIMIT__"

// The comprehension-nudge hook owns the churn threshold, and global.md / start.md have to
// quote the same number. Rather than duplicate it, the value is read back out of the hook
// core here and substituted into the prose — one source, checked at generate time.

var churnLimitRe = regexp.MustCompile(`(?m)^export const MIN_LINES = (\d+)$`)

// extractChurnLimit pulls the MIN_LINES literal out of a hook core.
func extractChurnLimit(core string) (string, bool) {
	m := churnLimitRe.FindStringSubmatch(core)
	if m == nil {
		return "", false
	}
	return m[1], true
}

// withChurnLimit substitutes the hook's threshold into a body's __CHURN_LIMIT__ tokens.
func withChurnLimit(text, core string) string {
	limit, ok := extractChurnLimit(core)
	if !ok {
		panic("config: comprehension-nudge core declares no `export const MIN_LINES = <n>` — " +
			"the prose threshold is read from it, so renaming it must not silently blank the number")
	}
	return strings.ReplaceAll(text, churnLimitToken, limit)
}
