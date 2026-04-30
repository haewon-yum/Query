# ODSB-17737 — Coupang Play RE Evergreen vs Winback Traffic Split

**Ticket:** [ODSB-17737](https://mlc.atlassian.net/browse/ODSB-17737)
**Advertiser:** Coupang Play (ECHOMARKETING workspace, Advertiser ID: A1Z688dwKvn2lIWa)
**Investigation started:** 2026-04-21

---

## Session 2026-04-21

### Context
- **Scope**: Campaign info lookup and audience setting comparison for Coupang Play RE campaigns; T4G resource links
- **Campaigns in scope**:
  - `XSSerwjZxLN6BPRz` — Moloco_RE_Open_AOS_RE_Evergreen_2511 (control)
  - `Bj9INzbGlRDi8Uyx` — Moloco_RE_Open_AOS_RE_Winback_2604 (test)
- **Sources used**: Glean (ODSB-17737 Analysis Report PDF, Jira ticket), Speedboat MCP (`get_campaign_setting`)

### Process & Hypotheses
| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | What are the basic configs for both campaigns? | Glean chat with campaign IDs | Both are APP_REENGAGEMENT / OPTIMIZE_REATTRIBUTION_FOR_APP / OPEN / Android / KOR under same advertiser |
| 2 | What is the audience targeting difference between Evergreen vs Winback? | Glean (inconclusive) → Speedboat MCP `get_campaign_setting` | Different audience target IDs; Evergreen ~8.8M users; Winback audience smaller by design |
| 3 | Where is T4G experiment list? | Glean chat | Notion hub + Test Library; also `go/t4g` shortcut |

### Key Findings

1. **Evergreen is active; Winback is not yet enabled** — As of Apr 17, Evergreen spends ~$2–2.7K/day. Winback has `enabled = NULL`, $0 spend, 0 impressions since Jan 2026. Winback was started Apr 16 but paused Apr 17. Implication: T16 experiment cannot start until Winback is re-enabled in MCP.

2. **Different audience lists — same campaign structure** — Evergreen uses audience `RVPJVUBQf4dCiCza` (~8.8M users); Winback uses `UiDAnnVwrNLxmLQC` (size unknown). All other settings are identical: same goal, KPI event (OPEN), LAT exclusion (NON_LAT_ONLY), frequency cap (1 imp/12h), bucket split (0–15 / 15–100). Implication: clean A/B pair structure is valid for T16; audience size asymmetry is expected and by design.

3. **Inactivity window not set at campaign level** — Neither campaign defines an explicit `inactive_since` or `attr_window` in MCP config. Lapse/churn logic is embedded in the audience list definitions (`RVPJVUBQf4dCiCza`, `UiDAnnVwrNLxmLQC`). Implication: to understand exact recency windows, inspect those audience lists in MCP or AppsFlyer audience builder directly.

4. **Proposed experiment split revised from 50:50 to 80:20** — Original ODSB-17737 request was 50:50 Evergreen:Winback. A later comment revised to 80:20. No ExpLab draft existed as of Apr 17 analysis. Implication: experiment type is `t4g_t16`; need to confirm final split ratio before creating ExpLab draft.

### Open Questions
- [ ] Confirm final traffic split ratio (50:50 or 80:20) with requestor before creating ExpLab draft
- [ ] Re-enable Winback campaign `Bj9INzbGlRDi8Uyx` in MCP before experiment can start
- [ ] Inspect audience list `UiDAnnVwrNLxmLQC` (Winback) and `RVPJVUBQf4dCiCza` (Evergreen) in MCP/AppsFlyer to confirm exact inactivity window definitions and Winback audience size
- [ ] Create ExpLab draft once Winback is enabled — experiment type `t4g_t16`, evaluation metric: CPD_Install (reattributions), secondary: D7 return rate / CPA
