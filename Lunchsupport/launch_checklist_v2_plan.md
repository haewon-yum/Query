# New Title Launch Support Checklist v2 — Planning Doc

## Overview

v2 restructures the diagnostic notebook into two tiers:

- **Bundle-level analysis** — checks that apply to the app as a whole (PA status, revenue postback)
- **Campaign-level analysis** — checks scoped to specific countries/campaigns (VT install, creative format, bid filter, CT leakage, rejected installs)

The key change from v1: support **multiple bundles, countries, and campaigns** as inputs, with smart campaign resolution logic.

---

## Input Parameters


| Parameter          | Type                   | Required | Example                                |
| ------------------ | ---------------------- | -------- | -------------------------------------- |
| `BUNDLE_IDS`       | comma-separated string | Yes      | `"6739616715, com.fatmerge.global"`    |
| `TARGET_COUNTRIES` | comma-separated string | No       | `"KOR, USA, JPN"`                      |
| `CAMPAIGN_IDS`     | comma-separated string | No       | `"nkgLw08ChONIguL7, GK2fIdNthVl1rtyn"` |


---

## Campaign Resolution Logic

The campaign-level checks need to determine **which campaigns to analyze**. The logic:

```
IF campaign_ids provided AND target_countries provided:
    campaigns = (all campaigns targeting the specified countries)
               UNION
               (explicitly listed campaign_ids, even if outside those countries)

ELSE IF campaign_ids provided AND NO target_countries:
    campaigns = explicitly listed campaign_ids only

ELSE IF NO campaign_ids AND target_countries provided:
    campaigns = all campaigns under the bundle targeting the specified countries

ELSE (neither provided):
    campaigns = all campaigns under the bundle
```

Implementation:

1. Query `fact_dsp_core` for all campaigns under the resolved bundles in the last 14 days
2. Filter by country/campaign inputs using the logic above
3. Store result as `df_campaigns` with columns: `campaign_id`, `country`, `spend`, `installs`
4. Use this resolved campaign list for all campaign-level checks

---

## Notebook Structure

### Section 0: Setup

- **Cell 0** — Markdown: title, author, description
- **Cell 1** — Colab authentication (`from google.colab import auth`)
- **Cell 2** — Environment setup: imports (`bigquery`, `pandas`, `plotly`), `run_query` helper, display settings

### Section 1: Parameters & Resolution

- **Cell 3** — User inputs: `BUNDLE_IDS`, `TARGET_COUNTRIES`, `CAMPAIGN_IDS` (Colab form params)
- **Cell 4** — Bundle resolution: for each bundle, resolve `tracking_bundle`, `mmp_bundle_id`, `app_store_bundle`, `os` from `product_digest`. Store as `df_bundles` (one row per bundle).
- **Cell 5** — Campaign resolution: apply the campaign resolution logic above. Query `fact_dsp_core` for active campaigns, filter by inputs. Print resolved campaign list with spend/installs summary. Store as `df_campaigns`.

### Section 2: Bundle-Level Analysis (loop per bundle)

These checks run **once per bundle**, not per campaign.

- **Cell 6** — Markdown: `## Bundle-Level Checks`
- **Cell 7** — **1-A. PA Status (iOS only)**: query `mmp_pb_summary.app_status` for each bundle. Skip for Android bundles. Show as table grouped by bundle.
- **Cell 8** — **1-B. PA Attribution Method**: query `cv` postbacks for each bundle. Check for probabilistic/modeled attribution. Show attribution methods per bundle.
- **Cell 9** — **2. Revenue Postback Reception**: query `cv` for revenue events per bundle. Flag bundles with zero revenue postbacks.

### Section 3: Campaign-Level Analysis (scoped by resolved campaigns)

These checks use the resolved `df_campaigns` list. All queries filter to the resolved campaign/country scope.

- **Cell 10** — Markdown: `## Campaign-Level Checks`
- **Cell 11** — **3. VT Install Check**: query `cv` for VT installs within the resolved campaign scope. Show daily breakdown.
- **Cell 12** — **4-A. Creatives Configured**: query `creative_digest` for bundles. Show active creative formats.
- **Cell 13** — **4-B. Creative Impressions**: query `fact_dsp_creative` for impressions within the campaign scope. Show by format. Interactive chart.
- **Cell 14** — **5. Kakao Bizboard (KOR only)**: only run if `KOR` is in the resolved countries. Query for 1029x258 creative impressions.
- **Cell 15** — **6-A. Bid Filter (pricing)**: query `pricing` table for resolved campaigns. Daily filter rate + interactive chart of filter reasons. Includes anomaly flags (see Bid Filter Anomaly Detection below).
- **Cell 16** — **6-B. Bid Filter (campaign_trace)**: query `campaign_trace_raw_prod` for resolved campaigns. Pre-pricing pipeline stages only. Interactive chart with `reason:reason_raw` detail. Includes funnel pass-through table + anomaly flags.
- **Cell 16b** — **6-C. Bid Filter Anomaly Summary**: consolidated anomaly flags from 6-A and 6-B. Auto-generated alerts printed in human-readable format.
- **Cell 17** — **7-A. CT Install Leakage (1h)**: query `pb` + `click` for unattributed installs within 1h of Moloco click. Scoped to resolved campaigns. Daily leakage rate.
- **Cell 18** — **7-B. Rejected Install Rate**: query `fact_dsp_core` for `installs_rejected` within campaign scope. Daily rejection rate.

### Section 4: Summary

- **Cell 19** — Markdown: `## Summary`
- **Cell 20** — Diagnostic summary: per-bundle results for bundle-level checks, aggregated campaign-level results. Includes bid filter alert count from anomaly detection. Use `bool()` for numpy-safe checks. Print with ✅/⚠️/❓/⏭️ icons.

---

## Key Design Decisions

### Multi-bundle iteration

- Bundle-level checks (PA, revenue) loop over each bundle in `df_bundles`
- Campaign-level checks query all resolved campaigns at once (no per-campaign loop — too slow)
- SQL `WHERE ... IN (...)` clauses built from the resolved lists

### Filter clause generation

Helper functions to build SQL filter clauses from the resolved lists:

```python
def sql_in_clause(values, field):
    """Generate 'AND field IN ('a','b','c')' or empty string if no values."""
    if not values:
        return ''
    quoted = ', '.join(f"'{v}'" for v in values)
    return f"AND {field} IN ({quoted})"
```

### Country handling

- `campaign.country` in `fact_dsp_core` uses uppercase 3-letter ISO codes (KOR, USA, JPN)
- Normalize user input: strip whitespace, uppercase
- Kakao Bizboard check auto-skips if KOR not in scope

### OS handling

- `APP_OS` derived per bundle from `product_digest`
- PA Status (1-A) skipped for Android bundles
- CT Leakage (7-A) note: IFA coverage is low on iOS post-ATT; results may be sparse

### Interactive charts

- Use Plotly for all charts (hover, toggle, zoom)
- 6-A: stacked bar of filter reasons after pricing
- 6-B: subplots per reason_block in funnel order, with `reason:reason_raw` labels

### Bid Filter Anomaly Detection (6-A / 6-B)

Three automated checks to flag abnormal bid filter patterns:

#### Check 1: Funnel Pass-Through Rate (6-B)

Show what % of requests survive each pipeline stage. Implemented as a summary table:

```
Stage                          | Volume (M) | Survived | Pass Rate
Get candidate campaigns        |     100.0  |   80.0   |   80.0%
Evaluate candidate campaigns   |      80.0  |   60.0   |   75.0%
get candidate ad_groups        |      60.0  |   40.0   |   66.7%
```

- Compute by taking each `reason_block`'s total volume and subtracting filtered volume
- The "survived" count of one stage = input to the next stage
- **Flag**: any stage with pass rate < 5% (almost everything filtered at that stage)

#### Check 2: Single-Reason Dominance (6-A + 6-B)

Flag when a single filter reason accounts for an outsized share of filtering at any stage. Based on proven heuristic from campaign trace knowledge: 96%+ at one reason = likely misconfiguration.

- For each `reason_block` (6-B) and for filtered `candidate_result` (6-A):
  - Compute each reason's share of the stage's total filtered volume
  - **Flag**: any single reason > 80% of a stage's filtered volume
- Common actionable flags:
  - `(ad_group) Req: LocationSets` → audience_target location mismatch
  - `(ad_group) Ctx: Categories` → filter_expr categories vs publisher mismatch
  - `(campaign) Req: DeviceOses` → OS targeting misconfigured
  - `BudgetExhausted` in 6-A → budget/pacing issue

Output format:
```
⚠️ DOMINANCE: "LocationSets" accounts for 94% of filtering at [get candidate ad_groups] stage
⚠️ DOMINANCE: "BudgetExhausted" accounts for 85% of filtering at [pricing] stage
```

#### Check 3: Day-over-Day Change Detection (6-A + 6-B)

Compare each day's filter reason distribution against the trailing average to detect sudden shifts (e.g., config changes, targeting updates).

- For each reason, compute:
  - `today_share`: reason's % of stage volume today
  - `trailing_avg`: reason's average % over previous days in the window
  - `delta`: `today_share - trailing_avg`
- **Flag conditions** (any of):
  - Reason share **increased by >20pp** vs trailing average
  - Reason **newly appeared** (0% trailing → >5% today)
  - Reason **disappeared** (>10% trailing → 0% today)

Output format:
```
⚠️ SPIKE: "BudgetExhausted" jumped from 12% avg → 45% on 2026-02-25 at [pricing] stage
⚠️ NEW: "(campaign) Req: DeviceOses" appeared at 15% on 2026-02-25 (not seen in prior days)
⚠️ GONE: "category_blocked" dropped from 8% avg → 0% on 2026-02-25
```

#### Implementation notes

- All three checks produce a list of `alerts: list[dict]` with keys: `type` (dominance/spike/new/gone/low_passthrough), `stage`, `reason`, `value`, `message`
- Alerts are printed in cell 16b and fed into the summary cell
- Summary check for bid filter: `✅ OK` if zero alerts, `⚠️ Check needed` if any alerts, with alert count

---

## Migration from v1


| v1                       | v2                            | Change                    |
| ------------------------ | ----------------------------- | ------------------------- |
| Single `BUNDLE_ID`       | `BUNDLE_IDS` (multi)          | Loop + list handling      |
| Single `CAMPAIGN_ID`     | `CAMPAIGN_IDS` (multi)        | Campaign resolution logic |
| No country input         | `TARGET_COUNTRIES`            | Country-aware scoping     |
| All checks sequential    | Bundle-level → Campaign-level | Cleaner structure         |
| matplotlib charts        | Plotly interactive            | Already done in v1 latest |
| `is True` checks         | `bool()` checks               | Already fixed in v1       |
| `critical_alert` for 7-B | `fact_dsp_core` for 7-B       | Already done in v1        |


---

## Feedback 260227 11PM (pending implementation)

1. **[General]** All columns representing metrics with a time window should include the duration in the column name (e.g., `spend` → `spend_L14D`, `installs` → `installs_L14D`, `revenue_events` → `revenue_events_L7D`). Apply consistently across all cells: Campaign Resolution, Revenue Postback, Creative Impressions, Rejected Installs, etc.
2. **[General]** Each section should have a markdown header cell before the code cell (like v1). Replace `#@title ...` pattern with a proper `## N. Section Name` markdown cell preceding each code cell.
3. **[General]** All queries must be consistent with the original v1 notebook (`Lunchsupport/campaign_diagnostic.ipynb`) — same tables, field paths, filter patterns, and column aliases — except for new logic in step 6 (bid filter anomaly detection). When in doubt, copy the v1 query and only adapt for multi-bundle/campaign support.
2. **[Revenue Postback Reception]** Don't hardcode event names (`PURCHASE`, `REVENUE`). Match v1 approach: filter by `cv.revenue_usd.amount IS NOT NULL` instead, and show `cv.event_pb` as the event name, `events_with_revenue` count, and `total_revenue_usd`. This captures all revenue-bearing events regardless of event name.
3. **[4-B. Creative Impressions by Format]** Add % share to both the printed summary and the chart hover. Specifically: (a) printed summary should show `% of impressions` and `% of spend` per format, (b) chart hover annotation should include the format's % share of daily impressions.
4. **[5. Kakao Bizboard]** Be consistent with v1 query — use `creative.size = '1029x258'` and `LOWER(exchange) LIKE '%kakao%'` instead of `creative.width`/`creative.height`. Also include `creative.format`, `creative.title`, `creative.id`, and `gross_spend_usd` in the output.

---

## To-Do (implementation order)

1. [ ] Create notebook `launch_checklist_v2.ipynb`
2. [ ] Implement cells 0-2 (setup, auth, imports)
3. [ ] Implement cell 3 (multi-value input parameters with parsing)
4. [ ] Implement cells 4-5 (bundle resolution + campaign resolution logic)
5. [ ] Implement cells 7-9 (bundle-level: PA status, PA method, revenue postback)
6. [ ] Implement cells 11-13 (campaign-level: VT install, creative config, creative impressions)
7. [ ] Implement cells 14-16 (Kakao bizboard, bid filter 6-A, bid filter 6-B with charts)
8. [ ] Implement cell 16b (bid filter anomaly detection: funnel pass-through, dominance check, day-over-day change)
9. [ ] Implement cells 17-18 (CT leakage, rejected installs)
10. [ ] Implement cell 20 (diagnostic summary, including bid filter alert count)
10. [ ] Test with iOS bundle (e.g., `6739616715`) + Android bundle (e.g., `com.fatmerge.global`)

