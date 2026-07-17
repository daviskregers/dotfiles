package target

import (
	"strconv"
	"strings"

	"clanker/src/spec"
)

func (Claude) RenderAgent(a spec.Agent) AgentOutput {
	var b strings.Builder
	b.WriteString("---\n")
	b.WriteString("name: " + a.Name + "\n")
	b.WriteString("description: " + a.Description + "\n")
	b.WriteString("tools: " + claudeTools(a) + "\n")
	if a.Model != "" {
		b.WriteString("model: " + a.Model + "\n")
	}
	if a.MaxTurns > 0 {
		b.WriteString("maxTurns: " + strconv.Itoa(a.MaxTurns) + "\n")
	}
	if len(a.Skills) > 0 {
		b.WriteString("skills:\n")
		for _, s := range a.Skills {
			b.WriteString("  - " + s + "\n")
		}
	}
	if len(a.Bash) > 0 {
		b.WriteString(claudeBashHook(a.Bash))
	}
	b.WriteString("---\n\n")
	b.WriteString(a.Body)

	return AgentOutput{Files: []OutputFile{{
		RelPath: "claude/.claude/agents/" + a.Name + ".md",
		Content: b.String(),
	}}}
}

// claudeTools builds the `tools:` allowlist from the agent's semantic capabilities.
func claudeTools(a spec.Agent) string {
	var tools []string
	if a.ReadOnly {
		tools = append(tools, "Read", "Grep", "Glob")
	}
	if len(a.Bash) > 0 {
		tools = append(tools, "Bash")
	}
	return strings.Join(tools, ", ")
}

// claudeBashHook emits the fixed PreToolUse hook that restricts Bash to the given
// command prefixes via validate-bash.sh.
func claudeBashHook(prefixes []string) string {
	quoted := make([]string, len(prefixes))
	for i, p := range prefixes {
		quoted[i] = "'" + p + "'"
	}
	return "hooks:\n" +
		"  PreToolUse:\n" +
		"    - matcher: \"Bash\"\n" +
		"      hooks:\n" +
		"        - type: command\n" +
		"          command: \"bash ~/.claude/scripts/validate-bash.sh " + strings.Join(quoted, " ") + "\"\n"
}
