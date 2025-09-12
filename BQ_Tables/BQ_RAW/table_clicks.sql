/*
- focal-elf-631.prod_stream_view.clicks
- Clicks from a Moloco campaign

SCHEMA
- timestamp
- platform_id
- advertiser_id
- req
- bid
- api
  - platform
  - advertiser
  - product
  - campaign
    - id
    - title
    - skan_id
    - skan_tr_suffix
  - trgroup
  - adgroup
  - crgroup
  - creative
  - tracking_links
- imp
- imp_extra
- ev
- ec
- click
- compliance

table_catalog	table_schema	table_name	column_name	ordinal_position	data_type
focal-elf-631	prod_stream_view	click	_uid_	1	STRING
focal-elf-631	prod_stream_view	click	timestamp	2	TIMESTAMP
focal-elf-631	prod_stream_view	click	platform_id	3	STRING
focal-elf-631	prod_stream_view	click	advertiser_id	4	STRING
focal-elf-631	prod_stream_view	click	req	5	"STRUCT<timestamp TIMESTAMP, exchange STRING, bid_region STRING, bid_id STRING, app STRUCT<bundle STRING, encoded_bundle STRING, id STRING, publisher STRUCT<id STRING, name STRING>, ver STRING>, site STRUCT<id STRING, domain STRING, page STRING, publisher STRUCT<id STRING, name STRING>>, device STRUCT<ifa STRING, anonymized_ifa STRING, os STRING, osv STRING, carrier STRING, connectiontype STRING, hwv STRING, make STRING, model STRING, model_norm STRING, devicetype STRING, language STRING, ip STRING, iptype STRING, geo STRUCT<utcoffset INT64, region STRING, country STRING, city STRING, zip STRING, metro STRING, lat FLOAT64, lon FLOAT64>, lmt BOOL, atts STRING, ua STRING, aux STRUCT<ip_data STRUCT<ip2asn STRUCT<range_start_ip STRING, usage STRING, asn INT64, isp STRING>>, geo_targeting_region STRING>>, imp STRUCT<bidfloor STRUCT<currency STRING, amount_micro INT64>, tagid STRING, adunitname STRING, instl BOOL, banner STRUCT<w INT64, h INT64, playable_type STRING>, video STRUCT<w INT64, h INT64, maxduration_sec INT64, minduration_sec INT64, skip BOOL, skipafter INT64, ext_rewarded BOOL, placement INT64, skipmin INT64>, native STRUCT<ext_has_image BOOL, ext_has_video BOOL>, inventory_format STRING, pmp STRUCT<deal STRUCT<id STRING>>, displaymanagerver STRING, displaymanager STRING, video_type STRING, exp INT64, inventory_format_signal INT64>, ext STRUCT<skadn STRUCT<version STRING, ifv STRING, anonymized_ifv STRING, skoverlay_eligible BOOL, autostore_eligible BOOL>, sdk STRUCT<publisher_platform_id STRING>, pas STRUCT<is_pas BOOL>, inventory_feature STRUCT<auto_inline_install_eligible BOOL, double_end_card_eligible BOOL>, effective_publisher_rate FLOAT64, auction_id STRING, app_set_id STRING>, `at` STRING, misc_json STRING, tmax INT64, internal_bid_id STRING>"
focal-elf-631	prod_stream_view	click	bid	6	"STRUCT<timestamp TIMESTAMP, mtid STRING, maid STRING, anonymized_maid STRING, bid_price STRUCT<currency STRING, amount_micro INT64>, IsTest BOOL, ext STRUCT<skadn STRUCT<campaign_id INT64>, inventory_feature STRUCT<enable_skoverlay BOOL, enable_engaged_click_for_skoverlay BOOL, enable_engaged_view_click BOOL, enable_autostore BOOL, enable_storekit_click BOOL, enable_double_end_card BOOL, enable_engaged_click BOOL, enable_imp_based_click BOOL, throttled_by_feature_based_sct BOOL, throttled_by_imp_based_sct BOOL>>, aux STRUCT<ignore_mmp_feedback BOOL, header_bidding_multiplier FLOAT64>, MODEL STRUCT<pricing_function STRING, pricing_name STRING, core STRUCT<pred FLOAT64, threshold FLOAT64, prediction_type STRING, ref_campaign STRING, context_name STRING, tf_model_name STRING, reason STRING, context_revision STRING, latency_ns INT64, wrapper STRUCT<normalizer FLOAT64, normalizer_from_tfserving BOOL, mixture_ratio FLOAT64, multiplier FLOAT64>, type STRING, prediction_type_mix_rate FLOAT64>, wrapper STRUCT<pred FLOAT64, threshold FLOAT64, prediction_type STRING, ref_campaign STRING, context_name STRING, tf_model_name STRING, reason STRING, context_revision STRING, latency_ns INT64, wrapper STRUCT<normalizer FLOAT64, normalizer_from_tfserving BOOL, mixture_ratio FLOAT64, multiplier FLOAT64>, type STRING, prediction_type_mix_rate FLOAT64>, multipliers STRUCT<converted_target FLOAT64, budget FLOAT64, calibration FLOAT64, exp FLOAT64>, bid_former STRUCT<fpa STRUCT<name STRING, in_cpm FLOAT64, out_cpm FLOAT64>, generic ARRAY<STRUCT<name STRING, in_cpm FLOAT64, out_cpm FLOAT64>>, out_cpm FLOAT64, win_pred FLOAT64>, value_price INT64, bid_price INT64, prediction_logs ARRAY<STRUCT<type STRING, pred FLOAT64, threshold FLOAT64, prediction_type STRING, prediction_type_mix_rate FLOAT64, ref_campaign STRING, context_name STRING, tf_model_name STRING, reason STRING, context_revision STRING, latency_ns INT64, wrapper STRUCT<normalizer FLOAT64, normalizer_from_tfserving BOOL, mixture_ratio FLOAT64, multiplier FLOAT64, vt_ratio FLOAT64>, base_model_prediction FLOAT64>>, p_value FLOAT64>, experiment STRUCT<ids_v1 ARRAY<INT64>, ids_v2 ARRAY<INT64>, counterfactual_tags ARRAY<STRUCT<group_id INT64, VALUES ARRAY<STRING>>>, custom_slices ARRAY<STRUCT<group_id INT64, VALUES ARRAY<STRING>>>, ids_v2_assigned ARRAY<INT64>, ids_v2_all ARRAY<STRUCT<group_id INT64, is_global_conducted BOOL, is_conducted BOOL>>, bin_number INT64>, cr_pick_log STRUCT<picker STRING, num_candidates INT64, score FLOAT64, reason STRING>, market_model STRUCT<name STRING, mu FLOAT64, sigma FLOAT64, clearing FLOAT64>, seatbid STRUCT<seat STRING>, rendezvous_bid STRUCT<test_and_submit_result STRING, partition_model STRING, auction_model STRING, `partition` STRUCT<submissions ARRAY<STRUCT<exec_id STRING, exchange STRING, winners ARRAY<STRUCT<bid_price STRUCT<currency STRING, amount_micro INT64>, value_price STRUCT<currency STRING, amount_micro INT64>>>>>>>, pricing_ext_src_revision INT64>"
focal-elf-631	prod_stream_view	click	api	7	"STRUCT<platform STRUCT<id STRING, title STRING>, advertiser STRUCT<id STRING, title STRING>, product STRUCT<id STRING, title STRING, app STRUCT<store_id STRING, tracking_bundle STRING, mmp STRING>>, campaign STRUCT<id STRING, title STRING, skadn_id INT64, skadn_tr_suffix STRING>, trgroup STRUCT<id STRING, title STRING, user_bucket INT64>, adgroup STRUCT<id STRING, title STRING, report_tag STRING, skan_id INT64>, crgroup STRUCT<id STRING, title STRING, report_group STRING>, creative STRUCT<crid STRING, id STRING, format STRING, cr_format STRING, title STRING, w INT64, h INT64, size_in_bytes INT64, video_duration_sec INT64, video_endcard_format STRING, video_endcard_file STRING>, tracking_links ARRAY<STRUCT<id STRING, mmp STRING, title STRING, vt STRUCT<raw STRING, json STRING>, ct STRUCT<raw STRING, json STRING>, updated_at TIMESTAMP>>>"
focal-elf-631	prod_stream_view	click	imp	8	"STRUCT<received_at TIMESTAMP, handled_at TIMESTAMP, happened_at TIMESTAMP, client_ip STRING, win_price_usd STRUCT<currency STRING, amount_micro INT64>, win_price_adv STRUCT<currency STRING, amount_micro INT64>, win_price_exc STRUCT<currency STRING, amount_micro INT64>, client_ua STRING, client_header STRUCT<x_device_ip STRING, x_device_ua STRING>, s2s_links ARRAY<STRUCT<id STRING, updated_at TIMESTAMP, link STRUCT<raw STRING, json STRING>>>, sdk_ext STRUCT<client_timestamp TIMESTAMP, device STRUCT<os STRING, os_ver STRING, model STRING, screen_scale FLOAT64>, app STRUCT<id STRING, ver STRING>, network STRUCT<connection_type STRING, carrier STRING>, sdk STRUCT<core_ver STRING, adapter_ver STRING>, mref STRING>, client_ip_data STRUCT<ip2asn STRUCT<range_start_ip STRING, usage STRING, asn INT64, isp STRING>>, cost STRUCT<billing STRUCT<type STRING, demand_charge_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>, demand_media_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>, supply_media_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>>, analysis STRUCT<win_price STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>, demand_charge_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>>>>"
focal-elf-631	prod_stream_view	click	imp_extra	9	"STRUCT<received_at TIMESTAMP, handled_at TIMESTAMP, happened_at TIMESTAMP, client_ip STRING, event_type STRING, client_ua STRING, client_header STRUCT<x_device_ip STRING, x_device_ua STRING>>"
focal-elf-631	prod_stream_view	click	ev	10	"STRUCT<received_at TIMESTAMP, handled_at TIMESTAMP, happened_at TIMESTAMP, client_ip STRING, client_ua STRING, ev_origin_asset STRING, s2s_mmp_url STRING, is_fire_click_link BOOL>"
focal-elf-631	prod_stream_view	click	ec	11	"STRUCT<received_at TIMESTAMP, handled_at TIMESTAMP, happened_at TIMESTAMP, client_ip STRING, client_ua STRING, ec_origin_asset STRING, mmp STRUCT<name STRING, is_reported BOOL, s2s_url STRING>>"
focal-elf-631	prod_stream_view	click	click	12	"STRUCT<received_at TIMESTAMP, handled_at TIMESTAMP, happened_at TIMESTAMP, client_ip STRING, type STRING, ip STRING, client_ua STRING, click_cookie_id STRING, generated_click_url STRING, s2s_mmp_url STRING, dcr STRUCT<catalog_item_id STRING>, click_origin_asset STRING, sdk_ext STRUCT<client_timestamp TIMESTAMP, device STRUCT<os STRING, os_ver STRING, model STRING, screen_scale FLOAT64>, app STRUCT<id STRING, ver STRING>, network STRUCT<connection_type STRING, carrier STRING>, sdk STRUCT<core_ver STRING, adapter_ver STRING>, interaction STRUCT<position STRUCT<x_pts FLOAT64, y_pts FLOAT64>, screen_size STRUCT<w_pts FLOAT64, h_pts FLOAT64>, view_position STRUCT<x_pts FLOAT64, y_pts FLOAT64>, view_size STRUCT<w_pts FLOAT64, h_pts FLOAT64>, buttons ARRAY<STRUCT<type STRING, pos STRUCT<x_pts FLOAT64, y_pts FLOAT64>, size STRUCT<w_pts FLOAT64, h_pts FLOAT64>>>>, mref STRING>, client_ip_data STRUCT<ip2asn STRUCT<range_start_ip STRING, usage STRING, asn INT64, isp STRING>>>"
focal-elf-631	prod_stream_view	click	compliance	13	STRUCT<is_anonymized BOOL>
*/


-- impact of click without catalog_id

DECLARE run_from_date DATE DEFAULT "2024-01-01";
DECLARE run_to_date DATE DEFAULT "2024-12-09";

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
# impressions with bid_region=’ASIA’, clicks and click url w.o. catalog_id

WITH
  advertiser AS (
    SELECT
      *,
      COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), run_to_date) AS last_effective_date_local,
    FROM
    (
      SELECT
        DISTINCT
        effective_date_local,
        platform.id AS platform_id,
        advertiser.id AS advertiser_id,
        advertiser.timezone AS advertiser_timezone,
        platform.serving_cost_percent AS platform_serving_cost_percent,
        platform.contract_markup_percent AS platform_markup_percent
      FROM
        `moloco-dsp-data-source.costbook.costbook`
      WHERE
        campaign.country = 'KOR'
      AND
        advertiser.id IN ('HKRCcBXgyO9rR9Pb', 'DyD0GQNf7zlp4hwy')
      AND
        DATE_DIFF(run_to_date, effective_date_local, DAY) >=0
    )
  ),

  advertiser_timezone AS (
    SELECT
      DISTINCT
      platform_id,
      advertiser_id,
      advertiser_timezone
    FROM
      advertiser
  ), 
  
  click_raw_t AS (
    SELECT
        platform_id,
        advertiser_id,
        click.happened_at as timestamp,
        bid.mtid,
        click.generated_click_url,
        REGEXP_EXTRACT(click.generated_click_url, r'&af_dp=([^&]*)') AS catalog_item_id,
        imp.win_price_usd.amount_micro AS media_cost
    FROM
      `focal-elf-631.prod_stream_view.click`
    WHERE 
      DATE(timestamp) BETWEEN run_from_date AND run_to_date
      AND advertiser_id IN ('HKRCcBXgyO9rR9Pb', 'DyD0GQNf7zlp4hwy')
      AND req.bid_region = 'ASIA'
      AND api.creative.cr_format in ("di", "db")
  ),

  click_join_t AS (
    SELECT
      C.platform_id,
      C.advertiser_id,
      DATE(C.timestamp, A.advertiser_timezone) AS local_date,
      A.platform_serving_cost_percent,
      A.platform_markup_percent,
      SUM(C.media_cost / 1e6) AS win_price_usd,
      COUNT(DISTINCT C.mtid) AS imp,
    FROM click_raw_t C
    JOIN  advertiser AS A
    ON C.platform_id=A.platform_id
      AND C.advertiser_id=A.advertiser_id
      AND A.effective_date_local<=DATE(C.timestamp, A.advertiser_timezone)
      AND DATE(C.timestamp, A.advertiser_timezone)<=A.last_effective_date_local
    WHERE
      catalog_item_id IS NULL
    GROUP BY ALL
  )

SELECT
  C.platform_id,
  C.advertiser_id,
  C.local_date,
  SAFE_CAST(SUM(C.win_price_usd * (1 + C.platform_serving_cost_percent/100) * (1 + C.platform_markup_percent/100)) AS FLOAT64) AS gross_spending_usd,
  SUM(C.imp) AS imp,
FROM
  click_join_t AS C
GROUP BY ALL
