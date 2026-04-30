# Slide 1: Intro
- I want to share how I've been using AI agents — primarily Claude Code — in my day-to-day GDS work.
- This isn't a prescription or something you need to follow. I'm sharing it as one data point, hoping it's useful as you build your own AI workflows.
- I'd also love to learn from each of you — ideally we can carve out a few minutes during weekly sync going forward for everyone to share what's working (or not).

# Slide 2: What is Claude Code
- Let me quickly go over what Claude Code is — I'll keep this brief since the goal is the practical usage, not the tool itself.
- Claude Code is an agentic CLI that runs in your terminal. Unlike chat-based AI, it can read your actual files, execute BigQuery queries, call Slack and Jira, and spawn parallel sub-agents — all within a single session.
- The key mental model is: it's not just answering questions, it's taking actions in a loop — understand intent → plan steps → call tools → observe results → iterate.

# Slide 3: Environment Architecture
- This is my current working environment. My root workspace is `~/Documents/Queries/` — originally just a personal query repo, now my full analytics hub.
- It has two CLAUDE.md files:
    - One for global instructions: my persona, analytical principles, and agent routing rules.
    - One for project-level guidance: BQ column gotchas, notebook templates, client bundle IDs, etc.
- There are four sub-agents, but the two I use most are MOBIUS (domain knowledge + BQ routing) and claude-bq-agent (SQL execution).
- 19 skills — I'll walk through these shortly.
- 6 MCP connections: Glean, Slack, Jira, Jupyter, Google Drive, and Explab.
- A local memory system with 7 files — more on this later.
- Hooks for automation — I'll be honest, I'm still getting familiar with these, so I'll skip a deep dive.
- I also registered the Moloco marketplace plugin (`moloco-ads-claude-plugins`) but haven't installed it yet — that's on my list.
- Lastly, I use Searchlight by invoking it through a Bash command from within my workspace. The instructions for how to call it are embedded in CLAUDE.md.

# Slide 4: Component Guide (1/2)
- Two CLAUDE.md files: one global (persona, principles, agent routing) and one project-level (BQ gotchas, notebook conventions, bundle IDs).
- Skills span four areas: Investigation & Analysis, Campaign & Launch, Productivity & Output, and Dev.
- Four sub-agents: MOBIUS, claude-bq-agent, client-profile, and notebook-executor. The rule is: all data questions go to MOBIUS first — it adds domain context before routing to the BQ agent.

# Slide 5: Component Guide (2/2)
- 6 MCP connections — all active except the BigQuery MCP, which has been failing. It doesn't matter since the BQ agent handles all query execution anyway.
- Memory system: 7 files auto-loaded at session start via a MEMORY.md index. BQ schema gotchas, client bundle IDs, feedback on past mistakes — once corrected, never forgotten.
- Marketplace: `moloco-ads-claude-plugins` has five bundles (gds-core, sales-core, gtm-core, productivity-core, plugin-general). Not yet installed — activate via `claude plugin install gds-core`. If anyone's already tried this, I'd love to hear how it went.

# Slide 6: BQ Agent vs. Searchlight — Why Different?
- This is a question I had early on, so I want to clarify it upfront.
- **claude-bq-agent** is a native sub-agent: it runs inside my current Claude session via Bash and poetry CLI. No separate process needed.
- **Searchlight** is a peer CLI session: it spawns a new Claude process with its own MCP connections — Looker, SensorTower, Notion, Google Docs/Sheets write access. These aren't available inside my main session.
- Rule: one question per Searchlight invocation; results land at `~/searchlight/tmp/data/`.
- Think of it as: BQ Agent = tools inside your session; Searchlight = a parallel analyst with different superpowers.

# Slide 7: Skills
- I've created several custom skills using a skill called `/new-command` — which Simon originally shared in the Slack channel. Very meta.
- Skills are organized into three buckets: Investigation, Campaign/Launch, and Productivity.
- The ones I use most frequently are highlighted:
    - `/weekly-summary`: pulls my Slack activity, mentions, pending action items, and unanswered DMs from the past week. Extremely useful on Monday mornings.
    - `/notify`: sends analysis results directly to my Slack DM, so I don't have to manually copy anything.
    - `/ticket`: end-to-end Jira ticket investigation scaffold — fetches the ticket, creates a folder, writes an analysis plan, and stubs a notebook.
    - `/campaign`: looks up campaign metadata by ID or by search conditions.

# Slide 8: Example of a Skill
- Let me quickly show the `/weekly-summary` output as a concrete example of what a skill looks like in practice.

# Slide 9: Two Ways to Work with Claude Code
- Now that we've covered the setup, let me talk about how I actually use it.
- There are two main working patterns.
    - **Pattern 1 — Deep Dive with Exploration:** I work side-by-side with Claude in Cursor IDE — me driving the notebook, Claude handling queries and interpreting results. We clear one hypothesis, surface a new one, and iterate. This is where the Jupyter MCP shines. Example: the KOR VT Rate Drop Analysis.
    - **Pattern 2 — End-to-End Autonomous Task:** For well-scoped, bounded tasks with a clear start and finish, I hand it off to Claude or Searchlight. Example: Jira ticket investigation for ODSB-17259. Claude fetches the ticket, runs the BQ analysis, creates the notebook, and sends the results to Slack — I just review the output.

# Slides 10–12: Pattern 1 Example — VT Analysis
- Slides 10 through 12 show real prompts from my actual work on the KOR VT deep-dive notebook (`kr_vt_deepdive.ipynb`).
- The key things to note: Claude reads the notebook context, updates chart code, writes plan documents, and asks clarifying questions mid-analysis rather than making assumptions.
- A good example: it surfaced that `cr_format = NULL` was silently dropping throttled rows — that's the kind of BQ gotcha that's very easy to miss and hard to debug. Claude caught it during the analysis and saved it to memory so it won't happen again.

# Slides 13–14: Pattern 2 Example — ODSB-17259
- For the Jira ticket, I delegated the first-draft investigation entirely to Searchlight using `/investigate-fast`.
- Searchlight fetched the ticket, ran the bidrequest funnel, and cross-referenced entity history — the root cause turned out to be a creative format gap: the ad group only had `ib` creatives, but KakaoTalk Native requires `nl`/`ni` format.
- After the investigation, I used `/create-notebook` to build CPI spike charts from the existing CSVs, then `/notify` to send everything to Slack, and `/doc-review` to proofread the writeup.

# Slide 15: [Optional — skip if short on time]
- This slide covers how Searchlight runs Pattern 2 under the hood — parallel agent execution instead of sequential tool calls, which is why it completes in ~3 minutes instead of 6–9.

# Slide 16: Jupyter MCP
- Quick note on Jupyter MCP: it lets Claude connect to a live Jupyter kernel and execute code directly — no manual pasting.
- In practice, Claude reads CSV output from BQ, builds matplotlib charts with proper KST timezone conversion, annotates outliers, and saves PNGs — all without me touching the notebook.

# Slide 17: CLAUDE.md vs. Memory
- Just to clarify the difference between these two persistence layers:
    - **CLAUDE.md** is static instruction — I write it, Claude reads it. It sets the persona, routing rules, and conventions. It doesn't change unless I edit it.
    - **Memory** is an evolving knowledge base — Claude writes to it automatically when something worth keeping surfaces. BQ schema gotchas, mistakes corrected once and never repeated, client context. You can also explicitly ask Claude to remember or forget things.

# Slide 18: Key Skills & BQ Knowledge Built
- This is an example of what gets accumulated in memory over time.
- Things like: use `timestamp_utc` not `date_utc` in `fact_dsp_all`; `cr_format = NULL` silently drops throttled rows; `pricing` table stores bid prices as INT64 micro-CPM (divide by 1e6).
- This is the kind of tribal knowledge that normally lives in someone's head or gets rediscovered every few months. With memory, it persists across sessions and can be queried.

# Slide 19: How to Get Better Results
- A few practical tips to close:
    - **Do:** Include IDs upfront; name the tool you want; paste a reference query; state output format before the first query; describe visual bugs with a screenshot.
    - **Don't:** Ask for CSV after you've already seen the results; leave tool routing ambiguous; bundle multiple questions into one BQ call; repeat the same prompt when stuck.
- The biggest unlock for me was learning to treat Claude more like a capable colleague than a search engine — give it context, state what you expect, and correct it specifically when it's wrong.
