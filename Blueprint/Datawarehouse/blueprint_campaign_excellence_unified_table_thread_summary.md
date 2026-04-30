# Blueprint × Campaign Excellence — Unified Data Table Discussion
**Source:** [Slack thread](https://moloco.slack.com/archives/C0AN9S6N5QS/p1775838682451159)  
**Captured:** 2026-04-13  
**Topic:** Building a single unified dataset covering Blueprint scores and Campaign Excellence defect signals

---

## TL;DR

The team is aligning on merging **Campaign Excellence defect signals** and **Blueprint scores** into a **single unified data product**. Key tension: Blueprint logic changes every 3–4 weeks, making historical backfill and physical table placement decisions complex. Q2 Phase 1 scope is narrowed to **campaign duplication (Type I/II)** and **supply block signals**. **DW team owns the migration.**

---

## Participants

| Person | Role / Contribution |
|--------|---------------------|
| **Grace Cui** | Campaign Excellence lead; defined Q2 OKR priorities, shared reference SQL, drove design direction |
| **Anirudh Narayanan** | DW team; implementation lead; raised DW best practices concerns, confirmed ownership |
| **Marvin Dao** | Blueprint team; raised Blueprint evolution/backfill concerns, flagged 3–4 week change cadence |
| **Nidhi Shah** | Updated Finance view fields sheet with candidate fields |
| **Myunggeun Song** | Acknowledged Nidhi's update |

---

## Thread Summary (Chronological)

1. **Nidhi** shared an updated Finance view fields sheet with candidate fields for the unified table. Myunggeun acknowledged.

2. **Marvin** signaled preference for **Option B** (keeping Blueprint data in a separate data products layer rather than embedding in `fact_dsp_daily`), citing Blueprint's fast-evolving logic — embedding permanent scores risks misleading users when definitions change.

3. **Grace** shared a **manual query** that pulls all columns needed for OKR metric calculation from existing tables — intended as the design reference for the consolidated table.

4. **Grace** asked **Anirudh** for a rough timeline for when OKR metrics could be computed from consolidated tables.

5. **Anirudh** noted that Ops Portal's `campaign_setup_defects_daily` logic and Grace's latest query defects are **complementary, not duplicative** — and flagged that having two parallel same-grain tables/pipelines violates DW best practices. Also noted: even a separate table doesn't avoid the "numbers change on logic update" problem.

6. **Grace** clarified:
   - Existing defects must stay in the data layer
   - Q2 OKR priority signals: **campaign duplication type 1/2** + **supply blocks** (not all Blueprint scores)
   - Goal: consolidate all defects/suboptimal signals into a **single source of truth**

7. **Anirudh** asked whether to extend `fact_dsp_daily_v3` (which already has 7 defects) by adding `has_type_ii_duplicate`, `is_unattributed_install_decline`, `supply_block` → **10 defects total**. Noted `fact_dsp_daily_v3` is better for slicing by region/vertical/goal/spend.

8. **Anirudh** agreed to the consolidation direction regardless of physical storage choice, as long as the **data product layer definition is stable**.

9. **Grace** shared a minor SQL fix for `under_experiment` logic; Anirudh confirmed it as the reference going forward. Grace also noted:
   - Dimensions already in existing tables don't need to be re-added
   - Daily aggregate flags (e.g., `has_any_defect`) can be computed from raw data → not required in the physical table

10. **Marvin** raised a set of design questions:
    - Will all Blueprint 5 pillars / ~15 scores be ingested?
    - Can grain be `(campaign_id, date)`?
    - Should wrong historical scores be null'd on logic change?
    - Is the real question whether to put Campaign Excellence daily score directly in `fact_dsp_daily_v3`?
    - Is Blueprint data still sourced from `alaricjames` tables?
    - Who owns the Airflow migration from scheduled queries?

11. **Anirudh** answered:
    - Phase 1 ingest: **campaign duplication score** (`has_type_i_duplicate`, `has_type_ii_duplicate`) + **supply accessibility score** (`is_supply_blocked`) — not all 15 scores yet; full ingest is the long-term plan
    - **Grain confirmed: `(campaign_id, date)`**
    - Logic change frequency is the key design variable — if changes are frequent, view-based computation is safer but more expensive; wrong-score nulling is technically hard
    - Short backfills are feasible; 3+ week backfills are a burden
    - **Blueprint source: stay with existing tables for now**; DW team can take ownership of Blueprint tables later
    - **DW team owns**: Campaign Excellence pipeline, target table, Airflow migration, data product creation (~1.5 weeks after CE pipeline is done)

12. **Marvin** confirmed anticipated Blueprint change cadence (~3–4 weeks): IGv5 score removal, new signals, creative score logic changes, vertical best practice updates, client feedback iterations. Personal view: **backfill matters only for OKR-linked metrics**.

13. **Anirudh** asked whether defect fields will keep expanding, shared a list of 14 candidate fields — deferred to Grace for an answer.

14. **Marvin** confirmed: **"DW team owns migration, not GDS"** — Anirudh confirmed.

---

## Decisions Made

| Decision | Detail |
|----------|--------|
| **Existing CE defects retained** | All current Campaign Excellence defects stay in the data layer |
| **Unified direction confirmed** | All defects + Blueprint signals consolidate into a single source |
| **Q2 Phase 1 scope** | Campaign duplication (Type I/II) + supply block signals only |
| **Grain** | `(campaign_id, date)` |
| **DW team owns migration** | GDS is not driving the pipeline/Airflow migration |
| **SQL reference** | Grace's latest query (with `under_experiment` fix) is the canonical reference |
| **Existing dimensions excluded** | No need to re-add dims already present in existing tables |
| **Daily aggregate flags excluded** | `has_any_defect` etc. computed on the fly from raw data |

---

## Open Questions

| Question | Owner |
|----------|-------|
| **Physical placement**: Embed in `fact_dsp_daily_v3` vs. separate data product layer? | Grace + Anirudh |
| **Backfill policy**: How far back when Blueprint logic changes? OKR-linked vs. non-OKR? | Grace + Anirudh |
| **Defect field expansion cadence**: Will new fields keep being added? At what frequency? | Grace (answer pending) |
| **OKR metrics timeline**: When can OKR metrics be computed from consolidated tables? | Anirudh / DW team |
| **Blueprint source migration**: When does `alaricjames` get replaced by DW-owned tables? | DW team |

---

## Next Steps

- **Anirudh / DW team**: Use Grace's latest SQL as the reference; proceed with Campaign Excellence pipeline → target table → Airflow migration → data product (~1.5 weeks for Blueprint source migration after CE pipeline done)
- **Grace**: Clarify future defect field addition scope/cadence so DW can finalize the schema
- **All**: Align on backfill scope (OKR-linked = backfill; non-OKR = no backfill?) and final physical placement decision (`fact_dsp_daily_v3` extension vs. separate layer)

---

## Context: What These Terms Mean

| Term | Meaning |
|------|---------|
| **Blueprint** | Moloco's campaign health scoring system — 5 pillars, ~15 scores; identifies structural issues in campaign setup |
| **Campaign Excellence** | Set of campaign defect signals already in `campaign_setup_defects_daily` / `fact_dsp_daily_v3`; tracks setup problems like missing creatives, budget issues, etc. |
| **Type I / Type II duplicate** | Blueprint campaign duplication signals: campaigns bidding against themselves in the same auction |
| **Supply block** | Signal indicating a campaign is blocked from relevant supply (publisher/format access issues) |
| **`fact_dsp_daily_v3`** | Core daily DSP fact table in `moloco-ods`; currently houses 7 Campaign Excellence defects |
| **`alaricjames` tables** | Current Blueprint score source tables (interim; to be migrated to DW-owned tables) |
| **DW team** | Data Warehouse engineering team; owns pipeline infrastructure and data product layer |
