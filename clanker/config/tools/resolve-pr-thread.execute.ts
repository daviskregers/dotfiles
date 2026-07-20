const done: string[] = []
if (args.replyBody?.trim()) {
    try {
        await execFileAsync("gh", ["api", "graphql", "-f", `query=${REPLY_MUT}`, "-f", `t=${args.threadId}`, "-f", `b=${args.replyBody}`], { encoding: "utf8", maxBuffer: MAX_BUFFER })
        done.push("replied")
    } catch (err: any) {
        return `Error posting reply: ${err.message}`
    }
}
try {
    const { stdout } = await execFileAsync("gh", ["api", "graphql", "-f", `query=${RESOLVE_MUT}`, "-f", `id=${args.threadId}`], { encoding: "utf8", maxBuffer: MAX_BUFFER })
    const resolved = JSON.parse(stdout)?.data?.resolveReviewThread?.thread?.isResolved
    done.push(resolved ? "resolved" : "resolve returned unexpected response")
} catch (err: any) {
    return `Error resolving thread: ${err.message}`
}
return `Thread ${args.threadId}: ${done.join(", ")}`
