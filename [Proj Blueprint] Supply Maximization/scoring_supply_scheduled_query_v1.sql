-- =====================================================================
-- Accessible Supply Scores at a campaign Level (considering targeting and traffic allowance)
-- =====================================================================

-- =====================================================================
-- AS-1. Get active campaigns with spend
-- =====================================================================
WITH campaigns_with_spend AS (
  SELECT 
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    AND campaign.os IN ('IOS','ANDROID')
  GROUP BY 1
  HAVING total_spend > 0
),

-- =====================================================================
-- AS-2. Campaign metadata (with target_countries array)
-- =====================================================================
campaign_tab AS (
  SELECT
    a.campaign_name   AS campaign_id,
    a.advertiser_name AS advertiser_id,
    a.os,
    ARRAY_AGG(DISTINCT cs.country) AS target_countries
  FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
  CROSS JOIN UNNEST(a.country_settings) cs
  WHERE TRUE
  -- state = "ACTIVE"
  --   AND enabled
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
-- AS-3. Extract raw targeting JSON
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
-- AS-4. Precompute TARGETING MASKS ("allowed_*", "blocked_*")
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

-- AS-4.5 Build compact targeting masks per campaign
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
-- AS-5. LAT policy + target_countries from campaign_digest
-- =====================================================================
campaign_digest AS (
  SELECT
    c.campaign_id,
    c.os,
    c.target_countries,
    d.campaign_country,
    d.campaign_os,
    CASE
      WHEN JSON_EXTRACT(d.original_json, "$.ad_tracking_allowance") = '"DO_NOT_CARE"'
        THEN 'DO_NOT_CARE'
      WHEN JSON_EXTRACT(d.original_json, "$.ad_tracking_allowance")
           IN ('"NON_LAT_ONLY"', '"AD_TRACKING_ALLOWANCE_NON_LAT_ONLY"')
        THEN 'NON_LAT_ONLY'
      WHEN JSON_EXTRACT(d.original_json, "$.ad_tracking_allowance") = '"LAT_ONLY"'
        THEN 'LAT_ONLY'
      ELSE 'DO_NOT_CARE'
    END AS ad_tracking_allowance
  FROM campaign_tab c
  JOIN `focal-elf-631.standard_digest.campaign_digest` d
    ON c.campaign_id = d.campaign_id
   AND c.os          = d.campaign_os
),

-- Split campaigns into with vs without targeting (for cheaper path)
campaign_with_target AS (
  SELECT DISTINCT campaign_id, os, target_countries, ad_tracking_allowance
  FROM campaign_digest
  WHERE campaign_id IN (SELECT campaign_id FROM target_masks)
),
campaign_without_target AS (
  SELECT DISTINCT campaign_id, os, target_countries, ad_tracking_allowance
  FROM campaign_digest
  WHERE campaign_id NOT IN (SELECT campaign_id FROM target_masks)
),


-- =====================================================================
-- AS-6. Aggregate bidrequest once per (country, os, is_lat, app, exchange, device_type)
-- =====================================================================
bid_dim AS (
  SELECT
    UPPER(b.country) AS country,
    UPPER(b.os) AS os,
    -- same logic as now
    (CASE
       WHEN IF(id_type IS NULL,
               REGEXP_CONTAINS(idfa, r'^[a-f0-9]8-[a-f0-9]4-4[a-f0-9]3-8000-000000000000$'),
               id_type IN (5,6)
             )
       THEN 'Yes' ELSE 'No'
     END) AS is_lat,
    b.app_bundle,
    b.exchange,
    b.dev_type AS device_type,
    COUNT(*) AS total_bids
  FROM `focal-elf-631.prod.bidrequest20*` b
  JOIN campaign_country_os cco
    ON UPPER(b.country) = cco.country
   AND UPPER(b.os)      = cco.os
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY))
                          AND FORMAT_DATE('%y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY country, os, is_lat, app_bundle, exchange, device_type
),



-- =====================================================================
-- AS-7. Eligible bid requests aggregation for campaigns with targeting
-- =====================================================================
campaign_bids_with_target AS (
  SELECT
    cl.campaign_id,

    SUM(bd.total_bids) AS total_bids,

    SUM(
      CASE
        WHEN cl.ad_tracking_allowance = 'NON_LAT_ONLY' THEN IF(bd.is_lat = 'No', bd.total_bids, 0)
        WHEN cl.ad_tracking_allowance = 'LAT_ONLY'     THEN IF(bd.is_lat = 'Yes', bd.total_bids, 0)
        ELSE bd.total_bids
      END
    ) AS tracking_eligible_bids,

    SUM(
      CASE
        WHEN
          IF(tm.allowed_apps IS NULL OR ARRAY_LENGTH(tm.allowed_apps) = 0,
             TRUE,
             bd.app_bundle IN UNNEST(tm.allowed_apps)
          )
          AND IF(tm.blocked_apps IS NULL,
                 TRUE,
                 bd.app_bundle NOT IN UNNEST(tm.blocked_apps)
          )
          AND IF(tm.allowed_exchanges IS NULL OR ARRAY_LENGTH(tm.allowed_exchanges) = 0,
                 TRUE,
                 bd.exchange IN UNNEST(tm.allowed_exchanges)
          )
          AND IF(tm.blocked_exchanges IS NULL,
                 TRUE,
                 bd.exchange NOT IN UNNEST(tm.blocked_exchanges)
          )
          AND IF(tm.allowed_countries IS NULL OR ARRAY_LENGTH(tm.allowed_countries) = 0,
                 TRUE,
                 bd.country IN UNNEST(tm.allowed_countries)
          )
          AND IF(tm.blocked_countries IS NULL,
                 TRUE,
                 bd.country NOT IN UNNEST(tm.blocked_countries)
          )
          AND IF(tm.allowed_device_types IS NULL OR ARRAY_LENGTH(tm.allowed_device_types) = 0,
                 TRUE,
                 bd.device_type IN UNNEST(tm.allowed_device_types)
          )
          AND IF(tm.blocked_device_types IS NULL,
                 TRUE,
                 bd.device_type NOT IN UNNEST(tm.blocked_device_types)
          )
        THEN bd.total_bids
        ELSE 0
      END
    ) AS tgt_eligible_bids,

    SUM(
      CASE
        WHEN
          (
            cl.ad_tracking_allowance = 'DO_NOT_CARE'
            OR (cl.ad_tracking_allowance='NON_LAT_ONLY' AND bd.is_lat = 'No')
            OR (cl.ad_tracking_allowance='LAT_ONLY'     AND bd.is_lat = 'Yes')
          )
          AND IF(tm.allowed_apps IS NULL OR ARRAY_LENGTH(tm.allowed_apps) = 0,
                TRUE,
                bd.app_bundle IN UNNEST(tm.allowed_apps)
          )
          AND IF(tm.blocked_apps IS NULL,
                TRUE,
                bd.app_bundle NOT IN UNNEST(tm.blocked_apps)
          )
          AND IF(tm.allowed_exchanges IS NULL OR ARRAY_LENGTH(tm.allowed_exchanges) = 0,
                TRUE,
                bd.exchange IN UNNEST(tm.allowed_exchanges)
          )
          AND IF(tm.blocked_exchanges IS NULL,
                TRUE,
                bd.exchange NOT IN UNNEST(tm.blocked_exchanges)
          )
          AND IF(tm.allowed_countries IS NULL OR ARRAY_LENGTH(tm.allowed_countries) = 0,
                TRUE,
                bd.country IN UNNEST(tm.allowed_countries)
          )
          AND IF(tm.blocked_countries IS NULL,
                TRUE,
                bd.country NOT IN UNNEST(tm.blocked_countries)
          )
          AND IF(tm.allowed_device_types IS NULL OR ARRAY_LENGTH(tm.allowed_device_types) = 0,
                TRUE,
                bd.device_type IN UNNEST(tm.allowed_device_types)
          )
          AND IF(tm.blocked_device_types IS NULL,
                TRUE,
                bd.device_type NOT IN UNNEST(tm.blocked_device_types)
          )
        THEN bd.total_bids
        ELSE 0
      END
    ) AS accessible_bids

  FROM campaign_with_target cl
  JOIN target_masks tm USING (campaign_id)
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN bid_dim bd
    ON bd.country = UPPER(tc) 
    AND bd.os = UPPER(cl.os)
  GROUP BY cl.campaign_id
),

-- =====================================================================
-- AS-8. Eligible bid requests aggregation for campaigns WITHOUT targeting
-- =====================================================================
campaign_bids_without_target AS (
  SELECT
    cl.campaign_id,

    SUM(bd.total_bids) AS total_bids,

    SUM(
      CASE
        WHEN cl.ad_tracking_allowance = 'NON_LAT_ONLY' THEN IF(bd.is_lat = 'No', bd.total_bids, 0)
        WHEN cl.ad_tracking_allowance = 'LAT_ONLY'     THEN IF(bd.is_lat = 'Yes', bd.total_bids, 0)
        ELSE bd.total_bids
      END
    ) AS tracking_eligible_bids,

    -- no targeting → all bids are target-eligible
    SUM(bd.total_bids) AS tgt_eligible_bids,

    -- accessible = tracking
    SUM(
      CASE
        WHEN cl.ad_tracking_allowance = 'NON_LAT_ONLY' THEN IF(bd.is_lat = 'No', bd.total_bids, 0)
        WHEN cl.ad_tracking_allowance = 'LAT_ONLY'     THEN IF(bd.is_lat = 'Yes', bd.total_bids, 0)
        ELSE bd.total_bids
      END
    ) AS accessible_bids

  FROM campaign_without_target cl
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN bid_dim bd
    ON bd.country = tc AND bd.os = cl.os
  GROUP BY cl.campaign_id
),


-- =====================================================================
-- AS-9. Final bid aggregation: union of both paths
-- =====================================================================
bid_agg AS (
  SELECT * FROM campaign_bids_with_target
  UNION ALL
  SELECT * FROM campaign_bids_without_target
),




-- =====================================================================
-- AS-10. Aggregate market level spend by country/os/traffic/publisher 
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
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  GROUP BY country, os, is_lat, app_bundle, exchange
),

-- =====================================================================
-- AS-11. Join campaigns × market buckets, apply masks efficiently
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
-- AS-12.   (B) campaigns WITHOUT targeting: much cheaper (no app/exchange checks)
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
-- AS-13. Compute ratios (base) -> spend-based accessible supply
-- =====================================================================
spend_agg AS (
  SELECT
    campaign_id,
    os,
    target_countries,
    ad_tracking_allowance,
    total_market_spend,
    tracking_eligible_spend,
    tgt_eligible_spend,
    accessible_spend,

    SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) AS  spend_accessible_ratio_tracking,
    SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend) AS spend_accessible_ratio_targeting,
    SAFE_DIVIDE(accessible_spend,         total_market_spend) AS spend_accessible_ratio_total,

  FROM campaign_market
),

-- =====================================================================
-- AS-14. Summary table in wide form (with both spend and bid request-level columns)
-- =====================================================================
summary AS (
  SELECT
    s.campaign_id,
    s.os,
    s.target_countries,
    s.ad_tracking_allowance,

    s.total_market_spend,
    s.tracking_eligible_spend,
    s.tgt_eligible_spend,
    s.accessible_spend,

    s.spend_accessible_ratio_tracking,
    s.spend_accessible_ratio_targeting,
    s.spend_accessible_ratio_total,

    t.num_blocked_apps,
    t.num_allowed_apps,
    t.num_blocked_exchanges,
    t.num_allowed_exchanges,
    t.num_blocked_countries,
    t.num_allowed_countries,
    t.num_blocked_device_types,
    t.num_allowed_device_types,

    b.total_bids,
    b.tracking_eligible_bids,
    b.tgt_eligible_bids,
    b.accessible_bids,

    SAFE_DIVIDE(b.tracking_eligible_bids, b.total_bids) AS bid_accessible_ratio_tracking,
    SAFE_DIVIDE(b.tgt_eligible_bids,      b.total_bids) AS bid_accessible_ratio_targeting,
    SAFE_DIVIDE(b.accessible_bids,        b.total_bids) AS bid_accessible_ratio_total

  FROM spend_agg s
  LEFT JOIN target_key_counts t USING (campaign_id)
  LEFT JOIN bid_agg          b USING (campaign_id)
  ORDER BY s.total_market_spend DESC
),

-- =====================================================================
-- AS-15. target_accessible_supply_score (Spend-based)
-- =====================================================================
target_accessible_supply_score AS (
  SELECT
    campaign_id,
    'target_accessible_supply_score' AS blueprint_index,
    ROUND(spend_accessible_ratio_targeting * 100, 2) AS score,
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
    ) AS recommendations

  FROM summary
),

-- =====================================================================
-- AS-16. traffic_accessible_supply_score (Spend-based)
-- =====================================================================
traffic_accessible_supply_score AS (
  SELECT
    campaign_id,
    'traffic_accessible_supply_score' AS blueprint_index,
    ROUND(spend_accessible_ratio_tracking * 100, 2) AS score,
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
    END AS recommendations
  FROM summary
),

-- =====================================================================
-- AS-17. target_accessible_supply_bidreq_score (BidRequest-based)
-- =====================================================================
target_accessible_supply_bids_score AS (
  SELECT
    campaign_id,
    'target_accessible_supply_bidreq_score' AS blueprint_index,
    ROUND(bid_accessible_ratio_targeting * 100, 2) AS score,
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
    ) AS recommendations
  FROM summary
),

-- =====================================================================
-- AS-18. traffic_accessible_supply_bidreq_score (BidRequest-based)
-- =====================================================================
traffic_accessible_supply_bids_score AS (
  SELECT
    campaign_id,
    'traffic_accessible_supply_bidreq_score' AS blueprint_index,
    ROUND(bid_accessible_ratio_tracking * 100, 2) AS score,
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
    END AS recommendations
  FROM summary
),

-- =====================================================================
-- OS Coverage Score at an advertiser level
-- =====================================================================
-- =====================================================================
-- OS-1. Get active advertisers with spend
-- =====================================================================
advertisers_with_spend AS (
  SELECT 
    advertiser_id,
    campaign.country,
    SUM(gross_spend_usd) AS total_spend,
    SUM(IF(campaign.os = 'IOS', gross_spend_usd, NULL)) AS ios_spend,
    SUM(IF(campaign.os = 'ANDROID', gross_spend_usd, NULL)) AS android_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
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
-- OS-2. Get market benchmark 
-- =====================================================================
market_dim_os AS (
  SELECT
    campaign.country      AS country,
    SUM(gross_spend_usd)  AS total_market_spend,
    SUM(IF(campaign.os = 'IOS',     gross_spend_usd, NULL)) AS ios_market_spend,
    SUM(IF(campaign.os = 'ANDROID', gross_spend_usd, NULL)) AS android_market_spend,
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  GROUP BY 1
),

market_dim_os_ratio AS (
  SELECT
    country,
    total_market_spend,
    ios_market_spend,
    android_market_spend,
    ROUND(COALESCE(SAFE_DIVIDE(ios_market_spend,     total_market_spend),0),2) AS market_ios_spend_ratio,
    ROUND(COALESCE(SAFE_DIVIDE(android_market_spend, total_market_spend),0),2) AS market_android_spend_ratio
  FROM market_dim_os
),


-- =====================================================================
-- OS-3. Calculate country score
-- =====================================================================

os_scoring_country AS(
  SELECT
    ar.advertiser_id,
    ar.country,
    ar.total_spend      AS advertiser_total_spend,
    SAFE_DIVIDE(ar.total_spend, SUM(total_spend) OVER (PARTITION BY ar.advertiser_id)) AS country_spend_ratio,
    ar.ios_spend_ratio    AS advertiser_ios_spend_ratio,
    ar.android_spend_ratio  AS advertiser_android_spend_ratio,
    mr.market_ios_spend_ratio,
    mr.market_android_spend_ratio,
    ROUND(100 * (1 - 1/2 * (ABS(ar.ios_spend_ratio-mr.market_ios_spend_ratio)+ABS(ar.android_spend_ratio-mr.market_android_spend_ratio))),2) AS country_score
  FROM advertisers_os_ratio ar 
  LEFT JOIN market_dim_os_ratio  mr
    ON ar.country = mr.country
),


os_scoring_agg AS (
  SELECT
    advertiser_id,
    ROUND(SUM(country_spend_ratio * country_score),2) AS os_coverage_score,
    STRING_AGG(
      FORMAT(
        "%s (spend: $%.0f): market android:ios = %.1f:%.1f, advertiser android:ios = %.1f:%.1f",
        country,
        advertiser_total_spend,
        market_android_spend_ratio,
        market_ios_spend_ratio,
        advertiser_android_spend_ratio,
        advertiser_ios_spend_ratio
      ),' ; '  -- separator between countries
    ORDER BY advertiser_total_spend DESC
  ) AS description,

    CONCAT(
      STRING_AGG(
        IF(
          country_score < 80
          AND (advertiser_ios_spend_ratio = 0 OR advertiser_android_spend_ratio = 0),
          -- Build the text depending on which OS is 0
          CASE
            WHEN advertiser_ios_spend_ratio = 0
              THEN FORMAT(
                "%s: no iOS spend, while iOS accounts for %.1f%% of the market",
                country,
                100 * market_ios_spend_ratio
              )
            WHEN advertiser_android_spend_ratio = 0
              THEN FORMAT(
                "%s: no Android spend, while Android accounts for %.1f%% of the market",
                country,
                100 * market_android_spend_ratio
              )
          END,
          NULL
        ),
        ' ; '
      ),
      "please review these countires for potential OS expansion opportunities."
    )  AS recommendations


  FROM os_scoring_country
  GROUP BY 1
),

-- drop advertiser_id
os_scoring_agg_camp AS (
  SELECT 
    -- advertiser_id,
    campaign_id,
    'os_coverage_supply_score' AS blueprint_index,
    os_coverage_score AS score,
    description,
    recommendations
  FROM campaign_tab 
  LEFT JOIN os_scoring_agg USING(advertiser_id)
),


-- =====================================================================
-- Merge Scores
-- =====================================================================
-- =====================================================================
-- M-1. Merge scores & compute overall index
-- =====================================================================
merged AS (
  SELECT * FROM target_accessible_supply_score
  UNION ALL SELECT * FROM traffic_accessible_supply_score
  UNION ALL SELECT * FROM target_accessible_supply_bids_score
  UNION ALL SELECT * FROM traffic_accessible_supply_bids_score
  UNION ALL SELECT * FROM os_scoring_agg_camp
),

overall_index AS (
  SELECT
    *,
    -- ✅ spend-based overall = (target_score * traffic_score) / 100
    ROUND(
      (
        MAX(
          CASE
            WHEN blueprint_index = 'target_accessible_supply_score'
            THEN score
          END
        ) OVER (PARTITION BY campaign_id)
        *
        MAX(
          CASE
            WHEN blueprint_index = 'traffic_accessible_supply_score'
            THEN score
          END
        ) OVER (PARTITION BY campaign_id)
      ) / 100.0,
      2
    ) AS overall_campaign_score,

    -- ✅ bids-based overall = (target_bids_score * traffic_bids_score) / 100
    ROUND(
      (
        MAX(
          CASE
            WHEN blueprint_index = 'target_accessible_supply_bidreq_score'
            THEN score
          END
        ) OVER (PARTITION BY campaign_id)
        *
        MAX(
          CASE
            WHEN blueprint_index = 'traffic_accessible_supply_bidreq_score'
            THEN score
          END
        ) OVER (PARTITION BY campaign_id)
      ) / 100.0,
      2
    ) AS overall_campaign_bidreq_score
  FROM merged
)

SELECT *
FROM overall_index