-- =====================================================================
-- Accessible Supply Scores at campaign level (optimized for global run)
-- Portable version:
-- - Works for ad-hoc/manual runs (no @run_time dependency)
-- - Also works in scheduled queries
-- =====================================================================

WITH params AS (
  SELECT
    DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AS spend_date_start,
    DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS spend_date_end
),

campaigns_with_spend AS (
  SELECT
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN
    (SELECT spend_date_start FROM params)
    AND (SELECT spend_date_end FROM params)
    AND campaign.os IN ('IOS', 'ANDROID')
  GROUP BY 1
  HAVING total_spend > 0
),

campaign_tab AS (
  SELECT
    a.campaign_name AS campaign_id,
    a.advertiser_name AS advertiser_id,
    UPPER(a.os) AS os,
    ARRAY_AGG(DISTINCT UPPER(cs.country)) AS target_countries
  FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
  CROSS JOIN UNNEST(a.country_settings) cs
  WHERE a.os IN ('IOS', 'ANDROID')
    AND EXISTS (
      SELECT 1
      FROM campaigns_with_spend s
      WHERE s.campaign_id = a.campaign_name
    )
  GROUP BY campaign_id, advertiser_id, os
),

adgroup_raw AS (
  SELECT
    ad_group_id,
    campaign_id,
    target_id
  FROM `ads-bpd-guard-china.standard_digest.ad_group_digest`,
    UNNEST(JSON_VALUE_ARRAY(original_json, "$.user_targets")) AS target_id
  WHERE NOT is_archived
    AND JSON_EXTRACT_SCALAR(original_json, "$.disabled") = 'false'
    AND EXISTS (
      SELECT 1
      FROM campaigns_with_spend s
      WHERE s.campaign_id = campaign_id
    )
),

distinct_target_ids AS (
  SELECT DISTINCT target_id
  FROM adgroup_raw
),

target_raw AS (
  SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json
  FROM `focal-elf-631.standard_digest.audience_target_digest`
  WHERE EXISTS (
    SELECT 1
    FROM distinct_target_ids d
    WHERE d.target_id = id
  )
),

target_masks_raw AS (
  SELECT
    ar.campaign_id,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.allowed_apps'), ARRAY<STRING>[])) AS allowed_apps_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.blocked_apps'), ARRAY<STRING>[])) AS blocked_apps_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.allowed_exchanges'), ARRAY<STRING>[])) AS allowed_exchanges_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.blocked_exchanges'), ARRAY<STRING>[])) AS blocked_exchanges_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.allowed_countries'), ARRAY<STRING>[])) AS allowed_countries_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.blocked_countries'), ARRAY<STRING>[])) AS blocked_countries_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.allowed_device_types'), ARRAY<STRING>[])) AS allowed_device_types_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.blocked_device_types'), ARRAY<STRING>[])) AS blocked_device_types_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.allowed_categories'), ARRAY<STRING>[])) AS allowed_categories_all,
    ARRAY_CONCAT_AGG(IFNULL(JSON_VALUE_ARRAY(t.condition_json, '$.blocked_categories'), ARRAY<STRING>[])) AS blocked_categories_all
  FROM adgroup_raw ar
  JOIN target_raw t USING (target_id)
  GROUP BY 1
),

target_masks AS (
  SELECT
    campaign_id,
    ARRAY(SELECT DISTINCT app FROM UNNEST(allowed_apps_all) AS app) AS allowed_apps,
    ARRAY(SELECT DISTINCT app FROM UNNEST(blocked_apps_all) AS app) AS blocked_apps,
    ARRAY(SELECT DISTINCT ex FROM UNNEST(allowed_exchanges_all) AS ex) AS allowed_exchanges,
    ARRAY(SELECT DISTINCT ex FROM UNNEST(blocked_exchanges_all) AS ex) AS blocked_exchanges,
    ARRAY(SELECT DISTINCT UPPER(ctry) FROM UNNEST(allowed_countries_all) AS ctry) AS allowed_countries,
    ARRAY(SELECT DISTINCT UPPER(ctry) FROM UNNEST(blocked_countries_all) AS ctry) AS blocked_countries,
    ARRAY(SELECT DISTINCT dt FROM UNNEST(allowed_device_types_all) AS dt) AS allowed_device_types,
    ARRAY(SELECT DISTINCT dt FROM UNNEST(blocked_device_types_all) AS dt) AS blocked_device_types,
    ARRAY(SELECT DISTINCT UPPER(cat) FROM UNNEST(allowed_categories_all) AS cat) AS allowed_categories,
    ARRAY(SELECT DISTINCT UPPER(cat) FROM UNNEST(blocked_categories_all) AS cat) AS blocked_categories
  FROM target_masks_raw
),

target_key_counts AS (
  SELECT
    campaign_id,
    ARRAY_LENGTH(blocked_apps) AS num_blocked_apps,
    ARRAY_LENGTH(allowed_apps) AS num_allowed_apps,
    ARRAY_LENGTH(blocked_exchanges) AS num_blocked_exchanges,
    ARRAY_LENGTH(allowed_exchanges) AS num_allowed_exchanges,
    ARRAY_LENGTH(blocked_countries) AS num_blocked_countries,
    ARRAY_LENGTH(allowed_countries) AS num_allowed_countries,
    ARRAY_LENGTH(blocked_device_types) AS num_blocked_device_types,
    ARRAY_LENGTH(allowed_device_types) AS num_allowed_device_types,
    ARRAY_LENGTH(blocked_categories) AS num_blocked_categories,
    ARRAY_LENGTH(allowed_categories) AS num_allowed_categories
  FROM target_masks
),

campaign_digest AS (
  SELECT
    c.campaign_id,
    c.advertiser_id,
    c.os,
    c.target_countries,
    CASE
      WHEN JSON_EXTRACT(d.original_json, "$.ad_tracking_allowance") = '"DO_NOT_CARE"' THEN 'DO_NOT_CARE'
      WHEN JSON_EXTRACT(d.original_json, "$.ad_tracking_allowance")
        IN ('"NON_LAT_ONLY"', '"AD_TRACKING_ALLOWANCE_NON_LAT_ONLY"') THEN 'NON_LAT_ONLY'
      WHEN JSON_EXTRACT(d.original_json, "$.ad_tracking_allowance") = '"LAT_ONLY"' THEN 'LAT_ONLY'
      ELSE 'DO_NOT_CARE'
    END AS ad_tracking_allowance
  FROM campaign_tab c
  JOIN `focal-elf-631.standard_digest.campaign_digest` d
    ON c.campaign_id = d.campaign_id
   AND c.os = UPPER(d.campaign_os)
),

campaign_target_profile AS (
  SELECT
    cd.campaign_id,
    cd.advertiser_id,
    cd.os,
    cd.target_countries,
    cd.ad_tracking_allowance,
    tm.allowed_apps,
    tm.blocked_apps,
    tm.allowed_exchanges,
    tm.blocked_exchanges,
    tm.allowed_countries,
    tm.blocked_countries,
    tm.allowed_device_types,
    tm.blocked_device_types,
    tm.allowed_categories,
    tm.blocked_categories,
    (
      COALESCE(ARRAY_LENGTH(tm.allowed_apps), 0) +
      COALESCE(ARRAY_LENGTH(tm.blocked_apps), 0) +
      COALESCE(ARRAY_LENGTH(tm.allowed_exchanges), 0) +
      COALESCE(ARRAY_LENGTH(tm.blocked_exchanges), 0) +
      COALESCE(ARRAY_LENGTH(tm.allowed_countries), 0) +
      COALESCE(ARRAY_LENGTH(tm.blocked_countries), 0) +
      COALESCE(ARRAY_LENGTH(tm.allowed_device_types), 0) +
      COALESCE(ARRAY_LENGTH(tm.blocked_device_types), 0) +
      COALESCE(ARRAY_LENGTH(tm.allowed_categories), 0) +
      COALESCE(ARRAY_LENGTH(tm.blocked_categories), 0)
    ) > 0 AS has_effective_targeting
  FROM campaign_digest cd
  LEFT JOIN target_masks tm USING (campaign_id)
),

campaign_with_target AS (
  SELECT * FROM campaign_target_profile
  WHERE has_effective_targeting
),

campaign_without_target AS (
  SELECT * FROM campaign_target_profile
  WHERE NOT has_effective_targeting
),

campaign_country_os_target AS (
  SELECT DISTINCT UPPER(tc) AS country, os
  FROM campaign_with_target
  CROSS JOIN UNNEST(target_countries) AS tc
),

campaign_country_os_no_target AS (
  SELECT DISTINCT UPPER(tc) AS country, os
  FROM campaign_without_target
  CROSS JOIN UNNEST(target_countries) AS tc
),

apt_categories AS (
  SELECT
    app_bundle,
    ARRAY(SELECT DISTINCT UPPER(cat) FROM UNNEST(app_categories) AS cat) AS pub_categories
  FROM `focal-elf-631.df_app_profile.lifetime_app_latest`
  WHERE app_categories IS NOT NULL
    AND ARRAY_LENGTH(app_categories) > 0
),

bid_dim_targeted AS (
  SELECT
    UPPER(b.country) AS country,
    UPPER(b.os) AS os,
    CASE
      WHEN IF(
        id_type IS NULL,
        REGEXP_CONTAINS(idfa, r'^[a-f0-9]8-[a-f0-9]4-4[a-f0-9]3-8000-000000000000$'),
        id_type IN (5, 6)
      ) THEN 'Yes'
      ELSE 'No'
    END AS is_lat,
    b.app_bundle,
    b.exchange,
    b.dev_type AS device_type,
    COUNT(*) AS total_bids
  FROM `focal-elf-631.prod.bidrequest20*` b
  JOIN campaign_country_os_target cco
    ON UPPER(b.country) = cco.country
   AND UPPER(b.os) = cco.os
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%y%m%d', (SELECT spend_date_start FROM params))
                          AND FORMAT_DATE('%y%m%d', (SELECT spend_date_end FROM params))
  GROUP BY country, os, is_lat, app_bundle, exchange, device_type
),

bid_dim_light AS (
  SELECT
    UPPER(b.country) AS country,
    UPPER(b.os) AS os,
    CASE
      WHEN IF(
        id_type IS NULL,
        REGEXP_CONTAINS(idfa, r'^[a-f0-9]8-[a-f0-9]4-4[a-f0-9]3-8000-000000000000$'),
        id_type IN (5, 6)
      ) THEN 'Yes'
      ELSE 'No'
    END AS is_lat,
    COUNT(*) AS total_bids
  FROM `focal-elf-631.prod.bidrequest20*` b
  JOIN campaign_country_os_no_target cco
    ON UPPER(b.country) = cco.country
   AND UPPER(b.os) = cco.os
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%y%m%d', (SELECT spend_date_start FROM params))
                          AND FORMAT_DATE('%y%m%d', (SELECT spend_date_end FROM params))
  GROUP BY country, os, is_lat
),

campaign_rows_with_target AS (
  SELECT
    cl.campaign_id,
    cl.ad_tracking_allowance,
    bd.total_bids,
    bd.is_lat,
    bd.country,
    bd.app_bundle,
    bd.exchange,
    bd.device_type,
    cl.allowed_apps,
    cl.blocked_apps,
    cl.allowed_exchanges,
    cl.blocked_exchanges,
    cl.allowed_countries,
    cl.blocked_countries,
    cl.allowed_device_types,
    cl.blocked_device_types,
    cl.allowed_categories,
    cl.blocked_categories,
    apt.pub_categories
  FROM campaign_with_target cl
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN bid_dim_targeted bd
    ON bd.country = UPPER(tc)
   AND bd.os = cl.os
  LEFT JOIN apt_categories apt
    ON bd.app_bundle = apt.app_bundle
),

campaign_rows_with_flags AS (
  SELECT
    campaign_id,
    total_bids,
    is_lat,
    ad_tracking_allowance,
    (
      IF(allowed_apps IS NULL OR ARRAY_LENGTH(allowed_apps) = 0, TRUE, app_bundle IN UNNEST(allowed_apps))
      AND IF(blocked_apps IS NULL OR ARRAY_LENGTH(blocked_apps) = 0, TRUE, app_bundle NOT IN UNNEST(blocked_apps))
      AND IF(allowed_exchanges IS NULL OR ARRAY_LENGTH(allowed_exchanges) = 0, TRUE, exchange IN UNNEST(allowed_exchanges))
      AND IF(blocked_exchanges IS NULL OR ARRAY_LENGTH(blocked_exchanges) = 0, TRUE, exchange NOT IN UNNEST(blocked_exchanges))
      AND IF(allowed_countries IS NULL OR ARRAY_LENGTH(allowed_countries) = 0, TRUE, country IN UNNEST(allowed_countries))
      AND IF(blocked_countries IS NULL OR ARRAY_LENGTH(blocked_countries) = 0, TRUE, country NOT IN UNNEST(blocked_countries))
      AND IF(allowed_device_types IS NULL OR ARRAY_LENGTH(allowed_device_types) = 0, TRUE, device_type IN UNNEST(allowed_device_types))
      AND IF(blocked_device_types IS NULL OR ARRAY_LENGTH(blocked_device_types) = 0, TRUE, device_type NOT IN UNNEST(blocked_device_types))
      AND IF(
        allowed_categories IS NULL OR ARRAY_LENGTH(allowed_categories) = 0,
        TRUE,
        pub_categories IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM UNNEST(pub_categories) AS pub_cat
          WHERE pub_cat IN UNNEST(allowed_categories)
        )
      )
      AND IF(
        blocked_categories IS NULL OR ARRAY_LENGTH(blocked_categories) = 0,
        TRUE,
        pub_categories IS NULL
        OR NOT EXISTS (
          SELECT 1
          FROM UNNEST(pub_categories) AS pub_cat
          WHERE pub_cat IN UNNEST(blocked_categories)
        )
      )
    ) AS targeting_pass,
    (
      ad_tracking_allowance = 'DO_NOT_CARE'
      OR (ad_tracking_allowance = 'NON_LAT_ONLY' AND is_lat = 'No')
      OR (ad_tracking_allowance = 'LAT_ONLY' AND is_lat = 'Yes')
    ) AS tracking_pass
  FROM campaign_rows_with_target
),

campaign_bids_with_target AS (
  SELECT
    campaign_id,
    SUM(total_bids) AS total_bids,
    SUM(IF(tracking_pass, total_bids, 0)) AS tracking_eligible_bids,
    SUM(IF(targeting_pass, total_bids, 0)) AS tgt_eligible_bids,
    SUM(IF(tracking_pass AND targeting_pass, total_bids, 0)) AS accessible_bids
  FROM campaign_rows_with_flags
  GROUP BY campaign_id
),

campaign_bids_without_target AS (
  SELECT
    cl.campaign_id,
    SUM(bd.total_bids) AS total_bids,
    SUM(
      CASE
        WHEN cl.ad_tracking_allowance = 'NON_LAT_ONLY' THEN IF(bd.is_lat = 'No', bd.total_bids, 0)
        WHEN cl.ad_tracking_allowance = 'LAT_ONLY' THEN IF(bd.is_lat = 'Yes', bd.total_bids, 0)
        ELSE bd.total_bids
      END
    ) AS tracking_eligible_bids,
    SUM(bd.total_bids) AS tgt_eligible_bids,
    SUM(
      CASE
        WHEN cl.ad_tracking_allowance = 'NON_LAT_ONLY' THEN IF(bd.is_lat = 'No', bd.total_bids, 0)
        WHEN cl.ad_tracking_allowance = 'LAT_ONLY' THEN IF(bd.is_lat = 'Yes', bd.total_bids, 0)
        ELSE bd.total_bids
      END
    ) AS accessible_bids
  FROM campaign_without_target cl
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN bid_dim_light bd
    ON bd.country = UPPER(tc)
   AND bd.os = cl.os
  GROUP BY cl.campaign_id
),

bid_agg AS (
  SELECT * FROM campaign_bids_with_target
  UNION ALL
  SELECT * FROM campaign_bids_without_target
),

summary AS (
  SELECT
    s.campaign_id,
    cd.os,
    cd.target_countries,
    cd.ad_tracking_allowance,
    t.num_blocked_apps,
    t.num_allowed_apps,
    t.num_blocked_exchanges,
    t.num_allowed_exchanges,
    t.num_blocked_countries,
    t.num_allowed_countries,
    t.num_blocked_device_types,
    t.num_allowed_device_types,
    t.num_blocked_categories,
    t.num_allowed_categories,
    s.total_bids,
    s.tracking_eligible_bids,
    s.tgt_eligible_bids,
    s.accessible_bids,
    SAFE_DIVIDE(s.tracking_eligible_bids, s.total_bids) AS bid_accessible_ratio_tracking,
    SAFE_DIVIDE(s.tgt_eligible_bids, s.total_bids) AS bid_accessible_ratio_targeting,
    SAFE_DIVIDE(s.accessible_bids, s.total_bids) AS bid_accessible_ratio_total
  FROM bid_agg s
  LEFT JOIN target_key_counts t USING (campaign_id)
  LEFT JOIN (
    SELECT DISTINCT campaign_id, os, target_countries, ad_tracking_allowance
    FROM campaign_digest
  ) cd USING (campaign_id)
),

target_accessible_supply_bids_score AS (
  SELECT
    campaign_id,
    '1_target_accessible_supply_bidreq_score' AS blueprint_index,
    ROUND(bid_accessible_ratio_targeting * 100, 2) AS score,
    ARRAY_TO_STRING(
      ARRAY(
        SELECT x
        FROM UNNEST([
          IF(num_blocked_apps > 0, 'num_blocked_apps: ' || CAST(num_blocked_apps AS STRING), NULL),
          IF(num_allowed_apps > 0, 'num_allowed_apps: ' || CAST(num_allowed_apps AS STRING), NULL),
          IF(num_blocked_exchanges > 0, 'num_blocked_exchanges: ' || CAST(num_blocked_exchanges AS STRING), NULL),
          IF(num_allowed_exchanges > 0, 'num_allowed_exchanges: ' || CAST(num_allowed_exchanges AS STRING), NULL),
          IF(num_blocked_countries > 0, 'num_blocked_countries: ' || CAST(num_blocked_countries AS STRING), NULL),
          IF(num_allowed_countries > 0, 'num_allowed_countries: ' || CAST(num_allowed_countries AS STRING), NULL),
          IF(num_blocked_device_types > 0, 'num_blocked_device_types: ' || CAST(num_blocked_device_types AS STRING), NULL),
          IF(num_allowed_device_types > 0, 'num_allowed_device_types: ' || CAST(num_allowed_device_types AS STRING), NULL),
          IF(num_blocked_categories > 0, 'num_blocked_categories: ' || CAST(num_blocked_categories AS STRING), NULL),
          IF(num_allowed_categories > 0, 'num_allowed_categories: ' || CAST(num_allowed_categories AS STRING), NULL)
        ]) AS x
        WHERE x IS NOT NULL
      ),
      ', '
    ) AS detail,
    CONCAT(
      IF(
        num_blocked_apps > 0 OR num_allowed_apps > 0 OR
        num_blocked_exchanges > 0 OR num_allowed_exchanges > 0 OR
        num_blocked_countries > 0 OR num_allowed_countries > 0 OR
        num_blocked_categories > 0 OR num_allowed_categories > 0,
        "Check: ",
        NULL
      ),
      ARRAY_TO_STRING(
        ARRAY(
          SELECT x FROM UNNEST([
            IF(num_blocked_apps > 0 OR num_allowed_apps > 0, 'publisher block/allowlist', NULL),
            IF(num_blocked_exchanges > 0 OR num_allowed_exchanges > 0, 'exchange block/allowlist', NULL),
            IF(num_blocked_countries > 0 OR num_allowed_countries > 0, 'country block/allowlist', NULL),
            IF(num_blocked_categories > 0 OR num_allowed_categories > 0, 'category block/allowlist', NULL)
          ]) AS x
          WHERE x IS NOT NULL
        ),
        ', '
      ),
      IF(
        num_blocked_apps > 0 OR num_allowed_apps > 0 OR
        num_blocked_exchanges > 0 OR num_allowed_exchanges > 0 OR
        num_blocked_countries > 0 OR num_allowed_countries > 0 OR
        num_blocked_categories > 0 OR num_allowed_categories > 0,
        '; Remove them if possible',
        NULL
      )
    ) AS recommendation
  FROM summary
),

traffic_accessible_supply_bids_score AS (
  SELECT
    campaign_id,
    '2_traffic_accessible_supply_bidreq_score' AS blueprint_index,
    ROUND(bid_accessible_ratio_tracking * 100, 2) AS score,
    IF(ad_tracking_allowance <> 'DO_NOT_CARE', ad_tracking_allowance, NULL) AS detail,
    CASE
      WHEN os = 'ANDROID' AND ad_tracking_allowance = 'NON_LAT_ONLY'
        THEN 'Consider utlizing LAT traffic in case of CPI optimization.'
      WHEN os = 'ANDROID' AND ad_tracking_allowance = 'LAT_ONLY'
        THEN 'Utilize both NON-LAT and LAT traffic.'
      WHEN os = 'IOS' AND ad_tracking_allowance = 'NON_LAT_ONLY'
        THEN 'Utilize LAT traffic in iOS.'
      WHEN os = 'IOS' AND ad_tracking_allowance = 'LAT_ONLY'
        THEN 'Utilize both NON-LAT and LAT traffic.'
      ELSE NULL
    END AS recommendation
  FROM summary
),

advertisers_with_spend AS (
  SELECT
    advertiser_id,
    campaign.country,
    SUM(gross_spend_usd) AS total_spend,
    SUM(IF(campaign.os = 'IOS', gross_spend_usd, NULL)) AS ios_spend,
    SUM(IF(campaign.os = 'ANDROID', gross_spend_usd, NULL)) AS android_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN
    (SELECT spend_date_start FROM params)
    AND (SELECT spend_date_end FROM params)
    AND campaign.os IN ('IOS', 'ANDROID')
  GROUP BY 1, 2
  HAVING total_spend > 0
),

advertisers_os_ratio AS (
  SELECT
    advertiser_id,
    country,
    total_spend,
    ios_spend,
    android_spend,
    ROUND(COALESCE(SAFE_DIVIDE(ios_spend, total_spend), 0), 2) AS ios_spend_ratio,
    ROUND(COALESCE(SAFE_DIVIDE(android_spend, total_spend), 0), 2) AS android_spend_ratio
  FROM advertisers_with_spend
),

market_dim_os AS (
  SELECT
    campaign.country AS country,
    SUM(gross_spend_usd) AS total_market_spend,
    SUM(IF(campaign.os = 'IOS', gross_spend_usd, NULL)) AS ios_market_spend,
    SUM(IF(campaign.os = 'ANDROID', gross_spend_usd, NULL)) AS android_market_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN
    (SELECT spend_date_start FROM params)
    AND (SELECT spend_date_end FROM params)
  GROUP BY 1
),

market_dim_os_ratio AS (
  SELECT
    country,
    total_market_spend,
    ios_market_spend,
    android_market_spend,
    ROUND(COALESCE(SAFE_DIVIDE(ios_market_spend, total_market_spend), 0), 2) AS market_ios_spend_ratio,
    ROUND(COALESCE(SAFE_DIVIDE(android_market_spend, total_market_spend), 0), 2) AS market_android_spend_ratio
  FROM market_dim_os
),

os_scoring_country AS (
  SELECT
    ar.advertiser_id,
    ar.country,
    ar.total_spend AS advertiser_total_spend,
    SAFE_DIVIDE(ar.total_spend, SUM(total_spend) OVER (PARTITION BY ar.advertiser_id)) AS country_spend_ratio,
    ar.ios_spend_ratio AS advertiser_ios_spend_ratio,
    ar.android_spend_ratio AS advertiser_android_spend_ratio,
    mr.market_ios_spend_ratio,
    mr.market_android_spend_ratio,
    ROUND(
      100 * (
        1 - 1 / 2 * (
          ABS(ar.ios_spend_ratio - mr.market_ios_spend_ratio) +
          ABS(ar.android_spend_ratio - mr.market_android_spend_ratio)
        )
      ),
      2
    ) AS country_score
  FROM advertisers_os_ratio ar
  LEFT JOIN market_dim_os_ratio mr
    ON ar.country = mr.country
),

os_scoring_agg AS (
  SELECT
    advertiser_id,
    ROUND(SUM(country_spend_ratio * country_score), 2) AS os_coverage_score,
    STRING_AGG(
      FORMAT(
        "%s (spend: $%.0f): market android:ios = %.1f:%.1f, advertiser android:ios = %.1f:%.1f",
        country,
        advertiser_total_spend,
        market_android_spend_ratio,
        market_ios_spend_ratio,
        advertiser_android_spend_ratio,
        advertiser_ios_spend_ratio
      ),
      ' ; '
      ORDER BY advertiser_total_spend DESC
    ) AS description,
    CONCAT(
      STRING_AGG(
        IF(
          country_score < 80
          AND (advertiser_ios_spend_ratio = 0 OR advertiser_android_spend_ratio = 0),
          CASE
            WHEN advertiser_ios_spend_ratio = 0 THEN FORMAT(
              "%s: no iOS spend, while iOS accounts for %.1f%% of the market",
              country,
              100 * market_ios_spend_ratio
            )
            WHEN advertiser_android_spend_ratio = 0 THEN FORMAT(
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
    ) AS recommendation
  FROM os_scoring_country
  GROUP BY 1
),

os_scoring_agg_camp AS (
  SELECT
    campaign_id,
    '3_os_coverage_supply_score' AS blueprint_index,
    os_coverage_score AS score,
    description AS detail,
    recommendation
  FROM campaign_tab
  LEFT JOIN os_scoring_agg USING (advertiser_id)
),

merged AS (
  SELECT * FROM target_accessible_supply_bids_score
  UNION ALL
  SELECT * FROM traffic_accessible_supply_bids_score
  UNION ALL
  SELECT * FROM os_scoring_agg_camp
),

overall_index AS (
  SELECT
    *,
    ROUND(
      (
        MAX(
          CASE
            WHEN blueprint_index = '1_target_accessible_supply_bidreq_score' THEN score
          END
        ) OVER (PARTITION BY campaign_id)
        *
        MAX(
          CASE
            WHEN blueprint_index = '2_traffic_accessible_supply_bidreq_score' THEN score
          END
        ) OVER (PARTITION BY campaign_id)
      ) / 100.0,
      2
    ) AS overall_optimization_bidreq_score
  FROM merged
)

SELECT *
FROM overall_index;
