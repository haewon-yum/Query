# IB Format Deepdive — Plan

**Context:** Follow-up to KOR VT analysis (GDS × Sales workshop, Jan 2026). KOR shows disproportionately high IB format share vs global (iOS: 42%, Android: 27% of total installs). This analysis investigates whether IB dominance is driven by supply composition, bidding behavior, or both.

**Output notebook:** `notebook/ib_format_deepdive.ipynb`

**Key question:** Why is IB format share significantly higher in KOR than globally?

---

## Hypotheses

1. **Supply hypothesis:** KOR has more Banner inventory in the bid request stream (supply-side skew) → Moloco bids more on Banner → more IB wins
2. **Bidding hypothesis:** KOR campaigns bid more aggressively on IB relative to other formats → higher bid rate / win rate on IB regardless of supply mix
3. **Kakao hypothesis:** KakaoTalk's massive Banner supply dominates KOR inventory, pulling up IB share specifically on that publisher

---

## Section 1 — IB Share Benchmark (KOR vs Global)

**Goal:** Establish the baseline. Confirm and decompose the iOS 42% / Android 27% IB install share figures.

**Table:** `moloco-ae-view.athena.fact_dsp_creative`

**Logic:**
- Group by `campaign.country`, `campaign.os`, `creative.format`
- Compute IB install share = `SUM(installs) WHERE creative.format = 'ib'` / `SUM(installs)`
- Compare KOR vs global average, by OS

**Output:** Bar chart — IB install share % by OS × KOR vs Global

---

## Section 2 — Supply Side: Bid Request Volume by Inventory Format

**Goal:** Test supply hypothesis. Is Banner (`'B'`) inventory disproportionately more available in KOR vs globally?

**Table:** `focal-elf-631.prod.bidrequest{YYYY}*`

**Key column:** `inventory_format` — values: `'B'` (Banner), `'N'` (Native), `'I'` (Interstitial)

**Logic:**
- Filter: `country = 'KOR'` vs all countries (global)
- Group by `inventory_format`, compute format share of total bid requests
- 1/10,000 sampled table → multiply `COUNT(*)` by 10,000 for volume estimates
- Break down by `os` (use `UPPER(os)`)

**Output:** Stacked bar — bid request format mix (B / N / I) for KOR vs Global, by OS

**Interpretation guide:**
- If KOR `'B'` share >> Global `'B'` share → supply-driven explanation supported
- If similar → bidding strategy is the more likely driver

---

## Section 3 — Bidding Strategy: Bid Rate & Imp-to-Bid Ratio by Format

**Goal:** Test bidding hypothesis. Does Moloco bid more selectively or aggressively on Banner in KOR vs globally?

**Table:** `moloco-ae-view.athena.fact_supply`

**Key columns:**
- `inventory_format` — `'Banner'`, `'Native'`, `'Video Interstitial'`, `'Interstitial'`
- `cr_format` — granular format code (ib, vi, ri, ni, nl, etc.)
- `bid_requests`, `bids`, `bids_won`, `impressions`
- `req.country`, `req.os`

**Canonical rate definitions:**
- `bid_rate = bids / bid_requests`
- `win_rate = bids_won / bids`
- `serve_rate = impressions / bids_won`
- `imp_to_bid = impressions / bids` (combined win + serve)

**Logic:**
- Group by `inventory_format` (or `cr_format`), `req.country = 'KOR'` vs global
- Compute bid_rate, win_rate, serve_rate, imp_to_bid
- Break down by OS

**Gotcha:** Do NOT filter `campaign_id IS NOT NULL` — zero-bid rows are needed for accurate bid_rate.

**Reference — KakaoTalk on KAKAO exchange (180-day baseline from Looker dashboard):**

| Metric | 180-day avg | Recent 30D | Prior 30D | Trend |
|--------|-------------|-----------|-----------|-------|
| Daily bid requests | 1.89B | — | — | — |
| Bid rate | 23.3% | 19.8% | 24.8% | -5.0pp |
| Win rate | 37.3% | 43.2% | 35.7% | +7.5pp |
| CPM | $0.296 | $0.270 | $0.267 | Stable |
| Daily impressions | 122M | 134.7M | 125.5M | +10.9% |

Key pattern: bid rate declining while win rate rising — Moloco bidding more selectively on Kakao but winning more when it does bid. This is relevant context for interpreting IB format bidding strategy in Section 3.

Looker dashboard (180d, KakaoTalk bundles, KAKAO exchange): `ads_bpd_china::supply_investigation__daily_trend_pivot_dimensions_fact_supply`
Raw data cached: `~/claude-bq-agent/tmp/data/20260406_165527_7773.csv`

**Output:** Side-by-side grouped bar — bid_rate / win_rate / imp_to_bid by format for KOR vs Global

---

## Section 4 — IB Deep Dive: Win Rate & Bid Price by Vertical

**Goal:** Within IB format, understand whether the KOR skew is uniform or concentrated in specific verticals or publishers (Kakao vs Non-Kakao).

**Tables:**
- `moloco-ae-view.athena.fact_supply` — single table for all Section 4 metrics; has full bid funnel (bid_requests, bids, bids_won, impressions) + `req.app_is_gaming` + `exchange`

**Splits (analyzed separately, both from `fact_supply`, KOR only):**
- Gaming vs Non-Gaming — `req.app_is_gaming` (BOOL). Filter: `cr_format = 'ib'`, `req.country = 'KOR'`, group by `req.app_is_gaming` × `req.os`
- Kakao vs Non-Kakao — `exchange = 'KAKAO'` vs others. Filter: `cr_format = 'ib'`, `req.country = 'KOR'`, group by exchange group × `req.os`

No join between the two dimensions at this stage.

**Note — publisher genre proxy:** `req.app_is_gaming` classifies the **publisher app** (the app where the IB ad is served), not the advertiser's game. This answers "are IB ads in KOR concentrated in gaming publisher inventory?" — a supply-side angle. Advertiser-side genre split (`product.is_gaming` from `fact_dsp_creative`) would require a separate join and is deferred.

**Metrics:**
- Win rate (`bids_won / bids`)
- Bid-to-imp ratio (`impressions / bids`)
- Average bid price — `fact_supply.bid_price_usd / bids` (average only; `bid_price_usd` is a pre-aggregated SUM, percentiles not possible from this table)
- Bid price distribution (median, P75/P90) — requires `focal-elf-631.prod_stream_view.pricing`: individual-level, `candidates.bid_price / 1e6` for CPM in USD (1/1000 sampled)

**Output:**
- Table: win rate + bid price stats for IB, split by Kakao/Non-Kakao × OS
- Bar chart: bid rate comparison gaming vs non-gaming within IB, KOR vs Global

---

## Data Scope

| Parameter | Value |
|-----------|-------|
| Date range | Last 30 days (`date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)`) |
| Geo filter | `req.country = 'KOR'` (request country = supply-side market, not advertiser office) |
| OS | iOS and Android separately |
| Office filter | None — supply depends on campaign market, not advertiser's office |

---

## Table Reference

| Table | Section | Purpose |
|-------|---------|---------|
| `moloco-ae-view.athena.fact_dsp_creative` | 1 | IB install share baseline |
| `focal-elf-631.prod.bidrequest{YYYY}*` | 2 | Supply-side format mix (B/N/I) |
| `moloco-ae-view.athena.fact_supply` | 3, 4 | Bid rate, win rate, imp-to-bid, gaming/Kakao splits |
| `focal-elf-631.prod_stream_view.pricing` | 4 (optional) | Bid price distribution by cr_format |
