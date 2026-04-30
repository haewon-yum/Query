# ODSB-17259: Creative Gap Analysis -- Validated Report

**Ticket:** ODSB-17259 (KR Retention campaign not spending)
**Campaigns compared:**
- `onLf8YMrzBKrT80y` -- **Broken** (KR Retention, not spending)
- `ttIK8j9coo7UMK9r` -- **Healthy** (Retention, scaling well)

**Data window:** Last 3 days (2026-03-25 to 2026-03-27)
**Data sources:** `moloco-data-prod.younghan.campaign_trace_raw_prod`, `focal-elf-631.prod_stream_view.pricing`

---

## 1. Executive Summary

The KR retention campaign (`onLf8YMrzBKrT80y`) is unable to spend due to **two compounding issues**:

1. **Banner creative incompatibility** -- 50.6% of all banner requests are filtered at "no compatible creatives" (reason 060), and **zero banner requests reach pricing**. This is the single largest distinguishing factor vs. the healthy campaign.
2. **Bids far below bidfloor across all formats** -- Even requests that survive creative filtering cannot win auctions. The p50 bid is $0.000002 vs. avg bidfloor of $0.014 (a ~7,000x gap).

Cold-start is **not** the primary issue -- the healthy campaign is also retention-type and scales well. The root cause is creative coverage + bid competitiveness.

---

## 2. Format-Level Funnel Analysis

### 2.1 Total Requests by Format (millions)

| Format | Broken | Healthy | Broken % of Total | Healthy % of Total |
|--------|-------:|--------:|-------------------:|-------------------:|
| Banner (B) | 1,785 | 21,420 | 46% | 34% |
| Interstitial (I) | 1,359 | 29,044 | 35% | 46% |
| Native (N) | 753 | 12,835 | 19% | 20% |
| **Total** | **3,897** | **63,299** | 100% | 100% |

> The broken campaign receives ~16x fewer total requests, but format distribution is comparable.

### 2.2 Key Funnel Stages by Format (millions)

#### Banner (B)

| Stage | Broken | % of B | Healthy | % of B |
|-------|-------:|-------:|--------:|-------:|
| 060 no compatible creatives | **903.3** | **50.6%** | 158.3 | 0.7% |
| 120 campaign limiter | 662.0 | 37.1% | 15,497.0 | 72.3% |
| 040 category_blocked | 39.1 | 2.2% | 249.7 | 1.2% |
| 305 filter(bidfloor,...) | 141.9 | 7.9% | 4,030.2 | 18.8% |
| **310 priced** | **0.0** | **0.0%** | **389.0** | **1.8%** |

**Finding:** 50.6% of banner supply is killed at creative compatibility. This is the smoking gun -- the healthy campaign loses only 0.7% at the same stage. Zero banner requests reach pricing for the broken campaign.

#### Interstitial (I)

| Stage | Broken | % of I | Healthy | % of I |
|-------|-------:|-------:|--------:|-------:|
| 060 no compatible creatives | 0.0 | 0.0% | 0.0 | 0.0% |
| 120 campaign limiter | 1,003.8 | 73.9% | 13,889.8 | 47.8% |
| 045 blocked advertiser or app | 70.2 | 5.2% | 313.3 | 1.1% |
| 236 avoided pricing (per cr_format) | 28.4 | 2.1% | 762.2 | 2.6% |
| 305 filter(bidfloor,...) | 235.5 | 17.3% | 10,264.4 | 35.3% |
| **310 priced** | **8.0** | **0.6%** | **3,014.5** | **10.4%** |

**Finding:** Interstitial has no creative compatibility issues. The campaign limiter absorbs 73.9% of supply (vs. 47.8% for healthy). 8.0M requests reach pricing, but almost none win due to bid-below-floor.

#### Native (N)

| Stage | Broken | % of N | Healthy | % of N |
|-------|-------:|-------:|--------:|-------:|
| 060 no compatible creatives | 0.0 | 0.0% | 0.0 | 0.0% |
| 040 category_blocked | **187.6** | **24.9%** | 223.8 | 1.7% |
| 120 campaign limiter | 429.8 | 57.1% | 6,808.0 | 53.0% |
| 300 no creative candidates | 2.2 | 0.3% | 248.2 | 1.9% |
| 305 filter(bidfloor,...) | 88.7 | 11.8% | 3,815.3 | 29.7% |
| **310 priced** | **0.1** | **0.01%** | **1,090.1** | **8.5%** |

**Finding:** Native creatives **do exist** (only 2.2M "no creative candidates" vs. 248.2M for the healthy campaign). However, `category_blocked` is abnormally high at **24.9%** (vs 1.7% for healthy) -- this is a secondary issue specific to native format that warrants investigation.

---

## 3. Bid Price Analysis

| Metric | Broken (onLf8Y...) | Healthy (ttIK8...) | Gap |
|--------|--------------------:|--------------------:|-----|
| Avg bidfloor | $0.01430 | $0.00805 | Broken faces 1.8x higher floors |
| Avg bid price | $0.000008 | $0.000172 | Healthy bids 21x higher |
| p25 bid | $0.000001 | $0.000007 | |
| p50 bid | $0.000002 | $0.000036 | |
| p75 bid | $0.000006 | $0.000158 | |
| p90 bid | $0.000019 | $0.000447 | |

**Finding:** Both campaigns have bids well below their respective bidfloors. However:
- **Broken:** p50 bid ($0.000002) is **7,150x below** avg floor ($0.01430). Essentially zero chance of winning.
- **Healthy:** p50 bid ($0.000036) is **224x below** avg floor ($0.00805). Still low on average, but the bid distribution has a long right tail -- p90 reaches $0.000447, and the campaign processes enough volume (13,279M at bidfloor filter) that even a small win rate produces 4,494M priced impressions.

The broken campaign's core problem: too few requests reach the bidfloor stage (466M vs. 22,604M for healthy), AND the bids that do arrive are far less competitive.

### 3.1 Pricing Stage Conversion Rate (priced / [filter + priced])

| Format | Broken | Healthy |
|--------|-------:|--------:|
| Banner | 0.0% (0 / 141.9M) | 8.8% (389 / 4,419M) |
| Interstitial | 3.3% (8 / 243.5M) | 22.7% (3,015 / 13,279M) |
| Native | 0.1% (0.1 / 88.8M) | 22.2% (1,090 / 4,905M) |

Even among requests that reach the bidfloor filter, the broken campaign converts at a fraction of the healthy campaign's rate.

---

## 4. Corrections to Original Searchlight Analysis

| Searchlight Claim | Actual Data | Verdict |
|-------------------|-------------|---------|
| "Banner: 1,444M req, 733.7M no-compatible (50.8%)" | 1,785M req, 903.3M no-compatible (50.6%) | **Percentage correct; absolute numbers off** (likely different date window) |
| "Banner: 0 priced" | 0.0M priced | **Confirmed** |
| "Interstitial: 1,074M req, 6.3M priced" | 1,359M req, 8.0M priced | **Directionally correct; numbers off** |
| "Native: 607M req, 0 priced, 1.9M no creative candidates" | 753M req, 0.1M priced, 2.2M no creative candidates | **Roughly correct** |
| **"Native creatives are missing entirely"** | Native has 0% "no compatible creatives" (reason 060), only 2.2M at "no creative candidates" (reason 300) vs. 248.2M for healthy | **INCORRECT -- native creatives exist.** The bottleneck is category_blocked (24.9%) + bidfloor filter, not missing creatives |
| "p50 bid $0.000003 vs $0.014 floor" | p50 = $0.000002, avg floor = $0.01430 | **Confirmed (minor rounding diff)** |
| "Healthy campaign: 300.9M banner priced, 2,432.8M interstitial priced, 828.1M native priced" | 389.0M, 3,014.5M, 1,090.1M | **Directionally correct; absolute numbers ~30% low** |

### Key correction: Native is NOT "completely missing"

The Searchlight analysis incorrectly concluded that native creatives are missing. In reality:
- "no creative candidates" (reason 300) is **lower** for the broken campaign (2.2M) than the healthy one (248.2M)
- The actual native bottleneck is **category_blocked at 24.9%** (187.6M of 753M native requests), compared to only 1.7% for the healthy campaign
- This suggests a **category/content restriction mismatch** on native supply, not missing creatives

---

## 5. Root Cause Summary

**Primary (Banner -- 46% of supply):**
> 50.6% of banner requests fail at "no compatible creatives" (reason 060). This is the single largest differentiator vs. the healthy campaign. **Action: Fix banner creative sizes to match inventory slot specifications.**

**Secondary (All formats -- bid competitiveness):**
> Bids are 3-4 orders of magnitude below bidfloors. The broken campaign's p50 bid ($0.000002) is 7,150x below the avg floor ($0.0143). Even interstitial, which passes creative checks, converts only 3.3% at the pricing stage vs. 22.7% for healthy. **Action: This will likely self-correct as impression volume increases and the model learns, but may also indicate a target CPA that is too aggressive or insufficient signal data.**

**Tertiary (Native -- 19% of supply):**
> 24.9% of native supply is lost to `category_blocked` vs. 1.7% for healthy. **Action: Investigate category/content restrictions on the campaign that may be overly restrictive for native inventory.**

---

## 6. Recommendation (Revised)

1. **Fix banner creative sizes** -- This is the highest-impact fix. 903M requests/3d are being wasted.
2. **Investigate native category blocking** -- 187.6M native requests are category_blocked (24.9%). Check if campaign-level category restrictions are too aggressive.
3. **Monitor bid prices after creative fix** -- Once impressions start flowing, the model should begin learning. If bids remain non-competitive after 3-5 days, investigate target CPA feasibility.
4. ~~Add native creatives~~ -- **Not needed.** Native creatives exist; the issue is category blocking, not missing assets.

### On Cold-Start

Confirmed: cold-start is **not the primary issue**. The healthy campaign (`ttIK8j9coo7UMK9r`) is also retention-type and processes 63B requests with 4.5B reaching pricing. The broken campaign's funnel is blocked upstream of where cold-start effects would manifest.

---

## 7. Queries Used

### Query 1: Aggregate Funnel (from user's original analysis)

```sql
SELECT
  campaign, reason_order, reason,
  ROUND(SUM(1/rate)/1e6, 2) AS req_mil,
  ROUND(SUM(1/rate)*100.0/SUM(SUM(1/rate)) OVER(), 2) AS pct
FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
WHERE campaign IN ('onLf8YMrzBKrT80y', 'ttIK8j9coo7UMK9r', 'Q6OdKwliixkg8XX3')
  AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
GROUP BY ALL
ORDER BY req_mil DESC
```

### Query 2: Format-Level Funnel (validation query)

```sql
SELECT
  campaign, inventory_format, reason_order, reason,
  ROUND(SUM(1/rate)/1e6, 2) AS req_mil
FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
WHERE campaign IN ('onLf8YMrzBKrT80y', 'ttIK8j9coo7UMK9r')
  AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
GROUP BY ALL
ORDER BY campaign, inventory_format, reason_order
```

### Query 3: Bid Price Distribution

```sql
SELECT
  campaign_id,
  AVG(req.imp.bidfloor.amount_micro / 1e6) AS bidfloor_usd,
  AVG(candidates.bid_price / 1e6) AS bid_price_usd,
  APPROX_QUANTILES(candidates.bid_price / 1e6, 100)[OFFSET(25)] AS p25_bid_price,
  APPROX_QUANTILES(candidates.bid_price / 1e6, 100)[OFFSET(50)] AS p50_bid_price,
  APPROX_QUANTILES(candidates.bid_price / 1e6, 100)[OFFSET(75)] AS p75_bid_price,
  APPROX_QUANTILES(candidates.bid_price / 1e6, 100)[OFFSET(90)] AS p90_bid_price
FROM `focal-elf-631.prod_stream_view.pricing`,
UNNEST(pricing.candidates) AS candidates
WHERE DATE(timestamp) BETWEEN '2026-03-25' AND '2026-03-27'
  AND campaign_id IN ('onLf8YMrzBKrT80y', 'ttIK8j9coo7UMK9r')
GROUP BY ALL
```

---

## 8. Banner Size Mismatch Deep-Dive

### 8.1 The Problem: `0x0` Flexible Slots

When we break down the **903M banner requests throttled at "no compatible creatives"** by ad slot size:

| Campaign | Slot Size | Throttled (M) | % of Throttled |
|----------|-----------|---------------:|---------------:|
| **Broken** | **0x0** | **88.0** | **99.1%** |
| Broken | 640x100 | 0.56 | 0.6% |
| Broken | 330x71 | 0.1 | 0.1% |
| Broken | 320x100 | 0.1 | 0.1% |
| Healthy | 320x100 | 5.4 | 34.2% |
| Healthy | 440x68 | 4.4 | 27.8% |
| Healthy | 300x50 | 0.7 | 4.4% |
| Healthy | (various) | 5.3 | 33.5% |
| Healthy | 0x0 | 0.1 | 0.6% |

> Note: Counts are from a 10% sample of the raw trace table, extrapolated. The totals won't match the campaign_trace_raw_prod exactly due to sampling, but the **distribution** is representative.

**Key finding:** 99.1% of the broken campaign's throttled banner requests come from **`0x0` slots** -- these are flexible/adaptive banner placements where the exchange does not specify dimensions and expects the bidder to select a matching creative size. The broken campaign's creatives cannot match these flexible slots.

The healthy campaign barely sees `0x0` at the throttle stage (0.6%), meaning its creatives successfully match flexible slots.

### 8.2 Banner Sizes That Reach Pricing (Healthy Campaign)

| Slot Size | Priced Requests (M) | % of Banner Priced |
|-----------|--------------------:|-------------------:|
| 320x50 | 16.8 | 70.6% |
| 728x90 | 6.2 | 26.1% |
| 300x50 | 0.6 | 2.5% |
| 300x250 | 0.1 | 0.4% |

The healthy campaign's banner pricing is dominated by **320x50** and **728x90** -- standard mobile/tablet banner sizes.

### 8.3 Banner Creative Sizes Actually Served (Healthy Campaign)

From the impression stream (`prod_stream_view.imp`):

| Creative Size | Format | Impressions | % of Banner Imps |
|---------------|--------|------------:|------------------:|
| **1456x180** | ib | 2,587,866 | **51.4%** |
| **640x100** | ib | 2,411,802 | **47.9%** |
| 600x500 | ib | 32,215 | 0.6% |
| 728x90 | ib | 2 | ~0% |

The healthy campaign serves banners primarily at **1456x180** and **640x100**. These are resizable creatives that get rendered into various slot sizes (320x50, 728x90, etc.) via server-side scaling.

### 8.4 Creative Format Candidates (Pricing Stream)

Both campaigns have the same creative format types registered:

| cr_format | Broken (cnt) | Healthy (cnt) | Ratio |
|-----------|-------------:|--------------:|------:|
| vi (Video Interstitial) | 247,979 | 13,381,996 | 54x |
| ri (Rewarded Interstitial) | 242,449 | 12,345,582 | 51x |
| ii (Image Interstitial) | 217,505 | 11,576,789 | 53x |
| **ib (Image Banner)** | **145,814** | **4,685,412** | **32x** |
| nl (Native Logo) | 94,216 | 5,376,168 | 57x |
| ni (Native Image) | 74,003 | 4,072,881 | 55x |
| nv (Native Video) | 20,276 | 1,777,125 | 88x |
| vb (Video Banner) | 8,836 | 674,421 | 76x |

**Critical observation:** The broken campaign **does have `ib` (image banner) creatives** reaching the pricing stage (145K candidates). But these are only for the small fraction of requests that survive the "no compatible creatives" filter -- the 0.9% of non-`0x0` slots. The `0x0` flexible slots (99.1% of throttled traffic) are rejected before they ever reach pricing.

### 8.5 Root Cause Hypothesis

The broken campaign's banner creatives lack the **size flexibility** needed to match `0x0` (adaptive) ad slots. This likely means:

1. **The creatives may have rigid size declarations** that don't include the flexible/resizable flag, OR
2. **The creative sizes uploaded don't cover the common banner aspect ratios** that the DSP's creative matching logic uses to fill `0x0` slots

The healthy campaign's banners (1456x180, 640x100) successfully match `0x0` slots because they have proper size declarations that the matching engine recognizes as compatible with flexible placements.

**Action:** Check the creative assets in the campaign's ad group -- specifically whether the banner images have the correct size metadata and whether resizable/adaptive flags are enabled.

### 8.6 Queries Used for Banner Analysis

**Query 4: Banner slot sizes at "no compatible creatives" (from raw trace, 10% sample)**
```sql
-- Executed against focal-elf-631.prod.trace* with bidfnt_req.imp[0].banner.w/h
-- Filtered on campaign = 'onLf8YMrzBKrT80y' / 'ttIK8j9coo7UMK9r'
-- AND reason_order equivalent to nobid at creative matching stage
-- See agent output for exact adapted query
```

**Query 5: Banner sizes reaching pricing (from raw trace)**
```sql
-- Same trace table, filtered on bid_result = 'BID'
-- Only ttIK8j9coo7UMK9r returned results (broken campaign has 0 BIDs)
```

**Query 6: Creative sizes served (from impression stream)**
```sql
SELECT
  campaign_id,
  CONCAT(CAST(api.creative.w AS STRING), 'x', CAST(api.creative.h AS STRING)) AS creative_size,
  cr_format,
  COUNT(*) AS impressions
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) BETWEEN '2026-03-26' AND '2026-03-28'
  AND campaign_id IN ('onLf8YMrzBKrT80y', 'ttIK8j9coo7UMK9r')
  AND cr_format IN ('ib', 'vb')
GROUP BY ALL
ORDER BY campaign_id, impressions DESC
```

**Query 7: Creative format candidates (from pricing stream)**
```sql
SELECT
  campaign_id,
  candidates.cr_format,
  COUNT(*) AS cnt
FROM `focal-elf-631.prod_stream_view.pricing`,
UNNEST(pricing.candidates) AS candidates
WHERE DATE(timestamp) BETWEEN '2026-03-26' AND '2026-03-28'
  AND campaign_id IN ('onLf8YMrzBKrT80y', 'ttIK8j9coo7UMK9r')
GROUP BY ALL
ORDER BY campaign_id, cnt DESC
```

---

## 9. Raw Data Files

- `tmp/data/ODSB-17259_funnel_by_format.csv` -- Full format-level funnel (67 rows)
- `tmp/data/ODSB-17259_bid_price.csv` -- Bid price distributions by campaign
- `tmp/data/ODSB-17259_banner_slot_sizes_throttled.csv` -- Banner slot sizes at "no compatible creatives"
- `tmp/data/ODSB-17259_banner_sizes_priced.csv` -- Banner sizes reaching pricing (healthy only)
- `tmp/data/ODSB-17259_banner_creative_sizes_served.csv` -- Creative sizes from impression stream
- `[Tickets]/ODSB-17259/funnel_by_exchange.csv` -- 548-row full funnel (campaign × exchange × reason, last 3 days)
- `[Tickets]/ODSB-17259/funnel_pivot_by_reason.csv` -- 19-row pivot: reason × KR/WW/US req_mil + pct

---

## 10. Three-Campaign Funnel Comparison (KR vs WW vs US)

**Campaigns:**
- `onLf8YMrzBKrT80y` — KR_New_retention_260326_iOS (no spend, **broken**)
- `ttIK8j9coo7UMK9r` — WW_New_retention (spending, **healthy**)
- `Q6OdKwliixkg8XX3` — US_New_retention (spending, **healthy**)

All three share the same action model and KPI event. Data window: last 3 days from 2026-03-28.

### Top Funnel Stages by Volume (millions, from campaign_trace_raw_prod)

| reason_order | reason | KR req_mil | WW req_mil | US req_mil | KR % | WW % | US % |
|---|---|---:|---:|---:|---:|---:|---:|
| 120 | campaign limiter | 1,388.5 | 35,978.5 | 12,151.6 | 35.6% | 57.1% | 57.6% |
| 060 | no compatible creatives | **865.5** | 158.3 | 72.3 | **22.2%** | 0.3% | 0.3% |
| 305 | filter(bidfloor/pricing/threshold/pmp) | 466.4 | 18,110.6 | 6,132.9 | 12.0% | 28.7% | 29.1% |
| 040 | category_blocked | 226.5 | 473.5 | 94.7 | 5.8% | 0.8% | 0.4% |
| 310 | priced | 8.3 | 4,493.5 | 1,503.2 | 0.2% | 7.1% | 7.1% |

**Key differentiator:** KR loses **22.2% of supply at "no compatible creatives"** — WW and US lose only 0.3%. KR also has disproportionate category blocking (5.8% vs 0.4–0.8%). KR reaches pricing at only **0.2%** vs **7.1%** for both healthy campaigns.

### Query Used

```sql
SELECT reason_order, reason,
  ROUND(SUM(CASE WHEN campaign = 'onLf8YMrzBKrT80y' THEN 1/rate ELSE 0 END)/1e6, 2) AS KR_req_mil,
  ROUND(SUM(CASE WHEN campaign = 'ttIK8j9coo7UMK9r' THEN 1/rate ELSE 0 END)/1e6, 2) AS WW_req_mil,
  ROUND(SUM(CASE WHEN campaign = 'Q6OdKwliixkg8XX3' THEN 1/rate ELSE 0 END)/1e6, 2) AS US_req_mil,
  ROUND(SUM(CASE WHEN campaign = 'onLf8YMrzBKrT80y' THEN 1/rate ELSE 0 END)*100.0
    / SUM(CASE WHEN campaign = 'onLf8YMrzBKrT80y' THEN 1/rate ELSE 0 END) OVER(), 2) AS KR_pct,
  ROUND(SUM(CASE WHEN campaign = 'ttIK8j9coo7UMK9r' THEN 1/rate ELSE 0 END)*100.0
    / SUM(CASE WHEN campaign = 'ttIK8j9coo7UMK9r' THEN 1/rate ELSE 0 END) OVER(), 2) AS WW_pct,
  ROUND(SUM(CASE WHEN campaign = 'Q6OdKwliixkg8XX3' THEN 1/rate ELSE 0 END)*100.0
    / SUM(CASE WHEN campaign = 'Q6OdKwliixkg8XX3' THEN 1/rate ELSE 0 END) OVER(), 2) AS US_pct
FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
WHERE campaign IN ('onLf8YMrzBKrT80y','ttIK8j9coo7UMK9r','Q6OdKwliixkg8XX3')
  AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
GROUP BY reason_order, reason
ORDER BY WW_req_mil DESC
```

---

## 11. Exchange-Level Funnel Analysis

### "No Compatible Creatives" by Exchange (KR campaign)

| exchange | req_mil | % of KR no_compat |
|---|---:|---:|
| KAKAO | 826.8 | **95.5%** |
| Others | 38.7 | 4.5% |

### "Category Blocked" by Exchange (KR campaign)

| exchange | req_mil | % of KR cat_blocked |
|---|---:|---:|
| KAKAO | 218.0 | **96.2%** |
| Others | 8.5 | 3.8% |

**Finding:** Both creative incompatibility and category blocking are overwhelmingly concentrated on **KAKAO exchange**. KAKAO is the primary KOR inventory source, making this the core supply-side bottleneck.

---

## 12. KAKAO Exchange Deep-Dive (IAB9-30 / Banner Format)

### Context

KakaoTalk app bundle `362057947` (the primary KAKAO publisher) carries **IAB9-30** (Video & Computer Games) in the `bcat` (blocked categories) field of its bid requests. When IAB9-30 is in `bcat`, Moloco fires reason 040 (category_blocked) for any campaign not whitelisted.

This affects gaming advertisers disproportionately — IAB9-30 is the standard category for mobile games.

### KakaoTalk (362057947): Banner 1029×258 vs Native, IAB9-30 in bcat

| format | IAB9-30 in bcat | bid_requests (est.) | % |
|---|---|---:|---:|
| banner_1029×258 | No | ~463M | 76% |
| banner_1029×258 | Yes | ~148M | 24% |
| native | Yes | ~131M | **86%** |
| native | No | ~21M | 14% |

**Key findings:**
- **Banner 1029×258**: 76% of KakaoTalk banner requests are NOT blocked by IAB9-30 — meaning the primary banner problem is creative incompatibility, NOT category blocking. These 463M requests fail at "no compatible creatives" because the campaign has no creatives sized/formatted for AdFit's 1029×258 slot.
- **Native**: 86% of KakaoTalk native requests ARE blocked by IAB9-30 — category blocking is the dominant issue for native on KakaoTalk.

### Other KAKAO Publishers: Banner by IAB9-30

| IAB9-30 in bcat | bid_requests (est.) | % |
|---|---:|---:|
| Yes | ~61% | majority blocked |
| No | ~39% | accessible |

For publishers outside KakaoTalk, category blocking is more prevalent even on banner inventory.

---

## 13. prod.trace Format/Size Funnel (Mar 26, 2026)

Full picture from `focal-elf-631.prod.trace20260326` for campaign `onLf8YMrzBKrT80y`.

| format_size | total_evaluated | no_compat_creative | category_blocked | campaign_cap | bidfloor / pricing threshold | bid_submitted |
|---|---:|---:|---:|---:|---:|---:|
| banner_1029×258 | 409M | **393M** | 15.9M | 0 | 0 | 0 |
| video | 170M | 0 | 0.5M | 2.8M | 153M | **112M** |
| native | 154M | 0 | **80M** | 12.6M | 55.9M | 5.6M |
| banner_320×50 | 88M | 0 | 0.4M | 8.7M | 72.5M | 1.2M |
| interstitial_320×480 | 18.6M | 0 | 0.1M | 0.3M | 17.1M | 13.4M |
| banner_728×90 | 9.2M | 0 | 0 | 1.6M | 6.9M | 0.1M |
| banner_750×160 | 9M | 9M | 0 | 0 | 0 | 0 |
| banner_300×250 | 4.1M | 0 | 0 | 0 | 3.8M | 0.1M |
| banner_640×100 | 2.1M | 2.1M | 0 | 0 | 0 | 0 |
| banner_320×100 | 1.9M | 1.9M | 0 | 0 | 0 | 0 |
| banner_300×50 | 1.5M | 0 | 0 | 0 | 1.3M | 0.1M |
| interstitial_300×250 | 0.8M | 0 | 0 | 0 | 0.5M | 0.3M |
| interstitial_1024×768 | 0.7M | 0 | 0 | 0 | 0.7M | 0.7M |
| interstitial_768×1024 | 0.7M | 0 | 0 | 0 | 0.7M | 0.7M |
| interstitial_480×320 | 0.5M | 0 | 0.1M | 0 | 0.4M | 0.4M |

**Total ~872M** evaluated in prod.trace vs **1,924M** in campaign_trace_raw_prod — gap is due to different sampling rates between the two tables.

### Column Notes

- `total_evaluated`: rows where campaign appears in `filtered_campaigns` or `candidates.priced` sections of raw_json
- `no_compat_creative`: reason string `= 'no compatible creatives'` in filtered_campaigns
- `category_blocked`: reason string `= 'category_blocked'` in filtered_campaigns
- `campaign_cap`: reason string `LIKE 'campaign_cap%'` in filtered_campaigns
- `bidfloor / pricing threshold`: campaign appears in `candidates.filtered` section (between `"filtered":{` and `"priced":{` in raw_json) — reached internal auction but bid did not clear floor or pricing threshold
- `bid_submitted`: campaign appears in `candidates.priced` section with `bid_price > 0`
- **Remaining gap** (total_evaluated − sum of all buckets): other filter reasons in filtered_campaigns not extracted above (e.g. `blocked advertiser (adomain)`, `no available deal between bidrequest and campaign`, `Req:AND{...}` targeting AST filters, `blocked by content rating`)

### Corrected Query (prod.trace)

```sql
SELECT
  CASE
    WHEN JSON_QUERY(raw_json, '$.bidbnd_req.bid_request.imp[0].video') IS NOT NULL THEN 'video'
    WHEN JSON_QUERY(raw_json, '$.bidbnd_req.bid_request.imp[0].native') IS NOT NULL THEN 'native'
    WHEN JSON_VALUE(raw_json, '$.bidbnd_req.bid_request.imp[0].instl') = 'true'
      THEN CONCAT('interstitial_',
        IFNULL(JSON_VALUE(raw_json,'$.bidbnd_req.bid_request.imp[0].banner.w'),'?'),'x',
        IFNULL(JSON_VALUE(raw_json,'$.bidbnd_req.bid_request.imp[0].banner.h'),'?'))
    WHEN JSON_QUERY(raw_json, '$.bidbnd_req.bid_request.imp[0].banner') IS NOT NULL
      THEN CONCAT('banner_',
        IFNULL(JSON_VALUE(raw_json,'$.bidbnd_req.bid_request.imp[0].banner.w'),'?'),'x',
        IFNULL(JSON_VALUE(raw_json,'$.bidbnd_req.bid_request.imp[0].banner.h'),'?'))
    ELSE 'other'
  END AS format_size,
  ROUND(SUM(1/rate)) AS total_evaluated,
  ROUND(SUM(CASE WHEN REGEXP_EXTRACT(
    SUBSTR(raw_json, STRPOS(raw_json,'"filtered_campaigns":')),
    r'"onLf8YMrzBKrT80y":"([^"]+)"') = 'no compatible creatives'
    THEN 1/rate ELSE 0 END)) AS no_compatible_creatives,
  ROUND(SUM(CASE WHEN REGEXP_EXTRACT(
    SUBSTR(raw_json, STRPOS(raw_json,'"filtered_campaigns":')),
    r'"onLf8YMrzBKrT80y":"([^"]+)"') = 'category_blocked'
    THEN 1/rate ELSE 0 END)) AS category_blocked,
  ROUND(SUM(CASE WHEN REGEXP_EXTRACT(
    SUBSTR(raw_json, STRPOS(raw_json,'"filtered_campaigns":')),
    r'"onLf8YMrzBKrT80y":"([^"]+)"') LIKE 'campaign_cap%'
    THEN 1/rate ELSE 0 END)) AS campaign_cap,
  ROUND(SUM(CASE WHEN STRPOS(raw_json,'"priced":') > 0
    AND STRPOS(raw_json,'"filtered_campaigns":') > 0
    AND CAST(REGEXP_EXTRACT(
      SUBSTR(raw_json, STRPOS(raw_json,'"priced":'),
             STRPOS(raw_json,'"filtered_campaigns":') - STRPOS(raw_json,'"priced":')),
      r'"onLf8YMrzBKrT80y".*?bid_price:(\d+)') AS INT64) > 0
    THEN 1/rate ELSE 0 END)) AS bid_submitted
FROM `focal-elf-631.prod.trace20260326`
WHERE raw_json LIKE '%onLf8YMrzBKrT80y%'
  AND (
    (STRPOS(raw_json,'"filtered_campaigns":') > 0
     AND STRPOS(SUBSTR(raw_json, STRPOS(raw_json,'"filtered_campaigns":')),'"onLf8YMrzBKrT80y"') > 0)
    OR REGEXP_CONTAINS(raw_json, r'"onLf8YMrzBKrT80y":\{"ad_groups"')
  )
GROUP BY format_size
ORDER BY total_evaluated DESC
```

---

## 14. Creative Groups — KR Ad Group (zNEQOUcPYYu5Ey6c)

Source: `focal-elf-631.entity_history.prod_entity_history`

**25 creative groups, ~252 total creatives:**

| Type | Groups | Creatives each | Total |
|---|---:|---:|---:|
| Playable | 6 | 1 | 6 |
| Video (`_kr`) | 8 | 12 | 96 |
| Banner (`_kr`) | 11 | 10 | 110 |
| **Total** | **25** | — | **~252** |

All creative groups carry `_kr` suffix — Korea-targeted assets. **No native creative groups exist** for this ad group.

Notable creative groups:

| ID | Display Name | Creatives |
|---|---|---:|
| G0lFXBKQ1HboOTan | Playable_PF_battle_DTB1_StringCheese_balance | 1 |
| aaVUIN1NjUm0mPhR | video_update_cos_kr | 12 |
| EozSofgy7kQlWSP5 | banner_product_titleart_smash_kr | 10 |
| HyNUTMI17TCOMdGw | banner_character_split_camp_kr | 10 |

**Critical gap:** Zero native creative groups. The 154M native requests evaluated per day have no creative candidates, causing them to fall through at campaign_cap / category_blocked / pricing stages with no chance of winning native placements.

---

## 15. ML Training Data Status

Source: `moloco-dsp-ml-prod.training_dataset_prod`

| Table | Type | Data for this app? |
|---|---|---|
| `tfexample_action_postback` | Pretraining IFA | ✅ Has data (postback-based) |
| `tfexample_action_postback_imp_v4_beta5_merged` | Pretraining LAT | ✅ Has data |
| `tfexample_action_campaignlog_imp_v2` | Finetuning IFA+LAT (imp-level) | ❌ No data yet |

The finetuning table (`tfexample_action_campaignlog_imp_v2`) has **zero records** for this app bundle because the campaign has never served an impression. The model is bidding based entirely on pretraining priors — which explains the extremely low bids.

**Cold-start loop:** creative incompatibility → no impressions → no finetuning data → model bids on cold priors → bids don't clear floors → still no impressions.

Once impressions start flowing (after creative issues are resolved), the finetuning table will accumulate imp-level data and bid prices should improve to be competitive with WW/US retention campaigns.

---

## 16. Updated Root Cause Summary

The KR retention campaign (`onLf8YMrzBKrT80y`) is blocked by **three compounding issues**:

### Issue 1 — Banner creative incompatibility (PRIMARY)
- **409M banner requests/day** on KAKAO are all filtered at "no compatible creatives"
- The primary KAKAO banner slot is **1029×258** (AdFit-specific format) — the campaign has no creatives sized for this
- Banner creative groups exist in entity_history (11 groups, 110 creatives) but are not approved/compatible for AdFit 1029×258 inventory
- **Fix:** Get banner creatives approved in AdFit 1029×258 format, OR add standard-sized banners (320×50, 300×250) that KAKAO also supports

### Issue 2 — No native creative groups (SECONDARY)
- **154M native requests/day** are evaluated but zero native creative groups exist for this ad group
- KAKAO native is additionally blocked 86% of the time by IAB9-30 in bcat, but even the 14% unblocked native traffic has no creatives to serve
- **Fix:** Add native creative groups to ad group `zNEQOUcPYYu5Ey6c`

### Issue 3 — Cold-start / low bids (CONSEQUENCE of Issues 1+2)
- No impressions → no finetuning data → model bids on pretraining priors only
- KR p50 bid ($0.000002) is ~18x lower than WW ($0.000036) and cannot clear bid floors
- This will self-correct once Issues 1+2 are resolved and impressions begin flowing
- Bid prices should converge toward WW/US levels within a few days of impression volume

### Issue 4 — IAB9-30 category blocking on KAKAO native (STRUCTURAL)
- 86% of KakaoTalk native requests carry IAB9-30 (Video & Computer Games) in bcat
- This is a platform-level restriction on KakaoTalk, not campaign-specific
- Even after adding native creatives, ~86% of KakaoTalk native inventory will remain inaccessible
- Actual native opportunity post-fix: ~21M unblocked requests/day on KakaoTalk + other KAKAO publishers

### Recommended Actions

| Priority | Action | Expected Impact |
|---|---|---|
| 1 | Add/approve banner creatives in **1029×258** format for AdFit | Unlocks ~463M banner requests/day on KakaoTalk alone |
| 2 | Add **native creative groups** to ad group `zNEQOUcPYYu5Ey6c` | Unlocks ~21M unblocked native requests/day |
| 3 | Monitor bid prices after first impressions | Bids should improve within 2–5 days as finetuning data accumulates |
| 4 | Investigate IAB9-30 whitelist with KakaoTalk | Structural issue — may need partnership-level resolution for native scale |
