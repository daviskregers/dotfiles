package spec

// HookEvent is a claude hook event (settings.json key). Typed so a mistyped event
// is a compile error, not a silently-dead hook.
type HookEvent string

const (
	PreToolUse       HookEvent = "PreToolUse"
	PostToolUse      HookEvent = "PostToolUse"
	UserPromptSubmit HookEvent = "UserPromptSubmit"
	Stop             HookEvent = "Stop"
)

// OpencodeEvent is the opencode plugin hook a hook registers with. Empty = claude-only
// (no opencode plugin emitted). V2 registers each hook on the domain that owns it:
// Tool* on ctx.tool, ChatMessage on ctx.session, SessionIdle as an event subscription.
type OpencodeEvent string

const (
	NoOpencodeEvent   OpencodeEvent = ""
	ToolExecuteBefore OpencodeEvent = "tool.execute.before"
	ToolExecuteAfter  OpencodeEvent = "tool.execute.after"
	// ChatMessage registers the session prompt hook (V2's successor to V1's
	// chat.message); the name is retained from the event it replaced.
	ChatMessage OpencodeEvent = "session.prompt"
	// SessionIdle subscribes to the event stream filtered to session.idle. Idle has
	// already fired, so the hook can neither block nor mutate that turn — a
	// block/context result is injected as a prompt, which re-activates the turn.
	SessionIdle OpencodeEvent = "session.idle"
)

// Hook is the single source for one hook. Its logic (Core, TS: exports
// `run(input, ctx): HookResult`) is shared; the targets wrap it — claude as a
// stdin→stdout entrypoint registered in settings.json, opencode as a plugin on the
// mapped event. A hook with NoOpencodeEvent is claude-only.
type Hook struct {
	Name          string // kebab, e.g. "dangerous-command-guard"
	Event         HookEvent
	Matcher       string // claude settings.json matcher (free-form: "Bash", "Write|Edit", "")
	OpencodeEvent OpencodeEvent
	Core          string // neutral TS module exporting run(input, ctx): HookResult
}
