/*

- focal-elf-631.standard_digest.campaign_digest
- Label table with information on the campaign, including target KPI histories.
- Key: campaign_id
- Notes
    + campaign_id might be duplicated. When joining to other tables, use platform_id as well
    + Should have parity with MOCAS (and same with all other digest tables)

- Schema
    campaign_id
    campaign_title
    advertiser_id
    product_id
    campaign_type
    creative_group_ids
    campaign_goal
    campaign_target_action
    campaign_kpi_actions
    campaign_os
    campaign_country
    platform
    service
    type
    version
    timestamp
    is_archived
    original_json


Original_json: 
    {"name":"tIXH3fTLKW980BVV",
    "cuid":100139645,
    "display_name":"Raid_RE_Moloco_Android_T1T2_NoDep_LVL30_Epic_1628952",
    "description":"",
    "disabled":true,
    "disabled_timestamp_nano":"1747051221767295000",
    "type":"APP_REENGAGEMENT",
    "goal":{"
        type":"OPTIMIZE_ROAS_FOR_APP_RE",
        "kpi_actions":["reDeposit_GG"],
        "target_kpi_histories":[],
        "main_target_kpi_history":null,
        "sub_target_kpi_histories":[],
        "optimize_re_app_roas":{
            "target_roas":0,
            "revenue_actions":["reDeposit_GG"],
            "reengagement_action":"click",
            "budget_centric":{"rate":1}
            }
    },
    "user_targets":[],
    "disable_product_level_user_targets":false,
    "country":"AUS",
    "country_settings":{
        "AUS":{
            "disabled":false,
            "representative":true,
            "summary":null
        },
        "BEL":{
            "disabled":false,
            "representative":false,
            "summary":null},
        "BGR":{
            "disabled":false,
            "representative":false,
            "summary":null
        },
        "CAN":{
            "disabled":false,
            "representative":false,
            "summary":null
        },
        "CZE":{
            "disabled":false,
            "representative":false,
            "summary":null
        },
        "DEU":{
            "disabled":false,
            "representative":false,
            "summary":null
        },
        "ESP":{
            "disabled":false,
            "representative":false,"summary":null},"FRA":{"disabled":false,"representative":false,"summary":null},"ISR":{"disabled":false,"representative":false,"summary":null},"JPN":{"disabled":false,"representative":false,"summary":null},"NLD":{"disabled":false,"representative":false,"summary":null},"POL":{"disabled":false,"representative":false,"summary":null},"PRT":{"disabled":false,"representative":false,"summary":null},"UKR":{"disabled":false,"representative":false,"summary":null},
        "USA":{"disabled":false,"representative":false,"summary":null},"ZAF":{"disabled":false,"representative":false,"summary":null}},
    "state":"PAUSED",
    "attr_window":null,
    "inactive_since":"2025-05-12T12:00:21Z",
    "advertiser":"DtOQzAMcYG259xkB",
    "product_name":"RVFu5uBKQjW6TWVC",
    "tracking_link_name":"hXllynFWy8ydDmLR",
    "final_landing_url":"",
    "os":"ANDROID",
    "target_ad_platforms":[],
    "creative_group_names":[],
    "traffic_groups":[{"name":"ALL","ad_groups_with_rank":{"pCH6ZWRwRBnMwbie":35},"user_buckets":[{"start":0,"end":100}],"capper":null,"enable":true}],
    "capper":{"imp_interval":"","imp_format_interval":{},"imp_lifetime":"0","imp_hourly":"0","imp_daily":"0","imp_weekly":"0","imp_monthly":"0",
    "budget":{"daily_spending":0,"hourly_spending":20},"user_event_count":{},"user_event_interval":{}},"currency":"USD",
    "user_capper":{
        "budget":{
            "total_budget":0,
            "total_budget_started_at":"",
            "daily_budget":500,
            "weekday_budget":null,
            "currency":"UNKNOWN_CURRENCY",
            "hourly_budget_pace":{},
            "daily_budget_relaxing_ratio":0,
            "enable_flexible_budget_spending":true,
            "weekly_flexible_budget":3500,
            "type":"UNSPECIFIED_BUDGET_TYPE"},
            "budget_timeline":{
                "most_recent_daily_budget_updated_nano":"1746692943695951000",
                "max_most_recent_daily_budget":800}
            },
            "monthly_budget_emulator":null,
            "advertiser_bidding":null,
            "tracking_company":"APPSFLYER",
            "all_regions":false,
            "system_targets":[
                "block_advertising_app","media_app"],
                "skadn_input":null,
                "feature_whitelist":{"country_settings":{},"pc_migrated":false,"allow_ctv_tr_links":false},"experimental_properties":{"restrict_category":[],"exclusive_deal_ids":[],"extra_app_bundles_for_ctv":[],"jio_support":null,"hotstar_support":null,"allow_reference_common_filters":false,"bid_flow_policy":null,"daily_budget_windows_tmp":[],"dreamgames_support":null,"value_based_bidding":null,"moloco_next_identifier":false},"audience_tags":{},"custom_key_values":{},"creative_pick":null,"ad_tracking_allowance":"NON_LAT_ONLY","timeline":{"liveness_changed_since_ns":"1747051221767295702"},
                "schedule":{"start":"2025-04-28T00:00:00Z","end":""},
                "ad_units":[],
                "deal_settings":null,
                "audience_extension":null,
                "created_timestamp_nano":"1745827865806718000",
                "updated_timestamp_nano":"1747051221770646000",
                "first_activated_timestamp_nano":"1745847182708182000",
                "apt_throttle_tags":[],
                "terminated_timestamp_nano":"0",
                "inventory_feature":null,"publisher_properties":null,"pas_tenant_target":null,"fraud_properties":null,"archived_timestamp_nano":"0"}





*/

DECLARE bundleList ARRAY<STRING> DEFAULT [
    '6739554056',
    'com.run.tower.defense',
    '6448786147',
    'com.fun.lastwar.gp',
    '6443575749',
    'com.gof.global',
    '6469732370',
    'com.wb.goog.dc.dcwc',
    'com.plarium.raidlegends',
    '1371565796',
    '1492005122',
    'com.supercell.clashroyale'
];





WITH app AS (
  SELECT 
    app_market_bundle,
    os,
    dataai.app_name,
    dataai.app_release_date_utc,
  FROM `moloco-ae-view.athena.dim1_app`
), 

netmarble_apps AS (
    SELECT
        product_id,
        app_store_bundle
    FROM `ads-bpd-guard-china.standard_digest.product_digest`
    WHERE
        platform = 'NETMARBLE'
),

product AS (
    SELECT 
        platform,
        app_store_bundle,
        product_id,
        title AS product_title,
        app.app_release_date_utc
    FROM `focal-elf-631.standard_digest.product_digest` pd
      LEFT JOIN app 
      ON pd.app_store_bundle = app.app_market_bundle
    WHERE app_store_bundle IN UNNEST(bundleList)
), 

campaign_kpi AS (
  SELECT 
    t1.platform,
    advertiser_id,
    t1.product_id,
    t2.product_title,
    t2.app_store_bundle,
    t2.app_release_date_utc,
    campaign_id,
    campaign_title,
    campaign_country,
    campaign_goal,
    json_extract(original_json, '$.goal.kpi_actions') AS kpi_actions,
    json_extract(original_json, '$.goal.target_kpi_histories') AS target_kpi_histories,
    json_extract(original_json, '$.goal.main_target_kpi_history') AS main_target_kpi_histories,
    json_extract(original_json, '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas') AS target_kpi_backdating_metadatas,
    DATE(TIMESTAMP(REPLACE(json_extract(original_json, '$.schedule.start'), '\"',''))) AS campaign_start_date,
    TIMESTAMP_DIFF(TIMESTAMP(REPLACE(json_extract(original_json, '$.schedule.start'), '\"','')), TIMESTAMP(app_release_date_utc), DAY) AS days_after_release,
    json_extract(original_json, '$.state') AS state,

    CASE
    WHEN IFNULL(ARRAY_LENGTH(JSON_QUERY_ARRAY(
            original_json,
            '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas'
          )), 0) > 0 THEN
      ARRAY(
        SELECT AS STRUCT
          JSON_VALUE(elem, '$.metric') AS metric,
          SAFE_CAST(JSON_VALUE(elem, '$.target_kpi_values[0].target_kpi') AS NUMERIC) AS target_kpi
        FROM UNNEST(
          JSON_QUERY_ARRAY(original_json,
            '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas')
        ) AS elem
        WITH OFFSET off
        ORDER BY off
      )
    ELSE
      ARRAY(
        SELECT AS STRUCT
          CASE WHEN campaign_goal LIKE '%ROAS%' THEN 'ROAS'
              WHEN campaign_goal LIKE '%CPA%' THEN 'CPA'
              ELSE NULL END AS metric,
          SAFE_CAST(JSON_VALUE(hist_first, '$.target_kpi') AS NUMERIC) AS target_kpi
        FROM (
          SELECT hist_first
          FROM UNNEST(JSON_QUERY_ARRAY(
                  original_json, '$.goal.target_kpi_histories')) AS hist_first
          WITH OFFSET off
          ORDER BY off          
          LIMIT 1
        )
      )
  END AS metric_kpi_arr    
  FROM `focal-elf-631.standard_digest.campaign_digest` t1
    INNER JOIN product t2
    ON t1.platform = t2.platform 
    AND t1.product_id = t2.product_id
  WHERE 
    campaign_goal IN (
      'OPTIMIZE_RETENTION_FOR_APP_UA',
      'OPTIMIZE_ROAS_FOR_APP_UA',
      'OPTIMIZE_CPI_FOR_APP_UA',
      'OPTIMIZE_CPA_FOR_APP_UA'    
    )
    AND json_extract(original_json, '$.schedule.start') IS NOT NULL 
    AND json_extract(original_json, '$.schedule.start') <> '""'
  ORDER BY campaign_start_date

)

SELECT * 
FROM campaign_kpi, UNNEST(metric_kpi_arr) metric_kpi_arr
WHERE metric_kpi_arr.metric IS NOT NULL




### for netmarble campaigns ###

WITH app AS (
  SELECT 
    app_market_bundle,
    os,
    dataai.app_name,
    dataai.app_release_date_utc,
  FROM `moloco-ae-view.athena.dim1_app`
), 

netmarble_apps AS (
    SELECT
        product_id,
        app_store_bundle
    FROM `ads-bpd-guard-china.standard_digest.product_digest`
    WHERE
        platform = 'NETMARBLE'
),

product AS (
    SELECT 
        pd.platform,
        pd.app_store_bundle,
        pd.product_id,
        pd.title AS product_title,
        app.app_release_date_utc
    FROM `focal-elf-631.standard_digest.product_digest` pd
      INNER JOIN netmarble_apps na
      ON pd.product_id = na.product_id 
      AND pd.app_store_bundle = na.app_store_bundle
      LEFT JOIN app 
      ON pd.app_store_bundle = app.app_market_bundle    
), 

campaign_kpi AS (
  SELECT 
    t1.platform,
    advertiser_id,
    t1.product_id,
    t2.product_title,
    t2.app_store_bundle,
    t2.app_release_date_utc,
    campaign_id,
    campaign_title,
    campaign_country,
    campaign_goal,
    json_extract(original_json, '$.goal.kpi_actions') AS kpi_actions,
    json_extract(original_json, '$.goal.target_kpi_histories') AS target_kpi_histories,
    json_extract(original_json, '$.goal.main_target_kpi_history') AS main_target_kpi_histories,
    json_extract(original_json, '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas') AS target_kpi_backdating_metadatas,
    DATE(TIMESTAMP(REPLACE(json_extract(original_json, '$.schedule.start'), '\"',''))) AS campaign_start_date,
    TIMESTAMP_DIFF(TIMESTAMP(REPLACE(json_extract(original_json, '$.schedule.start'), '\"','')), TIMESTAMP(app_release_date_utc), DAY) AS days_after_release,
    json_extract(original_json, '$.state') AS state,

    CASE
    WHEN IFNULL(ARRAY_LENGTH(JSON_QUERY_ARRAY(
            original_json,
            '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas'
          )), 0) > 0 THEN
      ARRAY(
        SELECT AS STRUCT
          JSON_VALUE(elem, '$.metric') AS metric,
          SAFE_CAST(JSON_VALUE(elem, '$.target_kpi_values[0].target_kpi') AS NUMERIC) AS target_kpi
        FROM UNNEST(
          JSON_QUERY_ARRAY(original_json,
            '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas')
        ) AS elem
        WITH OFFSET off
        ORDER BY off
      )
    ELSE
      ARRAY(
        SELECT AS STRUCT
          CASE WHEN campaign_goal LIKE '%ROAS%' THEN 'ROAS'
              WHEN campaign_goal LIKE '%CPA%' THEN 'CPA'
              ELSE NULL END AS metric,
          SAFE_CAST(JSON_VALUE(hist_first, '$.target_kpi') AS NUMERIC) AS target_kpi
        FROM (
          SELECT hist_first
          FROM UNNEST(JSON_QUERY_ARRAY(
                  original_json, '$.goal.target_kpi_histories')) AS hist_first
          WITH OFFSET off
          ORDER BY off          
          LIMIT 1
        )
      )
  END AS metric_kpi_arr    
  FROM `focal-elf-631.standard_digest.campaign_digest` t1
    INNER JOIN product t2
    ON t1.platform = t2.platform 
    AND t1.product_id = t2.product_id
  WHERE 
    campaign_goal IN (
      'OPTIMIZE_RETENTION_FOR_APP_UA',
      'OPTIMIZE_ROAS_FOR_APP_UA',
      'OPTIMIZE_CPI_FOR_APP_UA',
      'OPTIMIZE_CPA_FOR_APP_UA'    
    )
    AND json_extract(original_json, '$.schedule.start') IS NOT NULL 
    AND json_extract(original_json, '$.schedule.start') <> '""'
  ORDER BY campaign_start_date

)

SELECT * 
FROM campaign_kpi, UNNEST(metric_kpi_arr) metric_kpi_arr
WHERE metric_kpi_arr.metric IS NOT NULL





##### kpi 유무에 따른 캠페인 갯수 #####

WITH app AS (
  SELECT 
    app_market_bundle,
    os,
    dataai.app_name,
    -- app_release_date_utc가 STRING일 수 있으므로 안전 파싱
    SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S%Ez', CAST(dataai.app_release_date_utc AS STRING)) AS app_release_ts
  FROM `moloco-ae-view.athena.dim1_app`
),
netmarble_apps AS (
  SELECT product_id, app_store_bundle
  FROM `ads-bpd-guard-china.standard_digest.product_digest`
  WHERE platform = 'NETMARBLE'
),
product AS (
  SELECT 
    platform,
    app_store_bundle,
    product_id,
    title AS product_title,
    app.app_release_ts
  FROM `focal-elf-631.standard_digest.product_digest` pd
  LEFT JOIN app 
    ON pd.app_store_bundle = app.app_market_bundle
  WHERE app_store_bundle IN UNNEST([
    '6739554056','com.run.tower.defense','6448786147','com.fun.lastwar.gp',
    '6443575749','com.gof.global','6469732370','com.wb.goog.dc.dcwc',
    'com.plarium.raidlegends','1371565796','1492005122','com.supercell.clashroyale'
  ])
),
campaign_kpi AS (
  SELECT 
    t1.platform,
    advertiser_id,
    t1.product_id,
    t2.product_title,
    t2.app_store_bundle,
    t2.app_release_ts,
    campaign_id,
    campaign_title,
    campaign_country,
    campaign_goal,

    JSON_VALUE(original_json, '$.goal.kpi_actions') AS kpi_actions,
    JSON_VALUE(original_json, '$.goal.target_kpi_histories') AS target_kpi_histories,
    JSON_VALUE(original_json, '$.goal.main_target_kpi_history') AS main_target_kpi_histories,
    JSON_VALUE(original_json, '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas') AS target_kpi_backdating_metadatas,

    -- 스케줄 시작시간: 빈 문자열/형식 오류 안전 처리
    SAFE.PARSE_TIMESTAMP(
      '%Y-%m-%dT%H:%M:%E*S%Ez',
      NULLIF(JSON_VALUE(original_json, '$.schedule.start'), '')
    ) AS campaign_start_ts,

    DATE(
      SAFE.PARSE_TIMESTAMP(
        '%Y-%m-%dT%H:%M:%E*S%Ez',
        NULLIF(JSON_VALUE(original_json, '$.schedule.start'), '')
      )
    ) AS campaign_start_date,

    SAFE.TIMESTAMP_DIFF(
      SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', NULLIF(JSON_VALUE(original_json, '$.schedule.start'), '')),
      t2.app_release_ts,
      DAY
    ) AS days_after_release,

    JSON_VALUE(original_json, '$.state') AS state,

    CASE
      WHEN IFNULL(ARRAY_LENGTH(JSON_QUERY_ARRAY(
             original_json,
             '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas'
           )), 0) > 0 THEN
        ARRAY(
          SELECT AS STRUCT
            JSON_VALUE(elem, '$.metric') AS metric,
            SAFE_CAST(JSON_VALUE(elem, '$.target_kpi_values[0].target_kpi') AS NUMERIC) AS target_kpi
          FROM UNNEST(
            JSON_QUERY_ARRAY(original_json, '$.goal.main_target_kpi_history.target_kpi_backdating_metadatas')
          ) AS elem
          WITH OFFSET off
          ORDER BY off
        )
      ELSE
        ARRAY(
          SELECT AS STRUCT
            CASE WHEN campaign_goal LIKE '%ROAS%' THEN 'ROAS'
                 WHEN campaign_goal LIKE '%CPA%'  THEN 'CPA'
                 ELSE NULL END AS metric,
            SAFE_CAST(JSON_VALUE(hist_first, '$.target_kpi') AS NUMERIC) AS target_kpi
          FROM (
            SELECT hist_first
            FROM UNNEST(JSON_QUERY_ARRAY(original_json, '$.goal.target_kpi_histories')) AS hist_first
            WITH OFFSET off
            ORDER BY off
            LIMIT 1
          )
        )
    END AS metric_kpi_arr
  FROM `focal-elf-631.standard_digest.campaign_digest` t1
  INNER JOIN product t2
    ON t1.platform = t2.platform 
   AND t1.product_id = t2.product_id
  WHERE campaign_goal IN (
    'OPTIMIZE_RETENTION_FOR_APP_UA',
    'OPTIMIZE_ROAS_FOR_APP_UA',
    'OPTIMIZE_CPI_FOR_APP_UA',
    'OPTIMIZE_CPA_FOR_APP_UA'
  )
)
-- SELECT *
-- FROM campaign_kpi, UNNEST(metric_kpi_arr) metric_kpi_arr
-- -- 필요시 시작시간 있는 것만:
-- -- WHERE campaign_start_ts IS NOT NULL
-- ORDER BY campaign_start_date NULLS LAST;

SELECT
  campaign_goal,
  COUNT(DISTINCT campaign_id)                                            AS total_all,
  COUNT(DISTINCT IF(ARRAY_LENGTH(metric_kpi_arr) > 0, campaign_id, NULL)) AS with_kpi,
  COUNT(DISTINCT IF(ARRAY_LENGTH(metric_kpi_arr) = 0, campaign_id, NULL)) AS without_kpi
FROM campaign_kpi
-- WHERE campaign_goal IN (
--   'OPTIMIZE_ROAS_FOR_APP_UA',
--   'OPTIMIZE_CPA_FOR_APP_UA',
--   'OPTIMIZE_CPI_FOR_APP_UA'
-- )
GROUP BY 1
ORDER BY 1;


<Result>
Row	campaign_goal	total_all	with_kpi	without_kpi
1	OPTIMIZE_CPA_FOR_APP_UA	67	8	59
2	OPTIMIZE_CPI_FOR_APP_UA	50	15	35
3	OPTIMIZE_ROAS_FOR_APP_UA	322	175	147