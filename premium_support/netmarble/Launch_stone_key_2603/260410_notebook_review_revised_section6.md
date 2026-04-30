# StoneAge: Pet World — Notebook Review & Revised Section 6

**Reviewer:** Haewon Yum · KOR GDS
**Date:** 2026-04-11
**Notebook under review:** `260409_stoneage_performance_investigation.ipynb`
**Supporting evidence:** Searchlight investigation report (`cc7314f/REPORT.md`), MOBIUS attributed/unattributed research (Apr 10), BQ campaign status query (Apr 10)
**Strategic context:** `netmarble_q2_2026_title_context.md`

---

## Executive Summary

The notebook is well-structured with a sound analytical framework (ROAS decomposition, hypothesis-driven sections). However, several findings need reinterpretation, one key metric is misleading (the 10x ARPPU gap uses means distorted by whale outliers), and the iOS PA hypothesis — that both MMP and SKAN performance would improve after PA enablement — is **not supported by the data as presented**. The evidence tells a more nuanced story: PA unlocked a LAT traffic segment that actually outperforms degraded non-LAT on D1 ROAS, but simultaneous budget doubling and audience saturation collapsed non-LAT quality, masking the PA benefit.

**Current status (Apr 10):** All four KOR campaigns are running at reduced budgets. The two Android CPA campaigns are effectively winding down. The Android tROAS campaign has stabilized at ~$1.2K/day (down from $8.3K peak). iOS is the steadiest at ~$1.2K/day. None of the campaigns hit the 9% D1 ROAS target.

---

## Section-by-Section Review

---

### Section 0 — Setup & Discovery

**What it does:** Confirms bundle data exists, validates event names for login and purchase actions.

**Results:**
| Bundle | OS | Total Spend | Total Installs | Date Range |
|---|---|---|---|---|
| com.netmarble.stonkey | ANDROID | $767,691 | 75,352 | Mar 3 – Apr 10 |
| 6737408689 | IOS | $140,049 | 10,378 | Mar 3 – Apr 10 |

**Event validation (cv table, L3D):**
- Top events: `visit_shop` (158K), `login` (122K), `revenue` (4K), `install` (1.5K)
- `LOGIN_EVENT = 'login'` and `PURCHASE_EVENT = 'revenue'` are correctly set
- Deep-funnel purchase events: `buy_pet_lv3` (639), `buy_stargem` (170), `buy_pet_lv8` (138)

**Assessment:** Sound. One important observation: iOS has only 1,469 `install` events in cv despite 10K+ total installs. This is flagged later (iOS install events absent from cv pipeline) but should be called out here as it limits iOS cohort analysis throughout the notebook.

---

### Section 1 — OS × Country Performance Snapshot (L14D)

**What it does:** Maps performance across all geo × OS combinations. Identifies which markets are working.

**Key results (top geos by spend):**

| OS | Country | Spend | Installs | CPI | Login CPA | I2L Rate | D1 ROAS | D7 ROAS | KPI |
|---|---|---|---|---|---|---|---|---|---|
| ANDROID | KOR | $68,387 | 2,757 | $24.80 | $26.83 | 92.5% | 5.1% | 14.3% | ❌ |
| IOS | KOR | $14,597 | 946 | $15.43 | $16.31 | 94.6% | 3.0% | 10.5% | ❌ |
| ANDROID | IDN | $13,132 | 3,445 | $3.81 | $4.26 | 89.4% | 2.9% | 5.1% | ❌ |
| ANDROID | USA | $12,321 | 940 | $13.11 | $14.24 | 92.0% | 2.7% | 4.7% | ❌ |
| ANDROID | THA | $6,117 | 931 | $6.57 | $7.15 | 91.8% | 4.4% | 6.2% | ❌ |

**Geos meeting 9% D1 ROAS target:** Only ARE (18.6%), BEL (14.9%), PER (10.1%) — all with < $750 spend, statistically insignificant.

**CPP × ARPPU scatter (Cell 16, D1 payer-level):**

| OS | Country | CPP | ARPPU | Implied ROAS |
|---|---|---|---|---|
| ANDROID | KOR | $260 | $15.29 | 5.9% |
| IOS | KOR | $317 | $10.13 | 3.2% |
| ANDROID | JPN | $216 | $7.40 | 3.4% |
| ANDROID | USA | $181 | $6.12 | 3.4% |

**Interpretation:**
- KOR is the only market with meaningful scale. This aligns with the strategic context: *"Performance locked to KR; no other geo gaining traction"* and Netmarble's own assessment *"It's true that it's only doing well in Korea."*
- The L14D window includes both pre- and post-budget-ramp data, so KOR Android's $24.80 CPI is a blended average. The L7D CPI is much worse ($75 for tROAS), indicating rapid deterioration.
- Install-to-login rates are excellent (89–95% across all geos), confirming login is a near-universal early-funnel event. This is expected for an idle RPG where login = opening the app.
- **CPP is the primary blocker to ROAS** — it costs $260–$317 to acquire a single paying user in KOR. To hit 9% D1 ROAS at $260 CPP, D1 ARPPU would need to be $23.40 — but actual D1 ARPPU is only $15.29 (Android) and $10.13 (iOS).

**Gap:** The daily trend (Cell 18/19) shows the time-series but interpretation is missing from the notebook. The L7D vs prior-7D comparison would show how rapidly metrics deteriorated.

---

### Section 2 — KOR Diagnostic: CPI or ROAS Problem?

**Framework used:** `D1 ROAS = D1 I2P × D1 ARPPU / CPI` — correct decomposition.

#### 2a — KOR Summary & Problem Classification (L7D)

| OS | Goal | Spend | Installs | CPI | D1 ROAS | D7 ROAS | ARPU D7 | Verdict |
|---|---|---|---|---|---|---|---|---|
| ANDROID | ROAS | $33,108 | 441 | **$75.08** | 3.8% | 6.5% | $4.88 | 🔴 CPI + ROAS compound |
| ANDROID | CPA | $15,333 | 1,614 | $9.50 | 0.3% | 1.2% | $0.11 | 🟡 ROAS below target |
| IOS | CPA | $9,196 | 656 | $14.02 | 2.5% | 3.4% | $0.48 | 🟡 ROAS below target |

**Interpretation:** All three campaign types miss the 9% D1 ROAS target. But the problem is fundamentally different:
- **tROAS campaign:** Has the highest per-user value (D7 ARPU $4.88) but CPI is so elevated ($75) that even reasonable monetization can't compensate. This is a **CPI problem**.
- **CPA campaigns:** CPI is cheap ($5.87–$9.50) but user quality is near-zero (D7 ARPU $0.11). This is a **user quality problem** — the campaigns optimize for install/login volume, not revenue.
- **iOS:** Middle ground. CPI $14.02 is reasonable but D7 ARPU $0.48 is very low. Post-PA analysis needed (Section 5).

#### 2b — CPI Decomposition: CPM vs IPM

`CPI = CPM / IPM × 1000`

CPI decomposition data (Cell 25, 4 campaigns KOR L7D) — the notebook confirmed **IPM collapse is the dominant CPI driver for the tROAS campaign**, not CPM inflation. The investigation report quantifies this: IPM fell 75% (W1 to W4) while CPM rose only 37%. This means the model is bidding on impressions that don't convert to installs — a signal quality / audience saturation issue, not a supply cost issue.

**Implication for action:** Publisher exclusions or bid caps (supply-side interventions) won't fix this. The problem is demand-side: the convertible audience in KOR is exhausted at the current bid level.

#### 2c — D1 ROAS Decomposition by Campaign

**Campaign-level D1 ROAS (fact_dsp_core, L7D):**

| Campaign | OS | Goal | Spend | Installs | CPI | D1 Revenue | D1 ROAS | D7 ROAS |
|---|---|---|---|---|---|---|---|---|
| nazpxG3J5MareHRz | AND | tROAS | $33,409 | 445 | $75.08 | $1,260 | 3.8% | 6.4% |
| yFGQdt2EPPm0NU97 | AND | CPA | $10,169 | 734 | $13.85 | $52 | 0.5% | 1.8% |
| GdPe1hm9tPMaUhbt | IOS | CPA | $9,497 | 663 | $14.32 | $232 | 2.4% | 3.3% |
| ylgO8XQvDb5nx3k4 | AND | CPA | $5,164 | 880 | $5.87 | $1 | 0.0% | 0.1% |

**Interpretation:**
- ylgO8XQvDb5nx3k4 is generating $1 of D1 revenue on $5,164 spend. This is essentially zero-ROAS traffic.
- yFGQdt2EPPm0NU97 slightly better at $52 D1 revenue on $10K spend, but still 18x below target.
- The tROAS campaign generates $1,260 D1 revenue — demonstrating it *can* find paying users — but CPI makes it uneconomical.
- **Combined Android CPA spend ($15.3K) exceeds the total D1 revenue of the tROAS campaign ($1,260).** The CPA campaigns are consuming budget that produces near-zero return.

#### 2d — Attributed vs Unattributed: User Quality Signal

**This is the most important table in the notebook (Cell 31):**

| OS | Group | Installs | D1 I2P | D1 ARPPU | Median D1 ARPPU | D7 I2P | D7 ARPPU | Median D7 ARPPU |
|---|---|---|---|---|---|---|---|---|
| AND | Unattributed | 30,142 | 3.30% | $116.18 | **$14.70** | 3.96% | $145.86 | $21.55 |
| AND | nazpxG3J5MareHRz | 438 | **20.09%** | $14.95 | $4.04 | 22.15% | $21.54 | $6.10 |
| AND | yFGQdt2EPPm0NU97 | 730 | 3.56% | $2.23 | $0.96 | 4.66% | $5.30 | $1.16 |
| AND | ylgO8XQvDb5nx3k4 | 880 | 0.34% | $0.32 | $0.19 | 0.45% | $0.96 | $0.19 |
| IOS | Moloco (LAT/PA) | 376 | 4.26% | $3.68 | $0.96 | 5.32% | $6.07 | $2.09 |
| IOS | Moloco (non-LAT) | 278 | 3.96% | $15.57 | $6.68 | 3.96% | $16.51 | $6.68 |
| IOS | Unattributed | 306 | **14.05%** | $12.40 | $2.32 | 16.67% | $21.25 | $4.82 |

**Critical reinterpretation — the "10x ARPPU gap" is misleading:**

The notebook summary states *"Moloco ARPPU ($11.75) is 10× lower than organic ($116.18)"*. This uses the **mean** ARPPU, which is heavily distorted by whale outliers in the unattributed pool. The **median** comparison tells a different story:
- Moloco tROAS median D1 ARPPU: **$4.04** vs Unattributed median: **$14.70** → 3.6x gap (not 10x)
- Moloco tROAS median D7 ARPPU: **$6.10** vs Unattributed median: **$21.55** → 3.5x gap

**The 3.5x median gap is still significant** — unattributed users (which may include other paid channels, not just organic) spend more per transaction — but it's a different narrative than "10x worse." A few whales (likely re-engagement or brand-loyal players) inflate the mean dramatically.

**What the tROAS campaign does well:** I2P of 20.09% is **6x higher than unattributed** (3.30%). Moloco finds proportionally far more purchasers. The issue isn't finding payers — it's finding *high-ticket* payers.

**CPA campaigns are definitively poor quality:**
- ylgO8XQvDb5nx3k4: 0.34% I2P, $0.32 D1 ARPPU — these users essentially never spend
- yFGQdt2EPPm0NU97: 3.56% I2P (matches unattributed), but $2.23 ARPPU is 6.6x below unattributed median

**iOS insight:**
- Unattributed iOS users have 14.05% D1 I2P — 3x higher than Moloco LAT/PA (4.26%) and non-LAT (3.96%)
- iOS non-LAT ARPPU ($15.57) exceeds unattributed ($12.40) — small sample (278 installs, 11 payers) but directionally positive
- iOS LAT/PA ARPPU is low ($3.68) with 376 installs — PA attribution may be capturing lower-intent users

---

### Section 3 — Campaign Goal & Audience Analysis (KOR)

#### 3a — Campaign Inventory

Four active KOR campaigns confirmed:

| Campaign | OS | Goal | KPI Action | L7D Spend | L7D Installs | CPI |
|---|---|---|---|---|---|---|
| nazpxG3J5MareHRz | AND | tROAS | revenue | $33,108 | 441 | $75.08 |
| yFGQdt2EPPm0NU97 | AND | CPA | (none listed) | $10,169 | 734 | $13.85 |
| GdPe1hm9tPMaUhbt | IOS | CPA | login | $9,196 | 656 | $14.02 |
| ylgO8XQvDb5nx3k4 | AND | CPA | login_1st | $5,164 | 880 | $5.87 |

**Note:** yFGQdt2EPPm0NU97's title includes "AEO(join_clan)" but kpi_actions field is empty in the L7D data, suggesting a recent config change. The investigation report identifies a 5th campaign (EQCWerD5mEThZO4P, Android CPA buy_pet_lv3) that was paused earlier.

#### 3b — Performance by Goal Type

| OS | Goal | Total Spend | Installs | Campaigns | CPI |
|---|---|---|---|---|---|
| AND | CPA | $15,333 | 1,614 | 2 | $9.50 |
| AND | ROAS | $33,108 | 441 | 1 | $75.08 |
| IOS | CPA | $9,196 | 656 | 1 | $14.02 |

**Interpretation:** Android CPA campaigns deliver 3.7x more installs at 1/8th the CPI — but with near-zero revenue. The portfolio is spending $15K/week acquiring Android users who generate $53 in D1 revenue. This is the definition of budget waste for a ROAS-sensitive title.

#### 3c — Audience Overlap (INCOMPLETE)

Cell 39 is a TODO stub. The impression-level device overlap analysis between CPA and ROAS campaigns was never executed. **This is the single biggest analytical gap in the notebook.** If CPA campaigns are bidding on the same user pool, they may be cannibalizing ROAS quality by winning the cheap-to-acquire segment and leaving only expensive users for the tROAS campaign. This would directly explain the $75 CPI.

---

### Section 4 — Audience Saturation Check (KOR)

**Supply funnel metrics (fact_supply, L14D):**

| Date | OS | Win Rate | Clear Rate | Bid-to-Imp Rate | CPM |
|---|---|---|---|---|---|
| Apr 3 | AND | 36.2% | 92.3% | 33.4% | $0.64 |
| Apr 4 | AND | 29.4% | 90.1% | 26.5% | $1.10 |
| Apr 5 | AND | 31.9% | 86.9% | 27.7% | $1.32 |
| Apr 6 | AND | 34.0% | 97.0% | 32.9% | $0.82 |
| Apr 7 | AND | 28.7% | 98.7% | 28.4% | $1.04 |
| Apr 8 | AND | 38.7% | 112.2%* | 43.4% | $0.68 |
| Apr 9 | AND | 45.5% | 102.0% | 46.4% | $0.59 |
| | | | | | |
| Apr 3 | IOS | 31.7% | 71.1% | 22.5% | $0.94 |
| Apr 4 | IOS | 24.4% | 56.0% | 13.7% | **$2.55** |
| Apr 5 | IOS | 23.4% | 51.9% | 12.1% | **$2.80** |
| Apr 6 | IOS | 24.4% | 59.5% | 14.5% | $1.84 |
| Apr 7 | IOS | 28.3% | 66.2% | 18.7% | $1.27 |
| Apr 8 | IOS | 32.4% | 70.7% | 22.9% | $0.93 |
| Apr 9 | IOS | 35.3% | 74.9% | 26.4% | $0.65 |

*\*Clear rate >100% = multi-impression wins or reporting lag artifact*

**Interpretation:**
- **Android:** Win rate improving (29% → 46%) and CPM declining ($1.10 → $0.59) from Apr 4–9. This is the budget cut effect — less competition against self, more efficient wins. **No saturation alarm for Android at current spend levels (~$1.2K/day).**
- **iOS:** CPM spiked to $2.55–$2.80 on Apr 4–5 (coinciding with budget doubling on Apr 1 and LAT admission on Apr 3), then recovered to $0.65 by Apr 9 as spend stabilized. Clear rate is structurally lower for iOS (51–75%) vs Android (87–112%), reflecting iOS supply quality issues (SKAN measurement, LAT inventory characteristics).
- **The CPM recovery by Apr 9** suggests the iOS supply channel is not permanently saturated — the Apr 4–5 spike was a transient effect of sudden budget + audience expansion.

---

### Section 5 — iOS SKAN & MMP: Pre vs Post PA

This section is the most important for the strategic question. The hypothesis entering PA enablement was: **PA should improve both MMP attribution coverage and SKAN reporting accuracy, leading to better measured performance.**

#### 5a — SKAN Pre vs Post PA

| Period | Spend | SKAN Conversions | SKAN CPI | SKAN ROAS (min) | SKAN ROAS (max) | SKAN ROAS (mid) |
|---|---|---|---|---|---|---|
| Pre-PA | $5,400 | 341 | $15.84 | 4.4% | 14.9% | **9.6%** ✅ |
| Post-PA | $9,196 | 411 | $22.38 | 1.1% | 3.0% | **2.1%** ❌ |

**Raw comparison: SKAN ROAS dropped from 9.6% to 2.1% post-PA. This appears to reject the hypothesis.**

But the raw comparison is confounded by two simultaneous changes:
1. **Budget doubled** from ~$771/day (pre-PA) to ~$1,314/day (post-PA) — 70% increase
2. **PA enabled** on Apr 3, changing attribution methodology and audience composition simultaneously

SKAN CPI rose from $15.84 to $22.38 (+41%). SKAN conversion count increased only 21% (341 → 411) despite 70% more spend, indicating diminishing returns at higher budget.

**Critical caveat:** SKAN postback delivery depends on the SKAN version and MMP conversion window configuration. Under SKAN 4.0, the first postback arrives 24–48h post-install, but the second postback (which carries finer conversion values including revenue buckets) arrives at day 3–7. The post-PA window here (Apr 3–9) means the latest cohorts (Apr 7–9) may not have received their second postback yet, systematically deflating post-PA SKAN ROAS. **A fair comparison requires re-pulling after each post-PA cohort has at least 7 days of SKAN postback maturity** — i.e., the Apr 9 cohort matures around Apr 16. Additionally, the specific conversion value lock window configured in AppsFlyer for this title should be confirmed, as it determines when revenue values finalize.

#### 5b — MMP Pre vs Post PA

| Period | Spend | Installs | CPI | D1 ROAS | D7 ROAS |
|---|---|---|---|---|---|
| Pre-PA | $5,400 | 290 | $18.62 | 3.9% | 22.6% |
| Post-PA | $9,196 | 656 | $14.02 | 2.5% | 3.4% |

**MMP D1 ROAS dropped from 3.9% to 2.5%. D7 ROAS dropped from 22.6% to 3.4%.**

However, MMP installs more than doubled (290 → 656) at lower CPI ($18.62 → $14.02). PA expanded attribution coverage — more installs are now measurable. But the D7 ROAS drop is extreme (22.6% → 3.4%) and cannot be explained by attribution changes alone.

**D7 maturity bias:** Pre-PA installs (Mar 27–Apr 2) have 8–14 days of D7 maturity — fully realized. Post-PA installs (Apr 3–9) have only 1–7 days of D7 maturity — severely incomplete. The 22.6% vs 3.4% D7 ROAS comparison is **invalid** due to asymmetric maturity. D1 ROAS (3.9% → 2.5%) is the fair comparison.

#### 5c — LAT vs Non-LAT Split (Post-PA)

| Period | Traffic Type | Spend | Installs | CPI | D1 ROAS | D7 ROAS |
|---|---|---|---|---|---|---|
| Pre-PA | Non-LAT (only) | $5,400 | 290 | $18.62 | 3.9% | 22.6% |
| Post-PA | **LAT** | $4,240 | 335 | **$12.66** | **4.5%** | 6.0% |
| Post-PA | Non-LAT | $4,956 | 321 | $15.44 | **0.8%** | 1.2% |

**This is the key finding. The LAT/Non-LAT split reveals the true story:**

1. **LAT traffic (new via PA) is the best-performing segment post-PA:**
   - D1 ROAS **4.5%** — higher than pre-PA non-LAT (3.9%)
   - CPI **$12.66** — cheapest across all segments
   - 335 installs at $4,240 spend — efficient

2. **Non-LAT quality collapsed independently:**
   - D1 ROAS crashed from **3.9% → 0.8%** (−79%) for the *same traffic type*
   - This collapse has **nothing to do with LAT admission** — it's the same non-LAT users
   - Root cause: budget doubling (Apr 1, $697 → $1,379) + audience saturation in the non-LAT iOS KOR pool

3. **The blended post-PA D1 ROAS (2.5%) masks the LAT outperformance:**
   - LAT at 4.5% D1 ROAS is being averaged with non-LAT at 0.8%, producing a misleading 2.5% blend
   - If we isolate the PA effect (LAT performance), PA actually *improved* the best available D1 ROAS from 3.9% to 4.5%

**Revised PA assessment:** PA enablement was a net positive — it unlocked a cheaper, better-converting traffic segment. The simultaneous non-LAT quality collapse (driven by budget doubling and saturation) masked this benefit in the blended metrics.

---

## Current Campaign Status (Apr 10, 2026)

**Updated via BQ query (Apr 4–10 L7D):**

| Campaign | OS | Goal | KPI | L7D Spend | L7D Installs | CPI | D1 ROAS |
|---|---|---|---|---|---|---|---|
| nazpxG3J5MareHRz | AND | tROAS | revenue | $27,931 | 407 | $68.63 | 3.3% |
| GdPe1hm9tPMaUhbt | IOS | CPA | login | $8,892 | 611 | $14.55 | 2.1% |
| yFGQdt2EPPm0NU97 | AND | CPA | — | $7,719 | 610 | $12.65 | 0.2% |
| ylgO8XQvDb5nx3k4 | AND | CPA | login_1st | $4,590 | 770 | $5.96 | 0.02% |

**Daily spend trajectory (Apr 7–10):**

| Campaign | Apr 7 | Apr 8 | Apr 9 | Apr 10 | Trend |
|---|---|---|---|---|---|
| nazpxG3J5MareHRz (AND tROAS) | $3,014 | $1,178 | $1,168 | $1,324 | Stabilized ~$1.2K |
| GdPe1hm9tPMaUhbt (iOS CPA) | $1,166 | $1,267 | $1,297 | $893 | Stable ~$1.1K |
| yFGQdt2EPPm0NU97 (AND CPA) | $572 | $32 | $0 | $0 | **Effectively paused** |
| ylgO8XQvDb5nx3k4 (AND CPA) | $572 | $31 | $0 | $578 | Sporadic on/off |

**Key changes vs notebook L7D data:**
- tROAS CPI improved from $75.08 → $68.63 as budget cuts allow more efficient bidding
- yFGQdt2EPPm0NU97 appears to be shutting down (near-$0 spend Apr 9–10)
- ylgO8XQvDb5nx3k4 is intermittent — $0 on Apr 9 then $578 on Apr 10 (either manual toggling or budget pacing)
- iOS is the steadiest campaign with consistent ~$1.1–1.3K daily spend

**Context from Apr 2 biweekly:** Netmarble approved budget increase to 2.5천만원/day (~$18.8K). Actual current portfolio spend is ~$2.5K/day — **87% below approved budget**. The efficiency collapse prevented the approved ramp from materializing.

---

## REVISED Section 6 — Summary, Root Cause & Action Items

**Analysis date:** 2026-04-11 | **KOR focus window:** L7D (Apr 4–Apr 10)
**iOS note:** The cv table does contain iOS install events for this title (Cell 8: 1,469 installs across both OS; Cell 13: iOS KOR with 946 installs and 94.6% I2L rate). However, iOS cv install volume is significantly lower than fact_dsp_core totals, suggesting partial coverage. The notebook's Cell 29 comment ("iOS install events absent from cv — Android only") appears outdated. iOS cohort metrics from cv should be used with awareness of potential undercounting.

---

### Status Dashboard (KOR)

| Signal | Android | iOS | Status |
|---|---|---|---|
| CPI efficiency | $68.63 (tROAS) / $5.96–$12.65 (CPA) | $14.55 | 🔴 tROAS CPI 7.6x above CPA |
| D1 ROAS vs 9% target | 3.3% (tROAS) / 0.02–0.2% (CPA) | 2.1% (blended) | 🔴 All miss target |
| D1 ROAS by traffic type | — | LAT 4.5% / Non-LAT 0.8% | 🟡 LAT segment closest to target |
| SKAN ROAS (mid) | — | Pre-PA 9.6% → Post-PA 2.1% | 🟡 Post-PA data immature (revisit Apr 17) |
| User quality vs unattributed (median) | tROAS ARPPU $4.04 vs unattributed $14.70 (3.6x gap) | LAT ARPPU $3.68 / non-LAT $15.57 | 🟡 Gap is 3.6x (not 10x as reported using means) |
| CPA campaign ROAS | yFGQdt2EPPm0NU97: 0.2% / ylgO8XQvDb5nx3k4: 0.02% | — | 🔴 Near-zero revenue |
| Audience saturation | CPM declining, win rate improving (post-budget-cut) | CPM recovered from $2.80 to $0.65 | 🟢 Not saturated at current spend |
| Budget utilization | ~$2.5K/day vs $18.8K approved | — | 🔴 87% below approved ceiling |

---

### Root Cause Analysis

#### Android KOR: CPI is the Primary Bottleneck

```
D1 ROAS  =  D1 ARPU  ×  (1 / CPI)

tROAS current:   3.3%  =  $2.26  ×  (1 / $68.63)
To hit 9%:        9%   =  $6.18  ×  (1 / $68.63)   — need 2.7x ARPU improvement
  OR:             9%   =  $2.26  ×  (1 / $25.11)   — need CPI ≤ $25
  OR:             9%   =  $3.60  ×  (1 / $40.00)   — balanced improvement
```

**Why CPI is elevated ($68.63):**
1. **IPM collapse (dominant factor):** CVR fell from 2.88% (W1) to ~0.4% (W5). The convertible audience in KOR is largely reached after 5 weeks.
2. **Budget over-scaling:** 6x ramp ($1.4K to $8.3K/day) forced the model into progressively lower-quality inventory. Post-cut recovery confirms budget as the primary lever — CVR doubled and CPI dropped 63% when budget was cut 84%.
3. **CPI Balancer experiment (minor, ~5%):** The alpha=0.9 CPI Balancer is a minor bid repricing factor. Both control and test arms showed collapsed CVR.
4. **CPA campaign cannibalization (unproven but likely):** If CPA campaigns bid on the same user pool at $5–13 CPI, they win the easy-to-convert segment, leaving only expensive users for tROAS. *The audience overlap analysis (Cell 39) was not completed — this remains a hypothesis.*

**Why ARPU is low ($2.26 D1):**
- The tROAS campaign finds payers efficiently (20% I2P vs 3.3% unattributed) but at low ticket sizes (median $4.04 vs unattributed $14.70)
- The model optimizes for revenue volume (tROAS goal), which favors many small payers over fewer large payers
- Deep-funnel KPI events (buy_pet_lv3, buy_stargem) are not used as model signals in this campaign

#### iOS KOR: Post-PA Performance is Better Than It Looks

```
D1 ROAS (blended):   2.1%  — appears to reject PA hypothesis
D1 ROAS (LAT only):  4.5%  — PA unlocked the best segment
D1 ROAS (non-LAT):   0.8%  — collapsed independently of PA
```

**PA enablement was a net positive for iOS:**
- LAT traffic (4.5% D1 ROAS, $12.66 CPI) outperforms both the blended average and the pre-PA baseline (3.9% D1 ROAS, $18.62 CPI)
- The measured decline is driven by non-LAT quality collapse (3.9% → 0.8%), caused by budget doubling (Apr 1) and audience saturation — not PA itself
- SKAN ROAS pre-PA of 9.6% is the strongest signal in the entire analysis; post-PA SKAN is immature

**But we cannot claim PA fully succeeded yet:**
- LAT D1 ROAS at 4.5% is still 50% below the 9% target
- iOS non-LAT ARPPU ($15.57, n=11 payers) suggests the quality *potential* exists but the model hasn't converged
- Post-PA SKAN data needs until Apr 17 to mature

#### CPA Campaigns: Structural ROAS Destroyers

Both remaining CPA campaigns produce near-zero revenue:
- ylgO8XQvDb5nx3k4 (login_1st): 0.34% D1 I2P, $0.32 D1 ARPPU, 0.02% D1 ROAS
- yFGQdt2EPPm0NU97 (join_clan → no kpi_actions): 3.56% D1 I2P, $2.23 D1 ARPPU, 0.2% D1 ROAS

These campaigns optimize for login/install volume. They train the ML model on low-quality conversion signals, potentially polluting the broader Stonekey audience signal pool.

---

### Prioritized Action Items

#### IMMEDIATE (This Week)

**1. 🔴 Fully pause ylgO8XQvDb5nx3k4 (Android CPA, login_1st)**
- **Current:** Sporadic on/off ($578 → $0 → $578), 0.02% D1 ROAS
- **Evidence:** Cell 31 — 0.34% I2P, $0.32 D1 ARPPU (880 installs L7D). Worst user quality across all campaigns. Near-zero revenue ($1 D1 revenue on $5.2K spend).
- **Impact:** Frees ~$500/day. Eliminates worst-quality install signal from the model.
- **Risk:** Low. These installs contribute nothing to revenue.

**2. 🔴 Fully pause yFGQdt2EPPm0NU97 (Android CPA, join_clan)**
- **Current:** Appears to already be winding down ($0 spend Apr 9–10), but confirm disabled
- **Evidence:** Cell 28 — $52 D1 revenue on $10.2K spend (0.5% D1 ROAS). Even at $12.65 CPI, users don't monetize.
- **Impact:** Frees ~$1K/day (when running). Stops diluting portfolio ROAS.
- **Risk:** Low. Netmarble already cut budgets post-Apr 5; this aligns with their direction.

**3. 🟡 iOS: Separate LAT and non-LAT bidding strategy**
- **Current:** Single iOS campaign (GdPe1hm9tPMaUhbt) with blended LAT/non-LAT
- **Evidence:** LAT users have 4.5% D1 ROAS at $12.66 CPI; non-LAT users have 0.8% D1 ROAS at $15.44 CPI. LAT is 5.6x better on ROAS and 18% cheaper.
- **Action:** Create a separate ad group or campaign for LAT traffic with a ROAS-oriented goal (instead of CPA login). Maintain non-LAT at current levels but don't increase budget until quality stabilizes.
- **Impact:** Concentrates iOS budget on the highest-ROAS segment. Could improve blended iOS D1 ROAS from 2.1% toward 4–5%.
- **Risk:** Medium. LAT sample size (335 installs, 7 days) needs continued monitoring. LAT attribution relies on PA, which may have accuracy limitations.

#### SHORT-TERM (Next 1–2 Weeks)

**4. 🟡 Android tROAS: Hold budget at $1.2–1.5K/day, re-ramp slowly**
- **Current:** Stabilized at ~$1.2K/day with improving efficiency (CPI $68 → lower as saturation eases)
- **Evidence:** Investigation report — CVR doubled and CPI dropped 63% when budget was cut 84%. Current win rate (45.5%) and CPM ($0.59) show no saturation at this spend level.
- **Action:** Hold at $1.2K/day for 7 more days. If CPI drops below $50 and CVR recovers above 0.6%, re-ramp at max 20%/day. Do not exceed $2.5K/day without evidence of sustained efficiency.
- **Impact:** Allows model to recover from over-scaling. Maintains presence for learning.
- **Risk:** Low. Netmarble approved $18.8K/day — they won't object to $1.5K.

**5. 🟡 Validate iOS SKAN ROAS after postback maturation**
- **Current:** Pre-PA SKAN ROAS was 9.6% (mid) — above the 9% target. Post-PA SKAN ROAS is 2.1% — but likely immature (latest cohorts may not have received SKAN 4.0 second postback with revenue values).
- **Action:** Re-pull SKAN data once the last post-PA cohort (Apr 9) has at least 7 days of postback maturity (~Apr 16). Also confirm the AppsFlyer conversion value lock window for this title. If post-PA SKAN ROAS recovers to >5% mid, this confirms iOS as the priority scale path.
- **Impact:** Critical for the iOS scale decision. Pre-PA SKAN ROAS 9.6% is the only segment that has hit the Netmarble target. If PA preserves this, iOS KOR (and eventually iOS WW) becomes the growth vector.
- **Reference:** Apr 2 biweekly — *"iOS WW ROAS test being considered"* — mature SKAN data is a prerequisite.

**6. 🟡 Complete the audience overlap analysis (Cell 39)**
- **Status:** TODO stub in notebook — never executed
- **Action:** Query impression-level device IDs from the tROAS and CPA campaigns to measure Jaccard overlap. If overlap >30%, CPA campaigns are provably cannibalizing tROAS.
- **Impact:** Converts the "CPA cannibalization" hypothesis from directional to proven. If confirmed, it strengthens the case for Actions 1–2 and provides data for the Netmarble conversation.

#### STRATEGIC (May Biweekly Discussion)

**7. 🔵 Propose KPI event change for Android tROAS**
- **Current:** tROAS campaign uses `revenue` as KPI action. The model optimizes for revenue events broadly.
- **Proposal:** Test adding `visit_shop` or `buy_pet_lv3` as a secondary signal. `visit_shop` has 158K events (highest volume) and represents commercial intent. `buy_pet_lv3` (639 events) is a confirmed purchase action used in other Netmarble campaigns.
- **Rationale:** The model currently finds many low-ticket payers (median $4.04). A deeper-funnel signal could shift targeting toward higher-value users, even if it reduces volume.
- **Caveat:** Deep-funnel events can starve the model of learning data (see investigation report on EQCWerD5mEThZO4P paused at 0.70% ROAS with buy_pet_lv3 KPI). Start with `visit_shop` (higher volume) rather than buy events.

**8. 🔵 Position iOS as the scale path for Netmarble conversation**
- **Narrative for biweekly:** "Android KOR is stabilizing but CPI-constrained at ceiling. iOS delivered the only segment above 4% D1 ROAS (LAT at 4.5%), and pre-PA SKAN ROAS was 9.6%. Recommend concentrating iOS budget on LAT/PA traffic and validating iOS WW expansion."
- **Context:** The Apr 2 biweekly already noted *"iOS WW ROAS test being considered"* and *"KOR + JPN re-activation in April tied to major update."* PA enablement directly removes the historical blocker Netmarble cited for iOS UA.
- **CTV angle:** PA enablement also removes the CTV measurement blocker documented since Dec 2024. If iOS SKAN ROAS matures favorably, propose a CTV incrementality test on Solo Leveling's May/June 2nd anniversary — this addresses every objection Netmarble has raised.

**9. 🔵 Correct the "10x ARPPU gap" narrative and terminology before external sharing**
- **Issue:** The notebook summary states "Moloco ARPPU $11.75 vs organic $116 (10x gap)." This uses means heavily distorted by whale outliers in the unattributed pool. Note: "unattributed" ≠ "organic" — these users may include installs from other paid channels, not just organic.
- **Correction:** Use median ARPPU: Moloco tROAS $4.04 vs unattributed $14.70 (3.6x gap). Still significant, but a fundamentally different message for client conversations.
- **Why it matters:** A 10x gap implies Moloco is broken. A 3.6x gap with 6x higher I2P implies Moloco is good at finding payers but needs signal improvement to find *higher-value* payers — a solvable optimization problem, not a platform failure.

---

### Monitoring Checklist

| Item | When | What to check |
|---|---|---|
| iOS SKAN ROAS maturation | ~Apr 16 (7d after last post-PA cohort) | Do post-PA SKAN cohorts reach >5% mid ROAS? Confirm AF conversion value lock window. |
| Android tROAS CVR recovery | Daily | Has CVR stabilized above 0.5%? CPI below $50? |
| CPA campaign status | Apr 11 | Confirm yFGQdt2EPPm0NU97 and ylgO8XQvDb5nx3k4 fully paused |
| iOS LAT vs non-LAT weekly | Weekly | Is LAT D1 ROAS sustained above 4%? Non-LAT recovering? |
| ODSB-17082 postback trend | Weekly | Any unattributed postback anomalies? |
| ri (rich interstitial) format | Weekly | ri works on iOS (IPM 1.19) but poorly on Android tROAS ($128 CPI) — monitor format mix |

---

### Notebook Gaps to Address

| Gap | Section | Priority | Action |
|---|---|---|---|
| Audience overlap analysis | 3c (Cell 39) | **High** | Query impression-level device overlap between CPA and ROAS campaigns |
| D7 ROAS maturity filter | 2a, 5b | Medium | Restrict D7 ROAS comparisons to cohorts with ≥7 days maturity |
| Summary dict (Cell 51) | 6 | Low | Replace TBD values with actual findings — or remove (Section 6 markdown is the real summary) |
| Cell 35 not executed | 3a | Low | Run campaign inventory query to populate df_campaigns |
| Mean vs median ARPPU + terminology | 2d summary | **High** | Report median ARPPU alongside mean; add note about whale skew; replace "organic" with "unattributed" |
| CPI decomposition data | 2b | Low | Cell 25 ran but scatter plot (Cell 26) needs interpretation text |

---

*Generated: 2026-04-11 | Based on notebook data (Apr 3–9 L7D) + BQ campaign status (Apr 4–10) + investigation report (cc7314f) + Q2 strategy context*
