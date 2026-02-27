
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