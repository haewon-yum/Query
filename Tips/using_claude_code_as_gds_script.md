# Sharing Session Script: Using Claude Code as GDS
# Duration: 15–20 min | Haewon Yum | 2026-03

---

## SLIDE 1 — INTRO
*[~1 min]*

"Good [morning/afternoon] everyone. I wanted to share something I've been building over the past few months — how I use Claude Code as part of my day-to-day GDS work.

Before I jump in, I want to be clear: this is not a recommendation or a workflow you need to follow. My setup reflects my own preferences and work style. I'm sharing it as one data point, and I genuinely hope it sparks ideas or questions you can build on.

I'd also love this to be a two-way conversation. I'm still learning, and I think there's a lot of value in each of us sharing what we've tried. Hopefully we can carve out a few minutes in our weekly syncs going forward to do exactly that."

---

## SLIDE 2 — WHAT IS CLAUDE CODE
*[~1.5 min]*

"Let me start with a quick intro to Claude Code itself — I'll keep this brief since the goal is practical usage, not a product walkthrough.

Claude Code is an AI agent that runs in your terminal. The key difference from a chat tool like the Claude web interface is that it can actually take actions. It reads your real files, runs BigQuery queries, calls Slack and Jira APIs, and spawns sub-agents — all within a single session.

The mental model I find useful is: it's not just answering questions, it's operating in a loop. Understand what you want → plan the steps → call the right tools → observe the results → iterate.

So when I say I'm 'working with Claude Code,' I mean I'm having a back-and-forth where Claude is actively running code and writing files, not just generating text I paste somewhere else."

---

## SLIDE 3 — ENVIRONMENT ARCHITECTURE
*[~2 min]*

"This is what my working environment looks like. My root workspace is `~/Documents/Queries/` — which started as just a personal query repo and has grown into my full analytics hub.

At the top, there are two CLAUDE.md files. Think of these as instruction layers. One is global — it defines my persona as a Senior Data Scientist, analytical principles, and how to route tasks to different agents. The other is project-level — more tactical stuff like BQ column gotchas, notebook conventions, and client bundle IDs.

Then there are four sub-agents. The two I use most are MOBIUS — which handles domain knowledge and BQ routing — and the BQ agent, which actually executes SQL queries. I'll talk more about these in a moment.

I have 19 skills, which are essentially custom slash commands. Six MCP connections to external tools. A local memory system. And hooks for automation — though I'll be honest, I haven't fully explored hooks yet, so I'll skip that.

I also registered the Moloco marketplace plugin but haven't installed it. That's next on my list. If anyone's already tried it, let me know.

And finally, I invoke Searchlight via Bash from within my workspace — it's a separate tool with its own Claude session and its own MCP connections."

---

## SLIDES 4–5 — COMPONENT GUIDE
*[~2 min]*

"Let me go through each component quickly.

The two CLAUDE.md files form a layered instruction system. The global file sets the overall persona and analytical standards. The project file handles specifics — things like 'don't use `date_utc` in fact_dsp_all, it doesn't exist, use `timestamp_utc`.' Having these rules baked in means Claude doesn't make the same mistake twice.

The four sub-agents each have a specific role. The key rule is: all data questions go to MOBIUS first. MOBIUS adds domain context before routing to the BQ agent. This prevents the BQ agent from guessing table names or column formats.

For MCPs — six are active. The BigQuery MCP is failing, but that's fine since the BQ agent handles all query execution. The ones I actually use daily are Glean, Slack, Jira, and Jupyter.

Memory is probably the component I'm most excited about. It's an auto-evolving knowledge base. Seven files, all loaded at session start. When Claude makes a mistake and I correct it, it writes that correction to memory. So the next session, it already knows.

One thing I want to flag — the Moloco marketplace plugin has five bundles including a gds-core bundle. I haven't installed it yet. If you're interested in trying it together, let me know after the session."

---

## SLIDE 6 — BQ AGENT VS. SEARCHLIGHT
*[~1.5 min]*

"I want to clarify this early because it confused me at first.

Both BQ Agent and Searchlight can run BigQuery queries. So why are they different?

The BQ Agent is a native sub-agent — it runs inside my current Claude session. I can call it directly without starting anything new.

Searchlight is a peer session — it spawns a completely separate Claude process with its own MCP connections. And those connections are different: Looker, SensorTower, Notion, Google Sheets write access. These tools are not available inside my main session.

So the simple rule is: if I need just BigQuery, I use MOBIUS → BQ Agent. If I need cross-domain investigation — BQ plus Jira plus Looker plus a Notion doc, all synthesized together — I reach for Searchlight.

One important constraint: one question per Searchlight invocation. Results land at a temp data folder. So I plan my questions before I send them."

---

## SLIDE 7 — SKILLS
*[~1.5 min]*

"I've created 19 custom slash commands — or 'skills' — to automate recurring workflows.

I built most of them using a skill called `/new-command`, which Simon originally shared in Slack. Very meta — a skill that creates skills.

They're organized into three buckets.

Investigation and analysis skills: `/ticket` scaffolds a full Jira ticket investigation. `/query` delegates to MOBIUS. `/validate-experiment` audits ExpLab configs.

Campaign and launch skills: `/campaign` looks up metadata by ID or search conditions. `/launch-analysis` creates the full scaffold for a new title launch.

Productivity skills: the ones I use most. `/weekly-summary` pulls my Slack activity, mentions, pending action items — invaluable on Monday morning. `/notify` sends analysis results directly to my Slack DM. `/colab-export` converts a notebook to Colab format and uploads it to Google Drive with a Moloco-restricted shareable link."

---

## SLIDE 8 — EXAMPLE: /WEEKLY-SUMMARY
*[~0.5 min]*

"Here's a quick example of what `/weekly-summary` looks like in practice. I run this every Monday. It covers Slack activity, who mentioned me and whether I've responded, any pending action items, and unanswered DMs.

This kind of structured weekly recap used to take me 20–30 minutes to pull together. Now it's one command."

---

## SLIDE 9 — TWO WAYS TO WORK
*[~1.5 min]*

"Now let me talk about how I actually use this in practice. In my experience, there are two distinct working patterns.

Pattern 1 is what I call Deep Dive with Exploration. This is for open-ended analysis where I don't know exactly what I'll find. I work side-by-side with Claude — me driving the direction, Claude handling queries and interpreting results. We clear one hypothesis, surface a new one, and iterate. The KOR VT Rate Drop analysis is a good example of this.

Pattern 2 is End-to-End Autonomous Task. This is for well-scoped, bounded work with a clear output. I hand it off to Claude or Searchlight, it runs the full workflow, and I review the result. The ODSB-17259 ticket investigation is an example of this.

The choice between them mostly comes down to: do I know what I'm looking for? If yes, Pattern 2. If I'm exploring, Pattern 1."

---

## SLIDES 10–12 — PATTERN 1 EXAMPLES
*[~2 min]*

"Slides 10 through 12 show real prompts from my KOR VT deep-dive notebook.

A few things I want to highlight.

First — Claude reads the notebook context before acting. When I asked it to update a chart label, it first read Section 3 to understand what the chart was doing before editing it.

Second — it asks instead of assuming. When I asked for Section 4 on User Quality, it asked: gaming bundles only or all verticals? That question actually helped me think through the scope more carefully. The answer was: top 10 gaming and non-gaming each.

Third — and this is the one I'm most proud of — Claude caught a subtle BQ bug I would likely have missed. `cr_format = NULL` was silently dropping throttled rows from the analysis. The fix was to use `inventory_format IN ('B', 'N')` instead. After correcting it, Claude saved that gotcha to memory. So it won't happen again in any future session."

---

## SLIDES 13–14 — PATTERN 2 EXAMPLE
*[~2 min]*

"For the ODSB-17259 ticket — Devsisters iOS, no spend — I delegated the first-draft investigation to Searchlight with `/investigate-fast`.

Searchlight fetched the Jira ticket, ran the bidrequest funnel by throttle reason, and then cross-referenced the entity history table. The root cause: the ad group had only `ib` (image banner) creatives, but KakaoTalk Native requires `nl` or `ni` format. `ib` is not eligible for KakaoTalk Native — so every bid on that supply was zero. That's the kind of thing that's very hard to debug manually across three different tables.

After the investigation, I used `/create-notebook` to build CPI spike charts from the existing output CSVs — Claude scanned the tmp/data folder, matched the right file, and inserted five chart cells. Then `/notify` sent everything to my Slack DM. Then `/doc-review` proofread the write-up, checked the logic, and drafted a TL;DR.

The whole flow from ticket to Slack-ready output took about 25 minutes, with me mostly just reviewing."

---

## SLIDE 15 — [OPTIONAL — SKIP IF SHORT ON TIME]
*[~0.5 min]*

"Slide 15 is a quick look at how Searchlight runs Pattern 2 under the hood — it launches Jira, BQ, and Glean agents in parallel rather than sequentially, which is why it finishes in around 3 minutes instead of 6 to 9. I'll skip the details but happy to dig into this if anyone's curious."

---

## SLIDE 16 — JUPYTER MCP
*[~0.5 min]*

"One quick note on Jupyter MCP. This is probably the most tangible MCP in my daily workflow.

Claude connects to a live Jupyter kernel and executes code directly — no manual cell pasting. It reads CSV output from the BQ agent, builds matplotlib charts with proper timezone conversion, annotates outliers, and saves PNGs to disk. I don't touch the notebook during that process. It's particularly useful when I want to iterate quickly on visualization without breaking flow."

---

## SLIDE 17 — CLAUDE.MD VS. MEMORY
*[~1 min]*

"Just to clarify two persistence mechanisms, because they serve different purposes.

CLAUDE.md is static instructions — I write it, Claude reads it every session. It sets the persona, routing rules, notebook conventions. It doesn't change unless I manually edit it.

Memory is a living knowledge base. Claude writes to it automatically when something worth keeping surfaces — BQ schema gotchas, corrections to past mistakes, client bundle IDs, project context. You can also explicitly ask Claude to remember or forget something.

The practical implication: CLAUDE.md is where you put things you want Claude to always know. Memory is where accumulated learning lives. Together they mean I'm not re-explaining context every session, and mistakes I've corrected once don't come back."

---

## SLIDE 18 — BQ KNOWLEDGE BUILT
*[~0.5 min]*

"Here's a concrete example of what accumulates in memory over time.

Use `timestamp_utc`, not `date_utc` in `fact_dsp_all` — there is no `date_utc` column. `cr_format = NULL` silently drops throttled rows. Pricing table stores bid prices as INT64 micro-CPM — divide by 1e6. `publisher.app_market_bundle`, not `publisher_app_bundle` — that column doesn't exist.

This is tribal knowledge that normally lives in someone's head or gets rediscovered every few months. With memory, it persists across sessions and informs every future query."

---

## SLIDE 19 — HOW TO GET BETTER RESULTS
*[~1 min]*

"I'll close with a few practical tips I've learned from using this daily.

Do: Include IDs upfront — campaign IDs, ticket numbers, table names. Name the tool you want rather than leaving it ambiguous. Paste a reference query if you have one. State your expected output format before the first query, not after you see results. If there's a visual bug in a chart, screenshot it and describe it.

Don't: Ask for CSV after you've already seen the results displayed in chat. Bundle multiple questions into one BQ call — separate invocations work much better. Repeat the same prompt when stuck — diagnose why it failed first.

The biggest mindset shift for me was treating Claude like a capable colleague rather than a search engine. Give it context, state your hypothesis, correct it specifically when it's wrong. The more you treat it like a real working relationship, the better the output gets.

That's it from me — happy to take questions, and please share what you're all doing. I'm genuinely curious what's working on your end."

---

## TIMING GUIDE

| Slides | Topic | Time |
|--------|-------|------|
| 1 | Intro | ~1 min |
| 2 | What is Claude Code | ~1.5 min |
| 3 | Architecture | ~2 min |
| 4–5 | Components | ~2 min |
| 6 | BQ Agent vs Searchlight | ~1.5 min |
| 7 | Skills | ~1.5 min |
| 8 | weekly-summary demo | ~0.5 min |
| 9 | Two working patterns | ~1.5 min |
| 10–12 | Pattern 1 examples | ~2 min |
| 13–14 | Pattern 2 examples | ~2 min |
| 15 | Under the hood *(skip if short)* | ~0.5 min |
| 16 | Jupyter MCP | ~0.5 min |
| 17 | CLAUDE.md vs Memory | ~1 min |
| 18 | BQ knowledge built | ~0.5 min |
| 19 | How to get better results | ~1 min |
| **Total** | | **~18–19 min** |
