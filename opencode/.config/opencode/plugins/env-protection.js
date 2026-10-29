// Blocks the agent from reading .env files. Deny by throwing, per the V2 tool hook
// contract — the throw surfaces to the model as the reason.
export default {
    id: "env-protection",
    async setup(ctx) {
        await ctx.tool.hook("execute.before", (event) => {
            if (event.tool !== "read") return
            const filePath = event.input?.filePath
            if (typeof filePath === "string" && filePath.includes(".env")) {
                throw new Error("Do not read .env files")
            }
        })
    },
}
