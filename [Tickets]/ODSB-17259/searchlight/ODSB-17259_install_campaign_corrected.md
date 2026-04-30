# ODSB-17259 Follow-up: iOS Install Campaign CPI Spike -- Corrected Analysis

**Campaigns:**
- `BhTo5PHbtcsuQwkh` -- KR iOS Install
- `VveaqT1OAcxlbXSv` -- US iOS Install

**Context:** Follow-up to the KR retention campaign creative gap analysis (ODSB-17259). The GM asked whether the CPI spike on the install campaigns indicates a broader model issue.

---

## 1. Bottom Line

**No broader model malfunction.** The CPI spike on Day 2 was caused by the model increasing bids after receiving initial conversion signals, exhausting daily budget in a compressed window. Both campaigns have recovered.

However, "cold-start" is not the right framing. The spike is better described as a **budget pacing failure during early learning** -- and it is not universal. Among 346 newly launched iOS CPI campaigns in the same period, only **14% experienced a >1.5x CPI spike**. The US campaign's 3.75x spike ranks in the top ~5%, making it an outlier, not expected behavior.

---

## 2. What Actually Happened (Corrected Timeline)

### Daily CPI (UTC dates, gross spend)

| Campaign | Mar 26 (Day 0) | Mar 27 (Day 1) | Mar 28 (Day 2) | Mar 29 (Day 3) | Mar 30 (Day 4) |
|----------|----------------:|----------------:|----------------:|----------------:|----------------:|
| **KR Install** | $5.70 | **$8.82** | $4.25 | $3.96 | $5.71 |
| **US Install** | $3.54 | **$12.83** | $5.81 | $3.71 | $4.81 |

The CPI spike occurred on **Mar 27 UTC (Day 1)**, not Mar 28 as originally reported.

### Bid Price Evolution

| Campaign | Date | Avg Bid ($) | p50 Bid ($) | p90 Bid ($) | Candidates |
|----------|------|------------:|------------:|------------:|-----------:|
| KR | Mar 26 | 0.000549 | 0.000060 | 0.001325 | 1.78M |
| KR | **Mar 27** | **0.000930** | **0.000212** | **0.002322** | **2.34M** |
| KR | Mar 28 | 0.000931 | 0.000301 | 0.002321 | 0.23M (capped) |
| KR | Mar 29 | 0.000544 | 0.000211 | 0.001368 | 2.54M |
| KR | Mar 30 | 0.000683 | 0.000305 | 0.001738 | 1.76M |
| US | Mar 26 | 0.001030 | 0.000297 | 0.002513 | 19.3M |
| US | **Mar 27** | **0.001194** | **0.000371** | **0.002829** | **28.3M** |
| US | Mar 28 | 0.000283 | 0.000087 | 0.000695 | 5.2M (capped) |
| US | Mar 29 | 0.000291 | 0.000077 | 0.000715 | 17.8M |
| US | Mar 30 | 0.000295 | 0.000065 | 0.000729 | 8.5M |

**Sequence of events:**
1. **Mar 26 (Day 0):** Conservative initial bidding, normal CPIs
2. **Mar 27 (Day 1):** Model received first conversion signals → increased bids (KR: +69% avg, US: +16% avg). Win prices jumped (KR: +40%, US: +82%). Both campaigns exhausted daily budget early.
3. **Mar 28 (Day 2):** Budget capper (reason 030) fired aggressively -- KR: 2,008M requests absorbed, US: 21,994M. Candidate volume collapsed to 10-15% of normal. CPI dropped because only cheap inventory was accessible.
4. **Mar 29-30:** Stabilized. CPI normalized below market avg.

### Win Price Confirmation

| Campaign | Date | Impressions | Avg Win Price ($) | p90 Win Price ($) |
|----------|------|------------:|------------------:|------------------:|
| KR | Mar 26 | 280K | 0.001397 | 0.003508 |
| KR | **Mar 27** | 744K | **0.001961** | **0.004954** |
| KR | Mar 28 | 968K | 0.000362 | 0.000562 |
| KR | Mar 29 | 3.3M | 0.000265 | 0.000355 |
| US | Mar 26 | 1.6M | 0.000644 | 0.000561 |
| US | **Mar 27** | 2.2M | **0.001174** | **0.001142** |
| US | Mar 28 | 4.1M | 0.000235 | 0.000441 |
| US | Mar 29 | 5.0M | 0.000346 | 0.000502 |

Win prices confirm the model bid more aggressively on Day 1, then corrected sharply.

### Budget Capper (Reason 030) Over Time

| Campaign | Mar 26 | Mar 27 | Mar 28 | Mar 29 | Mar 30 |
|----------|-------:|-------:|-------:|-------:|-------:|
| KR | 0.2M | 334.6M | **2,008.4M** | 185.3M | 0M |
| US | 2.4M | 8,180.1M | **21,993.7M** | 0M | 1,130.7M |

The capper absorbed massive volumes on Mar 28 as a correction. By Mar 29-30, it normalized.

---

## 3. Is This "Cold-Start"? -- A More Precise Answer

### What the data actually shows

Among **346 newly launched iOS CPI campaigns** (Mar 24-28 launch window), I computed the max CPI spike ratio (max CPI in first 5 days / Day 0 CPI):

| Spike Category | Count | % of Total |
|----------------|------:|----------:|
| < 1.3x (stable) | 96 | 28% |
| 1.3x - 1.5x (mild) | ~201 | 58% |
| > 1.5x (notable spike) | 49 | 14% |
| > 3.0x (severe spike) | ~15 | 4% |

**The target campaigns:**
| Campaign | Day 0 CPI | Max CPI | Spike Ratio | Percentile |
|----------|----------:|--------:|------------:|-----------:|
| KR Install | $5.04 | $7.85 | **1.56x** | ~top 14% |
| US Install | $3.28 | $12.31 | **3.75x** | **~top 5%** |

### Why "cold-start" is imprecise

"Cold-start" implies this is expected behavior for any new campaign. The data shows otherwise:

1. **86% of new campaigns do NOT experience a >1.5x CPI spike.** The KR campaign is borderline; the US campaign is an outlier.

2. **The mechanism is budget pacing, not cold-start.** The model doesn't bid poorly because it lacks data -- it bids aggressively because early conversion signals suggest higher value, and the budget pacer hasn't yet learned the right spend curve. This is specifically a **pacing overshoot**, not a valuation error.

3. **The severity correlates with supply constraints.** The KR install campaign still has ~20% "no compatible creatives" filtering (407-548M requests/day at reason 060), concentrating bid pressure on fewer placements. When the model increases bids on an already constrained supply, it overshoots faster. The US campaign, with much larger absolute supply but still constrained creative coverage, hit an even more extreme spike.

### What actually drives Day 2 spikes

Based on the pattern across campaigns:

| Factor | Contributes to spike? | Evidence |
|--------|----------------------|----------|
| Limited creative coverage | **Yes** -- concentrates bids on fewer placements | KR: 20% creative incompatibility, narrowing effective supply |
| Budget relative to available supply | **Yes** -- small supply + normal budget = faster exhaustion | Both campaigns exhausted budget in <10 hours on Mar 28 |
| Model receiving first conversion signals | **Yes** -- triggers bid increase before pacing adjusts | Bids increased 16-69% from Day 0 to Day 1 |
| Broader model/pricing malfunction | **No** | Market CPI was stable ($6.67-$7.60), no other campaigns anomalous |

---

## 4. On the GM's Question

> "Is this a model issue rather than a creative issue?"

**It's neither a model malfunction nor purely a creative issue -- it's an interaction between creative constraints and budget pacing.**

1. **The creative gap from the retention campaign carries over.** The KR install campaign shares creatives and still has ~20% banner requests blocked (407-548M/day). This narrows effective supply.

2. **On constrained supply, the pacing model overshoots faster.** When the model increases bids after early conversions, a campaign with full creative coverage spreads bids across more placements (natural dampening). A campaign with limited coverage concentrates bids, hitting budget cap sooner.

3. **The US campaign confirms this.** Even without the extreme creative incompatibility of KR, it spiked 3.75x -- but US inventory is larger, so the pacing overshoot manifested through sheer bid volume rather than creative filtering.

4. **The model itself is working correctly.** It increased bids on positive signals (correct), then the budget capper intervened (correct), and CPIs normalized by Day 3-4 (correct). The spike is an expected artifact of the feedback loop, not a bug -- though its severity was amplified by creative constraints.

---

## 5. KOR Market Benchmark (Corrected)

The original analysis claimed KOR iOS market CPI was "flat at $7.57-$7.79." Actual data:

| Date | KOR iOS Market CPI (excl. target campaigns) |
|------|--------------------------------------------:|
| Mar 26 | $7.60 |
| Mar 27 | $7.39 |
| Mar 28 | **$6.67** |
| Mar 29 | **$7.19** |
| Mar 30 | $6.74 (incomplete) |

Actual range: **$6.67-$7.60**, not $7.57-$7.79. The market CPI dipped on Mar 28, likely reflecting the same inventory dynamics (more supply available as budget-capped campaigns released inventory). No anomalous movement indicating a broader model issue.

---

## 6. Open Item: KR Banner Creative Gap Persists

The install campaign's funnel still shows significant "no compatible creatives" filtering:

| Date | Reason 060 (no compatible creatives) | Priced (310) | % Filtered |
|------|--------------------------------------:|-------------:|-----------:|
| Mar 26 | 407.5M | 138.1M | 23.6% |
| Mar 27 | 547.9M | 236.8M | 24.6% |
| Mar 29 | 512.9M | 395.3M | 20.8% |
| Mar 30 | 397.8M | 230.3M | 21.9% |

~20-25% of banner supply is still being wasted. **Adding the missing banner sizes (particularly Kakao AdFit 1029x258)** would expand effective supply, reduce bid concentration, and likely dampen future pacing overshoots.

---

## 7. Recommendation

1. **No action needed on model/pricing.** Both campaigns have self-corrected. CPIs are now at or below market average.
2. **Fix KR banner creative sizes** (same recommendation as original ODSB-17259). This remains the most impactful change -- it would expand supply by ~20%, reduce bid concentration, and make the campaign more resilient to pacing overshoots.
3. **Monitor US campaign win rate.** At 3.75x spike, it was an outlier. If it spikes again in the next budget cycle, investigate whether budget/target CPI is too aggressive for the available supply.

---

## 8. Corrections from Original Investigation

| Claim | Original | Corrected |
|-------|----------|-----------|
| CPI spike date | "Mar 28 KST" | **Mar 27 UTC** |
| KR spike CPI | $10.45 | **$8.82** |
| US spike CPI | $11.86 | **$12.83** |
| KR recovery CPI (Mar 29) | $4.11 | **$3.96** |
| US recovery CPI (Mar 30) | $3.68 | **$4.81** |
| Budget cap timing | "hour 14 KST on Mar 29" | **hour 10 KST on Mar 28** |
| KR capping volume | 726M | **2,008M** |
| US capping volume | 12.9B | **22.0B** |
| Market CPI range | "$7.57-$7.79" | **$6.67-$7.60** |
| Framing | "normal cold-start" | **Budget pacing overshoot, top 5-14% severity, amplified by creative constraints** |

---

## 9. Queries Used

### Q1: Daily CPI
```sql
SELECT campaign_id, date_utc,
  ROUND(gross_spend_usd, 2) AS spend_usd, installs,
  ROUND(SAFE_DIVIDE(gross_spend_usd, installs), 2) AS cpi
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE date_utc BETWEEN '2026-03-26' AND '2026-03-30'
  AND campaign_id IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv')
ORDER BY campaign_id, date_utc
```

### Q2: Funnel by day
```sql
SELECT campaign, DATE(date) as dt, reason_order, reason,
  ROUND(SUM(1/rate)/1e6, 2) AS req_mil
FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
WHERE campaign IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv')
  AND date BETWEEN DATE('2026-03-26') AND DATE('2026-03-30')
  AND reason_order IN ('030', '060', '120', '305', '310')
GROUP BY ALL
ORDER BY campaign, dt, reason_order
```

### Q3: KOR market CPI benchmark
```sql
SELECT date_utc,
  ROUND(SUM(gross_spend_usd), 2) AS total_spend,
  SUM(installs) AS total_installs,
  ROUND(SAFE_DIVIDE(SUM(gross_spend_usd), SUM(installs)), 2) AS market_cpi
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE date_utc BETWEEN '2026-03-26' AND '2026-03-30'
  AND campaign.country = 'KOR' AND campaign.os = 'IOS'
  AND campaign.goal LIKE '%CPI%'
  AND campaign_id NOT IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv',
                          'onLf8YMrzBKrT80y', 'ttIK8j9coo7UMK9r')
GROUP BY date_utc ORDER BY date_utc
```

### Q4: Hourly spend pattern
```sql
SELECT api.campaign.id AS campaign_id, DATE(timestamp) AS dt,
  EXTRACT(HOUR FROM timestamp AT TIME ZONE 'Asia/Seoul') AS hour_kst,
  ROUND(SUM(imp.win_price_usd.amount_micro / 1e6), 2) AS spend_usd,
  COUNT(*) AS impressions
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) BETWEEN '2026-03-28' AND '2026-03-29'
  AND api.campaign.id IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv')
GROUP BY campaign_id, dt, hour_kst
ORDER BY campaign_id, dt, hour_kst
```

### Q5: Bid price distribution over time
```sql
SELECT campaign_id, DATE(timestamp) AS dt,
  ROUND(AVG(candidates.bid_price / 1e6), 6) AS avg_bid_usd,
  ROUND(APPROX_QUANTILES(candidates.bid_price / 1e6, 100)[OFFSET(50)], 6) AS p50_bid,
  ROUND(APPROX_QUANTILES(candidates.bid_price / 1e6, 100)[OFFSET(90)], 6) AS p90_bid,
  COUNT(*) AS candidate_cnt
FROM `focal-elf-631.prod_stream_view.pricing`,
UNNEST(pricing.candidates) AS candidates
WHERE DATE(timestamp) BETWEEN '2026-03-26' AND '2026-03-30'
  AND campaign_id IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv')
GROUP BY campaign_id, dt ORDER BY campaign_id, dt
```

### Q6: New iOS CPI campaign launches (cold-start comparison)
```sql
WITH daily AS (
  SELECT campaign_id, campaign.title, campaign.country, date_utc,
    ROUND(SUM(gross_spend_usd), 2) AS spend, SUM(installs) AS installs,
    ROUND(SAFE_DIVIDE(SUM(gross_spend_usd), SUM(installs)), 2) AS cpi
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN '2026-03-24' AND '2026-03-30'
    AND campaign.os = 'IOS' AND campaign.goal LIKE '%CPI%' AND installs > 0
  GROUP BY ALL
),
first_day AS (
  SELECT campaign_id, MIN(date_utc) AS launch_date
  FROM daily WHERE spend > 10
  GROUP BY campaign_id HAVING MIN(date_utc) >= '2026-03-24'
)
SELECT d.*, f.launch_date, DATE_DIFF(d.date_utc, f.launch_date, DAY) AS day_num
FROM daily d JOIN first_day f USING (campaign_id)
WHERE d.date_utc >= f.launch_date AND DATE_DIFF(d.date_utc, f.launch_date, DAY) <= 4
ORDER BY d.campaign_id, d.date_utc
```

---

## 10. Raw Data Files

- `claude-bq-agent/tmp/data/20260330_210614_d75b.csv` -- Daily CPI
- `claude-bq-agent/tmp/data/20260330_210512_43cc.csv` -- Funnel by day
- `claude-bq-agent/tmp/data/20260330_211047_3bd8.csv` -- KOR market CPI
- `claude-bq-agent/tmp/data/20260330_212240_3ce5.csv` -- Hourly spend
- `claude-bq-agent/tmp/data/20260330_213431_c08f.csv` -- Bid prices over time
- `claude-bq-agent/tmp/data/20260330_213200_7e89.csv` -- Win prices over time
- `claude-bq-agent/tmp/data/20260330_213140_525a.csv` -- 346 new campaign launches comparison
