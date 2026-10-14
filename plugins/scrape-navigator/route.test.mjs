// Unit tests for the scrape-navigator router. Run: node route.test.mjs
import { classify, decide, mentionedSkills, ROUTES, SKILL_IDS } from "./route.js"

let failed = 0
const eq = (name, got, want) => {
  const g = JSON.stringify(got), w = JSON.stringify(want)
  if (g !== w) { failed++; console.log(`FAIL ${name}\n   got  ${g}\n   want ${w}`) }
  else console.log(`ok   ${name}`)
}
const is = (name, cond) => eq(name, !!cond, true)

console.log("--- realistic prompts route to the right skill set ---")
eq("single-page scrape", classify("scrape https://example.com/product/1 to markdown").id, "scrape")
eq("bulk crawl", classify("crawl the whole docs site, max 50 pages").id, "crawl")
eq("site crawl w/ sitemap", classify("follow the sitemap and get every page").id, "crawl")
eq("structured extraction", classify("extract the name, price and sku into jsonl").id, "extract")
eq("api-first", classify("find the XHR the page calls and replay that endpoint").id, "api")
eq("blocked", classify("we are getting 403 blocked by cloudflare on every request").id, "stealth")
eq("captcha stop", classify("a captcha appeared, what do we do").id, "stealth")
eq("dataimpulse proxy", classify("rotate my dataimpulse residential proxy by country").id, "proxy")
eq("sticky session", classify("hold one sticky ip for the login flow").id, "proxy")
eq("social", classify("scrape the tiktok profile videos list").id, "social")
eq("monitor", classify("notify me when the price changes every hour").id, "monitor")
eq("pagination", classify("the crawler stops on page 1, infinite scroll below").id, "pagination")
eq("validation", classify("validate the output and dedup the records").id, "validate")
eq("web search", classify("search the web for recent papers on this topic").id, "search")
eq("tool choice", classify("should I use crawl4ai or scrapy for this").id, "tool")
eq("new job", classify("set up a new scraping job for this target").id, "scaffold")

console.log("--- non-scraping prompts must NOT be routed ---")
eq("git question", classify("why did the last commit fail").id, "none")
eq("bug report", classify("write the report for capture_3 and submit it").id, "none")
eq("ntfy script", classify("update the ntfy heartbeat script").id, "none")
eq("code refactor", classify("refactor the auth module and add unit tests").id, "none")
eq("empty", classify("").id, "none")
eq("undefined", classify(undefined).id, "none")
eq("greeting", classify("hello, how are you").id, "none")

console.log("--- skills actually get attached ---")
eq("scrape -> crawl4ai", decide("scrape this page").skills, ["crawl4ai"])
eq("crawl -> crawl4ai + pagination", decide("crawl the whole site").skills, ["crawl4ai", "pagination"])
eq("extract -> scrapling first", decide("extract the fields from the table").skills, ["scrapling", "llm-extraction"])
eq("stealth -> both", decide("bypass the cloudflare wall").skills, ["stealth-antibot", "proxies-dataimpulse"])
is("proxy -> dataimpulse", decide("test my dataimpulse proxy").skills.includes("proxies-dataimpulse"))
is("social -> social-media", decide("scrape twitter profiles").skills.includes("social-media"))
is("monitor -> monitor-diff", decide("track price changes daily").skills.includes("monitor-diff"))
is("api -> api-capture", decide("capture the xhr response").skills.includes("api-capture"))

console.log("--- explicit @mentions always attach, first-named wins ---")
eq("single mention", mentionedSkills("use @scrapling here"), ["scrapling"])
eq("spaced mention", mentionedSkills("load the crawl 4ai skill"), ["crawl4ai"])
eq("multiple keep prompt order", mentionedSkills("@pagination then @monitor-diff"), ["pagination", "monitor-diff"])
eq("mention attaches even with no route match",
   decide("just use @api-capture for this").skills.includes("api-capture"), true)
eq("mention on none-route still lists skill",
   decide("@tool-selection").id, "mention")

console.log("--- tool-selection is unconditional inside a jobs workspace ---")
eq("inside jobs/, tool-selection first",
   decide("scrape the page", { inJobs: true }).skills, ["tool-selection", "crawl4ai"])
eq("outside jobs/, not forced",
   decide("scrape the page", { inJobs: false }).skills, ["crawl4ai"])
is("even a non-scraping prompt gets tool-selection inside jobs/",
   decide("hello there", { inJobs: true }).skills.includes("tool-selection"))

console.log("--- gates and the suggested agent ---")
eq("crawl demands the robots gate",
   decide("crawl the site").gates.some((g) => g.includes("oc-robots")), true)
eq("validate routes to validator", decide("validate the output").agent, "validator")
eq("stealth routes to stealth agent", decide("we got 403 blocked").agent, "stealth")
eq("none has no gates", decide("update the config").gates, [])
eq("none routes to build", decide("update the config").agent, "build")

console.log("--- the table is well formed ---")
for (const [id, r] of Object.entries(ROUTES)) {
  is(`${id}: has a label`, typeof r.label === "string" && r.label.length > 0)
  is(`${id}: has patterns`, Array.isArray(r.patterns) && r.patterns.length > 0)
  is(`${id}: has an agent`, typeof r.agent === "string" && r.agent.length > 0)
}

console.log("--- coverage: every skill attaches for its own description's vocabulary ---")
const COVERAGE = {
  "tool-selection": ["which tool should I use for scraping this site"],
  "crawl4ai": ["turn this url into clean markdown with crawl4ai"],
  "scrapling": ["my css selectors keep breaking after redesigns"],
  "firecrawl-mcp": ["use firecrawl to map the site urls first"],
  "stealth-antibot": ["the site detects the headless browser fingerprint"],
  "proxies-dataimpulse": ["route requests through my dataimpulse residential pool"],
  "llm-extraction": ["use gpt to extract the product names and prices"],
  "social-media": ["collect posts from instagram profiles"],
  "api-capture": ["call the public json api directly instead of rendering"],
  "pagination": ["follow next page links beyond page 1"],
  "monitor-diff": ["check every day whether the page changed"],
}
for (const [skill, probes] of Object.entries(COVERAGE)) {
  for (const probe of probes) {
    is(`'${probe}' -> ${skill}`, decide(probe).skills.includes(skill))
  }
}

console.log("--- maxSkills cap and ordering ---")
eq("cap respected",
   decide("scrape and extract and use the llm", { maxSkills: 1 }).skills.slice(0, 2).length <= 3, true)

console.log("")
if (failed) { console.log(`${failed} test(s) FAILED`); process.exit(1) }
console.log("all tests passed")
