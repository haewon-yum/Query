### OS Coverage ###


DECLARE spend_date_start DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
DECLARE spend_date_end DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);


 

-- =====================================================================
-- 1️⃣ Get active campaigns with spend
-- =====================================================================
WITH campaigns_with_spend AS (
  SELECT 
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN spend_date_start AND spend_date_end
  -- AND advertiser.office = 'KOR'
  GROUP BY 1
  HAVING total_spend > 0
),
-- =====================================================================
-- 2️⃣ Campaign metadata (with target_countries array)
-- =====================================================================
campaign_tab AS (
  SELECT
    a.campaign_name   AS campaign_id,
    a.advertiser_name AS advertiser_id,
    a.os,
    ARRAY_AGG(DISTINCT cs.country) AS target_countries
  FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
  CROSS JOIN UNNEST(a.country_settings) cs
  WHERE state = "ACTIVE"
    AND enabled
    AND a.os IN ('IOS','ANDROID')
    AND a.campaign_name IN (SELECT campaign_id FROM campaigns_with_spend)
  GROUP BY campaign_id, advertiser_id, os
),

-- Precompute all (country, os) pairs actually needed by any campaign
campaign_country_os AS (
  SELECT DISTINCT
    UPPER(tc) AS country,
    UPPER(c.os) AS os
  FROM campaign_tab c
  CROSS JOIN UNNEST(c.target_countries) AS tc
),


-- =====================================================================
-- 1. Get active advertisers with spend
-- =====================================================================
advertisers_with_spend AS (
  SELECT 
  	advertiser_id,
    campaign.country,
    SUM(gross_spend_usd) AS total_spend,
    SUM(IF(campaign.os = 'IOS', gross_spend_usd, NULL)) AS ios_spend,
    SUM(IF(campaign.os = 'ANDROID', gross_spend_usd, NULL)) AS android_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN spend_date_start AND spend_date_end
  	AND campaign.os IN ('IOS','ANDROID') -- limited to App campaigns
  -- AND advertiser.office = 'KOR'
  GROUP BY 1,2
  HAVING total_spend > 0
),

advertisers_os_ratio AS (
  SELECT 
    advertiser_id,
    country,
    total_spend,
    ios_spend,
    android_spend,
    ROUND(COALESCE(SAFE_DIVIDE(ios_spend,     total_spend),0),2) AS ios_spend_ratio,
    ROUND(COALESCE(SAFE_DIVIDE(android_spend, total_spend),0),2) AS android_spend_ratio,
  FROM advertisers_with_spend
),

-- =====================================================================
-- 2. Get market benchmark 
-- =====================================================================
market_dim AS (
  SELECT
    campaign.country      AS country,
    SUM(gross_spend_usd)  AS total_market_spend,
    SUM(IF(campaign.os = 'IOS',     gross_spend_usd, NULL)) AS ios_market_spend,
    SUM(IF(campaign.os = 'ANDROID', gross_spend_usd, NULL)) AS android_market_spend,
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN spend_date_start AND spend_date_end
  GROUP BY 1
),

market_dim_ratio AS (
  SELECT
    country,
    total_market_spend,
    ios_market_spend,
    android_market_spend,
    ROUND(COALESCE(SAFE_DIVIDE(ios_market_spend,     total_market_spend),0),2) AS market_ios_spend_ratio,
    ROUND(COALESCE(SAFE_DIVIDE(android_market_spend, total_market_spend),0),2) AS market_android_spend_ratio
  FROM market_dim
),


-- =====================================================================
-- 3. Calculate country score
-- =====================================================================

os_scoring_country AS(
  SELECT
    ar.advertiser_id,
    ar.country,
    ar.total_spend  		AS advertiser_total_spend,
    SAFE_DIVIDE(ar.total_spend, SUM(total_spend) OVER (PARTITION BY ar.advertiser_id)) AS country_spend_ratio,
    ar.ios_spend_ratio 		AS advertiser_ios_spend_ratio,
    ar.android_spend_ratio 	AS advertiser_android_spend_ratio,
    mr.market_ios_spend_ratio,
    mr.market_android_spend_ratio,
    ROUND(100 * (1 - 1/2 * (ABS(ar.ios_spend_ratio-mr.market_ios_spend_ratio)+ABS(ar.android_spend_ratio-mr.market_android_spend_ratio))),2) AS country_score
  FROM advertisers_os_ratio ar 
  LEFT JOIN market_dim_ratio	mr
    ON ar.country = mr.country
),

os_scoring_agg AS (
  SELECT
    advertiser_id,
    ROUND(SUM(country_spend_ratio * country_score),2) AS os_coverage_score
  FROM os_scoring_country
  GROUP BY 1
)

SELECT 
  advertiser_id,
  campaign_id,
  os_coverage_score
FROM os_scoring_agg LEFT JOIN campaign_tab USING(advertiser_id)




