WITH
      advertiser_tab AS (
        SELECT
          office,
          CASE
            WHEN office = 'EMEA' THEN 'EMEA'
            WHEN office = 'USA' THEN 'AMER'
            WHEN office IN ('KOR', 'IND', 'JPN', 'SGP', 'CHN') THEN 'APAC'
            ELSE 'Other'
          END AS region,
          tier,
          account_manager,
          advertiser_id
        FROM
          (
            SELECT
              date_utc,
              ROW_NUMBER() OVER(PARTITION BY advertiser_id ORDER BY date_utc DESC, effective_date DESC) AS rnk,
              advertiser_id,
              office,
              account_manager,
              tier,
              effective_date,
              end_date
            FROM
              `moloco-ae-view.athena.dim2_platform_advertiser_daily`
          )
        WHERE
          rnk = 1
      ),

      campaign_tab as (
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
          CASE
            WHEN app.is_gaming = true THEN 'gaming'
            WHEN app.is_gaming = false THEN 'non-gaming'
            ELSE 'N/A'
          END AS gaming,
          a.os,
          JSON_EXTRACT_SCALAR(campaign_goal, "$.type") AS campaign_goal,
          campaign_name AS campaign_id,
          campaign_display_name AS campaign,
          DATE(created_timestamp_nano) AS campaign_start_date
        FROM
          `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
        LEFT JOIN
          advertiser_tab b
        ON
          a.advertiser_name = b.advertiser_id
        LEFT JOIN
          `ads-bpd-guard-china.athena.dim1_product` c
        ON
          a.product_name = c.product_id
        WHERE
          state = "ACTIVE"
          AND enabled
          AND a.os IN ('IOS', 'ANDROID')
      ),

      adgroup_tab as (
        SELECT
          ad_group_id,
          campaign_id,
          target_id
        FROM
          `ads-bpd-guard-china.standard_digest.ad_group_digest`
        CROSS JOIN
          UNNEST(JSON_VALUE_ARRAY(original_json, "$.user_targets")) as target_id
        WHERE
          NOT is_archived
          AND JSON_EXTRACT_SCALAR(original_json, "$.disabled") = 'false'
      ),

################### <START> CTE''s of exclusion targeting ###################
      target_tab AS (
        SELECT
          id AS target_id,
          JSON_QUERY(original_json, "$.condition") AS condition_json,
        FROM
          `focal-elf-631.standard_digest.audience_target_digest`
      ),

      potential_blocked_dimension AS (
        SELECT
          DISTINCT 
          office,
          region,
          tier,
          account_manager,
          platform_name,
          advertiser_id,
          advertiser,
          store_bundle,
          tracking_bundle,
          product_category,
          os,
          campaign_goal,
          campaign_id,
          campaign,
          campaign_start_date,
          ad_group_id                  
          target_id,
          condition_json,
          IF(JSON_EXTRACT(condition_json, '$.blocked_countries') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_countries'), ','))) AS blocked_countries,
          IF(JSON_EXTRACT(condition_json, '$.blocked_apps') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_apps'), ','))) AS blocked_apps,
          IF(JSON_EXTRACT(condition_json, '$.blocked_categories') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_categories'), ','))) AS blocked_categories,
          IF(JSON_EXTRACT(condition_json, '$.blocked_cities') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_cities'), ','))) AS blocked_cities,
          IF(JSON_EXTRACT(condition_json, '$.blocked_audiences') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_audiences'), ','))) AS blocked_audiences,
          IF(JSON_EXTRACT(condition_json, '$.blocked_cr_formats') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_cr_formats'), ','))) AS blocked_cr_formats,
          IF(JSON_EXTRACT(condition_json, '$.blocked_creative_formats') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_creative_formats'), ','))) AS blocked_creative_formats,
          IF(JSON_EXTRACT(condition_json, '$.blocked_sites') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_sites'), ','))) AS blocked_sites,
          IF(JSON_EXTRACT(condition_json, '$.blocked_geofences') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_geofences'), '},'))) AS blocked_geofences,
          IF(JSON_EXTRACT(condition_json, '$.blocked_exchanges') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_exchanges'), ','))) AS blocked_exchanges,
          IF(JSON_EXTRACT(condition_json, '$.blocked_idfas') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_idfas'), ','))) AS blocked_idfas,
          IF(JSON_EXTRACT(condition_json, '$.blocked_zipcodes') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_zipcodes'), ','))) AS blocked_zipcodes,
          IF(JSON_EXTRACT(condition_json, '$.blocked_device_models') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_device_models'), '",'))) AS blocked_device_models,
          IF(JSON_EXTRACT(condition_json, '$.blocked_user_tag_audiences') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_user_tag_audiences'), ','))) AS blocked_user_tag_audiences,
          IF(JSON_EXTRACT(condition_json, '$.blocked_languages') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_languages'), ','))) AS blocked_languages,
          IF(JSON_EXTRACT(condition_json, '$.blocked_direct_deal_ids') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_direct_deal_ids'), ','))) AS blocked_direct_deal_ids,
          IF(JSON_EXTRACT(condition_json, '$.blocked_device_types') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_device_types'), ','))) AS blocked_device_types,
          IF(JSON_EXTRACT(condition_json, '$.blocked_banner_apis') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_banner_apis'), ','))) AS blocked_banner_apis,
          IF(JSON_EXTRACT(condition_json, '$.blocked_video_types') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_video_types'), ','))) AS blocked_video_types,
          IF(JSON_EXTRACT(condition_json, '$.blocked_mostly_visited_countries') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_mostly_visited_countries'), ','))) AS blocked_mostly_visited_countries,
          IF(JSON_EXTRACT(condition_json, '$.blocked_regions') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_regions'), ','))) AS blocked_regions,
          IF(JSON_EXTRACT(condition_json, '$.blocked_gender_score') IS NULL, 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_gender_score'), ','))) AS blocked_gender_score,
          IF(JSON_EXTRACT(condition_json, '$.blocked_ages') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_ages'), '},'))) AS blocked_ages,
          IF(JSON_EXTRACT(condition_json, '$.blocked_recent_campaign_activities') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_recent_campaign_activities'), ','))) AS blocked_recent_campaign_activities,
          IF(JSON_EXTRACT(condition_json, '$.blocked_postback_has_all_events_conditions') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_postback_has_all_events_conditions'), ','))) AS blocked_postback_has_all_events_conditions,
          IF(JSON_EXTRACT(condition_json, '$.blocked_postback_has_any_events_conditions') = '[]', 0, ARRAY_LENGTH(SPLIT(REGEXP_EXTRACT(JSON_EXTRACT(condition_json, '$.blocked_postback_has_any_events_conditions'), r'"events":\s*\[([^]]*)\]'), ','))) AS blocked_postback_has_any_events_conditions,
          IF(JSON_EXTRACT(condition_json, '$.blocked_locations') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_locations'), ','))) AS blocked_locations,
          IF(JSON_EXTRACT(condition_json, '$.blocked_ip_ranges') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_ip_ranges'), ','))) AS blocked_ip_ranges,
          IF(JSON_EXTRACT(condition_json, '$.blocked_device_carriers') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_device_carriers'), ','))) AS blocked_device_carriers,
          IF(JSON_EXTRACT(condition_json, '$.blocked_apps_by_checksum') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_apps_by_checksum'), ','))) AS blocked_apps_by_checksum,
          IF(JSON_EXTRACT(condition_json, '$.blocked_dcr_user_signal_events') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_dcr_user_signal_events'), ','))) AS blocked_dcr_user_signal_events,
          IF(JSON_EXTRACT(condition_json, '$.blocked_apt_tags') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_apt_tags'), ','))) AS blocked_apt_tags,
          IF(JSON_EXTRACT(condition_json, '$.blocked_ad_units') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_ad_units'), ','))) AS blocked_ad_units,
          IF(JSON_EXTRACT(condition_json, '$.blocked_placements') = '[]' OR JSON_EXTRACT(condition_json, '$.blocked_placements') IS NULL, 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_placements'), ','))) AS blocked_placements,
          IF(JSON_EXTRACT(condition_json, '$.blocked_dev_makes') = '[]', 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_dev_makes'), ','))) AS blocked_dev_makes,
          IF(JSON_EXTRACT(condition_json, '$.blocked_location_set') IS NULL, 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_location_set'), ','))) AS blocked_location_set,
          IF(JSON_EXTRACT(condition_json, '$.blocked_publisher_custom_targeting_key_values') IS NULL, 0, ARRAY_LENGTH(SPLIT(JSON_EXTRACT(condition_json, '$.blocked_publisher_custom_targeting_key_values'), ','))) AS blocked_publisher_custom_targeting_key_values
        FROM
          campaign_tab
        JOIN
          adgroup_tab
        USING
          (campaign_id)
        JOIN
          target_tab
        USING
          (target_id)
      ),
            
            
    target_kpi_tab AS (
        SELECT
          campaign_id,
          target_KPI
        FROM (
          SELECT
            campaign_id,
            JSON_VALUE(target_kpi, "$.target_kpi") AS target_KPI,
            JSON_VALUE(target_kpi, "$.timestamp_nano") AS target_KPI_timestamp,
            RANK() OVER(PARTITION BY campaign_id ORDER BY JSON_VALUE(target_kpi, "$.timestamp_nano") DESC) AS ts_rnk
          FROM
            `ads-bpd-guard-china.standard_digest.campaign_digest`,
            UNNEST(JSON_QUERY_ARRAY(original_json, "$.goal.target_kpi_histories")) AS target_kpi
          )
        WHERE ts_rnk = 1
      ),

      campaign_summary_tab AS (
        SELECT
          campaign_id,
          SUM(gross_spend_usd) AS last_30_day_spend,
          SAFE_DIVIDE(SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)), gross_spend_usd, 0)), SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)), installs, 0))) AS CPI,
          SAFE_DIVIDE(SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)), gross_spend_usd, 0)), SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)), kpi_actions_d7, 0))) AS D7_CPA,
          SAFE_DIVIDE(SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)), kpi_pb_revenue_d7, 0)), SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)), gross_spend_usd, 0))) * 100 AS D7_ROAS,
          CAST(SAFE_DIVIDE(SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)), kpi_users_d7, 0)), COUNT(DISTINCT IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)), date_utc, NULL))) AS INT64) AS avg_daily_D7_kpi_user,
          CAST(SAFE_DIVIDE(SUM(IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)), kpi_actions, 0)), COUNT(DISTINCT IF((date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)), date_utc, NULL))) AS INT64) AS avg_daily_kpi_L7,
          CAST(SAFE_DIVIDE(SUM(kpi_actions), COUNT(DISTINCT date_utc)) AS INT64) AS avg_daily_kpi_L30
        FROM
          `ads-bpd-guard-china.athena.fact_dsp_core`
        WHERE
          date_utc BETWEEN DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY) AND DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
        GROUP BY 1
      )


SELECT *
FROM potential_blocked_dimension
WHERE platform_name = 'NETMARBLE'