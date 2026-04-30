# KOR VT Deep-Dive: Scoping Analysis

## Objective

Deep-dive into VT (View-Through) install behavior for **KOR-targeting campaigns**, building on the global VT landscape analysis (`vt_landscape.ipynb`). The goal is to **scope which supply segment to focus on** for building VT narratives and activation materials.

## Context

From the landscape analysis:
- VT ratio varies significantly by office, target country, and creative format
- IB (banner) format has a meaningfully different VT ratio than rich formats (vi/ri/nv)
- KOR is a key market where VT narrative needs development (from GDS × Sales workshop, Jan 2026)

In KOR, **Kakao** (KakaoTalk — via Kakao exchange or Kakao Bizboard) is a dominant publisher in the ib supply. Understanding Kakao's VT behavior vs. other ib supply is critical for scoping.

## Key Questions

1. **Which creative format drives VT installs in KOR?** — Is VT primarily an ib phenomenon, or do rich formats also contribute meaningfully?
2. **Within ib, how does Kakao supply differ?** — Does Kakao Bizboard / Kakao exchange have a different VT ratio vs. other ib publishers?
3. **What's the right supply segment to focus on?** — Should the VT narrative be about ib broadly, Kakao specifically, or rich formats?

## Analysis Steps

### 0. Setup & Parameters

- Period: align with landscape notebook (2026-01-01 to 2026-01-31), or extend to recent 90 days for more data
- Filter: `campaign.country = 'KOR'` (KOR-targeting campaigns, all offices — though primarily KOR office)
- Tables: `moloco-ae-view.athena.fact_dsp_creative` (format-level) and `moloco-ae-view.athena.fact_dsp_publisher` (publisher-level)

### 1. VT Ratio by Creative Format (KOR-targeting)

**Query**: From `fact_dsp_creative`, for KOR-targeting campaigns:
- Group by `creative.format`
- Metrics: `installs`, `installs_vt`, `vt_ratio`, `impressions`, `spend`, `clicks`
- Also compute: format's share of total installs, format's share of total VT installs

**Visualizations**:
- Bar chart: VT ratio by format + annotation with install volume
- Stacked bar: VT vs CT install composition by format
- Table summary: format × (installs, vt_installs, vt_ratio, install_share, vt_install_share)

**Expected insight**: Identify whether ib dominates VT installs (likely yes, since banner has no click-through path for many impressions) and how much of the VT story is format-driven.

### 2. Kakao Portion Within IB (KOR-targeting)

**Query**: From `fact_dsp_publisher`, for KOR-targeting campaigns with ib format:
- Need to identify Kakao supply. Check available fields:
  - `exchange` field — may contain Kakao exchange identifier
  - `publisher` or `app_market_bundle` — may contain KakaoTalk bundle (e.g., `com.kakao.talk`)
  - `inventory_type` — Bizboard may have a specific type
- Group by: Kakao vs. non-Kakao (binary), or by exchange/publisher for more granularity
- Metrics: `installs`, `installs_vt`, `vt_ratio`, `impressions`, `spend`

**Visualizations**:
- Pie/donut: Kakao vs. non-Kakao share of ib installs and ib VT installs
- Bar: VT ratio comparison — Kakao ib vs. non-Kakao ib vs. rich formats
- Table: top publishers within ib by VT install volume

**Expected insight**: Quantify Kakao's dominance in KOR ib supply and whether its VT ratio is systematically different. If Kakao drives most ib VT installs, the VT narrative should be Kakao-specific.

### 3. Scoping Summary

Based on 1 & 2, produce a summary matrix:

| Segment | VT Installs | VT Ratio | Share of Total VT | Recommended Focus |
|---------|-------------|----------|-------------------|-------------------|
| IB — Kakao | ? | ? | ? | ? |
| IB — Non-Kakao | ? | ? | ? | ? |
| Rich (vi/ri/nv) | ? | ? | ? | ? |
| Other | ? | ? | ? | ? |

This scoping will determine which segment the deeper VT narrative analysis should focus on.

## Data Dependencies

- `moloco-ae-view.athena.fact_dsp_creative` — creative format + installs/installs_vt (used in landscape notebook)
- `moloco-ae-view.athena.fact_dsp_publisher` — publisher-level breakdowns (need to verify schema for Kakao identification)
- May need `moloco-ae-view.athena.dim1_app_with_tracking_publisher_v2` for publisher name lookup

## Open Questions (to resolve during implementation)

1. How to identify Kakao supply — which field/value? (`exchange`, `publisher.app_market_bundle`, or `inventory_type`?)
2. Is Kakao Bizboard tagged differently from regular Kakao exchange inventory?
3. Should we include all offices targeting KOR, or only KOR office?

---

## Section 5 — User Quality Analysis (Android, KOR)

> **Notebook:** Section 5 in `kr_vt_deepdive.ipynb` (cells 35–49). Plan originally numbered this Section 4 — renumbered to align with notebook.

### Objective

Compare user quality across install type (VT vs CT) × publisher (KakaoTalk vs Non-KakaoTalk) to assess whether VT installs from KakaoTalk translate into genuine user engagement and monetisation.

### Scope (as implemented)

- **OS**: Android only
- **Market**: KOR-targeting campaigns, all offices
- **Bundle selection**: Top 10 Android bundles by KakaoTalk publisher spend, separately for Gaming and Non-Gaming verticals
- **Vertical classification**: `product.is_gaming` from `fact_dsp_publisher` (BOOL; no join to `product_dimensions_SoT` required)
- **Period**: 2026-01-01 to 2026-01-31 (retention window capped at `DATE_END − 7d = 2026-01-24`)

### Segments (4-way, per bundle)

| Label | Install type | Publisher |
|-------|-------------|-----------|
| VT × KakaoTalk | VT | KakaoTalk |
| VT × NonKakaoTalk | VT | Non-KakaoTalk |
| CT × KakaoTalk | CT | KakaoTalk |
| CT × NonKakaoTalk | CT | Non-KakaoTalk |

- **VT flag:** `cv.view_through = TRUE` (BOOL field, always populated; `engaged_view_through` is separate)
- **KakaoTalk identification in cv:** `req.app.bundle = 'com.kakao.talk'` (Android)
- **Minimum threshold:** ≥ 50 installs per segment per bundle — cells below flagged, not suppressed

### Metrics (as implemented)

| Metric | Definition | Source |
|--------|-----------|--------|
| ITIT | `TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, SECOND)` — CDF per segment | `prod_stream_view.cv` |
| D1/D3/D7 Retention | % of installs with ≥ 1 cv event for same `bid.mtid` on day n post-install | `prod_stream_view.cv` |
| D7 ARPPU | Total `cv.revenue_usd.amount` D0–D7 ÷ paying users (`revenue_usd.amount > 0`) | `prod_stream_view.cv` |

> **Join key:** `bid.mtid` (Moloco Tracking ID) — ties each post-install event to its specific attributed install. More precise than IFA: handles reinstalls correctly (each reinstall gets a new MTID) and avoids cross-cohort contamination. Current notebook implementation uses IFA — **should be updated to MTID**.
>
> **Retention note:** Uses "any cv event for same `bid.mtid` on target day" as proxy for session. DISTINCT (`bid.mtid`, app_bundle, event_date) in the post-events CTE prevents join explosion.

### Notebook Structure (Section 5)

| Cell | Sub-section | Description |
|------|-------------|-------------|
| 35 | Header | Objective, segment table |
| 36–38 | 5-A Bundle selection | Top 10 per vertical from `fact_dsp_publisher` |
| 39–41 | 5-B ITIT | CDF + summary table per segment |
| 42–44 | 5-C Retention | D1/D3/D7 heatmap per vertical; TEST_MODE guard |
| 45–47 | 5-D ARPPU | D7 ARPPU + paying rate bar charts per vertical |
| 48–49 | 5-E Vertical summary | Aggregate medians; uplift of VT×Kakao vs CT×NonKakao |

### Data Dependencies (confirmed)

- `moloco-ae-view.athena.fact_dsp_publisher` — bundle selection, spend, `product.is_gaming`
- `focal-elf-631.prod_stream_view.cv` — all user-level metrics (ITIT, retention, ARPPU)

---

## Section 5 — Side Analysis: KakaoTalk Bizboard vs Native Impression Skew

### Hypothesis to Validate

> KakaoTalk sends bid requests for Bizboard (`ib`) and native (`ni`/`nv`) at approximately a **1:1 ratio**, yet actual impressions are heavily skewed toward Bizboard. If confirmed, identify the root cause.

### Background

**VBT (Value-Based Throttler)** is a pre-pricing throttling layer inside `bidfnt` that evaluates each incoming bid request (by exchange, format, geo, bundle, etc.), predicts expected value per infra cost, and **drops low-value requests before pricing or campaign logic runs**. The pipeline position is:

```
Exchange → bid_request → bidfnt → VBT → pricing → bid → win/loss → impression
```

This means equal upstream bid request volume from Kakao does **not** guarantee equal downstream impressions — VBT can selectively throttle one format over the other.

### Two Root Cause Hypotheses

| Hypothesis | Mechanism | Signal to look for |
|------------|-----------|-------------------|
| **VBT throttling** | Native requests get lower predicted value → throttled before pricing → fewer bids & impressions | `bid_result = THROTTLED_*` rate higher for native than Bizboard |
| **Creative compatibility** | Native creative assets (title, description, image ratio) don't match Kakao's native spec → bid submitted but lost or not rendered | Win rate comparable, but native creative serve rate or fill rate lower |

### Analysis Steps

#### Step 1 — Validate the 1:1 Bid Request Claim

- **Source**: `moloco-ae-view.athena.fact_dsp_publisher` (or `fact_dsp_all`)
- **Metric**: `bid_requests` by `creative.format` (`ib` vs `ni`/`nv`) for `exchange LIKE '%kakao%'`
- **Expected output**: ratio of Bizboard vs native bid requests — confirm whether it is actually ~1:1

#### Step 2 — Quantify the Impression Skew

- Same table, same filter
- **Metrics**: `impressions`, `bids`, and compute:
  - `bid_request → bid rate` per format
  - `bid → impression rate` (win rate) per format
- **Expected output**: identify at which funnel stage the divergence happens — before bidding (VBT) or after (win rate)

#### Step 3 — VBT Throttling Check

- **Source**: impression-level or bid-result streaming table (e.g. `focal-elf-631.prod_stream_view.imp` or bid result logs)
- **Check**: proportion of bid results tagged as `THROTTLED_*` for Kakao native vs Kakao Bizboard
- If native has significantly higher throttle rate → **VBT hypothesis confirmed**

#### Step 4 — Creative Compatibility Check

- **Source**: `fact_dsp_all` or creative-level logs, filtered to Kakao exchange + native format
- **Check**: are there active native creatives (titles, descriptions, images) configured for KakaoTalk native placements? Compare creative eligibility rate between ib and ni advertisers on Kakao
- If throttle rates are similar but native win rate is lower → **creative compatibility hypothesis**

### Expected Output

A short summary table:

| Funnel stage | Bizboard | Native | Gap |
|---|---|---|---|
| Bid requests | — | — | — |
| Bids (post-VBT) | — | — | — |
| Impressions | — | — | — |
| Bid → imp rate | — | — | — |
| VBT throttle rate | — | — | — |

Plus a one-line conclusion: which hypothesis (VBT / creative compatibility / both) accounts for the skew.

### Data Dependencies

- `moloco-ae-view.athena.fact_dsp_all` — format + exchange + impressions/bids
- `focal-elf-631.prod_stream_view.imp` — bid result codes for VBT throttle check (TBC)
- Creative eligibility data — format TBD

---

## Section 6 — User Quality Analysis (iOS, KOR)

> **Status:** Planned — to be added to `kr_vt_deepdive.ipynb` as Section 6.

### Objective

Mirror the Android user quality analysis (Section 5) for iOS, with two key differences:
1. **Bundle selection criterion**: top X bundles by **VT ratio** (not KakaoTalk spend) — focuses on bundles where the VT signal is most material
2. **Additional metric**: CPA per bundle using each campaign's optimization event — requires an event lookup step before the main analysis

### Scope

- **OS**: iOS only
- **Market**: KOR-targeting campaigns, KOR office (`advertiser.office = 'KOR'`)
- **Bundle selection**: Top X iOS bundles by VT ratio with sufficient volume (minimum install threshold TBD — suggest ≥ 500 VT installs), split by Gaming / Non-Gaming
- **Period**: 2026-01-01 to 2026-01-31

### Segments (4-way, per bundle)

Same segment structure as Android:

| Label | Install type | Publisher |
|-------|-------------|-----------|
| VT × KakaoTalk | VT | KakaoTalk |
| VT × NonKakaoTalk | VT | Non-KakaoTalk |
| CT × KakaoTalk | CT | KakaoTalk |
| CT × NonKakaoTalk | CT | Non-KakaoTalk |

- **VT flag:** `cv.view_through = TRUE` (same field, same semantics as Android)
- **KakaoTalk identification in cv:** `req.app.bundle = '362057947'` (KakaoTalk iOS App Store ID)
- **Minimum threshold:** ≥ 50 installs per segment per bundle

### Metrics

| Metric | Definition | Source |
|--------|-----------|--------|
| ITIT | `TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, SECOND)` — CDF per segment | `prod_stream_view.cv` |
| D1/D3/D7 Retention | % of installs with ≥ 1 cv event for same `bid.mtid` on day n | `prod_stream_view.cv` |
| Payer conversion | % of installs with `cv.revenue_usd.amount > 0` in D0–D7, keyed by `bid.mtid` | `prod_stream_view.cv` |
| D7 ARPPU | Total `cv.revenue_usd.amount` D0–D7 ÷ paying users, keyed by `bid.mtid` | `prod_stream_view.cv` |
| CPA | Spend ÷ count of bundle-specific optimization event in D0–D7, keyed by `bid.mtid` | `fact_dsp_publisher` + `prod_stream_view.cv` |

> **Join key:** `bid.mtid` — attributed install ID, unique per install event. Preferred over IFA because: (1) handles reinstalls correctly, (2) iOS IFA may be zeroed out for ATT-declined users while MTID is always populated.

### CPA Calculation — Optimization Event Lookup

CPA requires knowing **which event each bundle's CPA campaigns optimize for** — this varies per advertiser.

**Step 6-A: Event lookup**
- Source: campaign digest table (campaign configuration metadata — exact table name to confirm, e.g. `moloco-ods.business_intelligence.campaign_digest` or equivalent)
- Filter: `campaign_goal = 'CPA'` (or equivalent), `os = 'IOS'`, `target_country = 'KOR'`, bundle in target bundle list
- Select: `app_bundle`, `optimization_event` (or equivalent field name — verify schema)
- For each bundle: take the most common optimization event across CPA campaigns (mode)
- Output: `{bundle → optimization_event}` lookup dict

**Step 6-B: CPA computation in cv**
- From `prod_stream_view.cv`: count `cv.event = optimization_event` for each `bid.mtid` cohort within D0–D7
- CPA = `SUM(spend_usd)` (from `fact_dsp_publisher`) / `COUNT(DISTINCT bid.mtid WHERE optimization_event occurred)`
- Computed per bundle × segment

> **Open question (remaining):** Confirm exact campaign digest table name and column names for optimization event and campaign goal. Check with BQ Agent before implementing 6-A.

### Bundle Selection

**Step 6-0: iOS bundle selection**
- Source: `moloco-ae-view.athena.fact_dsp_publisher`
- Filter: `campaign.os = 'IOS'`, `campaign.country = 'KOR'`, `advertiser.office = 'KOR'`, date range
- Metrics: `SUM(installs)`, `SUM(installs_vt)`, `SAFE_DIVIDE(SUM(installs_vt), SUM(installs))` as `vt_ratio`
- Vertical: `product.is_gaming` (BOOL)
- Selection: top X per vertical ranked by `vt_ratio DESC`, with minimum `installs_vt >= 500` over the full 1-month period (not per day) — tune threshold down if too few bundles qualify; check distribution first

### Notebook Structure (planned)

| Cell | Sub-section | Description |
|------|-------------|-------------|
| 6-0 header | Markdown | Objective, scope, segment table |
| 6-0 code | Bundle selection | `fact_dsp_publisher`: top X iOS bundles by VT ratio per vertical |
| 6-A header | Markdown | Optimization event lookup |
| 6-A code | Event lookup | CPA campaign event lookup; build `{bundle → event}` dict |
| 6-B header | Markdown | ITIT |
| 6-B code | ITIT | CDF + summary table (same pattern as 5-B) |
| 6-C header | Markdown | Retention |
| 6-C code | Retention | D1/D3/D7 heatmap (same pattern as 5-C) |
| 6-D header | Markdown | Payer conversion + ARPPU |
| 6-D code | ARPPU + payer | Grouped bar per vertical |
| 6-E header | Markdown | CPA |
| 6-E code | CPA | CPA per bundle × segment; compare VT vs CT |
| 6-F header | Markdown | Vertical summary |
| 6-F code | Summary | Aggregate: VT×Kakao vs CT×NonKakao uplift |

### Data Dependencies

- `moloco-ae-view.athena.fact_dsp_publisher` — bundle selection (VT ratio), spend for CPA denominator, optimization event lookup
- `focal-elf-631.prod_stream_view.cv` — all user-level metrics (ITIT, retention, ARPPU, CPA event counting)

### Open Questions

1. **Campaign digest table** — confirm exact table name and column names for optimization event and campaign goal before implementing 6-A (do not use `fact_dsp_publisher` / `fact_dsp_all` for this)
2. **Top X bundle count** — determine based on how many iOS bundles have `installs_vt >= 500` over the full 1-month period after filtering; lower threshold if too few qualify

---

## Output

- New notebook: `Measurement/VT/kor_vt_deepdive.ipynb`
- Scoping summary table to guide next-phase analysis
