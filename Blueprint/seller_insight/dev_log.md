# Blueprint Seller Insight — Development Log

**Service URL:** https://blueprint-seller-insight-326198683934.asia-southeast1.run.app
**Cloud Run project:** `gds-apac` · Region: `asia-southeast1`
**Source table:** `ads-bpd-guard-china.blueprint.project_blueprint_combined_data`
**BQ billing project:** `ads-bpd-guard-china`

---

## Session 2026-04-20

### Context
- **Scope**: UI polish (overall bar position, View 3 leaderboard), source table migration, validation query
- **Files changed**: `queries.py`, `callbacks.py`, `layout.py`

### Process & Hypotheses

| Step | Question | Approach | Outcome |
|------|----------|----------|---------|
| 1 | Overall bar appears at bottom of chart — move to top | Plotly `categoryarray`: last element = top; changed from `all_labels[::-1]` to `pillars[::-1] + ["overall"]` | Fixed |
| 2 | Restore View 3 peer group leaderboard (was dropped) | `_view3()` existed in callbacks but wasn't wired to layout or router; added `tab-btn-v3` to layout, updated `switch_tab` and `render_tab` | Restored with rank, focal highlight, per-pillar columns |
| 3 | Migrate source table from `alaricjames` to `ads-bpd-guard-china` | One-line change: `BLUEPRINT_TABLE` in `queries.py` | Done; validated with NEXON/1290086677 query |

### Key Findings
1. **Validation: NEXON / `1290086677` (MapleStory M iOS)** — 30 rows = 2 campaigns × 15 checks. Bundle overall score = **76.18** (spend-weighted: $558 × 76.45 + $350 × 75.75 / $908). Lowest pillar: `optimization_strategy` = 50.0 (both campaigns score 0 on `2_kpi_event_volume`). Math verified manually.
2. **spend_L7 is last-7-day spend** — pre-computed column in the blueprint table; used as weight for all bundle-level score aggregations.

### Open Questions
- [ ] None from this session

---

## Session 2026-04-22

### Context
- **Scope**: Fix Spend L7 showing "—" in campaign drill-down; redesign Pillar Drill-Down diagnosis section
- **Files changed**: `queries.py`, `callbacks.py`

### Process & Hypotheses

| Step | Question | Approach | Outcome |
|------|----------|----------|---------|
| 1 | Spend L7 always shows "—" in campaign view | `spend_L7` was absent from `focal_rows` SELECT in the UNION query | Added `f.spend_L7` to focal_rows; added `CAST(NULL AS FLOAT64) AS spend_L7` to peer_rows |
| 2 | Diagnosis section unreadable (wall of text) | Replace `_diagnosis_card()` text blocks with structured table | New table: Sub-pillar \| Campaign (title + ID) \| Spend L7 \| Score \| Detail \| Recommendation |
| 3 | Sub-pillar filtering | Add dropdown to filter campaign detail table by blueprint_index | `dd-subpillar-v2` dropdown + separate `render_view2_table` callback |

### Key Findings
1. **Root cause of missing Spend L7**: The SQL UNION had `f.spend_L7` omitted from the `focal_rows` CTE SELECT list, so the column was always NULL for focal rows regardless of actual data.

### Open Questions
- [ ] None from this session

---

## Session 2026-04-23

### Context
- **Scope**: Add peer benchmark comparison to Pillar Drill-Down; fix BQ billing project permissions; create architecture doc; fix Cloud Run IAM
- **Files changed**: `queries.py`, `callbacks.py`, `architecture.html` (new)

### Process & Hypotheses

| Step | Question | Approach | Outcome |
|------|----------|----------|---------|
| 1 | Pillar Drill-Down shows no peer comparison — only focal data | Add `_view2_pillar_callout()` (headline card) + `_view2_benchmark_summary()` (per-sub-pillar peer gap table) above campaign detail table | Callout shows pillar percentile + most lagged/strongest sub-pillar; benchmark table shows Bundle Score \| Peer Median \| Peer IQR \| Gap \| Status |
| 2 | Santiago can't see platform dropdown | Diagnosed: `gds-apac` has no `bigquery.jobUser` for end users; only `sitian.lim@moloco.com` and one SA | Changed `BQ_PROJECT` from `gds-apac` to `ads-bpd-guard-china`; users already have `bigquery.jobUser` there via `gcp-bigquery-user` group |
| 3 | `Error: Forbidden` on the service URL | Cloud Run IAM only had `domain:moloco.com` as invoker — requires identity token in header, which browsers don't send | Added `allUsers` as `roles/run.invoker`; app-level `@moloco.com` gate remains via Flask OAuth |

### Key Findings
1. **IAM root cause (Santiago)**: `gds-apac` project had no `bigquery.jobUser` grant for any end-user group. `ads-bpd-guard-china` already had both `bigquery.dataViewer` + `bigquery.jobUser` for `gcp-bigquery-user@moloco.com`, making it the natural billing project.
2. **Cloud Run Forbidden error**: `--allow-unauthenticated` in the deploy command did NOT override an existing `domain:moloco.com` IAM binding set previously. Had to explicitly add `allUsers` via `gcloud run services add-iam-policy-binding`. The two layers are independent: Cloud Run IAM (transport) vs Flask OAuth (application).
3. **Architecture doc created**: `architecture.html` — 9 sections covering system overview, auth flow, IAM, code components, data model, filter logic, UI views, deployment, and known constraints.

### Open Questions
- [ ] Slide generation feature (Google Slides API) — discussed options A/B/C; not yet implemented
- [ ] Any user not in `gcp-bigquery-user` or `gcp-gds-apac` will pass OAuth but see empty dropdowns — no self-service fix for end users today

---
