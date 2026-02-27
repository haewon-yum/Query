DECLARE spend_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- =====================================================================
-- 1️⃣ Get active campaigns with spend
-- =====================================================================
WITH campaigns_with_spend AS (
  SELECT campaign_id
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc = spend_date
    AND advertiser.office = 'KOR'
  GROUP BY 1
),

-- =====================================================================
-- 2️⃣ Campaign metadata (with target_countries array)
-- =====================================================================
campaign_tab AS (
  SELECT
    a.campaign_name AS campaign_id,
    a.os,
    ARRAY_AGG(DISTINCT cs.country) AS target_countries
  FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
  CROSS JOIN UNNEST(a.country_settings) cs
  WHERE state = "ACTIVE"
    AND enabled
    AND a.os IN ('IOS','ANDROID')
    AND a.campaign_name IN (SELECT campaign_id FROM campaigns_with_spend)
  GROUP BY campaign_id, os
),

-- =====================================================================
-- 3️⃣ Extract raw targeting JSON
-- =====================================================================
adgroup_raw AS (
  SELECT
    ad_group_id,
    campaign_id,
    target_id
  FROM `ads-bpd-guard-china.standard_digest.ad_group_digest`,
    UNNEST(JSON_VALUE_ARRAY(original_json, "$.user_targets")) AS target_id
  WHERE NOT is_archived
    AND JSON_EXTRACT_SCALAR(original_json, "$.disabled") = 'false'
    AND campaign_id IN (SELECT campaign_id FROM campaigns_with_spend)
),

target_raw AS (
  SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json
  FROM `focal-elf-631.standard_digest.audience_target_digest`
),

-- =====================================================================
-- 4️⃣ Precompute TARGETING MASKS ("allowed_*", "blocked_*")
-- =====================================================================
flat_target AS (
  SELECT
    ar.campaign_id,
    key,
    CASE
      WHEN key = 'allowed_apps'         THEN JSON_VALUE_ARRAY(t.condition_json, '$.allowed_apps')
      WHEN key = 'blocked_apps'         THEN JSON_VALUE_ARRAY(t.condition_json, '$.blocked_apps')
      WHEN key = 'allowed_exchanges'    THEN JSON_VALUE_ARRAY(t.condition_json, '$.allowed_exchanges')
      WHEN key = 'blocked_exchanges'    THEN JSON_VALUE_ARRAY(t.condition_json, '$.blocked_exchanges')
      WHEN key = 'allowed_countries'    THEN JSON_VALUE_ARRAY(t.condition_json, '$.allowed_countries')
      WHEN key = 'blocked_countries'    THEN JSON_VALUE_ARRAY(t.condition_json, '$.blocked_countries')
      ELSE []
    END AS vals
  FROM adgroup_raw ar
  JOIN target_raw t USING (target_id),
  UNNEST(REGEXP_EXTRACT_ALL(CAST(t.condition_json AS STRING),
        r'"(allowed_[^"]+|blocked_[^"]+)"')) AS key
),

-- 4.5️⃣  Build compact targeting masks per campaign
target_masks_raw AS (
  SELECT
    campaign_id,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_apps'      THEN vals ELSE [] END) AS allowed_apps_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_apps'      THEN vals ELSE [] END) AS blocked_apps_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_exchanges' THEN vals ELSE [] END) AS allowed_exchanges_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_exchanges' THEN vals ELSE [] END) AS blocked_exchanges_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_countries' THEN vals ELSE [] END) AS allowed_countries_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_countries' THEN vals ELSE [] END) AS blocked_countries_all
  FROM flat_target
  GROUP BY campaign_id
),

target_masks AS (
  SELECT
    campaign_id,

    -- distinct allowed_apps
    ARRAY(
      SELECT DISTINCT x
      FROM UNNEST(allowed_apps_all) AS x
    ) AS allowed_apps,

    -- distinct blocked_apps
    ARRAY(
      SELECT DISTINCT x
      FROM UNNEST(blocked_apps_all) AS x
    ) AS blocked_apps,

    -- distinct allowed_exchanges
    ARRAY(
      SELECT DISTINCT x
      FROM UNNEST(allowed_exchanges_all) AS x
    ) AS allowed_exchanges,

    -- distinct blocked_exchanges
    ARRAY(
      SELECT DISTINCT x
      FROM UNNEST(blocked_exchanges_all) AS x
    ) AS blocked_exchanges,

    -- distinct allowed_countries
    ARRAY(
      SELECT DISTINCT x
      FROM UNNEST(allowed_countries_all) AS x
    ) AS allowed_countries,

    -- distinct blocked_countries
    ARRAY(
      SELECT DISTINCT x
      FROM UNNEST(blocked_countries_all) AS x
    ) AS blocked_countries

  FROM target_masks_raw
),

-- =====================================================================
-- 5️⃣ Lookup LAT policy per campaign
-- =====================================================================
campaign_lat AS (
  SELECT
    c.campaign_id,
    c.os,
    c.target_countries,
    CASE
      WHEN JSON_EXTRACT(original_json, "$.ad_tracking_allowance")='"DO_NOT_CARE"' THEN 'DO_NOT_CARE'
      WHEN JSON_EXTRACT(original_json, "$.ad_tracking_allowance") IN ('"NON_LAT_ONLY"', '"AD_TRACKING_ALLOWANCE_NON_LAT_ONLY"') THEN 'NON_LAT_ONLY'
      WHEN JSON_EXTRACT(original_json, "$.ad_tracking_allowance")='"LAT_ONLY"' THEN 'LAT_ONLY'
      ELSE 'DO_NOT_CARE'
    END AS ad_tracking_allowance
  FROM campaign_tab c
  JOIN `focal-elf-631.standard_digest.campaign_digest` d
    ON c.campaign_id = d.campaign_id AND c.os = d.campaign_os
),

-- =====================================================================
-- 6️⃣ Aggregate publisher logs **once** → market_dim
-- =====================================================================
market_dim AS (
  SELECT
    campaign.country            AS country,
    campaign.os                 AS os,
    campaign.is_lat             AS is_lat,
    publisher.app_market_bundle AS app_bundle,
    exchange                    AS exchange,
    SUM(gross_spend_usd)        AS market_spend
  FROM `moloco-ae-view.athena.fact_dsp_publisher`
  WHERE date_utc = spend_date
  GROUP BY country, os, is_lat, app_bundle, exchange
),

-- =====================================================================
-- 7️⃣ Join campaigns × market buckets, apply masks efficiently
-- =====================================================================
campaign_market AS (
  SELECT
    cl.campaign_id,
    cl.os,
    cl.target_countries,
    cl.ad_tracking_allowance,

    -- Total market (across target countries)
    SUM(md.market_spend) AS total_market_spend,

    -- LAT-only eligibility
    SUM(
      CASE cl.ad_tracking_allowance
        WHEN 'NON_LAT_ONLY' THEN IF(md.is_lat = FALSE, md.market_spend, 0)
        WHEN 'LAT_ONLY'     THEN IF(md.is_lat = TRUE,  md.market_spend, 0)
        ELSE md.market_spend
      END
    ) AS tracking_eligible_spend,

    -- TARGETING-only eligibility
    SUM(
      CASE
        WHEN
          -- apps
          IF(tm.allowed_apps IS NULL OR ARRAY_LENGTH(tm.allowed_apps) = 0,
             TRUE,
             md.app_bundle IN UNNEST(tm.allowed_apps)
          )
          AND IF(tm.blocked_apps IS NULL,
                 TRUE,
                 md.app_bundle NOT IN UNNEST(tm.blocked_apps)
          )

          -- exchanges
          AND IF(tm.allowed_exchanges IS NULL OR ARRAY_LENGTH(tm.allowed_exchanges) = 0,
                 TRUE,
                 md.exchange IN UNNEST(tm.allowed_exchanges)
          )
          AND IF(tm.blocked_exchanges IS NULL,
                 TRUE,
                 md.exchange NOT IN UNNEST(tm.blocked_exchanges)
          )

          -- countries
          AND IF(tm.allowed_countries IS NULL OR ARRAY_LENGTH(tm.allowed_countries) = 0,
                 TRUE,
                 md.country IN UNNEST(tm.allowed_countries)
          )
          AND IF(tm.blocked_countries IS NULL,
                 TRUE,
                 md.country NOT IN UNNEST(tm.blocked_countries)
          )
        THEN md.market_spend
        ELSE 0
      END
    ) AS tgt_eligible_spend,

    -- LAT + TARGETING combined
    SUM(
      CASE
        WHEN
          -- LAT OK?
          (
            cl.ad_tracking_allowance = 'DO_NOT_CARE'
            OR (cl.ad_tracking_allowance='NON_LAT_ONLY' AND md.is_lat = FALSE)
            OR (cl.ad_tracking_allowance='LAT_ONLY'     AND md.is_lat = TRUE)
          )
          -- Targeting OK? (same IF pattern)
          AND IF(tm.allowed_apps IS NULL OR ARRAY_LENGTH(tm.allowed_apps) = 0,
                TRUE,
                md.app_bundle IN UNNEST(tm.allowed_apps)
          )
          AND IF(tm.blocked_apps IS NULL,
                TRUE,
                md.app_bundle NOT IN UNNEST(tm.blocked_apps)
          )
          AND IF(tm.allowed_exchanges IS NULL OR ARRAY_LENGTH(tm.allowed_exchanges) = 0,
                TRUE,
                md.exchange IN UNNEST(tm.allowed_exchanges)
          )
          AND IF(tm.blocked_exchanges IS NULL,
                TRUE,
                md.exchange NOT IN UNNEST(tm.blocked_exchanges)
          )
          AND IF(tm.allowed_countries IS NULL OR ARRAY_LENGTH(tm.allowed_countries) = 0,
                TRUE,
                md.country IN UNNEST(tm.allowed_countries)
          )
          AND IF(tm.blocked_countries IS NULL,
                TRUE,
                md.country NOT IN UNNEST(tm.blocked_countries)
          )
        THEN md.market_spend
        ELSE 0
      END
    ) AS accessible_spend

  FROM campaign_lat cl
  -- 🔁 LEFT JOIN so campaigns with NO targeting rules still appear
  LEFT JOIN target_masks tm
    USING (campaign_id)
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN market_dim md
    ON md.country = tc AND md.os = cl.os
  GROUP BY cl.campaign_id, cl.os, cl.target_countries, cl.ad_tracking_allowance
),

-- =====================================================================
-- 8️⃣ Compute ratios
-- =====================================================================
final AS (
  SELECT
    campaign_id,
    os,
    target_countries,
    ad_tracking_allowance,
    total_market_spend,
    tracking_eligible_spend,
    tgt_eligible_spend,
    accessible_spend,

    SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) AS accessible_ratio_tracking,
    SAFE_DIVIDE(tgt_eligible_spend, total_market_spend)       AS accessible_ratio_targeting,
    SAFE_DIVIDE(accessible_spend, total_market_spend)         AS accessible_ratio_actual,

    1 - SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) AS missing_ratio_tracking,
    1 - SAFE_DIVIDE(tgt_eligible_spend, total_market_spend)      AS missing_ratio_targeting,

    1 - (
      SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) *
      SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend)
    ) AS missing_ratio_total_mult,

    1 - SAFE_DIVIDE(accessible_spend, total_market_spend) AS missing_ratio_total_actual
  FROM campaign_market
)

SELECT *
FROM final
ORDER BY total_market_spend DESC;
