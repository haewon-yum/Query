# Plan: Stone Age Performance Investigation — OS × Country + KOR Optimization

**Context:** Netmarble Stone Age — newly launched early March 2026. Post-launch-burst decay expected; analysis should weight recent trend (L7D) over L14D aggregate.  
**Scope:** iOS + Android, all geographies for Section 1; KOR deep-dive in Sections 2–4.  
**Output:** `stoneage_performance_investigation.ipynb`

---

## Section 0: Setup & Discovery

### 0a. Parameters
```python
BUNDLE_IDS_ANDROID = ['com.netmarble.stonkey']
BUNDLE_IDS_IOS     = ['6737408689']   # App Store numeric ID; prepend 'id' only for App Store URL matching
LOOKBACK_DAYS      = 14
RECENT_DAYS        = 7   # primary focus window — post-launch-burst
LAUNCH_DATE        = '2026-03-03'
KOR_COUNTRY        = 'KR'
```

> **Bundle IDs confirmed:** StoneAge: Pet World (`스톤에이지 키우기`) — internally tracked as `stonkey`.  
> Launch: March 3, 2026 (global, Android + iOS simultaneous).

### 0b. Bundle ID Spot-Check
- Quick row count from `fact_dsp_core` WHERE `app_market_bundle IN (BUNDLE_IDS)` to confirm data exists
- Section 0b replaces full `dim1_app` lookup — IDs already verified

### 0c. Login Event Name Validation (two-step)

**Step 1 — Authoritative source: `fact_dsp_core.campaign.kpi_actions`**
```sql
SELECT DISTINCT
  campaign.id,
  campaign.title,
  campaign.os,
  campaign.kpi_actions
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE product.app_market_bundle IN (<BUNDLE_IDS>)
  AND date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
ORDER BY 1
```
- `kpi_actions` is the configured KPI event per campaign — this is the ground truth for what the campaign is optimizing toward
- **Hypothesis:** should show an event representing first login (e.g. `first_login`)
- Note: different campaigns may have different kpi_actions — check for consistency across KOR campaigns

**Step 2 — Cross-validate in cv table**
```sql
SELECT DISTINCT cv.pb.event.name, COUNT(*) AS cnt
FROM `focal-elf-631.prod_stream_view.cv`
WHERE cv.pb.app.bundle IN (<BUNDLE_IDS>)
  AND LOWER(cv.pb.event.name) LIKE '%login%'
  AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
GROUP BY 1 ORDER BY 2 DESC
```
- Confirm the event name from Step 1 actually appears in cv with meaningful volume
- Use the confirmed name in all Login CPA and Install-to-Login Rate calculations

---

## Section 1: OS × Country Performance Snapshot (L14D, recent-weighted)

**Source:** `moloco-ae-view.athena.fact_dsp_core`  
**Group by:** `campaign.os`, `campaign.country`

### 1a. Aggregate Table
| Metric | Formula |
|--------|---------|
| Spend (USD) | `SUM(gross_spend_usd)` |
| Installs | `SUM(installs)` |
| CPI | `SAFE_DIVIDE(spend, installs)` |
| Login events | From cv table (Section 0c event, attributed, post-install) |
| Login CPA | `SAFE_DIVIDE(spend, login_count)` |
| Install-to-Login Rate | `SAFE_DIVIDE(login_count, installs)` |
| D1 ROAS | `SAFE_DIVIDE(SUM(revenue_d1), spend)` |
| D7 ROAS | `SAFE_DIVIDE(SUM(revenue_d7), spend)` |

**Viz:** Color-coded heatmap table (countries as rows, OS as column groups). KOR row highlighted.

### 1b. Daily Trend (L14D)
- Daily line chart: CPI and D7 ROAS by OS
- Overlay: L7D average as dashed reference line
- **Why:** Identify if post-burst period shows stabilization or continued decline

---

## Section 2: KOR Diagnostic — CPI or ROAS Problem?

### 2a. KOR Summary & Classification
Pull KOR-only metrics for L7D broken down by campaign goal type.  
Apply the diagnostic framework:

```
D7 ROAS = D7 ARPU × (1 / CPI)
         = (D7 Revenue / Installs) × (Installs / Spend)
```

| Scenario | Signal | Root cause direction |
|----------|--------|---------------------|
| High CPI, OK ROAS | CPM high or IPM low | Supply/creative efficiency |
| Low ROAS, OK CPI | Low ARPU | User quality / targeting |
| High CPI + Low ROAS | Both | Compound — prioritize CPI first |

**Confirmed KPI target — D1 ROAS: 9%** (StoneAge: Pet World, per Netmarble)  
**Output:** Classification verdict per OS for KOR ("CPI issue", "ROAS below 9% D1 target", "both", "healthy").

### 2b. CPI Decomposition (if CPI is elevated)
**Source:** `moloco-ae-view.athena.fact_dsp_all`

```
CPI = CPM / IPM × 1000
IPM = (Installs / Impressions) × 1000
```

Pull `SUM(gross_spend_usd)`, `SUM(impressions)`, `SUM(installs)` for KOR, by OS and campaign.

| Sub-metric | If elevated → |
|-----------|---------------|
| CPM | Supply competition → bid strategy / publisher exclusion |
| Low IPM | Creative underperformance → creative refresh / landing page |
| Both | Systemic — consider geo targeting adjustment |

**Viz:** Scatter plot: CPM (X) vs IPM (Y) by campaign, sized by spend. Flag KOR outliers.

### 2c. ROAS Decomposition (if ROAS is low)
**Source:** `focal-elf-631.prod_stream_view.cv` (Moloco-attributed revenue events)

```
D7 ARPU = D7 Revenue / Attributed Installs
        = I2P × Avg Revenue per Paying User
```

**Cohort availability (as of April 9, 2026):**

| Cohort horizon | Mature install window | Days of data | Bias risk |
|---------------|----------------------|--------------|-----------|
| D7-mature | Install ≤ April 2 | ~30 days | Low — spans post-burst period |
| D28-mature | Install ≤ March 12 | ~10 days | **High — launch-burst users only** (early adopters / whales) |

**Decision: D7 ARPU is the primary metric.** D28 is technically available but the cohort (March 3–12) is exclusively launch-period users who over-index on monetization vs. steady-state. If D28 is included, flag the bias explicitly.

Compute per OS (KOR, attributed only), **D7-cohort as primary:**
- `I2P (Install-to-Payer rate) = COUNT(DISTINCT paying_users) / COUNT(DISTINCT install_users)` — D0–D7 window
- `ARPPU (Avg Revenue per Paying User) = SUM(revenue_usd) / COUNT(DISTINCT paying_users)` — D0–D7
- Revenue accumulation curve by day 0–7 from install date

**Optional D28 addendum:** If requested, run the March 3–12 cohort with a clear footnote: *"Launch-burst cohort only — D28 ARPU likely overstates steady-state LTV."*

**Viz:** Side-by-side bar: I2P vs ARPPU by OS (D7). Revenue curve D0–D7.

### 2d. Attributed vs Unattributed (Organic) Comparison
**Goal:** Determine if Moloco-acquired users underperform organic baseline → user quality signal.

**Why cv is not sufficient here:** `prod_stream_view.cv` contains only Moloco-attributed events. To compare attributed vs unattributed (organic) installs and their post-install revenue behavior, we need the raw postback table.

**Source:** `moloco-dsp-data-view.postback.pb` (unsampled postback table)
> ⚠️ **Table routing note:** `focal-elf-631.df_accesslog.pb` is deprecated — use `moloco-dsp-data-view.postback.pb` for all pb-based analyses going forward.

Filter logic:
- **Moloco-attributed:** `pb.moloco.attributed = TRUE` (or equivalent attribution flag in pb schema — verify field name at runtime)
- **Unattributed / organic:** `pb.moloco.attributed = FALSE` (or NULL)
- Country: KR, install date within L14D

Compute per attribution type × OS:
- D7 ARPU: sum of revenue events within 7 days of install, divided by install count
- I2P: distinct paying users / distinct installed users (D7 window)
- ARPPU: total revenue / distinct paying users (D7 window)
- Install-to-Login rate

| If Moloco ARPU << Organic ARPU | → Targeting is reaching wrong audience; consider goal type switch or audience signal improvement |
| If Moloco ARPU ≈ Organic ARPU  | → ROAS gap is a volume/CPI problem, not user quality |

**Note:** Verify pb schema field names (attribution flag, revenue field, event name field) in Section 0 before writing the full query.

**Viz:** Grouped bar: attributed vs unattributed ARPU at D1/D7, by OS.

---

## Section 3: Campaign Goal & Audience Analysis (KOR)

**Hypothesis:** Different campaign goals (CPI, D1 ROAS, D7 ROAS) target different audience quality signals. Comparing their outcomes reveals which goal is best aligned for this title's monetization curve.

### 3a. Campaign Inventory (KOR)
Pull all KOR campaigns: `campaign_id`, `goal`, `os`, `daily_budget_usd`, `cpi_target` / `roas_target`, `spend_L7D`.

### 3b. Performance by Goal Type
Group KOR campaigns by `campaign.goal`. Compute: CPI, D7 ROAS, Login CPA, Install-to-Login rate.

| Goal type | Expected behavior | Check |
|-----------|------------------|-------|
| CPI | Maximize installs; may sacrifice user quality | Compare ARPU vs ROAS-goal campaigns |
| D1/D7 ROAS | Targets paying users; should show higher ARPU | Confirm higher monetization rate |

**Viz:** Grouped bar by goal type: CPI, D7 ROAS, Login CPA. Flag if CPI-goal campaigns dominate spend but underperform on ROAS.

### 3c. Audience Overlap — Direct Comparison of Impressed Users by Campaign Goal

**Starting point:** Directly compare the user pools (device IDs) served impressions by CPI-goal vs ROAS-goal campaigns in KOR.

**Source:** Impression-level log table with device ID — verify correct table at runtime (likely `focal-elf-631.prod.trace*` or a bid-win log; confirm with BQ Agent before querying)

**Step 1 — Per-goal impression user sets**
```sql
-- For each campaign goal type, get distinct device IDs served at least 1 impression in KOR, L7D
SELECT campaign_goal, device_id, COUNT(*) AS impressions
FROM <impression_log_table>
WHERE country = 'KR'
  AND bundle IN (<BUNDLE_IDS>)
  AND date BETWEEN ...
GROUP BY 1, 2
```

**Step 2 — Overlap calculation**
- `|CPI ∩ ROAS|` — users reached by both goal types
- `|CPI only|`, `|ROAS only|` — exclusive audiences
- Overlap rate: `|CPI ∩ ROAS| / |CPI ∪ ROAS|` (Jaccard)

**Interpretation:**
| Overlap level | Meaning | Implication |
|---------------|---------|-------------|
| High (>50%) | Both goal types are bidding on the same users | Internal competition; differentiate by audience signal or segment |
| Low (<20%) | Goal types are naturally reaching different user pools | Healthy segmentation; understand who each reaches |
| Medium | Partial overlap | Check if the non-overlapping segments differ in post-install quality |

**Step 3 — Post-install quality by audience segment**
For users in each segment (CPI-only, ROAS-only, overlap), compare:
- Install rate (impressed → installed)
- I2P, ARPPU, D7 ARPU (from pb table)

This tells us whether the audience segments differ in monetization potential — not just that they were targeted differently.

**Recommendation trigger:** If CPI-goal campaigns are reaching the same audience as ROAS-goal campaigns with lower post-install quality → add purchase KPI signal or convert to ROAS goal.

---

## Section 4: Audience Saturation Check (KOR)

**Hypothesis:** For a title launched early March, KOR audience may be reaching saturation within 4–6 weeks — especially for a mobile RPG with core gamer audience.

**Signals to check:**

**Rate definitions (from `fact_supply`):**
```
bid_rate        = bids / bid_requests          -- how often Moloco enters the auction
win_rate        = bids_won / bids              -- how often Moloco wins when it bids
clear_rate      = impressions / bids_won       -- how often a win results in a rendered impression
bid_to_imp_rate = impressions / bids           -- = win_rate × clear_rate (the composite efficiency metric)
```

> **Note:** `impressions / bid_requests` is NOT win rate — it conflates bid rate, win rate, and clear rate. Use `bid_to_imp_rate` as the primary saturation signal; decompose into win_rate × clear_rate to identify where efficiency is lost.

| Signal | Formula | Saturation indicator |
|--------|---------|---------------------|
| CPM trend (daily) | `SUM(media_cost_usd) / SUM(impressions) * 1000` | Rising CPM = increasing competition for same users |
| Bid-to-imp rate | `SUM(impressions) / SUM(bids)` | Falling = harder to convert bids into impressions |
| ↳ Win rate component | `SUM(bids_won) / SUM(bids)` | Falling = losing more auctions (supply competition) |
| ↳ Clear rate component | `SUM(impressions) / SUM(bids_won)` | Falling = wins not rendering (exchange/fill issue) |
| Bid rate | `SUM(bids) / SUM(bid_requests)` | Falling = fewer eligible users entering auction (audience narrowing) |

**Source:** `moloco-ae-view.athena.fact_supply` — has all required fields (`bids`, `bids_won`, `impressions`, `bid_requests`, `media_cost_usd`)

**Viz:** Dual-axis line chart (L14D daily): CPM (left Y) + Bid-to-imp rate (right Y). Annotate with win_rate and clear_rate as separate traces or hover detail.

**If saturation detected:**
- Expand to adjacent geos (SEA, JP)
- Retargeting campaigns for D1 non-payers
- Lookalike audience from high-value KOR cohort

---

## Section 5: Summary & Prioritized Recommendations

Auto-generated from analysis outputs:
```
[RED / YELLOW / GREEN] CPI efficiency (KOR, Android / iOS)
[RED / YELLOW / GREEN] D7 ROAS (KOR, Android / iOS)
[RED / YELLOW / GREEN] User quality vs organic baseline
[RED / YELLOW / GREEN] Campaign goal alignment
[RED / YELLOW / GREEN] Audience saturation risk
```

Prioritized action list (top 3 for AM to act on immediately).

---

## Key Tables

| Table | Sections |
|-------|---------|
| `moloco-ae-view.athena.fact_dsp_core` | 1, 2a, 3a, 3b |
| `moloco-ae-view.athena.fact_dsp_all` | 2b (CPI decomp), 4 (saturation) |
| `focal-elf-631.prod_stream_view.cv` | 0c (event discovery), 2c (ARPU decomposition — attributed only) |
| `moloco-dsp-data-view.postback.pb` | 2d (attributed vs organic comparison — unsampled pb) |
| `moloco-ae-view.athena.dim1_app` | 0b (bundle discovery) |

---

## Open Items (resolve in Section 0)
1. ~~**Bundle IDs**~~ — **Confirmed:** Android `com.netmarble.stonkey`, iOS `6737408689`
2. **Login event name** — validate `first_login` from cv table (Section 0c)
3. **Revenue event name** — confirm purchase/payment event name for monetization rate calculation (Section 0c)

---

## Implementation Notes
- Prioritize L7D over L14D wherever possible — post-launch-burst window means L14D aggregates obscure recent trend
- All Login CPA calculations from cv table (NOT `kpi_actions_d7`) — filter `cv.pb.event.name = '<validated_login_event>'`
- `SAFE_DIVIDE` on all rate metrics
- Monotonicity assertion on revenue snapshots: `rev_d1 ≤ rev_d7`
