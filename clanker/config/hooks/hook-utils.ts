// Neutral hook result — each target adapter translates it: claude serializes to
// its stdout schema, opencode maps to throw / output mutation / message part.
export type HookResult =
    | { kind: "allow"; updatedInput?: Record<string, unknown> }
    | { kind: "deny"; reason: string }
    | { kind: "context"; text: string }
    | { kind: "block"; reason: string }
    | { kind: "none" }

// Injected per target: shell + base dir (claude: node child_process/cwd; opencode: $ / directory).
export type HookCtx = { directory: string }
