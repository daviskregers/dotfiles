import { execFile } from "child_process"
import { promisify } from "util"

const execFileAsync = promisify(execFile)
const MAX_BUFFER = 10 * 1024 * 1024

const REPLY_MUT = `mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{id url}}}`
const RESOLVE_MUT = `mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}`
