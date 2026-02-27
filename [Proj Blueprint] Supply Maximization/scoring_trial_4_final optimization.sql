DECLARE spend_date_start DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
DECLARE spend_date_end DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

-- =====================================================================
-- 1️⃣ Get active campaigns with spend
-- =====================================================================
WITH campaigns_with_spend AS (
  SELECT campaign_id
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN spend_date_start AND spend_date_end
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

-- Precompute all (country, os) pairs actually needed by any campaign
campaign_country_os AS (
  SELECT DISTINCT
    tc AS country,
    c.os
  FROM campaign_tab c
  CROSS JOIN UNNEST(c.target_countries) AS tc
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

-- distinct target_ids actually used → to prune audience_target_digest
distinct_target_ids AS (
  SELECT DISTINCT target_id
  FROM adgroup_raw
),

target_raw AS (
  SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json
  FROM `focal-elf-631.standard_digest.audience_target_digest`
  WHERE id IN (SELECT target_id FROM distinct_target_ids)
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
      WHEN key = 'allowed_device_types' THEN JSON_VALUE_ARRAY(t.condition_json, '$.allowed_device_types')
      WHEN key = 'blocked_device_types' THEN JSON_VALUE_ARRAY(t.condition_json, '$.blocked_device_types')
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
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_apps'         THEN vals ELSE [] END) AS allowed_apps_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_apps'         THEN vals ELSE [] END) AS blocked_apps_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_exchanges'    THEN vals ELSE [] END) AS allowed_exchanges_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_exchanges'    THEN vals ELSE [] END) AS blocked_exchanges_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_countries'    THEN vals ELSE [] END) AS allowed_countries_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_countries'    THEN vals ELSE [] END) AS blocked_countries_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'allowed_device_types' THEN vals ELSE [] END) AS allowed_device_types_all,
    ARRAY_CONCAT_AGG(CASE WHEN key = 'blocked_device_types' THEN vals ELSE [] END) AS blocked_device_types_all
  FROM flat_target
  GROUP BY campaign_id
),

target_masks AS (
  SELECT
    campaign_id,

    ARRAY(
      SELECT DISTINCT app
      FROM UNNEST(allowed_apps_all) AS app
    ) AS allowed_apps,

    ARRAY(
      SELECT DISTINCT app
      FROM UNNEST(blocked_apps_all) AS app
    ) AS blocked_apps,

    ARRAY(
      SELECT DISTINCT ex
      FROM UNNEST(allowed_exchanges_all) AS ex
    ) AS allowed_exchanges,

    ARRAY(
      SELECT DISTINCT ex
      FROM UNNEST(blocked_exchanges_all) AS ex
    ) AS blocked_exchanges,

    ARRAY(
      SELECT DISTINCT ctry
      FROM UNNEST(allowed_countries_all) AS ctry
    ) AS allowed_countries,

    ARRAY(
      SELECT DISTINCT ctry
      FROM UNNEST(blocked_countries_all) AS ctry
    ) AS blocked_countries,

    ARRAY(
      SELECT DISTINCT dt
      FROM UNNEST(allowed_device_types_all) AS dt
    ) AS allowed_device_types,

    ARRAY(
      SELECT DISTINCT dt
      FROM UNNEST(blocked_device_types_all) AS dt
    ) AS blocked_device_types

  FROM target_masks_raw
)
,

-- target_key_counts for summary table
target_key_counts AS (
  SELECT
    campaign_id,
    ARRAY_LENGTH(blocked_apps)         AS num_blocked_apps,
    ARRAY_LENGTH(allowed_apps)         AS num_allowed_apps,
    ARRAY_LENGTH(blocked_exchanges)    AS num_blocked_exchanges,
    ARRAY_LENGTH(allowed_exchanges)    AS num_allowed_exchanges,
    ARRAY_LENGTH(blocked_countries)    AS num_blocked_countries,
    ARRAY_LENGTH(allowed_countries)    AS num_allowed_countries,
    ARRAY_LENGTH(blocked_device_types) AS num_blocked_device_types,
    ARRAY_LENGTH(allowed_device_types) AS num_allowed_device_types
  FROM target_masks
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

-- Split campaigns into with vs without targeting (for cheaper path)
campaign_with_target AS (
  SELECT DISTINCT campaign_id, os, target_countries, ad_tracking_allowance
  FROM campaign_lat
  WHERE campaign_id IN (SELECT campaign_id FROM target_masks)
),
campaign_without_target AS (
  SELECT DISTINCT campaign_id, os, target_countries, ad_tracking_allowance
  FROM campaign_lat
  WHERE campaign_id NOT IN (SELECT campaign_id FROM target_masks)
),

-- =====================================================================
-- 6️⃣ Aggregate publisher logs once → market_dim BUT filtered to relevant country/os
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
  JOIN campaign_country_os cco
    ON campaign.country = cco.country
   AND campaign.os      = cco.os
  WHERE date_utc BETWEEN spend_date_start AND spend_date_end
  GROUP BY country, os, is_lat, app_bundle, exchange
),

-- =====================================================================
-- 7️⃣ Join campaigns × market buckets, apply masks efficiently
--     (A) campaigns WITH targeting
-- =====================================================================
campaign_market_with_target AS (
  SELECT
    cl.campaign_id,
    cl.os,
    cl.target_countries,
    cl.ad_tracking_allowance,

    SUM(md.market_spend) AS total_market_spend,

    SUM(
      CASE cl.ad_tracking_allowance
        WHEN 'NON_LAT_ONLY' THEN IF(md.is_lat = FALSE, md.market_spend, 0)
        WHEN 'LAT_ONLY'     THEN IF(md.is_lat = TRUE,  md.market_spend, 0)
        ELSE md.market_spend
      END
    ) AS tracking_eligible_spend,

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

    SUM(
      CASE
        WHEN
          (
            cl.ad_tracking_allowance = 'DO_NOT_CARE'
            OR (cl.ad_tracking_allowance='NON_LAT_ONLY' AND md.is_lat = FALSE)
            OR (cl.ad_tracking_allowance='LAT_ONLY'     AND md.is_lat = TRUE)
          )
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

  FROM campaign_with_target cl
  JOIN target_masks tm USING (campaign_id)
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN market_dim md
    ON md.country = tc AND md.os = cl.os
  GROUP BY cl.campaign_id, cl.os, cl.target_countries, cl.ad_tracking_allowance
),

-- =====================================================================
--     (B) campaigns WITHOUT targeting: much cheaper (no app/exchange checks)
-- =====================================================================
campaign_market_without_target AS (
  SELECT
    cl.campaign_id,
    cl.os,
    cl.target_countries,
    cl.ad_tracking_allowance,

    SUM(md.market_spend) AS total_market_spend,

    SUM(
      CASE cl.ad_tracking_allowance
        WHEN 'NON_LAT_ONLY' THEN IF(md.is_lat = FALSE, md.market_spend, 0)
        WHEN 'LAT_ONLY'     THEN IF(md.is_lat = TRUE,  md.market_spend, 0)
        ELSE md.market_spend
      END
    ) AS tracking_eligible_spend,

    -- No targeting → targeting-eligible == total
    SUM(md.market_spend) AS tgt_eligible_spend,

    -- LAT + no targeting
    SUM(
      CASE
        WHEN
          cl.ad_tracking_allowance = 'DO_NOT_CARE'
          OR (cl.ad_tracking_allowance='NON_LAT_ONLY' AND md.is_lat = FALSE)
          OR (cl.ad_tracking_allowance='LAT_ONLY'     AND md.is_lat = TRUE)
        THEN md.market_spend
        ELSE 0
      END
    ) AS accessible_spend

  FROM campaign_without_target cl
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN market_dim md
    ON md.country = tc AND md.os = cl.os
  GROUP BY cl.campaign_id, cl.os, cl.target_countries, cl.ad_tracking_allowance
),

campaign_market AS (
  SELECT * FROM campaign_market_with_target
  UNION ALL
  SELECT * FROM campaign_market_without_target
),

-- =====================================================================
-- 8️⃣ Compute ratios (base)
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
    SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend) AS accessible_ratio_targeting,
    SAFE_DIVIDE(accessible_spend,         total_market_spend) AS accessible_ratio_actual,

    1 - SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) AS missing_ratio_tracking,
    1 - SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend) AS missing_ratio_targeting,

    1 - (
      SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) *
      SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend)
    ) AS missing_ratio_total_mult,

    1 - SAFE_DIVIDE(accessible_spend, total_market_spend) AS missing_ratio_total_actual
  FROM campaign_market
),

-- =====================================================================
-- 9️⃣ Rename ratios to previous naming (missing_spend_*)
-- =====================================================================
missing_opportunity_spend AS (
  SELECT
    campaign_id,
    os,
    target_countries,
    ad_tracking_allowance,
    total_market_spend,
    tracking_eligible_spend,
    tgt_eligible_spend,
    accessible_spend,
    accessible_ratio_tracking,
    accessible_ratio_targeting,
    accessible_ratio_actual,
    missing_ratio_tracking      AS missing_spend_ratio_tracking,
    missing_ratio_targeting     AS missing_spend_ratio_targeting,
    missing_ratio_total_mult    AS missing_spend_ratio_total_mult,
    missing_ratio_total_actual  AS missing_spend_ratio_total_actual
  FROM final
),

-- =====================================================================
-- 🔟 Summary table in wide form (same columns as previous version)
-- =====================================================================
summary AS (
  SELECT
    mo.campaign_id,
    mo.os,
    mo.target_countries,
    mo.ad_tracking_allowance,

    mo.total_market_spend,
    mo.tracking_eligible_spend,
    mo.tgt_eligible_spend,
    mo.accessible_spend,

    mo.accessible_ratio_tracking,
    mo.accessible_ratio_targeting,
    mo.accessible_ratio_actual,

    mo.missing_spend_ratio_tracking,
    mo.missing_spend_ratio_targeting,
    mo.missing_spend_ratio_total_mult,
    mo.missing_spend_ratio_total_actual,

    t.num_blocked_apps,
    t.num_allowed_apps,
    t.num_blocked_exchanges,
    t.num_allowed_exchanges,
    t.num_blocked_countries,
    t.num_allowed_countries,
    t.num_blocked_device_types,
    t.num_allowed_device_types

  FROM missing_opportunity_spend mo
  LEFT JOIN target_key_counts t USING (campaign_id)
  ORDER BY mo.total_market_spend DESC
),

-- =====================================================================
-- 1️⃣1️⃣ target_accessible_supply_score
-- =====================================================================
target_accessible_supply_score AS (
  SELECT
    campaign_id,
    'target_accessible_supply_score' AS blueprint_index,
    ROUND(accessible_ratio_targeting * 100, 2) AS score,

    ARRAY_TO_STRING(
      ARRAY(
        SELECT x FROM UNNEST([
          IF(num_blocked_apps > 0,         'num_blocked_apps: '         || CAST(num_blocked_apps AS STRING),         NULL),
          IF(num_allowed_apps > 0,         'num_allowed_apps: '         || CAST(num_allowed_apps AS STRING),         NULL),
          IF(num_blocked_exchanges > 0,    'num_blocked_exchanges: '    || CAST(num_blocked_exchanges AS STRING),    NULL),
          IF(num_allowed_exchanges > 0,    'num_allowed_exchanges: '    || CAST(num_allowed_exchanges AS STRING),    NULL),
          IF(num_blocked_countries > 0,    'num_blocked_countries: '    || CAST(num_blocked_countries AS STRING),    NULL),
          IF(num_allowed_countries > 0,    'num_allowed_countries: '    || CAST(num_allowed_countries AS STRING),    NULL),
          IF(num_blocked_device_types > 0, 'num_blocked_device_types: ' || CAST(num_blocked_device_types AS STRING), NULL),
          IF(num_allowed_device_types > 0, 'num_allowed_device_types: ' || CAST(num_allowed_device_types AS STRING), NULL)
        ]) AS x
        WHERE x IS NOT NULL
      ),
      ', '
    ) AS detail,

    CONCAT(
      IF(
        num_blocked_apps > 0 OR num_allowed_apps > 0 OR
        num_blocked_exchanges > 0 OR num_allowed_exchanges > 0 OR
        num_blocked_countries > 0 OR num_allowed_countries > 0,
        "Check: ",
        NULL
      ),
      ARRAY_TO_STRING(
        ARRAY(
          SELECT x FROM UNNEST([
            IF(num_blocked_apps > 0      OR num_allowed_apps > 0,      'publisher block/allowlist', NULL),
            IF(num_blocked_exchanges > 0 OR num_allowed_exchanges > 0, 'exchange block/allowlist',  NULL),
            IF(num_blocked_countries > 0 OR num_allowed_countries > 0, 'country block/allowlist',   NULL)
          ]) AS x
          WHERE x IS NOT NULL
        ),
        ', '
      ),
      IF(
        num_blocked_apps > 0 OR num_allowed_apps > 0 OR
        num_blocked_exchanges > 0 OR num_allowed_exchanges > 0 OR
        num_blocked_countries > 0 OR num_allowed_countries > 0,
        '; Remove them if possible',
        NULL
      )
    ) AS recommendation

  FROM summary
),

-- =====================================================================
-- 1️⃣2️⃣ traffic_accessible_supply_score
-- =====================================================================
traffic_accessible_supply_score AS (
  SELECT
    campaign_id,
    'traffic_accessible_supply_score' AS blueprint_index,
    ROUND(accessible_ratio_tracking * 100, 2) AS score,
    IF(ad_tracking_allowance <> 'DO_NOT_CARE', ad_tracking_allowance, NULL) AS detail,
    CASE 
      WHEN os = 'ANDROID' AND ad_tracking_allowance='NON_LAT_ONLY'
        THEN 'Consider utlizing LAT traffic in case of CPI optimization.'
      WHEN os = 'ANDROID' AND ad_tracking_allowance='LAT_ONLY'
        THEN 'Utilize both NON-LAT and LAT traffic.'
      WHEN os = 'IOS' AND ad_tracking_allowance='NON_LAT_ONLY'
        THEN 'Utilize LAT traffic in iOS.'
      WHEN os = 'IOS' AND ad_tracking_allowance='LAT_ONLY'
        THEN 'Utilize both NON-LAT and LAT traffic.'
      ELSE NULL
    END AS recommendation
  FROM summary
),

-- =====================================================================
-- 1️⃣3️⃣ Merge scores & compute overall index
-- =====================================================================
merged AS (
  SELECT * FROM target_accessible_supply_score
  UNION ALL
  SELECT * FROM traffic_accessible_supply_score
),

overall_index AS (
  SELECT
    *,
    ROUND(AVG(score) OVER (PARTITION BY campaign_id), 2) AS overall_optimization_score
  FROM merged
)

SELECT *
FROM overall_index;
