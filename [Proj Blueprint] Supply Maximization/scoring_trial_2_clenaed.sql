WITH
-- 1️⃣  Identify campaigns that actually spent during the period
campaigns_with_spend AS (
  SELECT
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    -- AND advertiser.office IN ('JPN')  -- optional office filter
  GROUP BY 1
  HAVING total_spend > 0
),


-- 2️⃣  Campaign metadata (active campaigns only), keep target_countries as ARRAY
campaign_tab AS (
  SELECT
    a.os,
    JSON_EXTRACT_SCALAR(campaign_goal, "$.type") AS campaign_goal,
    campaign_name AS campaign_id,
    campaign_display_name AS campaign,
    DATE(created_timestamp_nano) AS campaign_start_date,
    ARRAY_AGG(DISTINCT country_settings.country) AS target_countries
  FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
  CROSS JOIN UNNEST(a.country_settings) AS country_settings
  WHERE
    state = "ACTIVE"
    AND enabled
    AND a.os IN ('IOS','ANDROID')
    AND campaign_name IN (SELECT DISTINCT campaign_id FROM campaigns_with_spend)
  GROUP BY ALL
),

-- 3️⃣  Extract ad group → target mapping

adgroup_tab AS (
  SELECT
    ad_group_id,
    campaign_id,
    target_id
  FROM `ads-bpd-guard-china.standard_digest.ad_group_digest`
  CROSS JOIN UNNEST(JSON_VALUE_ARRAY(original_json, "$.user_targets")) AS target_id
  WHERE
    NOT is_archived
    AND JSON_EXTRACT_SCALAR(original_json, "$.disabled") = 'false'
    AND campaign_id IN (SELECT DISTINCT campaign_id FROM campaigns_with_spend)
),

-- 4️⃣  Load targeting JSON per target_id
target_tab AS (
  SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json
  FROM `focal-elf-631.standard_digest.audience_target_digest`
),

-- 5️⃣  Merge all ad-group targeting JSONs → campaign-level targeting
campaign_targeting AS (
  WITH flattened AS (
    SELECT
      c.campaign_id,
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
      END AS val_array
    FROM campaign_tab c
    JOIN adgroup_tab a USING (campaign_id)
    JOIN target_tab  t USING (target_id),
    UNNEST(REGEXP_EXTRACT_ALL(CAST(t.condition_json AS STRING),
      r'"(allowed_[^"]+|blocked_[^"]+)"')) AS key
  ),
  per_key_flat AS (
    SELECT campaign_id, key, x AS val
    FROM flattened, UNNEST(val_array) AS x
  ),
  per_key_agg AS (
    SELECT campaign_id, key, ARRAY_AGG(DISTINCT val) AS merged_vals
    FROM per_key_flat
    GROUP BY campaign_id, key
  )
  SELECT campaign_id, ARRAY_AGG(STRUCT(key, merged_vals)) AS targeting_arrays
  FROM per_key_agg
  GROUP BY campaign_id
),

-- 6️⃣  Expand targeting arrays into per-key rows
targeting_rules AS (
  SELECT campaign_id, key, merged_vals AS value_array
  FROM campaign_targeting, UNNEST(targeting_arrays)
),

-- 7️⃣  Count number of targeting rules per campaign
target_key_counts AS (
  SELECT
    campaign_id,
    MAX(IF(key='blocked_apps',ARRAY_LENGTH(value_array),NULL)) AS num_blocked_apps,
    MAX(IF(key='allowed_apps',ARRAY_LENGTH(value_array),NULL)) AS num_allowed_apps,
    MAX(IF(key='blocked_exchanges',ARRAY_LENGTH(value_array),NULL)) AS num_blocked_exchanges,
    MAX(IF(key='allowed_exchanges',ARRAY_LENGTH(value_array),NULL)) AS num_allowed_exchanges,
    MAX(IF(key='blocked_countries',ARRAY_LENGTH(value_array),NULL)) AS num_blocked_countries,
    MAX(IF(key='allowed_countries',ARRAY_LENGTH(value_array),NULL)) AS num_allowed_countries,
    MAX(IF(key='blocked_device_types',ARRAY_LENGTH(value_array),NULL)) AS num_blocked_device_types,
    MAX(IF(key='allowed_device_types',ARRAY_LENGTH(value_array),NULL)) AS num_allowed_device_types
  FROM targeting_rules
  GROUP BY campaign_id
),

-- 8️⃣  Campaign ↔ LAT policy
campaign_digest AS (
  SELECT
    campaign_id,
    campaign_country,
    campaign_os,
    CASE
      WHEN JSON_EXTRACT(original_json, "$.ad_tracking_allowance")='"DO_NOT_CARE"' THEN 'DO_NOT_CARE'
      WHEN JSON_EXTRACT(original_json, "$.ad_tracking_allowance") IN
        ('"NON_LAT_ONLY"', '"AD_TRACKING_ALLOWANCE_NON_LAT_ONLY_DEFAULT"') THEN 'NON_LAT_ONLY'
      WHEN JSON_EXTRACT(original_json, "$.ad_tracking_allowance")='"LAT_ONLY"' THEN 'LAT_ONLY'
      ELSE NULL
    END AS ad_tracking_allowance
  FROM `focal-elf-631.standard_digest.campaign_digest`
  WHERE campaign_id IN (SELECT DISTINCT campaign_id FROM campaigns_with_spend)
),

campaign_lat AS (
  SELECT
    c.campaign_id,
    c.os,
    c.target_countries,
    d.ad_tracking_allowance
  FROM campaign_tab c
  JOIN campaign_digest d
    ON c.campaign_id = d.campaign_id
   AND c.os          = d.campaign_os
),

-- 9️⃣  Market-level spend by country / OS / LAT / app / exchange
market_dim AS (
  SELECT
    campaign.country            AS country,
    campaign.os                 AS os,
    campaign.is_lat             AS is_lat,
    publisher.app_market_bundle AS app_bundle,
    exchange,
    SUM(gross_spend_usd)        AS market_spend
  FROM `moloco-ae-view.athena.fact_dsp_publisher`
  WHERE date_utc = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  GROUP BY country, os, is_lat, app_bundle, exchange
),

-- 🔟  Campaign-level market + tracking + targeting accessible spend
campaign_market_spend AS (
  SELECT
    cl.campaign_id,
    cl.os,
    cl.target_countries,
    cl.ad_tracking_allowance,

    -- total market spend in this campaign's target countries (all LAT / apps / exchanges)
    SUM(md.market_spend) AS total_market_spend,

    -- tracking_eligible_spend: apply LAT only (ignore targeting)
    SUM(
      CASE cl.ad_tracking_allowance
        WHEN 'DO_NOT_CARE' THEN md.market_spend
        WHEN 'NON_LAT_ONLY' THEN IF(md.is_lat = FALSE, md.market_spend, 0)
        WHEN 'LAT_ONLY'     THEN IF(md.is_lat = TRUE,  md.market_spend, 0)
        ELSE md.market_spend
      END
    ) AS tracking_eligible_spend,

    -- tgt_eligible_spend: apply targeting only (ignore LAT)
    SUM(
      CASE
        WHEN
          -- allowed_*: if list exists, value must be in it
          (
            NOT EXISTS (
              SELECT 1 FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_apps'
            )
            OR md.app_bundle IN UNNEST((
              SELECT value_array FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_apps'
            ))
          )
          AND (
            NOT EXISTS (
              SELECT 1 FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_exchanges'
            )
            OR md.exchange IN UNNEST((
              SELECT value_array FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_exchanges'
            ))
          )
          AND (
            NOT EXISTS (
              SELECT 1 FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_countries'
            )
            OR md.country IN UNNEST((
              SELECT value_array FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_countries'
            ))
          )
          -- blocked_*: must NOT be in blocked lists
          AND NOT EXISTS (
            SELECT 1
            FROM targeting_rules tr
            WHERE tr.campaign_id = cl.campaign_id
              AND (
                (tr.key = 'blocked_apps'      AND md.app_bundle IN UNNEST(tr.value_array)) OR
                (tr.key = 'blocked_exchanges' AND md.exchange   IN UNNEST(tr.value_array)) OR
                (tr.key = 'blocked_countries' AND md.country    IN UNNEST(tr.value_array))
              )
          )
        THEN md.market_spend
        ELSE 0
      END
    ) AS tgt_eligible_spend,

    -- accessible_spend: apply tracking (LAT) AND targeting together
    SUM(
      CASE
        WHEN
          -- LAT condition
          (
            cl.ad_tracking_allowance = 'DO_NOT_CARE'
            OR (cl.ad_tracking_allowance = 'NON_LAT_ONLY' AND md.is_lat = FALSE)
            OR (cl.ad_tracking_allowance = 'LAT_ONLY'     AND md.is_lat = TRUE)
          )
          -- AND targeting condition (same as above)
          AND (
            (
              NOT EXISTS (
                SELECT 1 FROM targeting_rules tr
                WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_apps'
              )
              OR md.app_bundle IN UNNEST((
                SELECT value_array FROM targeting_rules tr
                WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_apps'
              ))
            )
            AND (
              NOT EXISTS (
                SELECT 1 FROM targeting_rules tr
                WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_exchanges'
              )
              OR md.exchange IN UNNEST((
                SELECT value_array FROM targeting_rules tr
                WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_exchanges'
              ))
            )
            AND (
              NOT EXISTS (
                SELECT 1 FROM targeting_rules tr
                WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_countries'
              )
              OR md.country IN UNNEST((
                SELECT value_array FROM targeting_rules tr
                WHERE tr.campaign_id = cl.campaign_id AND tr.key = 'allowed_countries'
              ))
            )
            AND NOT EXISTS (
              SELECT 1
              FROM targeting_rules tr
              WHERE tr.campaign_id = cl.campaign_id
                AND (
                  (tr.key = 'blocked_apps'      AND md.app_bundle IN UNNEST(tr.value_array)) OR
                  (tr.key = 'blocked_exchanges' AND md.exchange   IN UNNEST(tr.value_array)) OR
                  (tr.key = 'blocked_countries' AND md.country    IN UNNEST(tr.value_array))
                )
            )
          )
        THEN md.market_spend
        ELSE 0
      END
    ) AS accessible_spend

  FROM campaign_lat cl
  CROSS JOIN UNNEST(cl.target_countries) AS tc
  JOIN market_dim md
    ON md.country = tc
   AND md.os      = cl.os
  GROUP BY
    cl.campaign_id,
    cl.os,
    cl.target_countries,
    cl.ad_tracking_allowance
),

-- 1️⃣1️⃣  Compute ratios
missing_opportunity_spend AS (
  SELECT
    cms.*,

    SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) AS accessible_ratio_tracking,
    SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend) AS accessible_ratio_targeting,
    SAFE_DIVIDE(accessible_spend,         total_market_spend) AS accessible_ratio_actual,

    1 - SAFE_DIVIDE(tracking_eligible_spend, total_market_spend) AS missing_spend_ratio_tracking,
    1 - SAFE_DIVIDE(tgt_eligible_spend,       total_market_spend) AS missing_spend_ratio_targeting,

    -- multiplicative total missing ratio under independence assumption
    1 - (
      SAFE_DIVIDE(tracking_eligible_spend, total_market_spend)
      * SAFE_DIVIDE(tgt_eligible_spend,     total_market_spend)
    ) AS missing_spend_ratio_total_mult,

    -- actual total missing ratio from LAT + targeting combined
    1 - SAFE_DIVIDE(accessible_spend, total_market_spend) AS missing_spend_ratio_total_actual

  FROM campaign_market_spend cms
),

-- 1️⃣2️⃣  Summary table in wide form
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

-- 1️⃣3️⃣  target_accessible_supply_score
target_accessible_supply_score AS (
  SELECT
    campaign_id,
    'target_accessible_supply_score' AS blueprint_index,
    ROUND(accessible_ratio_targeting * 100, 2) AS score,

    -- 🆕 Conditionally concatenated string
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

    concat(
      IF(num_blocked_apps > 0      OR num_allowed_apps > 0 OR num_blocked_exchanges > 0 OR num_allowed_exchanges > 0 OR num_blocked_countries > 0 OR num_allowed_countries > 0, "Check: ", NULL),
      ARRAY_TO_STRING(
        ARRAY(
          SELECT x FROM UNNEST([
            IF(num_blocked_apps > 0      OR num_allowed_apps > 0,         'publisher block/allowlist',         NULL),
            IF(num_blocked_exchanges > 0 OR num_allowed_exchanges > 0,    'exchange block/allowlist' ,    NULL),
            IF(num_blocked_countries > 0 OR num_allowed_countries > 0,    'country block/allowlist',    NULL)
          ]) AS x
          WHERE x IS NOT NULL
        ),
        ', '
        ), 
        IF(num_blocked_apps > 0      OR num_allowed_apps > 0 OR num_blocked_exchanges > 0 OR num_allowed_exchanges > 0 OR num_blocked_countries > 0 OR num_allowed_countries > 0, '; Remove them if possible', NULL))
     AS recommendation

  FROM summary
),

-- 1️⃣4️⃣  traffic_accessible_supply_score
traffic_accessible_supply_score AS (

  SELECT
    campaign_id,
    'traffic_accessible_supply_score' AS blueprint_index,
    ROUND(accessible_ratio_tracking * 100, 2) AS score,
    IF(ad_tracking_allowance <> 'DO_NOT_CARE', ad_tracking_allowance, NULL) AS detail,
    CASE 
      WHEN os = 'ANDROID' AND ad_tracking_allowance='NON_LAT_ONLY' THEN 'Consider utlizing LAT traffic in case of CPI optimization.'
      WHEN os = 'ANDROID' AND ad_tracking_allowance='LAT_ONLY' THEN 'Utilize both NON-LAT and LAT traffic.'
      WHEN os = 'IOS' AND ad_tracking_allowance='NON_LAT_ONLY' THEN 'Utilize LAT traffic in iOS.'
      WHEN os = 'IOS' AND ad_tracking_allowance='LAT_ONLY' THEN 'Utilize both NON-LAT and LAT traffic.'
      ELSE NULL END AS recommendation

  FROM summary

),

-- 1️⃣5️⃣  two scores merged
merged AS (
  SELECT *
  FROM target_accessible_supply_score

  UNION ALL

  SELECT *
  FROM traffic_accessible_supply_score
),

-- 1️⃣6️⃣  calculate overall index
overall_index AS (
  SELECT 
    *,
    ROUND(AVG(score) OVER (PARTITION BY campaign_id),2) AS overall_optimization_score
  FROM merged
)

SELECT *
FROM overall_index

