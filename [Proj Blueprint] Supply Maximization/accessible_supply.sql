#@title Query: expanded with missing opportunity in terms of spend


-- 🧩 Parameters
DECLARE spend_start_date DATE DEFAULT '{analysis_date}';
DECLARE spend_end_date   DATE DEFAULT '{analysis_date}';
DECLARE analysis_date    STRING DEFAULT '{suffix}';

CREATE OR REPLACE TABLE `moloco-ods.haewon.blueprint_supply_251101_{str.lower(office)}` AS

WITH
-- 0️⃣  Identify campaigns that actually spent during the period
campaigns_with_spend AS (
    SELECT
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
    FROM `moloco-ae-view.athena.fact_dsp_core`
    WHERE date_utc BETWEEN spend_start_date AND spend_end_date
    AND advertiser.office IN ('{office}')
    GROUP BY 1
    HAVING total_spend > 0
),

-- 1️⃣  Market-level total spend by country / OS / LAT
market_spend AS (
    SELECT
    campaign.country,
    campaign.os,
    -- campaign.is_lat,
    SUM(gross_spend_usd) AS total_market_spend
    FROM `moloco-ae-view.athena.fact_dsp_publisher`
    WHERE date_utc BETWEEN spend_start_date AND spend_end_date
    GROUP BY 1,2
),

-- 2️⃣  Advertiser metadata (region, manager, etc.)
advertiser_tab AS (
    SELECT
    office,
    CASE
        WHEN office = 'EMEA' THEN 'EMEA'
        WHEN office = 'USA'  THEN 'AMER'
        WHEN office IN ('KOR','IND','JPN','SGP','CHN') THEN 'APAC'
        ELSE 'Other'
    END AS region,
    tier,
    account_manager,
    advertiser_id
    FROM (
    SELECT
        date_utc,
        ROW_NUMBER() OVER (
        PARTITION BY advertiser_id
        ORDER BY date_utc DESC, effective_date DESC
        ) AS rnk,
        advertiser_id,
        office,
        account_manager,
        tier
    FROM `moloco-ae-view.athena.dim2_platform_advertiser_daily`
    )
    WHERE rnk = 1
),

-- 3️⃣  Campaign metadata (active campaigns only)
campaign_tab AS (
    SELECT
    office,
    region,
    tier,
    account_manager,
    platform_name,
    advertiser_name AS advertiser_id,
    advertiser_display_name AS advertiser,
    store_bundle,
    tracking_bundle,
    product_category,
    CASE WHEN app.is_gaming THEN 'gaming' ELSE 'non-gaming' END AS gaming,
    a.os,
    JSON_EXTRACT_SCALAR(campaign_goal, "$.type") AS campaign_goal,
    campaign_name AS campaign_id,
    campaign_display_name AS campaign,
    DATE(created_timestamp_nano) AS campaign_start_date,
    STRING_AGG(DISTINCT country_settings.country) AS target_countries
    FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
    LEFT JOIN advertiser_tab b ON a.advertiser_name = b.advertiser_id
    LEFT JOIN `ads-bpd-guard-china.athena.dim1_product` c ON a.product_name = c.product_id
    CROSS JOIN UNNEST(a.country_settings) AS country_settings
    WHERE
    state = "ACTIVE" AND enabled AND a.os IN ('IOS','ANDROID')
    AND campaign_name IN (SELECT DISTINCT campaign_id FROM campaigns_with_spend)
    GROUP BY ALL
),

-- 4️⃣  Extract ad group → target mapping
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

-- 5️⃣  Load targeting JSON per target_id
target_tab AS (
    SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json
    FROM `focal-elf-631.standard_digest.audience_target_digest`
),

-- 6️⃣  Merge all ad-group targeting JSONs → campaign-level targeting
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

-- 7️⃣  Campaign-country mapping + LAT policy flag
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

-- 8️⃣  Expand targeting arrays into per-key rows
targeting_rules AS (
    SELECT campaign_id, key, merged_vals AS value_array
    FROM campaign_targeting, UNNEST(targeting_arrays)
),

-- 9️⃣  Bid-level table (join bidrequest logs with campaign_country/os)
bids AS (
    SELECT
    d.campaign_id,
    b.bid_id,
    idfa,
    country,
    app_bundle,
    exchange,
    os,
    (CASE WHEN IF(id_type IS NULL,
        REGEXP_CONTAINS(idfa, r'^[a-f0-9]8-[a-f0-9]4-4[a-f0-9]3-8000-000000000000$'),
        id_type IN (5,6)) THEN 'Yes' ELSE 'No' END) AS is_lat,
    dev_type AS device_type
    FROM `focal-elf-631.prod.bidrequest20*` b
    JOIN campaign_digest d
    ON LOWER(b.country) = LOWER(d.campaign_country)
    AND LOWER(b.os)      = LOWER(d.campaign_os)
    WHERE _TABLE_SUFFIX = analysis_date
),

-- 🔟  Evaluate targeting per bid → produce pass_flags array
evals AS (
    SELECT
    b.campaign_id,
    b.country,
    b.os,
    b.device_type,
    b.is_lat,
    b.bid_id,
    ARRAY_AGG(
        CASE
        WHEN STARTS_WITH(t.key,'allowed_') THEN (
            ARRAY_LENGTH(t.value_array)=0 OR
            CASE
            WHEN t.key='allowed_apps'         THEN b.app_bundle   IN UNNEST(t.value_array)
            WHEN t.key='allowed_exchanges'    THEN b.exchange     IN UNNEST(t.value_array)
            WHEN t.key='allowed_countries'    THEN b.country      IN UNNEST(t.value_array)
            WHEN t.key='allowed_device_types' THEN b.device_type  IN UNNEST(t.value_array)
            ELSE TRUE END)
        WHEN STARTS_WITH(t.key,'blocked_') THEN (
            ARRAY_LENGTH(t.value_array)=0 OR
            CASE
            WHEN t.key='blocked_apps'         THEN NOT b.app_bundle   IN UNNEST(t.value_array)
            WHEN t.key='blocked_exchanges'    THEN NOT b.exchange     IN UNNEST(t.value_array)
            WHEN t.key='blocked_countries'    THEN NOT b.country      IN UNNEST(t.value_array)
            WHEN t.key='blocked_device_types' THEN NOT b.device_type  IN UNNEST(t.value_array)
            ELSE TRUE END)
        ELSE TRUE
        END
    ) AS pass_flags
    FROM bids b
    JOIN targeting_rules t ON b.campaign_id = t.campaign_id
    GROUP BY b.campaign_id,b.country,b.os,b.device_type,b.is_lat,b.bid_id
),

-- 1️⃣1️⃣  Aggregate per campaign/country/os with LAT policy
campaign_summary AS (
    SELECT
    e.campaign_id,
    e.country,
    e.os,
    d.ad_tracking_allowance,
    COUNT(*) AS total_bids,
    COUNTIF(NOT FALSE IN UNNEST(e.pass_flags)) AS targeting_pass_bids,
    COUNTIF(
        NOT FALSE IN UNNEST(e.pass_flags) AND (
        d.ad_tracking_allowance='DO_NOT_CARE' OR
        (d.ad_tracking_allowance='NON_LAT_ONLY' AND e.is_lat='No') OR
        (d.ad_tracking_allowance='LAT_ONLY'     AND e.is_lat='Yes')
        )
    ) AS matched_bids,
    SAFE_DIVIDE(COUNTIF(NOT FALSE IN UNNEST(e.pass_flags)), COUNT(*)) AS targeting_accessible_ratio,
    SAFE_DIVIDE(
        COUNTIF(
        NOT FALSE IN UNNEST(e.pass_flags) AND (
            d.ad_tracking_allowance='DO_NOT_CARE' OR
            (d.ad_tracking_allowance='NON_LAT_ONLY' AND e.is_lat='No') OR
            (d.ad_tracking_allowance='LAT_ONLY'     AND e.is_lat='Yes')
        )
        ), COUNT(*)) AS accessible_ratio,
    SAFE_DIVIDE(
        COUNTIF(
        NOT FALSE IN UNNEST(e.pass_flags) AND (
            d.ad_tracking_allowance='DO_NOT_CARE' OR
            (d.ad_tracking_allowance='NON_LAT_ONLY' AND e.is_lat='No') OR
            (d.ad_tracking_allowance='LAT_ONLY'     AND e.is_lat='Yes')
        )
        ), COUNTIF(NOT FALSE IN UNNEST(e.pass_flags))
    ) AS lat_policy_retention_ratio
    FROM evals e
    JOIN campaign_digest d ON e.campaign_id = d.campaign_id
    GROUP BY e.campaign_id, e.country, e.os, d.ad_tracking_allowance
),

-- 1️⃣2️⃣  Count number of targeting rules per campaign
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

-- 1️⃣3️⃣  Compute accessible spend (apply targeting + LAT) — de-duplicated
accessible_spend AS (
SELECT
    d.campaign_id,
    s.campaign.country AS country,
    s.campaign.os      AS os,
    SUM(s.gross_spend_usd) AS accessible_spend
FROM `moloco-ae-view.athena.fact_dsp_publisher` s
JOIN campaign_digest d
    ON LOWER(s.campaign.country) = LOWER(d.campaign_country)
AND LOWER(s.campaign.os)      = LOWER(d.campaign_os)
WHERE s.date_utc BETWEEN spend_start_date AND spend_end_date

    -- (A) LAT policy
    AND (
    d.ad_tracking_allowance = 'DO_NOT_CARE'
    OR (d.ad_tracking_allowance = 'NON_LAT_ONLY' AND NOT s.campaign.is_lat)
    OR (d.ad_tracking_allowance = 'LAT_ONLY'      AND     s.campaign.is_lat)
    )

    -- (B) ALLOWED rules: for each dimension, if an allowed list exists, value must be in it
    AND (
    -- apps
    NOT EXISTS (
        SELECT 1
        FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_apps'
    )
    OR EXISTS (
        SELECT 1
        FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
        AND tr.key = 'allowed_apps'
        AND s.publisher.app_market_bundle IN UNNEST(tr.value_array)
    )
    )
    AND (
    -- exchanges
    NOT EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_exchanges'
    )
    OR EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
        AND tr.key = 'allowed_exchanges'
        AND s.exchange IN UNNEST(tr.value_array)
    )
    )
    AND (
    -- countries
    NOT EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_countries'
    )
    OR EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
        AND tr.key = 'allowed_countries'
        AND s.campaign.country IN UNNEST(tr.value_array)
    )
    )
    -- device_type allowed_* : skipped as there's no device_type dim in dsp_fact_publisher

    -- (C) BLOCKED rules: exclude if app/exchange/country is included in blocked_* list
    AND NOT EXISTS (
    SELECT 1
    FROM targeting_rules tr
    WHERE tr.campaign_id = d.campaign_id
        AND (
        (tr.key = 'blocked_apps'      AND s.publisher.app_market_bundle IN UNNEST(tr.value_array)) OR
        (tr.key = 'blocked_exchanges' AND s.exchange                    IN UNNEST(tr.value_array)) OR
        (tr.key = 'blocked_countries' AND s.campaign.country            IN UNNEST(tr.value_array))
        )
    )

GROUP BY d.campaign_id, country, os
),

-- 1️⃣4️⃣  Compute missing opportunity (spend-based)
missing_opportunity_spend AS (
    SELECT
    a.campaign_id,
    a.country,
    a.os,
    m.total_market_spend,
    a.accessible_spend,
    m.total_market_spend - a.accessible_spend AS missing_spend,
    SAFE_DIVIDE(m.total_market_spend - a.accessible_spend, m.total_market_spend)
        AS missing_spend_ratio
    FROM accessible_spend a
    JOIN market_spend m USING (country, os)
)

-- 1️⃣5️⃣  Final output
SELECT
    s.campaign_id,
    c.store_bundle,
    s.os,
    c.target_countries,
    c.office,
    c.region,
    c.tier,
    c.account_manager,
    c.advertiser_id,
    c.advertiser,
    s.ad_tracking_allowance,
    s.total_bids,
    s.targeting_pass_bids,
    s.matched_bids,
    s.targeting_accessible_ratio,
    s.lat_policy_retention_ratio,
    s.accessible_ratio,
    (1 - s.accessible_ratio) AS missing_supply_ratio,
    mo.total_market_spend,
    mo.accessible_spend,
    mo.missing_spend,
    mo.missing_spend_ratio, -- spend-based missing opportunity
    t.num_blocked_apps,
    t.num_allowed_apps,
    t.num_blocked_exchanges,
    t.num_allowed_exchanges,
    t.num_blocked_countries,
    t.num_allowed_countries,
    t.num_blocked_device_types,
    t.num_allowed_device_types
FROM campaign_summary s
LEFT JOIN target_key_counts t USING (campaign_id)
LEFT JOIN campaign_tab c USING (campaign_id)
LEFT JOIN missing_opportunity_spend mo
    ON s.campaign_id = mo.campaign_id
AND s.country = mo.country
AND LOWER(s.os) = LOWER(mo.os)
ORDER BY s.total_bids DESC;



#############################################
### Missing opportunity only with Spend   ###
############################################# 


-- 🧩 Parameters
DECLARE spend_start_date DATE DEFAULT '{analysis_date}';
DECLARE spend_end_date   DATE DEFAULT '{analysis_date}';
DECLARE analysis_date    STRING DEFAULT '{suffix}';

-- CREATE OR REPLACE TABLE `moloco-ods.haewon.blueprint_supply_251101_{str.lower(office)}` AS

WITH
-- 0️⃣  Identify campaigns that actually spent during the period
campaigns_with_spend AS (
  SELECT
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN spend_start_date AND spend_end_date
    AND advertiser.office IN ('{office}')
  GROUP BY 1
  HAVING total_spend > 0
),

-- 1️⃣  Market-level total spend by country / OS
market_spend AS (
  SELECT
    campaign.country,
    campaign.os,
    SUM(gross_spend_usd) AS total_market_spend
  FROM `moloco-ae-view.athena.fact_dsp_publisher`
  WHERE date_utc BETWEEN spend_start_date AND spend_end_date
  GROUP BY 1,2
),

-- 2️⃣  Advertiser metadata (region, manager, etc.)
advertiser_tab AS (
  SELECT
    office,
    CASE
      WHEN office = 'EMEA' THEN 'EMEA'
      WHEN office = 'USA'  THEN 'AMER'
      WHEN office IN ('KOR','IND','JPN','SGP','CHN') THEN 'APAC'
      ELSE 'Other'
    END AS region,
    tier,
    account_manager,
    advertiser_id
  FROM (
    SELECT
      date_utc,
      ROW_NUMBER() OVER (
        PARTITION BY advertiser_id
        ORDER BY date_utc DESC, effective_date DESC
      ) AS rnk,
      advertiser_id,
      office,
      account_manager,
      tier
    FROM `moloco-ae-view.athena.dim2_platform_advertiser_daily`
  )
  WHERE rnk = 1
),

-- 3️⃣  Campaign metadata (active campaigns on iOS & Android only)
campaign_tab AS (
  SELECT
    office,
    region,
    tier,
    account_manager,
    platform_name,
    advertiser_name AS advertiser_id,
    advertiser_display_name AS advertiser,
    store_bundle,
    tracking_bundle,
    product_category,
    CASE WHEN app.is_gaming THEN 'gaming' ELSE 'non-gaming' END AS gaming,
    a.os,
    JSON_EXTRACT_SCALAR(campaign_goal, "$.type") AS campaign_goal,
    campaign_name AS campaign_id,
    campaign_display_name AS campaign,
    DATE(created_timestamp_nano) AS campaign_start_date,
    STRING_AGG(DISTINCT country_settings.country) AS target_countries
  FROM `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
  LEFT JOIN advertiser_tab b ON a.advertiser_name = b.advertiser_id
  LEFT JOIN `ads-bpd-guard-china.athena.dim1_product` c ON a.product_name = c.product_id
  CROSS JOIN UNNEST(a.country_settings) AS country_settings
  WHERE
    state = "ACTIVE"
    AND enabled
    AND a.os IN ('IOS','ANDROID')
    AND campaign_name IN (SELECT DISTINCT campaign_id FROM campaigns_with_spend)
  GROUP BY ALL
),

-- 4️⃣  Extract ad group → target mapping
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

-- 5️⃣  Load targeting JSON per target_id
target_tab AS (
  SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json
  FROM `focal-elf-631.standard_digest.audience_target_digest`
),

-- 6️⃣  Merge all ad-group targeting JSONs → campaign-level targeting
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

-- 7️⃣  Campaign-country mapping + LAT policy flag
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

-- 8️⃣  Expand targeting arrays into per-key rows
targeting_rules AS (
  SELECT campaign_id, key, merged_vals AS value_array
  FROM campaign_targeting, UNNEST(targeting_arrays)
),

-- 9️⃣  Count number of targeting rules per campaign
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

-- 1️⃣0️⃣  Spend after applying *only LAT policy* (no targeting)
lat_only_spend AS (
  SELECT
    d.campaign_id,
    s.campaign.country AS country,
    s.campaign.os      AS os,
    d.ad_tracking_allowance,
    SUM(s.gross_spend_usd) AS lat_eligible_spend
  FROM `moloco-ae-view.athena.fact_dsp_publisher` s
  JOIN campaign_digest d
    ON LOWER(s.campaign.country) = LOWER(d.campaign_country)
   AND LOWER(s.campaign.os)      = LOWER(d.campaign_os)
  WHERE s.date_utc BETWEEN spend_start_date AND spend_end_date
    AND (
      d.ad_tracking_allowance = 'DO_NOT_CARE'
      OR (d.ad_tracking_allowance = 'NON_LAT_ONLY' AND NOT s.campaign.is_lat)
      OR (d.ad_tracking_allowance = 'LAT_ONLY'      AND     s.campaign.is_lat)
    )
  GROUP BY d.campaign_id, country, os, d.ad_tracking_allowance
),

-- 1️⃣1️⃣  Spend after applying *only targeting* (ignore LAT)
targeting_only_spend AS (
  SELECT
    d.campaign_id,
    s.campaign.country AS country,
    s.campaign.os      AS os,
    SUM(s.gross_spend_usd) AS tgt_eligible_spend
  FROM `moloco-ae-view.athena.fact_dsp_publisher` s
  JOIN campaign_digest d
    ON LOWER(s.campaign.country) = LOWER(d.campaign_country)
   AND LOWER(s.campaign.os)      = LOWER(d.campaign_os)
  WHERE s.date_utc BETWEEN spend_start_date AND spend_end_date

    -- ❌ no LAT policy filter here

    -- (B) ALLOWED rules: for each dimension, if an allowed list exists, value must be in it
    AND (
      -- apps
      NOT EXISTS (
        SELECT 1
        FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_apps'
      )
      OR EXISTS (
        SELECT 1
        FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
          AND tr.key = 'allowed_apps'
          AND s.publisher.app_market_bundle IN UNNEST(tr.value_array)
      )
    )
    AND (
      -- exchanges
      NOT EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_exchanges'
      )
      OR EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
          AND tr.key = 'allowed_exchanges'
          AND s.exchange IN UNNEST(tr.value_array)
      )
    )
    AND (
      -- countries
      NOT EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_countries'
      )
      OR EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
          AND tr.key = 'allowed_countries'
          AND s.campaign.country IN UNNEST(tr.value_array)
      )
    )
    -- device_type allowed_* : skipped as there's no device_type dim in dsp_fact_publisher

    -- (C) BLOCKED rules: exclude if app/exchange/country is included in blocked_* list
    AND NOT EXISTS (
      SELECT 1
      FROM targeting_rules tr
      WHERE tr.campaign_id = d.campaign_id
        AND (
          (tr.key = 'blocked_apps'      AND s.publisher.app_market_bundle IN UNNEST(tr.value_array)) OR
          (tr.key = 'blocked_exchanges' AND s.exchange                    IN UNNEST(tr.value_array)) OR
          (tr.key = 'blocked_countries' AND s.campaign.country            IN UNNEST(tr.value_array))
        )
    )

  GROUP BY d.campaign_id, country, os
),

-- 1️⃣2️⃣  Spend after applying LAT policy + targeting (actual accessible spend)
accessible_spend AS (
  SELECT
    d.campaign_id,
    s.campaign.country AS country,
    s.campaign.os      AS os,
    SUM(s.gross_spend_usd) AS accessible_spend
  FROM `moloco-ae-view.athena.fact_dsp_publisher` s
  JOIN campaign_digest d
    ON LOWER(s.campaign.country) = LOWER(d.campaign_country)
   AND LOWER(s.campaign.os)      = LOWER(d.campaign_os)
  WHERE s.date_utc BETWEEN spend_start_date AND spend_end_date

    -- (A) LAT policy
    AND (
      d.ad_tracking_allowance = 'DO_NOT_CARE'
      OR (d.ad_tracking_allowance = 'NON_LAT_ONLY' AND NOT s.campaign.is_lat)
      OR (d.ad_tracking_allowance = 'LAT_ONLY'      AND     s.campaign.is_lat)
    )

    -- (B) ALLOWED rules: for each dimension, if an allowed list exists, value must be in it
    AND (
      -- apps
      NOT EXISTS (
        SELECT 1
        FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_apps'
      )
      OR EXISTS (
        SELECT 1
        FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
          AND tr.key = 'allowed_apps'
          AND s.publisher.app_market_bundle IN UNNEST(tr.value_array)
      )
    )
    AND (
      -- exchanges
      NOT EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_exchanges'
      )
      OR EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
          AND tr.key = 'allowed_exchanges'
          AND s.exchange IN UNNEST(tr.value_array)
      )
    )
    AND (
      -- countries
      NOT EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id AND tr.key = 'allowed_countries'
      )
      OR EXISTS (
        SELECT 1 FROM targeting_rules tr
        WHERE tr.campaign_id = d.campaign_id
          AND tr.key = 'allowed_countries'
          AND s.campaign.country IN UNNEST(tr.value_array)
      )
    )
    -- device_type allowed_* : skipped as there's no device_type dim in dsp_fact_publisher

    -- (C) BLOCKED rules: exclude if app/exchange/country is included in blocked_* list
    AND NOT EXISTS (
      SELECT 1
      FROM targeting_rules tr
      WHERE tr.campaign_id = d.campaign_id
        AND (
          (tr.key = 'blocked_apps'      AND s.publisher.app_market_bundle IN UNNEST(tr.value_array)) OR
          (tr.key = 'blocked_exchanges' AND s.exchange                    IN UNNEST(tr.value_array)) OR
          (tr.key = 'blocked_countries' AND s.campaign.country            IN UNNEST(tr.value_array))
        )
    )

  GROUP BY d.campaign_id, country, os
),

-- 1️⃣3️⃣  Decomposed missing opportunity (spend-based)
missing_opportunity_spend AS (
  SELECT
    a.campaign_id,
    a.country,
    a.os,
    l.ad_tracking_allowance,
    m.total_market_spend,
    l.lat_eligible_spend,
    t.tgt_eligible_spend,
    a.accessible_spend,

    -- accessible ratios
    SAFE_DIVIDE(l.lat_eligible_spend, m.total_market_spend) AS accessible_ratio_lat,
    SAFE_DIVIDE(t.tgt_eligible_spend, m.total_market_spend) AS accessible_ratio_targeting,
    SAFE_DIVIDE(a.accessible_spend,   m.total_market_spend) AS accessible_ratio_actual,

    -- missing ratios "solely" due to each factor (ignoring the other)
    1 - SAFE_DIVIDE(l.lat_eligible_spend, m.total_market_spend) AS missing_spend_ratio_lat,
    1 - SAFE_DIVIDE(t.tgt_eligible_spend, m.total_market_spend) AS missing_spend_ratio_targeting,

    -- multiplicative total missing ratio under independence assumption
    1 - (
      SAFE_DIVIDE(l.lat_eligible_spend, m.total_market_spend)
      * SAFE_DIVIDE(t.tgt_eligible_spend, m.total_market_spend)
    ) AS missing_spend_ratio_total_mult,

    -- actual total missing ratio from LAT + targeting combined
    1 - SAFE_DIVIDE(a.accessible_spend, m.total_market_spend) AS missing_spend_ratio_total_actual

  FROM accessible_spend a
  JOIN lat_only_spend l
    ON a.campaign_id = l.campaign_id
   AND a.country     = l.country
   AND a.os          = l.os
  JOIN targeting_only_spend t
    ON a.campaign_id = t.campaign_id
   AND a.country     = t.country
   AND a.os          = t.os
  JOIN market_spend m
    ON a.country = m.country
   AND a.os      = m.os
)

-- 1️⃣4️⃣  Final output (spend-based opportunity only)
SELECT
  mo.campaign_id,
  c.store_bundle,
  mo.os,
  c.target_countries,
  c.office,
  c.region,
  c.tier,
  c.account_manager,
  c.advertiser_id,
  c.advertiser,
  mo.ad_tracking_allowance,

  -- market vs LAT vs targeting+LAT
  mo.total_market_spend,
  mo.lat_eligible_spend,
  mo.tgt_eligible_spend,
  mo.accessible_spend,

  -- accessible ratios
  mo.accessible_ratio_lat,
  mo.accessible_ratio_targeting,
  mo.accessible_ratio_actual,

  -- decomposed missing ratios
  mo.missing_spend_ratio_lat,
  mo.missing_spend_ratio_targeting,
  mo.missing_spend_ratio_total_mult,
  mo.missing_spend_ratio_total_actual,

  -- targeting complexity features
  t.num_blocked_apps,
  t.num_allowed_apps,
  t.num_blocked_exchanges,
  t.num_allowed_exchanges,
  t.num_blocked_countries,
  t.num_allowed_countries,
  t.num_blocked_device_types,
  t.num_allowed_device_types

FROM missing_opportunity_spend mo
LEFT JOIN campaign_tab      c USING (campaign_id)
LEFT JOIN target_key_counts t USING (campaign_id)
ORDER BY mo.total_market_spend DESC;
