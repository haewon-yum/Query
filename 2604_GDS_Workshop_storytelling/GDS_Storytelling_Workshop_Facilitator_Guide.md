# GDS Storytelling Workshop — Facilitator Guide
**Workshop 2: Storytelling with Data | Beyond the Model Series**
*Script written for non-native English speaker delivery*

---

> **⚠️ Before you start:** The current presentation has slides 11–14 which are old duplicate slides (the retention example). **Delete slides 11–14** before your session so the flow goes: 1–10, then 15–24 (now renumbered 11–20 after deletion).

---

## Estimated Total Time: ~60–75 minutes

| Section | Slides | Time |
|---------|--------|------|
| Opening | 1–4 | 5 min |
| Icebreaker | 5 | 5 min |
| SCR Framework | 6 | 5 min |
| Breakout Activity | 7–9 | 15 min |
| Big Idea | 10–12 | 12 min |
| Chart Chooser | 13–17 | 10 min |
| 5 Pitfalls | 18 | 5 min |
| Story Sprint | 19 | 10 min |
| Wrap-up | 20 | 3 min |

---

## SLIDE 1 — Title: Beyond the Model

**Key Points**
- This is Workshop 2 of the 4-part GDS series
- Set a welcoming tone to open

**Script**
> "Welcome everyone. Good to have you all here.
>
> This is Workshop 2 of our Beyond the Model series. Last time, we talked about communicating with clarity. Today, we go deeper — we're talking about storytelling with data.
>
> Not just how to analyze. How to make people *act* on what you've found."

---

## SLIDE 2 — Learning Objectives (Series)

**Key Points**
- Remind them of the full series arc
- These 4 workshops build on each other

**Script**
> "Let me quickly remind you where we are in the full series.
>
> By the end of all four workshops, GDS will be able to communicate with executive-level clarity, structure data into narratives that drive decisions, influence stakeholders — even without formal authority — and drive projects toward real business outcomes.
>
> We're building this skill by skill. Today's focus is the foundation: storytelling."

---

## SLIDE 3 — Workshop 2 Title: Storytelling with Data

**Key Points**
- Name the central problem: data without a story doesn't move people
- Set expectations for the session

**Script**
> "Storytelling with Data. From Numbers to Narratives.
>
> Here's the truth: most of us in GDS are very good at finding the answer. The hard part is getting the *right people* to understand it — and to do something about it.
>
> Today, we're going to change that. We'll give you a framework, a sentence structure, and a set of tools to make your analysis land."

---

## SLIDE 4 — Session Learning Objectives

**Key Points**
- 4 concrete things they will be able to do after this session
- Read each one slowly — let it sink in

**Script**
> "By the end of today, you'll be able to do four things.
>
> One — **Apply the SCR framework**. This is the core structure for any data story.
>
> Two — **Craft a Big Idea**. One sentence. Opinionated. With stakes.
>
> Three — **Choose the right chart** for the right message. Not every chart works for every story.
>
> Four — **Avoid the five most common storytelling pitfalls** that GDS teams fall into.
>
> Let's start."

---

## SLIDE 5 — Icebreaker: Write in the Chat

**Key Points**
- Activate prior experience — everyone has felt this frustration
- Don't rush this; give real wait time (30–60 seconds)
- React to a few responses with empathy

**Script**
> "Before we go into the framework — I want to start with a question.
>
> Think of a time when your analysis was good... but nothing happened. No decision was made. No one acted on it.
>
> Drop **one word or phrase** in the chat: what do you think was the real reason it didn't land?
>
> *(wait 30–45 seconds)*
>
> *(read a few responses out loud)*
>
> Yes... 'too long.' 'Too technical.' 'Wrong audience.' 'No clear ask.'
>
> These are all storytelling problems — not analysis problems. The data was fine. The story was missing.
>
> That's exactly what we're solving today."

---

## SLIDE 6 — SCR Framework

**Key Points**
- SCR = Situation / Complication / Resolution
- Each component has a specific job — don't confuse them
- Spend time on this — it's the anchor for the whole session

**Script**
> "The framework we'll use today is called **SCR — Situation, Complication, Resolution**.
>
> It comes from management consulting, but it works perfectly for data storytelling.
>
> Let me explain each part.
>
> **Situation** — this is the context. What everyone already knows and agrees on. It's stable. It's not controversial. Think of it as: 'setting the scene.'
>
> **Complication** — this is where the tension lives. Something changed. There's a problem. There's a gap. This is the *reason* your audience needs to pay attention.
>
> **Resolution** — this is your recommendation. What does the data tell us to do? What action should we take?
>
> *(pause)*
>
> The most common mistake I see? People start with the Complication — or they skip straight to the Resolution. When you do that, your audience doesn't have the context they need. They feel confused, or they resist your conclusion.
>
> Always start with the Situation. Always."

---

## SLIDE 7 — Breakout Activity: What's the Story?

**Key Points**
- This is a hands-on group activity
- Give them a real case: m_rev_5 campaign expansion from Tier-2 to US
- Tell them to discuss in small groups for 5 minutes
- They should identify S, C, and R from the data

**Script**
> "Now let's practice. We're going to work with a real case.
>
> Here's the context: **A KR gaming client has a CPA campaign using a custom event called m_rev_5 — this fires when a user generates more than $5 in revenue within the first 7 days.**
>
> This campaign has been running in Tier-2 markets — UK, Australia, Germany, Canada. It's been performing well.
>
> Now, the client wants to expand to the **US**.
>
> I'll share the data with you now. *(share the data — the two tables from the case document)*
>
> In your breakout groups, I want you to answer three questions:
>
> **What is the Situation?** What's the stable context everyone agrees on?
>
> **What is the Complication?** What tension does the data reveal?
>
> **What is the Resolution?** What does the data suggest we should do?
>
> You have **5 minutes**. Go."
>
> *(After groups report back)*
>
> "Thank you. Let's look at what the full story looks like."

---

## SLIDE 8 — SCR Answers (m_rev_5 Case)

**Key Points**
- Walk through the data tables first, THEN land the SCR — don't read the bullets cold
- The complication is NOT "US users spend more per purchase" — median first purchase is $3.00 in both AUS and US. The issue is the DISTRIBUTION (wide vs. tight P75)
- Introduce "whales and minnows" as plain language before using the term "structural mismatch"
- cumul_rev_7 is also a binary threshold event (>$7), not a continuous signal — the argument is threshold recalibration, not a different type of event

**Data reference (have the Colab notebook or case study doc visible)**

| Table 1: First purchase amount | AUS | CAN | DEU | GBR | USA |
|-------------------------------|-----|-----|-----|-----|-----|
| Median | $3.0 | $2.0 | $2.2 | $3.2 | $3.0 |
| **P75** | **$3.1** | **$2.9** | **$3.0** | **$3.3** | **$8.0** |

| Table 2: Before m_rev_5 fires | AUS | CAN | DEU | GBR | USA |
|-------------------------------|-----|-----|-----|-----|-----|
| Median IAP count | 1 | 1 | 1 | 2 | 1 |
| **Avg IAP count** | 1.2 | 1.4 | 1.2 | 1.8 | **5.7** |
| Median total spend | $1.9 | $2.9 | $2.2 | $5.5 | $4.0 |
| **Avg total spend** | $2.8 | $3.4 | $4.3 | $6.6 | **$31.4** |

**Script**
> "Thank you. Let me walk through what the data is actually telling us — and then we'll put the SCR together.
>
> *(point to install-to-action curve)*
>
> Let's start with the install-to-action curve — cumulative converter reach by day since install.
>
> In Tier-2 markets, over 90% of converters trigger m_rev_5 within Day 7. In the US, only about 70% reach $5 by Day 7. That gap already tells us something is structurally different between these two markets.
>
> *(point to Table 1 — first purchase amount)*
>
> Now let's look at the first purchase amount table.
>
> The median first purchase is $3.00 for both Tier-2 countries and the US. Same number. So US users are not spending more per purchase than T2 users. That might surprise you.
>
> But now look at the P75 column — the 75th percentile.
>
> In Tier-2 countries — for example, Australia — P75 is about $3.10. That means 75% of Australian m_rev_5 users made their first purchase for $3.10 or less. The range is very tight. Almost everyone is buying around the same small amount.
>
> In the US, P75 is $8.00. That is a completely different picture. The top 25% of US users spent $8 or more on their first purchase. There is a much wider spread.
>
> *(pause)*
>
> Same median. Very different distribution.
>
> What does this mean? In Tier-2 markets, users are fairly uniform — almost everyone makes a small purchase of $2 or $3, and crosses $5 after one or two transactions. That is why 90%+ of Tier-2 converters trigger m_rev_5 within Day 7.
>
> In the US, you have two very different types of users.
>
> The first type — **whales**. They spend $8, $15, sometimes $30 on their very first purchase. They cross $5 immediately.
>
> The second type — **minnows**. They spend $2 or $3 each time and accumulate slowly. Many of them never reach $5 by Day 7. That ~30% of US users who never trigger m_rev_5 are mostly minnows.
>
> *(point to Table 2 — purchase count and total spend)*
>
> Now look at the second table — purchase count and total spend before m_rev_5 fires.
>
> Median purchase counts are about one across all markets. But in the US, the average is 5.7 purchases and $31 in cumulative spend.
>
> That gap — median $4, average $31 — is the whale effect. A small group of US users made many large purchases, pulling the average way up. The typical US user is actually close to a T2 user. But the whale outliers are very different.
>
> *(pause)*
>
> Now let's put this into our SCR.
>
> **Situation:** 'Our m_rev_5 CPA campaigns have delivered strong performance across Tier-2 markets — UK, Australia, Germany, Canada.'
>
> This is the agreed context. The campaigns work. Everyone accepts this. That is our foundation.
>
> **Complication:** 'Only ~70% of US converters reach $5 by Day 7, versus 90%+ in Tier-2 — US users split into whales who blow past $5 and minnows who never reach it.'
>
> This is the tension. The m_rev_5 trigger was calibrated for Tier-2's tight, uniform spending behavior. The US has a bimodal population — whales and minnows — and the same $5 threshold cannot serve both.
>
> **Resolution:** 'A US-specific trigger — cumul_rev_7 — should replace m_rev_5 for US campaigns, while Tier-2 stays unchanged.'
>
> Why cumul_rev_7? A $7 threshold sits just below the US P75 first purchase of $8.00. It targets the whale segment — the high-value users — and gives the model a cleaner, more consistent signal to learn from. We are not changing the type of event. We are recalibrating the threshold to match how US users actually spend.
>
> We are not saying the campaign is bad. We are saying: the same threshold does not fit two different markets.
>
> *(pause)*
>
> Notice what we just did. Situation gave us shared agreement. Complication introduced specific numbers as evidence — not a feeling, but data. Resolution gave a clear, actionable direction with a reason.
>
> That is the SCR framework working as it should."

**Slide 8 Complication bullet (live on deck)**
> *"Only ~70% of US converters reach $5 by D7 vs. 90%+ in T2 — US users split into whales who blow past $5 and minnows who never reach it."*

---

## SLIDE 9 — SCR in Action: Process-Led vs. Story-Led

**Key Points**
- Show the contrast between a "data dump" response and an SCR story
- The left side (❌) sounds like a process report — it describes what was done, not what was found
- The right side (✅) leads with the conclusion and earns the reader's attention immediately

**Script**
> "Now let me show you what this looks like in practice — side by side.
>
> Look at the **❌ Process-Led** version on the left.
>
> *'We pulled m_rev_5 CPA performance data across geos and analyzed install-to-action timing. After segmenting by market, we found differences in user conversion patterns. We then looked at first purchase behavior. There might be something structurally different about US users.'*
>
> How does that feel? *(pause)*
>
> It describes the work. It talks about what was done. But it never tells you what to think or what to do. And the ending — 'there might be something' — is not a conclusion. It's a shrug.
>
> Now look at the **✅ Story-Led** version.
>
> *'[S] Our m_rev_5 campaign has delivered strong performance in Tier-2 markets. [C] But the same $5 bar misfits the US — only ~70% of converters reach it by D7 vs. 90%+ in T2, because US users split into whales who blow past $5 and minnows who never reach it. [R] Switching to cumul_rev_7 for the US — while keeping m_rev_5 for Tier-2 — would restore efficiency without disruption.'*
>
> Three sentences. Clear situation. Clear problem. Clear action.
>
> Same data. Very different impact.
>
> The Process-Led version makes the reader do all the work. The Story-Led version respects their time and gives them what they need to decide."

---

## SLIDE 10 — The Big Idea

**Key Points**
- Every analysis needs one "Big Idea" sentence
- It must: (1) state a point of view, (2) include what's at stake
- The example comes directly from the m_rev_5 case
- Three rules: complete sentence, must have a verb, must be opinionated

**Script**
> "SCR gives you structure. The Big Idea gives you a *punch*.
>
> Every analysis should have one sentence — one single sentence — that captures your entire point of view and the stakes.
>
> Here's the example from our case:
>
> *'Applying a Tier-2 revenue trigger to the US without adjusting for whale-heavy user behavior is a structural mismatch — adopting a US-specific LTV marker now could prevent CPA deterioration before Q3 budget scales.'*
>
> *(pause)*
>
> Notice three things.
>
> First — **it has a point of view**. It says this IS a structural mismatch. Not 'might be.' Not 'potentially.' Is.
>
> Second — **it has stakes**. CPA deterioration. Budget scaling. These are real business consequences.
>
> Third — **it has urgency**. 'Before Q3 budget scales.' There's a time element.
>
> The three rules for your Big Idea: one complete sentence. A verb that takes a position. And an opinion — not just a description.
>
> Sounds simple. It's actually very hard. Let's practice."

---

## SLIDE 11 — Write Your Big Idea Sentence (Activity)

**Key Points**
- Individual reflection — give them 3 minutes of quiet thinking
- They should use something from their current work
- This is personal — not the m_rev_5 case

**Script**
> "Now it's your turn.
>
> Think about an analysis you are working on right now. Or one you finished recently.
>
> Write one sentence. Your Big Idea for that analysis.
>
> It should be opinionated. It should have stakes. One complete sentence.
>
> You have **3 minutes**. Take the time. Don't rush it."
>
> *(wait 3 minutes)*

---

## SLIDE 12 — Big Idea Coaching Prompts

**Key Points**
- Use these as real-time coaching when people are stuck
- Three common blockers: no point of view, no stakes, too vague
- Read the prompts slowly — pause after each question

**Script**
> "If you're stuck, here are three questions to help.
>
> **Stuck on point of view?**
> Ask yourself: 'What do I *believe* this data means?' Not what it shows — what does it *mean*? Write that.
>
> **Stuck on stakes?**
> Ask yourself: 'What happens if leadership ignores this finding?' If you can answer that question, you have your stakes.
>
> **Too vague?**
> Ask: 'For whom? By when? Can I put a number on this?'
>
> Add specifics. Specifics make your idea credible.
>
> *(pause)*
>
> Now — who wants to share? Drop your sentence in the chat."
>
> *(read 2–3 responses, give brief positive or coaching feedback)*
>
> "Great. The more you practice this, the faster it becomes. Every analysis starts with this sentence from now on."

---

## SLIDE 13 — Chart Chooser

**Key Points**
- Chart choice is not aesthetic — it's a communication decision
- Four types, four jobs
- Connect each to a GDS use case to make it real

**Script**
> "Now let's talk about visuals. You have your story. What chart do you use to support it?
>
> There are four main types, and each one has a specific job.
>
> **Comparison → Bar or Column chart.** When you want to show which group is bigger or smaller. GDS example: retention by acquisition channel.
>
> **Trend over time → Line chart.** When you want to show how something changes. GDS example: 30-day activation rate across cohorts.
>
> **Part-to-whole → Stacked bar.** When you want to show how components add up to a total. GDS example: revenue mix by product segment.
>
> **Correlation → Scatter plot.** When you want to show the relationship between two variables. GDS example: ad spend versus LTV by channel.
>
> *(pause)*
>
> The most common mistake: using a line chart for something that isn't a time series. Or using a stacked bar when a simple bar would be clearer.
>
> Match the chart to the message. Let's look at some examples."

---

## SLIDES 14–17 — Chart Examples (Bar / Stacked Bar / Line / Scatter)

**Key Points**
- Walk through each example quickly — 1–2 minutes per chart
- Focus on: what's the message this chart sends? What makes it clear?
- You don't need to explain the data in detail — use them as visual anchors

**Script (for each chart, adapt to what's shown)**
> *(Slide 14 — Bar/Column)*
> "Here's a bar chart comparison. Look at how easy it is to see which bar is tallest. No explanation needed. The chart does the work.
> Key rule for bar charts: always start your axis at zero. If you cut the axis, you exaggerate differences. That's misleading."
>
> *(Slide 15 — Stacked Bar)*
> "Stacked bars show composition. You can see both the total and the parts.
> Warning: don't use more than 3–4 categories. If you have 10 colors in a stacked bar, no one can read it."
>
> *(Slide 16 — Line Chart)*
> "Line charts are for time. Your eye naturally follows the line — it creates a sense of movement, of change.
> Key tip: annotate the interesting moments. Don't make people guess what happened at a spike or dip."
>
> *(Slide 17 — Scatter Plot)*
> "Scatter plots show relationships. Is there a pattern? A cluster? An outlier?
> These are harder for audiences to read, so add a trend line and label the key points."

---

## SLIDE 18 — 5 Pitfalls to Avoid

**Key Points**
- These are the most common mistakes GDS makes
- Be direct — call them out with examples if you have them
- This slide should feel like a checklist, not a lecture

**Script**
> "Before we close with an activity, here are the five pitfalls I see most often in GDS work.
>
> **One: Data Dumping.** Showing everything you found instead of what matters. Your audience doesn't need the full analysis — they need the answer.
>
> **Two: Chart Spaghetti.** Too many lines, too many colors, too many data points on one chart. When everything is highlighted, nothing is.
>
> **Three: Missing the 'So What.'** You show the data, but you don't tell people what to do with it. Always end with a clear recommendation.
>
> **Four: Leading with Methodology.** Starting your story with 'we used a cohort analysis with 30-day windows...' No. Start with the finding. If someone wants to know your method, they'll ask.
>
> **Five: Designing for Yourself.** You know the data inside out. Your audience doesn't. Always ask: 'Can someone who has never seen this data understand my slide in 10 seconds?'
>
> *(pause)*
>
> Print this list. Check it before every presentation."

---

## SLIDE 19 — Activity: Story Sprint

**Key Points**
- Final synthesis activity — they apply everything from today
- Give them 8–10 minutes
- Debrief with 2–3 volunteers

**Script**
> "Last activity. This is your Story Sprint.
>
> Three steps.
>
> **Step 1:** Write your Big Idea sentence. You already did this — refine it now.
>
> **Step 2:** Choose one chart type that best supports your Big Idea.
>
> **Step 3:** Write your three-sentence SCR narrative.
>
> You have **8 minutes**.
>
> *(wait)*
>
> *(after time is up)*
>
> Who wants to share? I'll ask two or three of you to read your SCR narrative out loud.
>
> *(for each person, give 1-line feedback: 'Strong Situation.' / 'Your Complication is clear.' / 'The Big Idea needs more stakes — what's the business risk?')*
>
> Really good work. You can see how different the story feels when it has structure."

---

## SLIDE 20 — Thank You

**Key Points**
- Land on a clear takeaway they can use tomorrow
- Close with energy — this is a workshop, not a lecture

**Script**
> "Thank you all for today.
>
> One thing I want you to take away from this session:
>
> **Before you send any analysis — write your Big Idea sentence first.**
>
> Not at the end. At the beginning. It will force you to be clear about what you actually believe.
>
> The SCR framework, the chart chooser, the pitfall list — those are tools. But the habit of leading with a point of view? That's the real skill.
>
> See you at Workshop 3."

---

## Quick Reference Card (print this for the session)

| Moment | What to do |
|--------|-----------|
| Opening | Welcome warmly, slow down |
| Icebreaker | Wait 30–45 sec for responses, react to 2–3 |
| SCR intro | Pause after each component |
| Breakout | Give 5 min, walk around if in-person / monitor chat if virtual |
| SCR reveal | Don't rush — explain the *why* behind each sentence |
| Big Idea | Give 3 min of silence for individual writing |
| Chart section | 1–2 min per chart, don't over-explain |
| Story Sprint | Give full 8–10 min, don't cut short |
| Close | End with one sentence takeaway |

---

*Total session: ~65 minutes. If running short, cut chart examples (Slides 14–17) to titles only.*
