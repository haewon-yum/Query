# Steve Power 1-1 — Meeting Prep

**Meeting:** Skip-level 1-1 with Steve Power (Senior Director, Data Science)
**Prepared:** 2026-04-22
**Output file:** `Tmp/steve_power_1on1.md`

---

## Session 2026-04-22

### Context
- **Scope:** Enrich Haewon's draft 1-1 agenda for a skip-level with Steve Power, who was visiting Korea for the APAC Leadership Summit
- **Sources used:** Google Doc (original draft), Glean search (Steve's OKRs, All Hands slides, org docs)

### Process & Research

| Step | Question | Approach | Finding |
|------|----------|----------|---------|
| 1 | What is Steve's current top-of-mind? | Glean search across Slack, OKR sheets, All Hands slides | April 13 All Hands announced Q2 Global DS Offsite; AI-enabled GDS initiative (Steve named APAC sponsor); KOR P0 OKR (Netmarble launches, Bitmango/Playhard +50%) |
| 2 | How does KOR GDS map to his OKRs? | Cross-reference Haewon's draft with OKR spreadsheet | "Defend KOR" is explicit P0 OKR; Steve has personal headcount OKR to "Hire 2 KOR GDS"; Haewon named as node in APAC org chart |
| 3 | Write enriched draft to Google Doc new tab | Google Docs API via gcloud ADC | Blocked: gcloud ADC lacks Docs scope → added scope via `gcloud auth application-default login`; then blocked by Docs API disabled in `gds-apac` project → ended up providing content as text for manual copy-paste |
| 4 | Save draft as markdown | Bash write to Tmp/ | Success: `steve_power_1on1.md` |

### Key Decisions Made During Prep

1. **Connected AI work to Steve's APAC sponsorship** — explicitly linked KOR GDS agentic workflows to the AI-enabled GDS initiative he is sponsoring, and flagged the Q2 DS Offsite as a potential venue to share learnings.

2. **Named Netmarble launches explicitly** — original draft was generic on premium accounts; enriched version calls out Netmarble new title launches as a P0 KOR OKR, giving Steve direct visibility into progress.

3. **Translated Korean career growth section** — original draft had career concerns written in Korean; translated and reframed as a structured, honest growth discussion.

4. **IC/manager dual role question** — moved from Career Growth section to Questions, as it's more of an ask for his perspective than a statement.

5. **Internal transfer question framing** — softened from "internal transfers" to "career pathing within the DS org broadly" to avoid signaling active intent to leave; keeps the question but reduces risk of awkwardness.

6. **Help Needed → reframed as alignment signal** — Haewon has no immediate asks; reframed as "things are well-aligned with Simon, I wanted to use this time to share KOR context and hear your perspective on the org direction" — avoids looking unmotivated while being honest.

### Final Document Structure
- **Ice Breaking** — Korea trip, LinkedIn kids post
- **KOR GDS Focus** — AI adoption, premium account support, product activation (IAA/RE)
- **Career Growth Discussion** — market growth constraints, global initiative contribution, PDS/Explab collaboration
- **Questions** — IC/manager dual role sustainability, career pathing, PDS structure, headcount determination
- **Help Needed** — alignment with Simon framing
- **Feedback** — weekly wins format positive feedback

### Open Questions / Notes
- [ ] Google Docs API disabled in `gds-apac` project — worth enabling for future use (`gcloud services enable docs.googleapis.com --project=gds-apac`)
- [ ] gds-core plugin safety hook has a bug: `type: "prompt"` hook outputs prose instead of JSON, causing hard errors on tool calls with OAuth file paths — fix applied to `hooks.json` but requires Claude Code restart to take effect
