// Routing logic for the scrape-navigator plugin.
//
// Pure functions, no OpenCode imports, so they are unit-tested directly:
//   node route.test.mjs
//
// Why this exists: an agent can only *advise* that a skill should be loaded.
// A plugin attaches the skill's text to the request, which is enforcement
// rather than suggestion. This file decides what gets attached — and, just as
// important, what does NOT: injecting scraping skills into unrelated sessions
// (git, config, other stacks) is context pollution, so every non-scraping
// prompt must route to `none`.

/**
 * Every skill this plugin can attach. Doubles as the list an explicit
 * `@name` mention is matched against, so naming a skill is never ignored.
 */
export const SKILL_IDS = [
  "api-capture", "crawl4ai", "firecrawl-mcp", "llm-extraction", "monitor-diff",
  "pagination", "proxies-dataimpulse", "scrapling", "social-media",
  "stealth-antibot", "tool-selection",
];

/** Explicit mention: `@crawl4ai`, `crawl4ai`, `crawl 4ai` (hyphens/spaces optional). */
export function mentionedSkills(text) {
  const t = String(text ?? "");
  const found = [];
  for (const id of SKILL_IDS) {
    // Per-character optional separators so "crawl 4ai", "crawl4ai" and
    // "tool selection" all match the id "crawl4ai"/"tool-selection". Only
    // [- ] are allowed as connectors, so the char sequence itself must still
    // match exactly - "crawls 4 airdrops" cannot slip through the boundary.
    const stem = id.split("")
      .map((c) => (c === "-" ? "[- ]?" : c.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")))
      .join("[- ]?");
    const re = new RegExp(`(?:^|[\\s(\`])@?${stem}(?=$|[\\s)\`.,:;!?])`, "i");
    const m = re.exec(t);
    if (m) found.push({ id, at: m.index });
  }
  // Prompt order, not SKILL_IDS order: index.ts injects at most MAX_BODIES
  // skill bodies, so the skill named first must be the one that reaches the
  // model when several are named.
  return found.sort((a, b) => a.at - b.at).map((x) => x.id);
}

/** Used when a skill was named explicitly but no route matched on wording. */
const MENTION = {
  id: "mention",
  label: "skill requested explicitly",
  agent: "navigator",
  skills: [],
  gates: [],
  patterns: [],
};

/**
 * Route table. Order matters for tie-breaking; scoring picks the winner.
 * Most-specific first. Placed above generic extraction/api routes on purpose.
 */
export const ROUTES = {
  stealth: {
    label: "blocked - anti-bot escalation",
    agent: "stealth",
    skills: ["stealth-antibot", "proxies-dataimpulse"],
    gates: ["log every attempt to logs/bypass-recipe.md"],
    patterns: [
      /\b403\b/, /\b429\b/, /\bblocked?\b/i, /\bunblock\b/i, /\bcloudflare\b/i,
      /\bcaptcha\b/i, /\banti-?bot\b/i, /\bbot (detect|wall|protect)/i,
      /\bfingerprint\b/i, /\bbypass\b/i, /\bstealth\b/i, /\bheadless\b/i,
      /\bdata ?dome\b/i, /\bkasada\b/i, /\bperimeterx\b/i, /\bjs challenge\b/i,
      /\bchallenge page\b/i, /\bgetting blocked\b/i, /\brecaptcha\b/i,
      /\bflaresolverr\b/i, /\bcamoufox\b/i, /\bnodriver\b/i, /\bundetected\b/i,
    ],
  },
  proxy: {
    label: "proxy configuration / DataImpulse",
    agent: "stealth",
    skills: ["proxies-dataimpulse"],
    gates: [String.raw`bin\oc-proxy-test.ps1 -Mode rotate`],
    patterns: [
      /\bdataimpulse\b/i, /\bresidential\b/i, /\bexit ip\b/i, /\brotating ip\b/i,
      /\bgeo[- ]?target/i, /\bsticky (ip|session|proxy)\b/i, /\bsessid\b/i,
      /\bip rotation\b/i, /\bsessttl\b/i, /\bgw\.dataimpulse\b/i,
      /\bproxy\b/i, /\bproxies\b/i, /\bsocks5?\b/i,
    ],
  },
  monitor: {
    label: "change detection / scheduled monitoring",
    agent: "crawler",
    skills: ["monitor-diff"],
    gates: ["baseline first; alert only on change"],
    patterns: [
      /\bmonitor\b/i, /\bchange detection\b/i, /\bdiff (the )?page\b/i,
      /\bnotify me when\b/i, /\btrack (prices?|stock|availability|changes?|updates?)\b/i,
      /\bprice (drop|change|watch)\b/i, /\bschedule[ds]?\b/i, /\bcron\b/i,
      /\bevery (hour|day|week|minute)\b/i, /\bweb_diff\b/i, /\bweb_check\b/i,
      /\bwatch (this|the|the page)\b/i, /\bstill (available|in stock|same)\b/i,
    ],
  },
  social: {
    label: "social platform scraping",
    agent: "crawler",
    skills: ["social-media"],
    gates: [],
    patterns: [
      /\btwitter\b/i, /\binstagram\b/i, /\btiktok\b/i, /\blinkedin\b/i,
      /\breddit\b/i, /\byoutube\b/i, /\bdouyin\b/i, /\bxiaohongshu\b/i,
      /\bred ?note\b/i, /\bbilibili\b/i, /\bkuaishou\b/i, /\bthreads\b/i,
      /\bsocial media\b/i, /\bsubreddit\b/i, /\bmedia ?crawler\b/i,
      /\bprofile (page|posts)\b/i, /\bfollowers\b/i,
    ],
  },
  // api sits ABOVE extract: "extract the API's fields" should fire the
  // api-first approach (replay the endpoint) rather than scraping its HTML —
  // the whole point of the api-capture skill is that it beats rendering.
  api: {
    label: "capture and reuse the backing API",
    agent: "extractor",
    skills: ["api-capture"],
    gates: ["save the endpoint recipe to logs/api-recipe.md"],
    patterns: [
      /\bxhr\b/i, /\bfetch requests?\b/i, /\bnetwork (tab|requests?|traffic)\b/i,
      /\bdev ?tools\b/i, /\bhar\b/i, /\bgraphql\b/i, /\bbacking api\b/i,
      /\bendpoint\b/i, /\bnext\/data\b/i, /\b\/api\//, /\bjson-?api\b/i,
      /\bresponse (body|json)\b/i, /\brequest (payload|body|headers)\b/i,
      /\breplay the (request|api|call)\b/i, /\bapi first\b/i, /\bapi-first\b/i,
      /\bpublic api\b/i, /\bapi key\b/i, /\bwp-json\b/i, /\boutput=json\b/i,
      /\bapi(s|'s)?\b/i,
    ],
  },
  pagination: {
    label: "pagination / multi-page navigation",
    agent: "crawler",
    skills: ["pagination", "crawl4ai"],
    gates: [],
    patterns: [
      /\bpaginat/i, /\binfinite scroll\b/i, /\bload[- ]more\b/i,
      /\bnext page\b/i, /\bpagination trap\b/i, /\blazy[- ]load/i,
      /\bscroll to (load|the bottom)\b/i, /\bpage=(\d|next)\b/i,
      /\boffset\b/i, /\bcursor token\b/i, /\brel=["']?next\b/i,
      /\btoo many (pages|urls)\b/i, /\bfacet/i,
    ],
  },
  crawl: {
    label: "bulk crawl of a site",
    agent: "crawler",
    skills: ["crawl4ai", "pagination"],
    gates: [String.raw`bin\oc-robots.ps1 <domain> before the first request`],
    patterns: [
      /\bcrawl(ing|er|s)?\b/i, /\bspider(ing)?\b/i, /\bwhole (site|website)\b/i,
      /\bsite[- ]wide\b/i, /\bevery (page|url)\b/i, /\bsitemaps?\b/i,
      /\bmax[ -]?pages?\b/i, /\bfollow (all )?links\b/i, /\bdeep[- ]crawl\b/i,
      /\bdiscover(y|) (all )?(the )?(urls|pages|links)\b/i,
      /\bwalk (the )?site\b/i, /\ball docs pages\b/i,
    ],
  },
  scrape: {
    label: "scrape a single page",
    agent: "navigator",
    skills: ["crawl4ai"],
    gates: [String.raw`bin\oc-robots.ps1 <domain> before the first request`],
    patterns: [
      /\bscrape\b/i, /\bsingle page\b/i, /\bto markdown\b/i, /\bmarkdown from\b/i,
      /\bsave (the|this) page\b/i, /\bscreenshot\b/i, /\brender (the|this) page\b/i,
      /\bhtml to\b/i, /\bpage content\b/i, /\bread (this|the) (page|url|site)\b/i,
      /\bfetch (this|the) (page|url|site|link)\b/i,
    ],
  },
  extract: {
    label: "structured extraction from content",
    agent: "extractor",
    skills: ["scrapling", "llm-extraction"],
    gates: [String.raw`/check-output <job-dir> before delivery`],
    patterns: [
      /\bextract\b/i, /\bstructured (data|output|json)\b/i, /\bschema\b/i,
      /\bjsonl\b/i, /\bcsv\b/i, /\binto a (table|dataset|list)\b/i,
      /\brecords?\b/i, /\bpydantic\b/i, /\bxpath\b/i, /\bcss selectors?\b/i,
      /\bself[- ]?heal/i, /\badaptive selector/i, /\bspreadsheet\b/i,
      /\bfields? (from|of|on)\b/i, /\bparse (the )?(table|list|results)\b/i,
      /\bprice[s]? (from|of)\b/i,
    ],
  },
  search: {
    label: "web search / site URL discovery",
    agent: "navigator",
    skills: ["firecrawl-mcp"],
    gates: [],
    patterns: [
      /\bsearch (the )?web\b/i, /\bweb search\b/i, /\bserp\b/i,
      /\bgoogle (results|search|SERP)\b/i, /\bmap (the |this )?site\b/i,
      /\blist (all )?(the )?urls\b/i, /\bfind (all )?(the )?(urls|pages|links) (on|for)\b/i,
      /\bfirecrawl\b/i, /\bresearch (across|the web|multiple sites)\b/i,
      /\bfresh (data|results|sources)\b/i,
    ],
  },
  llm: {
    label: "LLM-driven extraction",
    agent: "extractor",
    skills: ["llm-extraction"],
    gates: ["validate every row; nulls stay null"],
    patterns: [
      /\bllm\b/i, /\bgpt\b/i, /\buse (ai|claude|gpt) to extract\b/i,
      /\bai extraction\b/i, /\bopenai\b/i, /\blitellm\b/i, /\bai-powered extract/i,
      /\bnatural language (query|extraction)\b/i, /\bprompt.*extract/i,
    ],
  },
  validate: {
    label: "validate scraped output",
    agent: "validator",
    skills: [],
    gates: [String.raw`/check-output <job-dir> must write validation_report.md`],
    patterns: [
      /\bvalidat/i, /\bdedup/i, /\bduplicate rows?\b/i, /\bnull rate\b/i,
      /\bspot[- ]?check\b/i, /\bcheck (the )?output\b/i, /\bdata quality\b/i,
      /\bcoverage\b/i, /\bcompleteness\b/i, /\bmissing (rows|records|pages)\b/i,
      /\bvalidation report\b/i, /\bclean the data\b/i,
    ],
  },
  scaffold: {
    label: "set up a new scraping job",
    agent: "navigator",
    skills: ["tool-selection"],
    gates: ["/newjob scaffolds jobs/<name>/ and runs oc-robots first"],
    patterns: [
      /\bnew (scraping |scrape |crawl )?job\b/i, /\bscaffold\b/i,
      /\bset up (a|an|the) (new )?(crawl|scrape|scraping|job|workspace|target)\b/i,
      /\bstart (a|the) (crawl|scrape|scraping|job)\b/i, /\bworkspace for\b/i,
      /\bdata[- ]?scraping stack\b/i, /\bscraping stack\b/i, /\bfresh job\b/i,
    ],
  },
  tool: {
    label: "choose the right scraping tool",
    agent: "navigator",
    skills: ["tool-selection"],
    gates: [],
    patterns: [
      /\bwhich (tool|engine|lib|library|framework)\b/i,
      /\bwhat should i (use|scrape with|crawl with)\b/i,
      /\bpick (the )?(right )?tool\b/i, /\btool (for|to) (use|pick|choose)\b/i,
      /\bcrawl4ai or\b/i, /\bplaywright or\b/i, /\bscrapy or\b/i,
      /\bfirecrawl or\b/i, /\bvs\.? (scrapy|playwright|crawl4ai|firecrawl)\b/i,
      /\bcompare (the )?(tools|engines)\b/i, /\bdecision tree\b/i,
    ],
  },
};

export const NON_SCRAPE = {
  label: "not a scraping task",
  agent: "build",
  skills: [],
  gates: [],
};

/** Score a prompt against every route. Highest score wins; ties break by ROUTES order. */
export function classify(text) {
  const t = String(text ?? "");
  let best = null;
  let bestScore = 0;
  for (const [id, r] of Object.entries(ROUTES)) {
    let score = 0;
    for (const p of r.patterns) if (p.test(t)) score++;
    if (score > bestScore) { bestScore = score; best = id; }
  }
  if (!best || bestScore === 0) return { ...NON_SCRAPE, id: "none", score: 0 };
  return { ...ROUTES[best], id: best, score: bestScore };
}

/**
 * Final decision: route + the skills that must be present.
 *
 * `tool-selection` is unconditional inside a scrape workspace (a directory
 * containing `jobs/`), mirroring scope-first in the hunt stack: every route
 * that touches a host needs the decision tree, and the one rule with no
 * exceptions must not depend on wording.
 *
 * An explicitly named skill (`@crawl4ai`) is attached whatever the route
 * decided and is not counted against maxSkills — naming it is an instruction,
 * not a routed suggestion.
 */
export function decide(text, opts = {}) {
  const { inJobs = false, maxSkills = 2 } = opts;
  const mentioned = mentionedSkills(text);
  let route = classify(text);
  if (route.id === "none" && mentioned.length) route = { ...MENTION, score: 0 };

  const skills = [];
  if (inJobs) skills.push("tool-selection");
  for (const s of mentioned) if (!skills.includes(s)) skills.push(s);
  for (const s of route.skills.slice(0, maxSkills)) if (!skills.includes(s)) skills.push(s);

  return {
    id: route.id,
    label: route.label,
    agent: route.agent,
    gates: route.gates ?? [],
    skills,
    mentioned,
    why: route.id === "none"
      ? "no scraping signal in the prompt"
      : route.id === "mention"
        ? `skill(s) named explicitly: ${mentioned.join(", ")}`
        : `matched ${route.score} signal(s) for '${route.label}'` +
          (mentioned.length ? `; named explicitly: ${mentioned.join(", ")}` : ""),
  };
}
