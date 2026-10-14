// scrape-navigator: routes a scraping task and makes the relevant skill
// *present* rather than merely suggested.
//
// Why a plugin and not just an agent: an agent is a prompt plus permissions.
// It can only tell the model "you should load the crawl4ai skill", and the
// model may not. A plugin puts the skill's text into the request, which is
// enforcement.
//
// Three hooks, deliberately belt-and-braces:
//   1. `chat.message` - classify the incoming prompt, stash the decision
//      keyed by sessionID (cheap; never blocks admission);
//   2. `experimental.chat.system.transform` - push the routing decision AND
//      the matched skills' bodies into the system prompt, so knowledge is
//      present even if native skill attachment is not attempted;
//   3. `shell.env` - inject DATAIMPULSE_*/NTFY_*/FIRECRAWL_* env vars from the
//      stack's gitignored local.env into every spawned shell, so proxies work
//      in any session without manual exports. Values never logged.
//
// It never blocks a request. On any error it does nothing at all.

import type { Plugin } from "@opencode-ai/plugin"
import { readFileSync, existsSync, appendFileSync, mkdirSync } from "node:fs"
import { join, dirname, resolve } from "node:path"
import { homedir } from "node:os"
import { decide } from "./route.js"

const HOME = homedir()
const STACK_ROOT = process.env.SCRAPING_STACK_ROOT ?? "D:/Code/Data Scraping"
const SKILLS_DIR = join(HOME, ".config", "opencode", "skills")
const STACK_SKILLS_DIR = join(STACK_ROOT, "skills")
const LOCAL_ENV = join(STACK_ROOT, "config", "dataimpulse.local.env")
const LOG_DIR = join(HOME, ".local", "state", "opencode-scrape")
const MAX_BODY = 4000
const MAX_BODIES = 2

// Prefixes allowed to cross from local.env into shell env. Everything else in
// the file is ignored - the blast radius of a stray key stays bounded.
const ENV_PREFIXES = ["DATAIMPULSE_", "NTFY_", "FIRECRAWL_", "BRIGHTDATA_"]

// Plugin stderr does NOT reach opencode's own log file (verified pattern from
// the hunt-stack navigator), so write our own - otherwise "it is logging" is
// an assumption rather than an observation. Tail it:
//   tail -5 ~/.local/state/opencode-scrape/navigator.log
function logLine(msg: string) {
  try {
    mkdirSync(LOG_DIR, { recursive: true })
    appendFileSync(join(LOG_DIR, "navigator.log"), `${new Date().toISOString()} ${msg}\n`)
  } catch { /* logging must never break anything */ }
}

const bodyCache = new Map<string, string>()   // skill id -> body text (frontmatter stripped)
const pending = new Map<string, { decision: any; injected: boolean }>()

function skillBody(id: string): string {
  if (bodyCache.has(id)) return bodyCache.get(id) as string
  let body = ""
  for (const dir of [SKILLS_DIR, STACK_SKILLS_DIR]) {
    try {
      const raw = readFileSync(join(dir, id, "SKILL.md"), "utf8")
      body = raw.replace(/^---\n[\s\S]*?\n---\n/, "").trim()
      break
    } catch { /* try next location */ }
  }
  if (body.length > MAX_BODY) body = body.slice(0, MAX_BODY) + "\n[...truncated]"
  bodyCache.set(id, body)
  return body
}

/** Is this directory inside (or above) a scrape workspace (has jobs/)? */
function inJobsWorkspace(dir?: string): boolean {
  if (!dir) return false
  let d: string
  try { d = resolve(dir) } catch { return false }
  for (let i = 0; i < 8; i++) {
    if (existsSync(join(d, "jobs"))) return true
    const p = dirname(d)
    if (!p || p === d) break
    d = p
  }
  return false
}

/** Pull prompt text out of a user message without trusting any one shape. */
function promptText(output: any): string {
  try {
    const parts = output?.parts ?? []
    const fromParts = parts
      .filter((p: any) => p?.type === "text")
      .map((p: any) => p?.text ?? "")
      .join("\n")
      .trim()
    if (fromParts) return fromParts
    const c = output?.message?.content
    if (typeof c === "string") return c
    if (Array.isArray(c))
      return c.map((x: any) => (typeof x === "string" ? x : x?.text ?? "")).join(" ").trim()
  } catch { /* fall through */ }
  return ""
}

export const ScrapeNavigator: Plugin = async (ctx) => {
  try {
    await ctx.client.app.log({
      body: {
        service: "scrape-navigator",
        level: "info",
        message: "loaded",
        extra: { stack: STACK_ROOT, skillsDir: SKILLS_DIR, localEnv: existsSync(LOCAL_ENV) },
      },
    })
  } catch { /* logging must never break anything */ }

  return {
    // ---- 1. classify the incoming prompt, stash the decision ----------------
    "chat.message": async (input: any, output: any) => {
      try {
        const role = output?.message?.role
        if (role && role !== "user") return
        const text = promptText(output)
        if (!text) return

        const decision = decide(text, { inJobs: inJobsWorkspace(ctx.directory) })
        pending.set(input.sessionID, { decision, injected: false })

        // Logged so routing can be verified from a file rather than assumed.
        if (decision.id !== "none" || decision.skills.length) {
          logLine(`route=${decision.id} skills=${decision.skills.join(",") || "-"} ` +
                  `agent=${decision.agent} why="${decision.why}"`)
        }
      } catch { /* never break prompt admission */ }
    },

    // ---- 2. put the decision, and the skills themselves, before the model ----
    "experimental.chat.system.transform": async (input: any, output: any) => {
      try {
        const st = input?.sessionID ? pending.get(input.sessionID) : undefined
        if (!st || st.injected) return
        const d = st.decision
        // Inject whenever there is something to inject. Presence must not
        // depend on wording: an explicitly named skill or a jobs/-workspace
        // attach fires even when no route matched.
        if (!d || (d.id === "none" && !d.skills.length)) { st.injected = true; return }

        const bodies: string[] = []
        for (const id of d.skills.slice(0, MAX_BODIES)) {
          const b = skillBody(id)
          if (b) bodies.push(`--- skill: ${id} ---\n${b}`)
        }

        const gates = d.gates.length
          ? `\nMandatory before this task is finished: ${d.gates.join("  ·  ")}.`
          : ""

        output.system.push(
          `[scrape-navigator] This task routes to: **${d.label}** (${d.why}).\n` +
          `Suggested agent for the specialist step: \`${d.agent}\` - dispatch with the task/subagent tool, ` +
          `or use /scrape /crawl /extract /bypass which already route.\n` +
          `Skills applied to this request: ${d.skills.join(", ") || "(none)"}.${gates}\n` +
          `The skill text is included below so it does not have to be loaded again.\n\n` +
          bodies.join("\n\n"),
        )
        st.injected = true
      } catch { /* never break a request */ }
    },

    // ---- 3. proxy/notify/API credentials into every spawned shell ------------
    "shell.env": async (_input: any, output: any) => {
      try {
        if (!existsSync(LOCAL_ENV)) return
        const raw = readFileSync(LOCAL_ENV, "utf8")
        for (const line of raw.split(/\r?\n/)) {
          const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line)
          if (!m) continue
          const [, key, val] = m
          if (!ENV_PREFIXES.some((p) => key.startsWith(p))) continue
          if (!val || val.startsWith("#")) continue
          output.env[key] = val.replace(/^["']|["']$/g, "")
        }
        // Deliberately no value logging: existence check only.
        logLine("shell.env injected stack credentials")
      } catch { /* never break a shell */ }
    },
  }
}
