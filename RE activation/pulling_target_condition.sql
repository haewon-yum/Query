/* 1️⃣  keep only the most-recent row for every target ─────────────────── */
WITH latest AS (
  SELECT
    timestamp,
    SAFE.PARSE_JSON(original_json) AS j                 -- 🔹 JSON-typed column
  FROM  `focal-elf-631.standard_digest.latest_digest`
  WHERE type = 'AUDIENCE_TARGET'
  QUALIFY ROW_NUMBER() OVER (
            PARTITION BY JSON_VALUE(original_json, '$.name')   -- target_id
            ORDER BY timestamp DESC) = 1
)

/* 2️⃣  explode every app_event from each branch ───────────────────────── */
, per_event AS (

  /* ─── include_having_any ────────────────────────────────────────────── */
  SELECT
    l.timestamp,
    JSON_VALUE(l.j, '$.advertiser_name')                      AS advertiser_id,
    JSON_VALUE(l.j, '$.name')                                 AS target_id,
    JSON_VALUE(l.j, '$.display_name')                         AS display_name,
    JSON_VALUE(l.j, '$.not_referenced_since_timestamp_nano')  AS not_referenced_since_timestamp_nano,
    'include_any'  AS branch,
    JSON_VALUE(ev, '$.product_id')               AS product_id,
    JSON_VALUE(ev, '$.event')                    AS event,
    JSON_VALUE(ev, '$.sliding_window_duration')  AS sliding_window_duration
  FROM latest l
  CROSS JOIN UNNEST(
    IFNULL(
      JSON_EXTRACT_ARRAY(
        l.j,
        '$.condition.custom_audience_set.include_having_any.app_events'
      ),
      []          -- ← empty array if path is null
    )
  ) AS ev                                           -- ev is a JSON object

  UNION ALL

  /* ─── include_having_all ────────────────────────────────────────────── */
  SELECT
    l.timestamp,
    JSON_VALUE(l.j, '$.advertiser_name'),
    JSON_VALUE(l.j, '$.name'),
    JSON_VALUE(l.j, '$.display_name'),
    JSON_VALUE(l.j, '$.not_referenced_since_timestamp_nano'),
    'include_all',
    JSON_VALUE(ev, '$.product_id'),
    JSON_VALUE(ev, '$.event'),
    JSON_VALUE(ev, '$.sliding_window_duration')
  FROM latest l
  CROSS JOIN UNNEST(
    IFNULL(
      JSON_EXTRACT_ARRAY(
        l.j,
        '$.condition.custom_audience_set.include_having_all.app_events'
      ),
      []
    )
  ) AS ev

  UNION ALL

  /* ─── exclude_having_any ────────────────────────────────────────────── */
  SELECT
    l.timestamp,
    JSON_VALUE(l.j, '$.advertiser_name'),
    JSON_VALUE(l.j, '$.name'),
    JSON_VALUE(l.j, '$.display_name'),
    JSON_VALUE(l.j, '$.not_referenced_since_timestamp_nano'),
    'exclude_any',
    JSON_VALUE(ev, '$.product_id'),
    JSON_VALUE(ev, '$.event'),
    JSON_VALUE(ev, '$.sliding_window_duration')
  FROM latest l
  CROSS JOIN UNNEST(
    IFNULL(
      JSON_EXTRACT_ARRAY(
        l.j,
        '$.condition.custom_audience_set.exclude_having_any.app_events'
      ),
      []
    )
  ) AS ev

  UNION ALL

  /* ─── exclude_having_all ────────────────────────────────────────────── */
  SELECT
    l.timestamp,
    JSON_VALUE(l.j, '$.advertiser_name'),
    JSON_VALUE(l.j, '$.name'),
    JSON_VALUE(l.j, '$.display_name'),
    JSON_VALUE(l.j, '$.not_referenced_since_timestamp_nano'),
    'exclude_all',
    JSON_VALUE(ev, '$.product_id'),
    JSON_VALUE(ev, '$.event'),
    JSON_VALUE(ev, '$.sliding_window_duration')
  FROM latest l
  CROSS JOIN UNNEST(
    IFNULL(
      JSON_EXTRACT_ARRAY(
        l.j,
        '$.condition.custom_audience_set.exclude_having_all.app_events'
      ),
      []
    )
  ) AS ev
),

target_campaigns AS (
  SELECT
    campaign_id
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    AND platform_id IN ('NETMARBLE','NEXON','111PERCENT')
    AND campaign.type = 'APP_REENGAGEMENT'
  GROUP BY ALL 
  HAVING SUM(gross_spend_usd) > 0

),

product_dim AS (
  SELECT
    t1.product_id,
    t1.product.genre      AS genre,
    t1.product.sub_genre  AS sub_genre,
    ROW_NUMBER() OVER (PARTITION BY product_id
                       ORDER BY date_utc DESC) AS rn
  FROM `moloco-ae-view.athena.fact_dsp_core` t1
  INNER JOIN target_campaigns t2 USING(campaign_id)
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  -- AND product.app_market_bundle IN ('com.netmarble.sololv', 'com.netmarble.tskgb')
  -- AND advertiser_id = 'yfg0At8VksGnt6EO'
  -- AND platform_id IN ('NETMARBLE','NEXON','111PERCENT')
  
),

campaign_targets AS (
  WITH targets AS (
    SELECT
      campaign_id,
      ad_group_id,
      ad_group_title,
      REPLACE(target_id, '"', '') AS target_id
    FROM `focal-elf-631.standard_digest.ad_group_digest`,
        UNNEST(
          CAST(
            JSON_QUERY_ARRAY(original_json, "$.user_targets")
            AS ARRAY<STRING>
          )
        ) AS target_id
    WHERE campaign_id IN (SELECT * FROM target_campaigns)
  )
  SELECT
    campaign_id,
    ad_group_id,
    ad_group_title,
    target_id
  FROM targets
)


SELECT
  pe.timestamp,
  pe.advertiser_id,
  ct.campaign_id,
  ct.ad_group_id,
  ct.ad_group_title,
  pe.target_id,
  pe.display_name,
  pe.not_referenced_since_timestamp_nano,
  pe.branch,
  pe.product_id,
  pd.genre,
  pd.sub_genre,
  pe.event,
  pe.sliding_window_duration
FROM per_event  AS pe
INNER JOIN ( SELECT * FROM product_dim WHERE rn = 1 ) AS pd USING (product_id)
RIGHT JOIN campaign_targets AS ct USING(target_id)
ORDER BY pe.timestamp DESC