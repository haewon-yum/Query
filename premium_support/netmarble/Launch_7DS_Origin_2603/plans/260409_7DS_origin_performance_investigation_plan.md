# Plan: 7DS: Origin Performance Investigation — OS × Country + KOR Optimization

**Context:** Netmarble The Seven Deadly Sins: Origin (`일곱 개의 대죄: 오리진`) — launched March 23–24, 2026 (iOS + Android global). Near-total UA pullback by late March; Moloco SoI was 3.2% globally (13% KOR) at launch. Analysis window is ~21 days (as of Apr 13).  
**Scope:** iOS + Android, all geographies for Section 1; KOR deep-dive in Sections 2–4.  
**Output:** `260409_7DS_origin_performance_investigation.ipynb`

---

## Title-Specific Context (read before analyzing)

| Dimension | Detail |
|-----------|--------|
| Bundle IDs | Android: `com.netmarble.nanaori` · iOS: `6744205088` |
| Launch | March 23–24, 2026 (global, Android + iOS) |
| Genre | Open-world action RPG, cross-platform (PC / console / mobile) |
| D1 ROAS KPI | **5%** (per Netmarble) |
| Moloco role at launch | Secondary — budget routed to other channels (DoubleVerify + Amazon) pre-launch |
| Key structural friction | 9–16 GB download size → significant drop-off before first login event |
| Business model | Light, low-ticket purchases → ROAS ceiling is structurally lower than mid-core RPG |
| UA status (Apr 2026) | Near-total pullback; ~$20K across all media by Mar 26 |
| **Campaigns (confirmed)** | Android: `HTVA26OzfthK6LPa` (CPA, paused Apr 8), `vHKyRhJl9k9V6xXs` (CPA, active), `iyH1zVvUZpViudzo` (ROAS, active Apr 6+); iOS: `wtxzCfjzlievxX0V` (CPA, active), `okI07jJTGX8mzoyK` (ROAS, inactive) |
| **Login event** | `login_1st` (confirmed via Searchlight — NOT standard `login`) |
| **Key finding (Searchlight)** | IPM collapsed −75% (Android) and −89% (iOS) W1→W3; worst 2–3% of 540 KOR gaming campaigns. Root cause: audience exhaustion, not creative fatigue (creatives ruled out via F1). |
| **Kakao VT artifact** | 95.6% of Kakao installs = VT; CT-only CPI: $53.79 vs apparent $2.39; CVR 35.47% is artifact. VT user quality good (D7 ROAS 60.3%) but attribution questionable. |
| **D56 recency** | pickByPerformance defaults to random for <56d titles — cold-start compounding factor since Apr 6 |

**Implication for analysis:** Moloco data volume is thin. Organic/unattributed baseline comparison (Section 2d) is especially important to understand true user quality vs attribution noise.

---

## Section 0: Setup & Discovery

### 0a. Parameters
```python
BUNDLE_ANDROID   = 'com.netmarble.nanaori'
BUNDLE_IOS       = '6744205088'            # numeric App Store ID — no 'id' prefix in BQ
BUNDLES          = [BUNDLE_ANDROID, BUNDLE_IOS]
BUNDLE_SQL       = "('com.netmarble.nanaori', '6744205088')"   # for cv / fact_dsp_* tables
MMP_BUNDLE_SQL   = "('com.netmarble.nanaori', 'id6744205088')" # for pb table — iOS uses id-prefix

# Confirmed campaign IDs (Searchlight Apr 9, 2026)
ANDROID_CAMPAIGNS = ['HTVA26OzfthK6LPa', 'vHKyRhJl9k9V6xXs', 'iyH1zVvUZpViudzo']
IOS_CAMPAIGNS     = ['wtxzCfjzlievxX0V', 'okI07jJTGX8mzoyK']
ALL_CAMPAIGNS     = ANDROID_CAMPAIGNS + IOS_CAMPAIGNS
CAMPAIGN_SQL      = "('HTVA26OzfthK6LPa','vHKyRhJl9k9V6xXs','iyH1zVvUZpViudzo','wtxzCfjzlievxX0V','okI07jJTGX8mzoyK')"
IOS_KOR_CAMPAIGN  = 'wtxzCfjzlievxX0V'   # primary iOS KOR campaign (CPA, active)

LAUNCH_DATE      = '2026-03-23'
ANALYSIS_DATE    = '2026-04-13'   # fixed reference date — all LXD windows computed relative to this
LOOKBACK_DAYS    = 21   # full history since launch (Mar 23 → Apr 13)
RECENT_DAYS      = 7
KOR              = 'KOR'

# Netmarble KPI targets (confirmed)
ROAS_D1_TARGET   = 0.05   # 5% — 7DS: Origin

# Confirmed in Section 0c / Searchlight
LOGIN_EVENT      = 'login_1st'   # confirmed — NOT standard 'login'; matches kpi_actions in fact_dsp_core
PURCHASE_EVENT   = 'revenue'     # validate in 0c
```

> **Bundle IDs confirmed:** `com.netmarble.nanaori` (Android) · `6744205088` (iOS).  
> Launch: March 23–24, 2026.

> ⚠️ **Use `LAUNCH_DATE` as the lookback floor** — title is only ~17 days old. L14D from today captures March 26 onward and misses the 3-day launch burst. Use `DATE(timestamp) >= LAUNCH_DATE` where possible.

### 0b. Bundle ID Spot-Check
- Row count from `fact_dsp_core` WHERE `app_market_bundle IN (BUNDLE_SQL)` since `LAUNCH_DATE`
- If very low spend/installs: expect thin data — note volume caveat throughout

### 0c. Login & Purchase Event Validation (two-step)

**Step 1 — Authoritative source: `fact_dsp_core.campaign.kpi_actions`**
```sql
SELECT DISTINCT
  campaign_id,
  campaign.title,
  campaign.os,
  campaign.kpi_actions
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE product.app_market_bundle IN ('com.netmarble.nanaori', '6744205088')
  AND date_utc >= '2026-03-23'
ORDER BY 1
```
- Confirm login event name — **hypothesis:** may NOT be a standard `login` event given the 9–16 GB download barrier; the funnel may track `tutorial_complete` or similar first-session events instead

**Step 2 — Cross-validate in cv table**
```sql
SELECT cv.pb.event.name AS event_name, COUNT(*) AS cnt
FROM `focal-elf-631.prod_stream_view.cv`
WHERE cv.pb.app.bundle IN ('com.netmarble.nanaori', '6744205088')
  AND DATE(timestamp) >= '2026-03-23'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 30
```
- Review all event names — flag if login volume is disproportionately low relative to installs (would confirm download-size friction hypothesis)

---

## Section 1: OS × Country Performance Snapshot (Full History Since Launch)

**Source:** `moloco-ae-view.athena.fact_dsp_core`  
**Group by:** `campaign.os`, `campaign.country`  
**Date filter:** `date_utc >= LAUNCH_DATE` (not L14D — use full history given short window)

### 1a. Aggregate Table

| Metric | Formula |
|--------|---------|
| Spend (USD) | `SUM(gross_spend_usd)` |
| Installs | `SUM(installs)` |
| CPI | `SAFE_DIVIDE(spend, installs)` |
| Login CPA | `SAFE_DIVIDE(spend, unique_login_users)` — from cv, user-level via mtid |
| Install-to-Login Rate | `unique_login_users / unique_installers` — cohort-based, cv only |
| D1 ROAS | `SAFE_DIVIDE(SUM(revenue_d1), spend)` |
| D7 ROAS | `SAFE_DIVIDE(SUM(revenue_d7), spend)` |

**KPI flag column:** `kpi_d1` = ✅ if D1 ROAS ≥ 5%, else ❌  
**Viz:** Color-coded heatmap table. KOR row highlighted. `roas_d1` gradient anchored at `vmin=0, vmax=0.10` (2× KPI).

**Login calculation:** Cohort-based join in cv — installs since `LAUNCH_DATE`, first login post-install — using `cv.pb.moloco.mtid` for user-level counting.

> ⚠️ **Install-to-Login Rate is a key diagnostic for this title.** 9–16 GB download = many users install but never open. Expect significantly lower I2L than StoneAge.

### 1b. Daily Trend (Since Launch)
- 3-panel chart: CPI / D1 ROAS (with 5% KPI line) / D7 ROAS — by OS
- L7D shaded band overlay
- **Watch for:** Whether D1 ROAS ever cleared 5% even in launch burst — if not, ROAS was structurally insufficient from day 1

### 1c. CPP × D1 ARPPU Scatter (Geo Expansion Signal)
- Cohort-based D1 payer query from cv (same approach as StoneAge analysis)
- X: D1 CPP, Y: D1 ARPPU, size: spend, color: OS, label: country
- Reference lines at ROAS = 5% (KPI), 25%, 50%
- Geos above the 5% KPI line = meeting target despite thin data

---

## Section 2: KOR Diagnostic — CPI or ROAS Problem?

### 2a. KOR Summary & Classification
Pull KOR-only metrics for full history (since launch, not just L7D — volume too low to slice further).

```
D1 ROAS  =  D1 ARPU  ×  (1 / CPI)
D1 ARPU  =  I2P  ×  D1 ARPPU
CPI      =  CPM  /  IPM  ×  1000
```

**Confirmed KPI target — D1 ROAS: 5%** (7DS: Origin, per Netmarble)

| Scenario | Signal | Root cause direction |
|----------|--------|---------------------|
| High CPI, OK ROAS | CPM high or IPM low | Supply/creative efficiency |
| Low ROAS, OK CPI | Low ARPU | User quality or structural BM ceiling |
| High CPI + Low ROAS | Both | Compound — check if structural (BM) or operational (targeting) |

**Additional hypothesis for this title:** Low ROAS may be structural (light BM, low-ticket purchases) rather than operational → compare with organic users in 2d before recommending targeting changes.

### 2b. CPI Decomposition (if CPI is elevated)
**Source:** `moloco-ae-view.athena.fact_dsp_all`

```
CPI = CPM / IPM × 1000
```

Scatter: CPM (X) vs IPM (Y) by campaign, sized by spend.  
**For this title:** Also check IPM vs StoneAge benchmark — a cross-platform AAA title may have lower IPM due to steeper creative requirements / audience selectivity.

### 2c. ROAS Decomposition (if ROAS is low)
**Source:** `focal-elf-631.prod_stream_view.cv`

**Cohort availability (as of April 13, 2026):**

| Cohort horizon | Mature install window | Days of data | Notes |
|---------------|----------------------|--------------|-------|
| D7-mature | Install ≤ April 5 | ~13 days (Mar 23–Apr 5) | Usable — still biased toward launch-burst, but improving |
| D28-mature | Not available | 0 | Title launched 21 days ago |

**Decision: D7 is the only cohort available.** D7-mature cutoff = April 5. Flag launch-burst bias. Complete D7 revenue is available for the first ~13 days post-launch.

Compute per OS (KOR, attributed only):
- `I2P` = distinct D7 payers / distinct installers
- `ARPPU` = D7 revenue / distinct D7 payers
- Revenue accumulation curve D0–D7

**Extra diagnostic for this title:** Plot I2P vs Install-to-Login rate together — if I2L is very low, I2P being low is expected (users who don't log in can't pay). The real question is: *of users who do log in, what is their I2P?*

```
Conditional I2P = D7 payers / login_users  (not / installers)
```

### 2d. Attributed vs Unattributed (Organic) Comparison
**Source:** `moloco-dsp-data-view.postback.pb` (unsampled)
> ⚠️ `focal-elf-631.df_accesslog.pb` is deprecated — use `moloco-dsp-data-view.postback.pb` going forward.

**This section is especially critical for 7DS: Origin:**
- Moloco SoI was only 3.2% globally — organic installs dominate
- If Moloco-attributed users show comparable ARPU to organic → Moloco is delivering market-quality users
- If Moloco ARPU << organic → targeting may be off, or organic base is self-selected high-intent users

Compute per attribution type × OS:
- D7 ARPU, I2P, ARPPU, Install-to-Login rate

**Note:** Verify pb schema field paths at runtime before running full query.

**Viz:** Grouped bar: Moloco-attributed vs organic ARPU at D1/D7, by OS.

### 2e. Kakao VT Attribution Deep-Dive
**Source:** `moloco-ae-view.athena.fact_dsp_core` (exchange + installs_ct/installs_vt split)

**Background (Searchlight finding):** 95.6% of Kakao installs are view-through (VT). CTR = 0.045%. Launch-day CVR = 119.5% (more installs than clicks — pure VT artifact). Apparent CPI $2.39 vs CT-only CPI $53.79. Kakao = 30–44% of total spend.

**What to compute:**
- Weekly CT vs VT install split on Kakao vs non-Kakao
- CT-only CPI: `SAFE_DIVIDE(spend, installs_ct)` on Kakao
- VT-only CPI: `SAFE_DIVIDE(spend, installs_vt)` on Kakao
- VT user quality: D7 ROAS of Kakao VT cohort (from cv, filter `installs_vt` users) — Searchlight found ~60.3% D7 ROAS, likely organic

**Viz:** Stacked bar (CT vs VT installs by week, Kakao vs non-Kakao). Table: apparent CPI vs CT-only CPI vs VT-only CPI.

**Interpretation guide:**
- If VT D7 ROAS ≈ organic ROAS → VT installs are organic, not incremental; Kakao budget not driving incremental value
- If CT-only CPI >> target → Kakao CT efficiency is poor; recommend deprioritizing Kakao CT budget

---

## Section 3: Campaign Goal & Audience Analysis (KOR)

> ⚠️ **Volume caveat:** Near-total budget pullback means KOR campaign count may be very small (1–2 campaigns). If so, goal-type comparison is not statistically meaningful — note explicitly and skip to Section 3c audience analysis.

### 3a. Campaign Inventory (KOR)
Pull all KOR campaigns since launch: `campaign_id`, `goal`, `os`, `spend`, `installs`, `kpi_actions`.

### 3b. Performance by Goal Type
If ≥2 goal types exist: group and compare CPI, D1 ROAS, Login CPA, I2L rate.  
If only 1 goal type: document and move on.

### 3c. Audience Overlap — Impressed Users by Campaign Goal
**Source:** Impression-level log table with device ID (verify correct table — likely `focal-elf-631.prod.trace*`; confirm with BQ Agent before querying)

Per-goal distinct device IDs served ≥1 impression in KOR → compute Jaccard overlap → compare post-install quality (I2P, ARPPU) by segment.

> For this title: given thin campaign coverage, audience overlap analysis may reveal whether a single audience pool is being saturated quickly by few campaigns.

---

## Section 4: Audience Saturation Check (KOR)

**Source:** `moloco-ae-view.athena.fact_supply`

```
bid_rate        = bids / bid_requests
win_rate        = bids_won / bids
clear_rate      = impressions / bids_won
bid_to_imp_rate = impressions / bids  =  win_rate × clear_rate
```

| Signal | Formula | Saturation indicator |
|--------|---------|---------------------|
| CPM trend (daily) | `SUM(media_cost_usd) / SUM(impressions) * 1000` | Rising CPM = increasing competition |
| Bid-to-imp rate | `SUM(impressions) / SUM(bids)` | Falling = harder to convert bids to impressions |
| ↳ Win rate | `SUM(bids_won) / SUM(bids)` | Falling = losing more auctions |
| ↳ Clear rate | `SUM(impressions) / SUM(bids_won)` | Falling = wins not rendering |
| Bid rate | `SUM(bids) / SUM(bid_requests)` | Falling = audience narrowing |

**Viz:** Dual-axis line chart (since launch, daily): CPM + Bid-to-imp rate. Decompose into win_rate × clear_rate.

**For this title:** Given rapid budget pullback, saturation may NOT be the issue — instead, look for whether bid rates are falling (insufficient eligible audience) or CPM spiking (competition). Either would reinforce the case for geo expansion.

---

## Section 5: Summary & Prioritized Recommendations

```
[RED / YELLOW / GREEN] CPI efficiency (KOR, Android / iOS)
[RED / YELLOW / GREEN] D1 ROAS vs 5% KPI (KOR, Android / iOS)
[RED / YELLOW / GREEN] Install-to-Login rate (download friction signal)
[RED / YELLOW / GREEN] User quality vs organic baseline
[RED / YELLOW / GREEN] Campaign goal alignment
[RED / YELLOW / GREEN] Audience saturation risk
```

Prioritized action list — top 3 for GDS to bring to biweekly.

---

## Key Tables

| Table | Sections |
|-------|---------|
| `moloco-ae-view.athena.fact_dsp_core` | 1, 2a, 3a, 3b |
| `moloco-ae-view.athena.fact_dsp_all` | 2b (CPI decomp) |
| `moloco-ae-view.athena.fact_supply` | 4 (saturation) |
| `focal-elf-631.prod_stream_view.cv` | 0c (event discovery), 1a (login cohort), 2c (ARPU) |
| `moloco-dsp-data-view.postback.pb` | 2d (attributed vs organic) |

---

## Key Differences vs StoneAge Plan

| Dimension | StoneAge | 7DS: Origin |
|-----------|----------|-------------|
| D1 ROAS KPI | 9% | **5%** |
| Launch | Mar 3 | Mar 23–24 |
| Data window | ~37 days | **~17 days** |
| D7-mature cohort | ~30 days | **~10 days** |
| D28-mature cohort | ~10 days (launch-burst bias) | **Not available** |
| Lookback | L14D + L7D focus | **Full history since launch** |
| Login funnel risk | Standard | **High — 9–16 GB download friction** |
| Moloco SoI | Primary DSP | **3.2% global, 13% KOR** |
| Budget status | Reduced floor | **Near-total pullback (~$20K)** |
| Campaign variety | Multiple goals | **Likely 1–2 campaigns only** |

---

## Open Items (resolve in Section 0)
1. ~~**Bundle IDs**~~ — **Confirmed:** Android `com.netmarble.nanaori`, iOS `6744205088`
2. ~~**Login event name**~~ — **Confirmed:** `login_1st` (Searchlight, kpi_actions in fact_dsp_core)
3. **Revenue event name** — confirm purchase event name in cv (hypothesis: `revenue`)
4. **Campaign count in KOR** — **5 campaigns confirmed** (3 Android, 2 iOS); HTVA paused Apr 8; iyH1 (ROAS) launched Apr 6 — compare pre/post Apr 6 carefully

---

## Implementation Notes
- Use `DATE(timestamp) >= LAUNCH_DATE` as floor instead of L14D — captures full post-launch history
- All Login CPA from cv table (NOT `kpi_actions_d7`) — `cv.pb.moloco.mtid` for unique user counting
- `SAFE_DIVIDE` on all rate metrics
- Flag thin data explicitly when installs < 500 for any geo/OS slice
- Section 3b: check campaign count before running goal-type comparison — may be moot with 1–2 campaigns
