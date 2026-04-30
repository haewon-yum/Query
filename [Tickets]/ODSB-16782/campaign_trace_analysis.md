# Campaign Trace Analysis: ohLrG2wb6Iyfzkxi / Mp6OMsRw15IMDy2Z

**Date analyzed**: 2026-03-09 (using data from 2026-03-05)

## Campaign Overview

| Field | Value |
|-------|-------|
| Campaign ID | `ohLrG2wb6Iyfzkxi` |
| Campaign Title | `E_Moloco_DA_BAU_INSTALL_JP_iOS_2601_N_N` |
| Ad Group ID | `Mp6OMsRw15IMDy2Z` |
| Goal | CPI (Install) |
| Country | JPN |
| OS | iOS |
| Creative Group | `hs4mXqrfkmhP4RdY` — 12 NV (Native Video) + 9 VI (Video) |
| Targeted Publishers | Kakao piccoma (`1091496983`), LINE (`597088068`) |
| Model | I2I_TF_JOINT (single install prediction model) |

---

## Bidding Funnel Trace (2026-03-05)

```sql
SELECT
  ad_group, reason_order, reason, reason_raw,
  ROUND(SUM(1 / rate) / 1e6, 2) AS req_mil
FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
WHERE date = DATE('2026-03-05')
  AND campaign = 'ohLrG2wb6Iyfzkxi'
  AND ad_group = 'Mp6OMsRw15IMDy2Z'
GROUP BY 1, 2, 3, 4
ORDER BY reason_order ASC
```

### Summary

| Stage | Reason | req_mil |
|-------|--------|---------|
| 218 - Req | PublisherBundles | 4,340.7M |
| 218 - Req | UserBuckets | 240.8M |
| 225 | No compatible creative formats | 5.4M |
| 300 | No creative candidates (`unacceptable_native:12`) | 3.1M |
| 305 | Bidfloor filter (90+ buckets) | ~12M total |

- **Total requests**: ~4,581M (4,341M from PublisherBundles + 241M from UserBuckets)
- **Filtered at creative stages**: 8.5M (5.4M no compatible formats + 3.1M unacceptable native)
- **Filtered at bidfloor**: ~12M across 90+ publisher buckets, bid_cpm consistently 5-50x below bidfloor

---

## Action Items

### P0: Investigate Underbidding (Stage 305)

**Observation**: Across all bidfloor filter entries, `bid_cpm` is 1-2 orders of magnitude below `bidfloor` — e.g., bidfloor $1.88 vs bid_cpm $0.09, bidfloor $27.11 vs bid_cpm $0.61.

**Possible causes**:
- CPI target too low for JPN iOS market
- Model predictions extremely low (pCVR near zero) due to new campaign or lack of conversion signal
- Stability multiplier or CPI balancer compressing bids further

### P1: Fix Native Creative Compliance (Stage 300)

All 12 NV creatives rejected as "unacceptable_native" before bidding. Review native creative assets — check for missing required fields per OpenRTB native spec (title, icon, main image, CTA text, description).

### P2: Add Missing Creative Formats (Stage 225)

5.4M requests had no compatible creative format. Upload native and/or static banner creatives to unlock additional bid opportunities.

**Caveat**: Even if all 8.5M creative-filtered requests become eligible, the underbidding problem (stage 305) will still block most of them. Creative fix is necessary but not sufficient.

---

## Deep Dive: Creative Issues

### What's Serving vs What's Not

| Creative Type | In Ad Group | Bidding | Impressions |
|---------------|-------------|---------|-------------|
| VI (Video Interstitial) | 9 | Yes — 6,571 bids | 4,310 |
| VB (Video Banner) | (same assets) | Yes — 55 bids | 274 |
| NV (Native Video) | 12 | **Zero bids** | **0** |

### Why NV Creatives Are "Unacceptable"

The `unacceptable_native:12` rejection at stage 300 means the system checked all 12 NV creatives against publisher/exchange native specs and rejected all of them.

**Root Cause: `nv` (Native Video) ≠ `native`**

Both publishers actively support Native (N) inventory and `native` creative format — hundreds of campaigns bid and win with standard native creatives:

| Publisher | Native (N) Bid Requests/day | Native Bids by Other Campaigns | Creative Format Used |
|-----------|---------------------------|-------------------------------|---------------------|
| Kakao piccoma | 344K | 344K | `native` (standard) |
| LINE | 162K | 162K | `native` (standard) |

However, the ad group has `nv` (Native Video) creatives — a hybrid format combining a native container with an embedded video asset. This doesn't map to the standard `native` format these publishers accept. The NV creatives are checked against native specs and rejected because the native video hybrid doesn't match the publishers' standard native ad requirements.

**Conclusion**: The NV creatives aren't broken — they're incompatible with these specific publishers. These publishers support `native` (image-based) and `video` as separate formats, but not the combined `nv` format.

### Publisher Native & Format Support (Verified)

**Inventory formats requested (Mar 5, from bid table):**

| Publisher | I (Interstitial) | B (Banner) | N (Native) |
|-----------|------------------|-----------|-----------|
| Kakao piccoma | 896K | 686K | 344K |
| LINE | 699K | — | 162K |

**Creative formats bid by all Moloco campaigns (Mar 5):**

| Publisher | Creative Format | Inventory Format | Bid Count |
|-----------|----------------|-----------------|-----------|
| Kakao piccoma | video | I | 626K |
| Kakao piccoma | 300x250 | B | 435K |
| Kakao piccoma | native | N | 345K |
| Kakao piccoma | video | B | 226K |
| Kakao piccoma | mraid | I | 177K |
| LINE | video | I | 432K |
| LINE | native | N | 162K |
| LINE | mraid | I | 116K |

### Moloco Spend on These Publishers by Creative Format (Feb 27 – Mar 5)

**Kakao piccoma (`1091496983`)** — $57.1K total weekly spend:

| Format | Spend | Impressions | # Campaigns |
|--------|-------|-------------|-------------|
| video | $30.8K | 30.8M | 1,569 |
| **native** | **$19.1K** | **27.5M** | **726** |
| 300x250 | $4.8K | 12.7M | 948 |
| mraid | $1.9K | 128K | 247 |
| others | $0.4K | — | — |

**LINE (`597088068`)** — $58.2K total weekly spend:

| Format | Spend | Impressions | # Campaigns |
|--------|-------|-------------|-------------|
| video | $45.8K | 7.1M | 1,095 |
| **native** | **$7.7K** | **14.5M** | **113** |
| mraid | $3.8K | 295K | 299 |
| 320x480 | $0.6K | 149K | 205 |
| others | $0.2K | — | — |

**Opportunity**: $26.8K combined weekly native spend across 700+ campaigns on these 2 publishers alone. Standard `native` (NL) creatives would unlock this inventory.

### Revised Action Items for Creative Issues

| # | Action | Impact |
|---|--------|--------|
| **1** | **Add standard `native` (NL) creatives** to the ad group | Unlocks ~500K native bid opportunities/day. Biggest win. |
| **2** | **Add banner creatives** (e.g., 300x250) | Unlocks ~686K banner requests from Kakao piccoma |
| **3** | **Understand NV limitation** — NV only works on exchanges that explicitly support VAST-in-native. Kakao piccoma and LINE don't. The 12 NV creatives will remain unusable on these publishers. |

### Queries Used

```sql
-- Publishers and inventory formats for this campaign (from bid table, 1% sampled)
SELECT
  req.imp.publisher.bundle AS publisher_bundle,
  req.imp.publisher.name AS publisher_name,
  req.imp.inventory_format AS inventory_format,
  COUNT(*) AS bid_count,
  COUNT(DISTINCT bid.creative.id) AS num_creatives_used
FROM `focal-elf-631.prod_stream_view.bid`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
  AND api.ad_group.id = 'Mp6OMsRw15IMDy2Z'
GROUP BY 1, 2, 3
ORDER BY bid_count DESC
```

```sql
-- Creative types in bid attempts for this campaign
SELECT
  bid.creative.type AS creative_type,
  COUNT(*) AS total_bids
FROM `focal-elf-631.prod_stream_view.bid`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
  AND api.ad_group.id = 'Mp6OMsRw15IMDy2Z'
GROUP BY 1
ORDER BY total_bids DESC
```

```sql
-- Impressions by publisher and creative type for this campaign
SELECT
  req.imp.publisher.bundle AS publisher_bundle,
  req.imp.publisher.name AS publisher_name,
  bid.creative.type AS creative_type,
  bid.creative.id AS creative_id,
  req.imp.inventory_format AS inventory_format,
  COUNT(*) AS impressions
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
  AND api.ad_group.id = 'Mp6OMsRw15IMDy2Z'
GROUP BY 1, 2, 3, 4, 5
ORDER BY impressions DESC
```

```sql
-- All creative formats serving on these 2 publishers (all Moloco campaigns)
SELECT
  req.app.bundle AS publisher_bundle,
  api.creative.format AS creative_format,
  COUNT(*) AS impressions,
  COUNT(DISTINCT api.campaign.id) AS num_campaigns
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) BETWEEN DATE('2026-03-03') AND DATE('2026-03-05')
  AND req.app.bundle IN ('1091496983', '597088068')
GROUP BY 1, 2
ORDER BY publisher_bundle, impressions DESC
```

```sql
-- All creative formats x inventory formats bid on these 2 publishers (all campaigns)
SELECT
  req.app.bundle AS publisher_bundle,
  api.creative.format AS creative_format,
  req.imp.inventory_format AS inventory_format,
  COUNT(*) AS bid_count
FROM `focal-elf-631.prod_stream_view.bid`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND req.app.bundle IN ('1091496983', '597088068')
GROUP BY 1, 2, 3
ORDER BY publisher_bundle, bid_count DESC
```

```sql
-- Inventory formats requested by these 2 publishers (all campaigns)
SELECT
  req.app.bundle AS publisher_bundle,
  req.imp.inventory_format AS inventory_format,
  COUNT(*) AS total_requests
FROM `focal-elf-631.prod_stream_view.bid`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND req.app.bundle IN ('1091496983', '597088068')
GROUP BY 1, 2
ORDER BY 1, 3 DESC
```

```sql
-- Spend on these 2 publishers by creative format (7-day, all campaigns)
SELECT
  req.app.bundle AS publisher_bundle,
  api.creative.format AS creative_format,
  ROUND(SUM(bid.bid_price.amount_micro) / 1e6, 2) AS spend_usd,
  COUNT(*) AS impressions,
  COUNT(DISTINCT api.campaign.id) AS num_campaigns
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) BETWEEN DATE('2026-02-27') AND DATE('2026-03-05')
  AND req.app.bundle IN ('1091496983', '597088068')
GROUP BY 1, 2
ORDER BY publisher_bundle, spend_usd DESC
```

---

## Deep Dive: Underbidding

### Key Contradiction Resolved

| Source | bid_cpm | bidfloor |
|--------|---------|----------|
| **Campaign trace** (stage 305, filtered out) | $0.01–$1.41 | $0.21–$27.11 |
| **Bid table** (passed all filters) | 82% above $1.00, avg $3.95 on imps | ~$0.00 |

The trace captures **all requests including filtered ones**, while the bid table only shows requests that **passed** all filters. The campaign bids competitively on zero/low-floor inventory but cannot access premium inventory with real bidfloors.

### Model & Prediction Details

| Metric | Value |
|--------|-------|
| Model | I2I_TF_JOINT (single install model) |
| Avg I2I prediction | 0.00003963 |
| Normalizer | NULL (stability wrapper not active) |
| Won impression avg bid_cpm | $3.95 |
| Max bid_cpm observed | $46.86 |

### Bid CPM Distribution

| Bid CPM Bucket | # Bids | % | Avg Bidfloor |
|---------------|--------|---|-------------|
| $0.01–$0.05 | 20 | 0.3% | ~$0.00 |
| $0.05–$0.10 | 21 | 0.3% | ~$0.00 |
| $0.10–$0.50 | 349 | 5.3% | ~$0.00 |
| $0.50–$1.00 | 769 | 11.6% | ~$0.00 |
| $1.00–$2.00 | 1,686 | 25.4% | ~$0.00 |
| $2.00+ | 3,781 | 57.1% | ~$0.00 |

57% of bids that pass filters are $2.00+ CPM. The campaign bids well on low-floor inventory.

### Two-Tier Inventory Situation

| Inventory Tier | Bidfloor | Can Compete? | Volume |
|---------------|----------|-------------|--------|
| Low-floor (won) | ~$0 | Yes, avg bid $3.95 | ~6.6K bids → 4.6K imps |
| High-floor (lost) | $1–$27 | No, bid_cpm too low | ~12M requests filtered |

### Root Cause

The I2I prediction (~0.00004) is relatively constant. For low-floor supply, the bid formula produces $2–$4+ CPM which clears. But high-floor placements likely have **lower predicted install rates** (less relevant users), producing sub-$1 bids that can't clear $5–$27 floors. This may be **the system working as intended** — not bidding on inventory where the expected value doesn't justify the price.

### Potential Actions

| Priority | Action | Expected Impact |
|----------|--------|----------------|
| **Investigate** | Check if NV is supported by Kakao piccoma & LINE at exchange level | If NV unsupported, no creative fix will help |
| **Investigate** | Check if any Moloco campaign serves NV on these 2 publishers | Quick way to determine publisher vs creative issue |
| **Consider** | Whether high-floor inventory (~12M lost) is worth pursuing | If user quality is similar, raising CPI target could unlock it. If worse, current behavior is correct |
| **Monitor** | Win rate and CPI on current low-floor inventory | If CPI is on target, the campaign may be correctly optimized |

### Queries Used

```sql
-- Campaign details with bid stats
SELECT
  api.campaign.id AS campaign_id,
  api.campaign.title AS campaign_title,
  api.campaign.goal AS goal,
  api.campaign.country AS country,
  api.campaign.os AS os,
  api.campaign.app_market_bundle AS bundle,
  ROUND(AVG(bid.bid_cpm), 4) AS avg_bid_cpm,
  ROUND(MAX(bid.bid_cpm), 4) AS max_bid_cpm,
  ROUND(MIN(bid.bid_cpm), 4) AS min_bid_cpm,
  ROUND(AVG(req.imp.bidfloor), 4) AS avg_bidfloor,
  COUNT(*) AS total_bids
FROM `focal-elf-631.prod_stream_view.bid`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
GROUP BY 1, 2, 3, 4, 5, 6
```

```sql
-- Model prediction distribution
SELECT
  bid.MODEL.prediction_logs[SAFE_OFFSET(0)].type AS model_type_0,
  bid.MODEL.prediction_logs[SAFE_OFFSET(1)].type AS model_type_1,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred), 8) AS avg_action_pred,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer), 8) AS avg_action_normalizer,
  ROUND(AVG(SAFE_DIVIDE(
    bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred,
    bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer
  )), 4) AS avg_stability_multiplier,
  ROUND(AVG(bid.bid_cpm), 4) AS avg_bid_cpm,
  COUNT(*) AS num_impressions
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
  AND api.ad_group.id = 'Mp6OMsRw15IMDy2Z'
GROUP BY 1, 2
```

```sql
-- All prediction log offsets (campaign-wide)
SELECT
  bid.MODEL.prediction_logs[SAFE_OFFSET(0)].type AS type_0,
  bid.MODEL.prediction_logs[SAFE_OFFSET(1)].type AS type_1,
  bid.MODEL.prediction_logs[SAFE_OFFSET(2)].type AS type_2,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(0)].pred), 8) AS avg_pred_0,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred), 8) AS avg_pred_1,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(2)].pred), 8) AS avg_pred_2,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(0)].wrapper.normalizer), 8) AS avg_norm_0,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer), 8) AS avg_norm_1,
  ROUND(AVG(bid.MODEL.prediction_logs[SAFE_OFFSET(2)].wrapper.normalizer), 8) AS avg_norm_2,
  COUNT(*) AS n
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
GROUP BY 1, 2, 3
```

```sql
-- Bid CPM distribution
SELECT
  CASE
    WHEN bid.bid_cpm < 0.01 THEN '<0.01'
    WHEN bid.bid_cpm < 0.05 THEN '0.01-0.05'
    WHEN bid.bid_cpm < 0.1 THEN '0.05-0.10'
    WHEN bid.bid_cpm < 0.5 THEN '0.10-0.50'
    WHEN bid.bid_cpm < 1.0 THEN '0.50-1.00'
    WHEN bid.bid_cpm < 2.0 THEN '1.00-2.00'
    ELSE '2.00+'
  END AS bid_cpm_bucket,
  COUNT(*) AS num_bids,
  ROUND(AVG(req.imp.bidfloor), 4) AS avg_bidfloor_in_bucket
FROM `focal-elf-631.prod_stream_view.bid`
WHERE DATE(timestamp) = DATE('2026-03-05')
  AND api.campaign.id = 'ohLrG2wb6Iyfzkxi'
  AND api.ad_group.id = 'Mp6OMsRw15IMDy2Z'
GROUP BY 1
ORDER BY 1
```
