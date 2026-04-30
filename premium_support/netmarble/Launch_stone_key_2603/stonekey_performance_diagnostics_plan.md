# Plan: Stonekey Performance Diagnostics Notebook

## Context
Netmarble Stonekey is launching/running across Android & iOS. The AM needs a single notebook to:
1. Quickly assess campaign-level efficiency (CPI, Login CPA, D1/D7 ROAS) for the past 7 days, broken down by OS
2. Understand monetization timing behavior (what % of revenue lands within D1/D3/D7/D28) to determine whether campaigns are eligible for the D1 or D3 model

**Eligibility logic (from Glean / existing ODSB tickets):**
- D1 model eligible: ≥50% of purchases/revenue within D1
- D3 model eligible: ≥50% within D3 (but <50% within D1)
- D7 default: if neither threshold met
- Cross-reference with: https://docs.google.com/spreadsheets/d/1w8StJ19HpuPZ8kj4oA3SD_To5sEoEVpoZce8gpkthQY/edit?gid=1375953392

---

## Output File
`premium_support/netmarble/Launch_stone_key_2603/stonekey_performance_diagnostics.ipynb`

---

## Inputs (parameterized at top)
```python
BUNDLE_IDS = ['com.netmarble.stonkey']          # Android confirmed; iOS TBD - discover via dim1_app
ANALYSIS_WINDOW_DAYS = 7                         # for Section 1 campaign performance
COHORT_WINDOW_DAYS = 45                          # for Section 2 purchasing behavior (need mature D28+ cohorts)
KPI_EVENT = 'login'                              # inferred from prior Stonekey analysis; verify from fact_dsp_core campaign.kpi_actions
```

---

## Notebook Structure

### Section 0: Setup
- Standard imports (bigquery, pandas, plotly)
- `run_query()` helper (matching existing project pattern)
- Parameter config block

### Section 0: Discover iOS Bundle & Verify KPI Event

**0a.** Query `dim1_app` WHERE `app_name LIKE '%stonkey%'` OR `app_name LIKE '%stonekey%'` to find iOS bundle
**0b.** Update `BUNDLE_IDS` with iOS App Store bundle ID once found
**0c.** Verify KPI event name from `fact_dsp_core.campaign.kpi_actions`

---

### Section 1: Campaign-Level Performance (Past 7 Days)

**Source:** `moloco-ae-view.athena.fact_dsp_core`
**Filter:** `app_market_bundle IN (BUNDLE_IDS)`, `date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE() - 1`
**Group by:** `campaign_id`, `campaign.title`, `campaign.os`, `campaign.country`, `campaign.goal`

**Metrics computed per campaign:**
| Metric | Formula |
|--------|---------|
| CPI | `SUM(gross_spend_usd) / SUM(installs)` |
| Login CPA | `SUM(gross_spend_usd) / SUM(kpi_actions_d7)` |
| D1 ROAS | `SUM(revenue_d1) / SUM(gross_spend_usd)` |
| D7 ROAS | `SUM(revenue_d7) / SUM(gross_spend_usd)` |
| Installs | `SUM(installs)` |
| Spend | `SUM(gross_spend_usd)` |

**Output:**
- Summary table with columns: `campaign_id`, `title`, `os`, `country`, `goal`, `spend_L7D`, `installs_L7D`, `cpi`, `login_cpa`, `roas_d1`, `roas_d7`
- Plotly grouped bar chart: CPI and Login CPA side-by-side by campaign, colored by OS (Android vs iOS)
- Plotly grouped bar chart: D1 ROAS and D7 ROAS by campaign, colored by OS

**Note on Login CPA:** Use `kpi_actions_d7` as denominator since login is a post-install event typically measured D7. Confirm the KPI event name by checking `campaign.kpi_actions` field (Section 0c).

---

### Section 2: Purchasing Behavior — Revenue Timeline

**Goal:** Show what % of total revenue arrives by D1, D2, ..., D28 (continuous curve), broken down by OS. Suggest D1 or D3 model.

**Step 2a — Cohort snapshot from `fact_dsp_core` (fast, D1/D3/D7/D14/D30 snapshots):**
```sql
SELECT
  campaign.os AS os,
  SUM(installs) AS installs,
  SUM(revenue_d1)  AS rev_d1,
  SUM(revenue_d3)  AS rev_d3,
  SUM(revenue_d7)  AS rev_d7,
  SUM(revenue_d14) AS rev_d14,
  SUM(revenue_d30) AS rev_d30
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE app_market_bundle IN (<BUNDLE_IDS>)
  AND date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 45 DAY)
                   AND DATE_SUB(CURRENT_DATE(), INTERVAL 31 DAY)  -- mature D30 cohort
GROUP BY 1
```
- Compute cumulative % at each snapshot: `pct_d1 = rev_d1/rev_d30`, etc.
- Monotonicity check: assert `rev_d1 ≤ rev_d3 ≤ rev_d7 ≤ rev_d14 ≤ rev_d30`
- Used for the eligibility summary box

**Step 2b — Continuous daily curve from `prod_stream_view.cv` (event-level):**
```sql
SELECT
  cv.pb.device.os AS os,
  TIMESTAMP_DIFF(timestamp, cv.pb.event.install_at, DAY) AS days_since_install,
  SUM(cv.revenue_usd.amount) AS revenue_usd
FROM `focal-elf-631.prod_stream_view.cv`
WHERE cv.pb.app.bundle IN (<BUNDLE_IDS>)
  AND cv.pb.moloco.attributed = TRUE
  AND cv.revenue_usd.amount > 0
  AND DATE(cv.pb.event.install_at) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 45 DAY)
                                       AND DATE_SUB(CURRENT_DATE(), INTERVAL 31 DAY)
  AND TIMESTAMP_DIFF(timestamp, cv.pb.event.install_at, DAY) BETWEEN 0 AND 30
GROUP BY 1, 2
ORDER BY 1, 2
```
- Aggregate cumulative revenue by day; compute `cumulative_pct = cumrev / total_rev_d30`
- **Verified:** Install timestamp field is `cv.pb.event.install_at` (from `BQ_Tables/BQ_RAW/table_cv.sql:169`)

**Output:**
- Plotly line chart: X = days since install (0–30), Y = cumulative % of D30 revenue
  - One line per OS (Android / iOS)
  - Vertical dashed lines at D1, D3, D7, D28
  - Horizontal dashed line at 50% threshold
  - Hover shows exact % at each day
- D1/D3/D7 % table (by OS): `rev_d1_pct`, `rev_d3_pct`, `rev_d7_pct`

---

### Section 3: D1/D3 Model Recommendation

**Logic (per OS):**
```python
if pct_d1 >= 0.50:
    recommendation = 'D1 model eligible'
elif pct_d3 >= 0.50:
    recommendation = 'D3 model eligible'
else:
    recommendation = 'D7 model (default) — insufficient early purchases'
```

**Output:**
- Summary table per OS: `os`, `pct_d1`, `pct_d3`, `pct_d7`, `recommendation`
- Inline note linking to the eligibility tracker spreadsheet for formal request submission

---

## Key Tables

| Table | Use |
|-------|-----|
| `moloco-ae-view.athena.fact_dsp_core` | Section 1 campaign perf + Section 2a cohort snapshot |
| `focal-elf-631.prod_stream_view.cv` | Section 2b continuous revenue curve |
| `moloco-ae-view.athena.dim1_app` | Discover iOS bundle ID for Stonekey |

---

## Open Items to Resolve During Implementation
1. **iOS bundle ID** — Run Section 0a query on `dim1_app` then update `BUNDLE_IDS`
2. **install timestamp field in cv** — Verified: `cv.pb.event.install_at` (not `install_ts`)
3. **Login event name** — Confirm via Section 0c (check `campaign.kpi_actions` in `fact_dsp_core`)
4. **Cohort maturity** — Cohort window excludes last 31 days; `COHORT_MATURITY_DAYS = 31`

---

## Reusable Patterns
- `run_query()` helper: `launch_checklist_v2.ipynb`
- `sql_in_clause()` helper: same file
- Plotly chart style: grouped bar + hover templates matching existing notebooks

---

## Verification Checklist
1. Run Section 1 — confirm at least 1 campaign appears per OS with non-zero spend
2. Run Section 2a — confirm `rev_d1 <= rev_d3 <= rev_d7 <= rev_d14 <= rev_d30` (monotone check in cell)
3. Run Section 2b — confirm daily curve sums match 2a snapshots approximately
4. Section 3 recommendation auto-populates from 2a percentages
