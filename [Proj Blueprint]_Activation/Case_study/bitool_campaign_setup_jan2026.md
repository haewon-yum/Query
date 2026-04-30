# Bitool (Hungry Studio) - Campaign Setup as of Jan 19, 2026

## Overview

- **Customer**: Bitool (advertiser.title = 'Hungry Studio')
- **App**: Block Blast Adventure Master
  - iOS bundle: `1617391485`
  - Android bundle: `com.block.juggle`
- **Genre**: Puzzle (hybrid IAA+IAP)
- **Platform Rank**: #1 spender on Moloco (4.0% of platform gross spend, Jan-Feb 2026)
- **DRR on Jan 19**: ~$345K (by bundle ID)
- **Active campaigns**: 319, spanning 352 country x OS combinations

Note: Filtering by bundle ID (`1617391485`, `com.block.juggle`) captures 22 more campaigns / ~$27K more DRR than filtering by `advertiser.title = 'Hungry Studio'`, likely due to multiple ad accounts running Block Blast.

## Single-geo vs Multi-geo Split

| Type | # Campaigns | DRR | Share |
|------|-------------|-----|-------|
| Single-geo | 223 | $147K | 43% |
| Multi-geo | 96 | $198K | 57% |
| **Total** | **319** | **$345K** | |

```sql
-- Single-geo vs Multi-geo campaign split (by bundle ID)
WITH campaign_geos AS (
  SELECT
    campaign_id,
    COUNT(DISTINCT campaign.country) AS num_countries,
    SUM(gross_spend_usd) AS spend
  FROM moloco-ae-view.athena.fact_dsp_core
  WHERE product.app_market_bundle IN ('1617391485', 'com.block.juggle')
    AND date_utc = '2026-01-19'
  GROUP BY 1
)
SELECT
  CASE WHEN num_countries = 1 THEN 'Single-geo' ELSE 'Multi-geo' END AS type,
  COUNT(*) AS num_campaigns,
  ROUND(SUM(spend), 0) AS daily_spend
FROM campaign_geos
GROUP BY 1
```

## Single-geo Campaigns by OS x Country

| OS | Country | # Campaigns | DRR |
|----|---------|-------------|-----|
| iOS | USA | 24 | $37.7K |
| Android | USA | 23 | $27.1K |
| iOS | JPN | 16 | $23.6K |
| iOS | BRA | 7 | $8.2K |
| iOS | KOR | 9 | $7.1K |
| iOS | DEU | 7 | $4.8K |
| Android | KOR | 10 | $4.3K |
| Android | BRA | 11 | $3.7K |
| iOS | CAN | 5 | $3.4K |
| **iOS** | **FRA** | **6** | **$3.4K** |
| iOS | ITA | 2 | $2.4K |
| Android | JPN | 17 | $2.4K |
| Android | MEX | 4 | $1.9K |
| iOS | AUS | 2 | $1.8K |
| Android | GBR | 4 | $1.7K |
| Android | DEU | 4 | $1.5K |
| Android | FRA | 3 | $1.5K |
| Android | RUS | 5 | $1.4K |
| iOS | GBR | 8 | $1.2K |
| iOS | RUS | 2 | $1.1K |
| iOS | TUR | 4 | $1.0K |
| iOS | ESP | 2 | $0.9K |
| Android | AUS | 2 | $0.9K |
| Android | IDN | 5 | $0.8K |
| iOS | IDN | 2 | $0.8K |
| iOS | MEX | 5 | $0.7K |
| Android | TUR | 4 | $0.7K |
| Android | CAN | 2 | $0.4K |
| Android | ITA | 2 | $0.4K |
| Android | ESP | 2 | $0.4K |
| Android | THA | 3 | $0.2K |
| Android | PHL | 2 | $0.1K |

Plus 12 $0-spend OS x Country combos (SAU, ARG, PHL, VNM, IND, AZE, EGY, TWN, CHL, ISR).

```sql
-- Single-geo campaigns by OS x Country (by bundle ID)
WITH campaign_geos AS (
  SELECT
    campaign_id,
    campaign.os,
    campaign.country,
    SUM(gross_spend_usd) AS spend
  FROM moloco-ae-view.athena.fact_dsp_core
  WHERE product.app_market_bundle IN ('1617391485', 'com.block.juggle')
    AND date_utc = '2026-01-19'
  GROUP BY 1, 2, 3
),
single_geo_campaigns AS (
  SELECT campaign_id, os, country, spend
  FROM campaign_geos
  WHERE campaign_id IN (
    SELECT campaign_id
    FROM campaign_geos
    GROUP BY campaign_id
    HAVING COUNT(DISTINCT country) = 1
  )
)
SELECT
  os,
  country,
  COUNT(DISTINCT campaign_id) AS num_campaigns,
  ROUND(SUM(spend), 0) AS daily_spend
FROM single_geo_campaigns
WHERE country IS NOT NULL
GROUP BY 1, 2
ORDER BY daily_spend DESC
```

## Single-geo Campaigns by OS x Country x Goal

Top combos with spend > $0:

| OS | Country | Goal | # Campaigns | DRR |
|----|---------|------|-------------|-----|
| iOS | USA | ROAS | 13 | $37.7K |
| Android | USA | ROAS | 12 | $27.1K |
| iOS | JPN | ROAS | 10 | $20.3K |
| iOS | BRA | ROAS | 7 | $8.2K |
| iOS | KOR | ROAS | 5 | $7.1K |
| iOS | DEU | ROAS | 6 | $4.8K |
| Android | KOR | ROAS | 8 | $4.3K |
| Android | BRA | ROAS | 7 | $3.7K |
| iOS | CAN | ROAS | 4 | $3.4K |
| **iOS** | **FRA** | **ROAS** | **6** | **$3.4K** |
| iOS | JPN | CPA | 3 | $2.7K |
| iOS | ITA | ROAS | 2 | $2.4K |
| Android | JPN | ROAS | 9 | $2.2K |
| Android | MEX | ROAS | 1 | $1.9K |
| iOS | AUS | ROAS | 2 | $1.8K |
| Android | GBR | ROAS | 4 | $1.7K |
| Android | DEU | ROAS | 4 | $1.5K |
| Android | FRA | ROAS | 3 | $1.5K |
| Android | RUS | ROAS | 3 | $1.4K |
| iOS | GBR | ROAS | 7 | $1.2K |
| iOS | RUS | ROAS | 2 | $1.1K |
| iOS | TUR | ROAS | 4 | $1.0K |
| iOS | ESP | ROAS | 2 | $0.9K |
| Android | AUS | ROAS | 2 | $0.9K |
| Android | IDN | ROAS | 3 | $0.8K |
| iOS | IDN | ROAS | 2 | $0.8K |
| iOS | MEX | ROAS | 5 | $0.7K |
| Android | TUR | ROAS | 4 | $0.7K |
| iOS | JPN | Retention | 2 | $0.5K |
| Android | CAN | ROAS | 2 | $0.4K |
| Android | ITA | ROAS | 2 | $0.4K |
| Android | ESP | ROAS | 2 | $0.4K |
| Android | THA | ROAS | 1 | $0.2K |
| Android | PHL | ROAS | 1 | $0.1K |
| Android | JPN | CPA (RE) | 4 | $0.1K |

Plus 40+ $0-spend (paused/inactive) single-geo campaigns across CPA, CPI, Retention, and Reengagement goals.

```sql
-- Single-geo campaigns by OS x Country x Goal (by bundle ID)
WITH campaign_geos AS (
  SELECT
    campaign_id,
    campaign.os,
    campaign.country,
    campaign.goal,
    SUM(gross_spend_usd) AS spend
  FROM moloco-ae-view.athena.fact_dsp_core
  WHERE product.app_market_bundle IN ('1617391485', 'com.block.juggle')
    AND date_utc = '2026-01-19'
  GROUP BY 1, 2, 3, 4
),
single_geo_campaigns AS (
  SELECT campaign_id, os, country, goal, spend
  FROM campaign_geos
  WHERE campaign_id IN (
    SELECT campaign_id
    FROM campaign_geos
    GROUP BY campaign_id
    HAVING COUNT(DISTINCT country) = 1
  )
)
SELECT
  os,
  country,
  goal,
  COUNT(DISTINCT campaign_id) AS num_campaigns,
  ROUND(SUM(spend), 0) AS daily_spend
FROM single_geo_campaigns
GROUP BY 1, 2, 3
ORDER BY daily_spend DESC
```

## USA Deep Dive (Jan 19)

Total USA: **86 campaigns (32 with spend), $125.4K DRR**

| OS | Goal | # Campaigns | With Spend>0 | DRR |
|----|------|-------------|--------------|-----|
| iOS | ROAS | 33 | 19 | $96.3K |
| iOS | CPA | 10 | 0 | $0 |
| iOS | CPI | 3 | 0 | $0 |
| iOS | Retention | 2 | 0 | $0 |
| Android | ROAS | 25 | 13 | $29.2K |
| Android | ROAS (RE) | 4 | 0 | $0 |
| Android | CPA | 4 | 0 | $0 |
| Android | CPA (RE) | 3 | 0 | $0 |
| Android | Retention | 2 | 0 | $0 |
| **Total** | | **86** | **32** | **$125.4K** |

## JPN Deep Dive (Jan 19)

Total JPN: **79 campaigns (26 with spend), $42.5K DRR**

| OS | Goal | # Campaigns | With Spend>0 | DRR |
|----|------|-------------|--------------|-----|
| iOS | ROAS | 30 | 13 | $35.4K |
| iOS | CPA | 7 | 2 | $2.7K |
| iOS | CPI | 4 | 0 | $0 |
| iOS | Retention | 2 | 1 | $0.5K |
| Android | ROAS | 22 | 7 | $3.7K |
| Android | CPA (RE) | 4 | 3 | $0.1K |
| Android | CPA | 6 | 0 | $0 |
| Android | Reattribution | 2 | 0 | $0 |
| Android | Retention | 2 | 0 | $0 |
| **Total** | | **79** | **26** | **$42.5K** |

```sql
-- USA and JPN: all campaigns by OS x Goal (Jan 19)
SELECT
  campaign.os,
  campaign.country,
  campaign.goal,
  COUNT(DISTINCT campaign_id) AS num_campaigns,
  COUNT(DISTINCT CASE WHEN gross_spend_usd > 0 THEN campaign_id END) AS campaigns_with_spend,
  ROUND(SUM(gross_spend_usd), 0) AS daily_spend
FROM moloco-ae-view.athena.fact_dsp_core
WHERE product.app_market_bundle IN ('1617391485', 'com.block.juggle')
  AND campaign.country IN ('USA', 'JPN')
  AND date_utc = '2026-01-19'
GROUP BY 1, 2, 3
ORDER BY campaign.country, campaign.os, daily_spend DESC
```

## FRA iOS Deep Dive (Jan 19, Pre-consolidation)

Total iOS FRA: **29 campaigns, $9.2K DRR**

| Type | Goal | # Campaigns | With Spend>0 | DRR |
|------|------|-------------|--------------|-----|
| Multi-geo | ROAS | 16 | 9 | $5.2K |
| Multi-geo | CPA | 4 | 1 | $0.6K |
| Multi-geo | CPI | 3 | 0 | $0 |
| Single-geo | ROAS | 6 | 3 | $3.4K |
| **Total** | | **29** | **13** | **$9.2K** |

Only 13 of 29 campaigns had actual spend on Jan 19. Multi-geo ROAS campaigns contributed the majority ($5.2K), with single-geo ROAS adding $3.4K.

```sql
-- FRA iOS: single/multi-geo x goal breakdown (Jan 19)
WITH all_campaign_geos AS (
  SELECT
    campaign_id,
    COUNT(DISTINCT campaign.country) AS num_countries
  FROM moloco-ae-view.athena.fact_dsp_core
  WHERE product.app_market_bundle = '1617391485'
    AND campaign.os = 'IOS'
    AND date_utc = '2026-01-19'
  GROUP BY 1
),
fra_spend AS (
  SELECT
    campaign_id,
    campaign.goal,
    SUM(gross_spend_usd) AS spend
  FROM moloco-ae-view.athena.fact_dsp_core
  WHERE product.app_market_bundle = '1617391485'
    AND campaign.os = 'IOS'
    AND campaign.country = 'FRA'
    AND date_utc = '2026-01-19'
  GROUP BY 1, 2
)
SELECT
  CASE WHEN g.num_countries = 1 THEN 'Single-geo' ELSE 'Multi-geo' END AS type,
  f.goal,
  COUNT(DISTINCT f.campaign_id) AS num_campaigns,
  ROUND(SUM(f.spend), 0) AS daily_spend
FROM fra_spend f
JOIN all_campaign_geos g ON f.campaign_id = g.campaign_id
GROUP BY 1, 2
ORDER BY 1, daily_spend DESC
```

### FRA iOS Consolidation Timeline

- **Pre-consolidation (Jan 19)**: 29 campaigns totaling $9.2K DRR (6 single-geo ROAS + 23 multi-geo across ROAS/CPA/CPI)
- **Jan 20-21, 2026**: Consolidated all iOS FRA campaigns into a single ROAS campaign (`xzSf12n8jTuFlhvA` / `DSP-FR-IOS-ROAS-PA-YM-251224-SFB`) at $5K/day
- **Post-consolidation**: Budget scaled to $11K/day, exceeding the pre-consolidation $9.2K/day total

## Key Observations

1. **Extreme campaign fragmentation** - 319 campaigns for a single app, with e.g. 13 single-geo ROAS campaigns in US iOS alone
2. **Multi-geo campaigns dominate spend** - 96 multi-geo campaigns account for 57% ($198K) of DRR
3. **iOS-dominated** - ~4:1 iOS:Android spend ratio
4. **ROAS-dominated** - vast majority of spend on ROAS goal
5. **Long tail of dormant campaigns** - 40+ $0-spend single-geo campaigns across various goals adding to clutter
6. **Multiple ad accounts** - Bundle-level query captures 22 more campaigns than platform-level, indicating multiple ad accounts running Block Blast
