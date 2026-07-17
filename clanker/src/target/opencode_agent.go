package target

import "clanker/src/spec"

const opencodeJSON = "opencode/.config/opencode/opencode.json"

func (Opencode) RenderAgent(a spec.Agent) AgentOutput {
	// opencode prompts announce skills in prose, but inconsistently across agents,
	// so the divergence is carried as an authored overlay body, not auto-injected.
	promptBody := pick(a.Overlay.Opencode.Body, a.Body)

	tools := map[string]any{"*": false}
	if a.ReadOnly {
		tools["read"], tools["grep"], tools["glob"] = true, true, true
	}
	if len(a.Bash) > 0 {
		tools["bash"] = true
	}

	frag := map[string]any{
		"description": pick(a.Overlay.Opencode.Description, a.Description),
		"mode":        "subagent",
		"prompt":      "{file:./prompts/" + a.Name + ".md}",
		"temperature": 0.1,
		"tools":       tools,
	}
	if len(a.Bash) > 0 {
		bash := map[string]any{"*": "deny"}
		for _, p := range a.Bash {
			bash[p+"*"] = "allow"
		}
		frag["permission"] = map[string]any{"bash": bash}
	}

	return AgentOutput{
		Files: []OutputFile{{
			RelPath: "opencode/.config/opencode/prompts/" + a.Name + ".md",
			Content: promptBody,
		}},
		Config: &ConfigMerge{File: opencodeJSON, Path: []string{"agent", a.Name}, Value: frag},
	}
}
