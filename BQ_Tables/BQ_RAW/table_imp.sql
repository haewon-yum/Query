/*
- focal-elf-631.prod_stream_view.imp
- impression from a Moloco campaign
- Sampled? 1/1
- DS team can join this table with other tables to calculate CTR, identify specific types of fraud and actual i2i rates.
- If really need imp level data for a long period of time, can use this table: focal-elf-631.prod_stream_sampled.imp_1to100

Ref
- ML validation i2i

SCHEMA
- _uid_
- timestamp
- platform_id
- advertiser_id
- req
  - app
  - site
  - device
    - ifa
    - os
    - osv 
    - model
    - model_norm
    - ip
    - iptype
    - country
    - session_count
    - ua
    - ifv
    - anonymized_ifv
    - lauguage
    - name
    - name
    - appsetid
  - publisher
    - ...
  - ..
- bid
  - mtid
  - maid
  - ...
- api
    - platform
        -...d
    - advertiser
        - ...
    - product
        - ...
    - campaign
        - id
        - title
        - skadn_id
        - skadn_tr_suffix
    - trgroup
    - ...
- imp
- compliance

table_catalog	table_schema	table_name	column_name	ordinal_position	data_type
focal-elf-631	prod_stream_view	imp	_uid_	1	STRING
focal-elf-631	prod_stream_view	imp	timestamp	2	TIMESTAMP
focal-elf-631	prod_stream_view	imp	platform_id	3	STRING
focal-elf-631	prod_stream_view	imp	advertiser_id	4	STRING
focal-elf-631	prod_stream_view	imp	req	5	"STRUCT<timestamp TIMESTAMP, exchange STRING, bid_region STRING, bid_id STRING, app STRUCT<bundle STRING, encoded_bundle STRING, id STRING, publisher STRUCT<id STRING, name STRING>, ver STRING>, site STRUCT<id STRING, domain STRING, page STRING, publisher STRUCT<id STRING, name STRING>>, device STRUCT<ifa STRING, anonymized_ifa STRING, os STRING, osv STRING, carrier STRING, connectiontype STRING, hwv STRING, make STRING, model STRING, model_norm STRING, devicetype STRING, language STRING, ip STRING, iptype STRING, geo STRUCT<utcoffset INT64, region STRING, country STRING, city STRING, zip STRING, metro STRING, lat FLOAT64, lon FLOAT64>, lmt BOOL, atts STRING, ua STRING, aux STRUCT<ip_data STRUCT<ip2asn STRUCT<range_start_ip STRING, usage STRING, asn INT64, isp STRING>>, geo_targeting_region STRING>>, imp STRUCT<bidfloor STRUCT<currency STRING, amount_micro INT64>, tagid STRING, adunitname STRING, instl BOOL, banner STRUCT<w INT64, h INT64, playable_type STRING>, video STRUCT<w INT64, h INT64, maxduration_sec INT64, minduration_sec INT64, skip BOOL, skipafter INT64, ext_rewarded BOOL, placement INT64, skipmin INT64>, native STRUCT<ext_has_image BOOL, ext_has_video BOOL>, inventory_format STRING, pmp STRUCT<deal STRUCT<id STRING>>, displaymanagerver STRING, displaymanager STRING, video_type STRING, exp INT64, inventory_format_signal INT64>, ext STRUCT<skadn STRUCT<version STRING, ifv STRING, anonymized_ifv STRING, skoverlay_eligible BOOL, autostore_eligible BOOL>, sdk STRUCT<publisher_platform_id STRING>, pas STRUCT<is_pas BOOL>, inventory_feature STRUCT<auto_inline_install_eligible BOOL, double_end_card_eligible BOOL>, effective_publisher_rate FLOAT64, auction_id STRING, app_set_id STRING>, `at` STRING, misc_json STRING, tmax INT64, internal_bid_id STRING>"
focal-elf-631	prod_stream_view	imp	bid	6	"STRUCT<timestamp TIMESTAMP, mtid STRING, maid STRING, anonymized_maid STRING, bid_price STRUCT<currency STRING, amount_micro INT64>, IsTest BOOL, ext STRUCT<skadn STRUCT<campaign_id INT64>, inventory_feature STRUCT<enable_skoverlay BOOL, enable_engaged_click_for_skoverlay BOOL, enable_engaged_view_click BOOL, enable_autostore BOOL, enable_storekit_click BOOL, enable_double_end_card BOOL, enable_engaged_click BOOL, enable_imp_based_click BOOL, throttled_by_feature_based_sct BOOL, throttled_by_imp_based_sct BOOL>>, aux STRUCT<ignore_mmp_feedback BOOL, header_bidding_multiplier FLOAT64>, MODEL STRUCT<pricing_function STRING, pricing_name STRING, core STRUCT<pred FLOAT64, threshold FLOAT64, prediction_type STRING, ref_campaign STRING, context_name STRING, tf_model_name STRING, reason STRING, context_revision STRING, latency_ns INT64, wrapper STRUCT<normalizer FLOAT64, normalizer_from_tfserving BOOL, mixture_ratio FLOAT64, multiplier FLOAT64>, type STRING, prediction_type_mix_rate FLOAT64>, wrapper STRUCT<pred FLOAT64, threshold FLOAT64, prediction_type STRING, ref_campaign STRING, context_name STRING, tf_model_name STRING, reason STRING, context_revision STRING, latency_ns INT64, wrapper STRUCT<normalizer FLOAT64, normalizer_from_tfserving BOOL, mixture_ratio FLOAT64, multiplier FLOAT64>, type STRING, prediction_type_mix_rate FLOAT64>, multipliers STRUCT<converted_target FLOAT64, budget FLOAT64, calibration FLOAT64, exp FLOAT64>, bid_former STRUCT<fpa STRUCT<name STRING, in_cpm FLOAT64, out_cpm FLOAT64>, generic ARRAY<STRUCT<name STRING, in_cpm FLOAT64, out_cpm FLOAT64>>, out_cpm FLOAT64, win_pred FLOAT64>, value_price INT64, bid_price INT64, prediction_logs ARRAY<STRUCT<type STRING, pred FLOAT64, threshold FLOAT64, prediction_type STRING, prediction_type_mix_rate FLOAT64, ref_campaign STRING, context_name STRING, tf_model_name STRING, reason STRING, context_revision STRING, latency_ns INT64, wrapper STRUCT<normalizer FLOAT64, normalizer_from_tfserving BOOL, mixture_ratio FLOAT64, multiplier FLOAT64, vt_ratio FLOAT64>, base_model_prediction FLOAT64>>, p_value FLOAT64>, experiment STRUCT<ids_v1 ARRAY<INT64>, ids_v2 ARRAY<INT64>, counterfactual_tags ARRAY<STRUCT<group_id INT64, VALUES ARRAY<STRING>>>, custom_slices ARRAY<STRUCT<group_id INT64, VALUES ARRAY<STRING>>>, ids_v2_assigned ARRAY<INT64>, ids_v2_all ARRAY<STRUCT<group_id INT64, is_global_conducted BOOL, is_conducted BOOL>>, bin_number INT64>, cr_pick_log STRUCT<picker STRING, num_candidates INT64, score FLOAT64, reason STRING>, market_model STRUCT<name STRING, mu FLOAT64, sigma FLOAT64, clearing FLOAT64>, seatbid STRUCT<seat STRING>, rendezvous_bid STRUCT<test_and_submit_result STRING, partition_model STRING, auction_model STRING, `partition` STRUCT<submissions ARRAY<STRUCT<exec_id STRING, exchange STRING, winners ARRAY<STRUCT<bid_price STRUCT<currency STRING, amount_micro INT64>, value_price STRUCT<currency STRING, amount_micro INT64>>>>>>>, pricing_ext_src_revision INT64>"
focal-elf-631	prod_stream_view	imp	api	7	"STRUCT<platform STRUCT<id STRING, title STRING>, advertiser STRUCT<id STRING, title STRING>, product STRUCT<id STRING, title STRING, app STRUCT<store_id STRING, tracking_bundle STRING, mmp STRING>>, campaign STRUCT<id STRING, title STRING, skadn_id INT64, skadn_tr_suffix STRING>, trgroup STRUCT<id STRING, title STRING, user_bucket INT64>, adgroup STRUCT<id STRING, title STRING, report_tag STRING, skan_id INT64>, crgroup STRUCT<id STRING, title STRING, report_group STRING>, creative STRUCT<crid STRING, id STRING, format STRING, cr_format STRING, title STRING, w INT64, h INT64, size_in_bytes INT64, video_duration_sec INT64, video_endcard_format STRING, video_endcard_file STRING>, tracking_links ARRAY<STRUCT<id STRING, mmp STRING, title STRING, vt STRUCT<raw STRING, json STRING>, ct STRUCT<raw STRING, json STRING>, updated_at TIMESTAMP>>>"
focal-elf-631	prod_stream_view	imp	imp	8	"STRUCT<received_at TIMESTAMP, handled_at TIMESTAMP, happened_at TIMESTAMP, client_ip STRING, win_price_usd STRUCT<currency STRING, amount_micro INT64>, win_price_adv STRUCT<currency STRING, amount_micro INT64>, win_price_exc STRUCT<currency STRING, amount_micro INT64>, client_ua STRING, client_header STRUCT<x_device_ip STRING, x_device_ua STRING>, s2s_links ARRAY<STRUCT<id STRING, updated_at TIMESTAMP, link STRUCT<raw STRING, json STRING>>>, sdk_ext STRUCT<client_timestamp TIMESTAMP, device STRUCT<os STRING, os_ver STRING, model STRING, screen_scale FLOAT64>, app STRUCT<id STRING, ver STRING>, network STRUCT<connection_type STRING, carrier STRING>, sdk STRUCT<core_ver STRING, adapter_ver STRING>, mref STRING>, client_ip_data STRUCT<ip2asn STRUCT<range_start_ip STRING, usage STRING, asn INT64, isp STRING>>, cost STRUCT<billing STRUCT<type STRING, demand_charge_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>, demand_media_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>, supply_media_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>>, analysis STRUCT<win_price STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>, demand_charge_cost STRUCT<usd STRUCT<currency STRING, amount_micro INT64>, adv STRUCT<currency STRING, amount_micro INT64>, exc STRUCT<currency STRING, amount_micro INT64>>>>>"
focal-elf-631	prod_stream_view	imp	compliance	9	STRUCT<is_anonymized BOOL>
*/



imp_t AS (
    SELECT
        I.platform_id,
        I.advertiser_id,
        I.api.campaign.id AS campaign_id,
        I.api.campaign.title AS campaign_title,
        DATE(I.timestamp) AS date_utc,
        DATE(I.timestamp, A.advertiser_timezone) AS local_date,
        A.platform_serving_cost_percent,
        A.platform_markup_percent,
        I.req.device.os,
        CASE
            WHEN I.req.device.geo.lon BETWEEN -180 AND 180 AND I.req.device.geo.lat BETWEEN -90 AND 90 THEN I.req.device.geo.lat
            ELSE NULL
        END AS lat,
        CASE
            WHEN I.req.device.geo.lon BETWEEN -180 AND 180 AND I.req.device.geo.lat BETWEEN -90 AND 90 THEN I.req.device.geo.lon
            ELSE NULL
        END AS lon,
        `moloco-ods.general_utils.normalize_ip`(req.device.ip) AS ip,
        api.creative.cr_format AS cr_format,
        SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
        COUNT(*) AS imp
    FROM `focal-elf-631.prod_stream_view.imp` AS I
        INNER JOIN advertiser AS A ON
            I.platform_id = A.platform_id AND
            I.advertiser_id = A.advertiser_id AND
            A.effective_date_local <= DATE(I.timestamp, A.advertiser_timezone) AND DATE(I.timestamp, A.advertiser_timezone) <= A.last_effective_date_local
    WHERE
        DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
        AND req.device.geo.country = 'USA'
        AND api.product.app.store_id = app_bundle

        -- AND I.api.campaign.id IN UNNEST(campaign_id)
        -- AND api.creative.cr_format = 'vi'
    GROUP BY ALL
),
imp_usa_t AS (
    SELECT
        I.platform_id,
        I.advertiser_id,
        I.api.product.app.store_id,
        I.campaign_id,
        I.campaign_title,
        I.os,
        I.date_utc,
        I.local_date,
        COALESCE(O.osm_city, IF(I.lon IS NULL OR I.lon = 0, IP.osm_city, 'n/a'), 'other') AS city,
        I.cr_format,
        SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent / 100) * (1 + I.platform_markup_percent / 100)) AS FLOAT64) AS gross_spending_usd,
        SUM(I.imp) AS imp
    FROM imp_t AS I
        LEFT JOIN osm_t AS O ON ST_CONTAINS(O.geometry, ST_GEOGPOINT(I.lon, I.lat)) AND I.lon != 0
        LEFT JOIN ip_t IP ON
            NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(I.ip), 16) = NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(IP.ip_start), 16) AND
            NET.IPV4_TO_INT64(NET.SAFE_IP_FROM_STRING(I.ip)) BETWEEN IP.ipv4num_start AND IP.ipv4num_end
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
),



-- PIM-1837 : impressions subjected to refund
SELECT
    advertiser_id,
    api.creative.cr_format, 
    req.bid_region,
    COUNT(DISTINCT bid.mtid) AS num_mtid,
    SUM(imp.win_price_usd.amount_micro) AS media_cost
FROM `focal-elf-631.prod_stream_view.imp`
WHERE 
    DATE(timestamp) BETWEEN '2021-08-01' AND CURRENT_DATE()
    AND advertiser_id IN ('HKRCcBXgyO9rR9Pb', 'DyD0GQNf7zlp4hwy')
    and api.creative.cr_format in ("di", "db")
GROUP BY ALL


/*
imp, gross spending calculation 
*/

DECLARE run_from_date DATE DEFAULT "2024-11-01";
DECLARE run_to_date DATE DEFAULT "2024-12-09";

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
# Impression with bid_region <> 'ASIA' (limited to cr_format = di or db)

WITH
  advertiser AS (
    SELECT
      *,
      COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), 
                INTERVAL 1 DAY), run_to_date) AS last_effective_date_local,
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

  imp_t AS (
    SELECT
      I.platform_id,
      I.advertiser_id,
      DATE(I.timestamp, A.advertiser_timezone) AS local_date,
      A.platform_serving_cost_percent,
      A.platform_markup_percent,
      SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
      COUNT(*) AS imp,
    FROM
      `focal-elf-631.prod_stream_view.imp` AS I
    INNER JOIN
      advertiser AS A
    ON I.platform_id=A.platform_id
      AND I.advertiser_id=A.advertiser_id
      AND A.effective_date_local<=DATE(I.timestamp, A.advertiser_timezone)
      AND DATE(I.timestamp, A.advertiser_timezone)<=A.last_effective_date_local
    WHERE
      DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
      AND I.api.advertiser.id IN ('HKRCcBXgyO9rR9Pb', 'DyD0GQNf7zlp4hwy')
      AND I.api.creative.cr_format in ("di", "db")
      AND I.req.bid_region != 'ASIA'
    GROUP BY ALL
  )

SELECT
  I.platform_id,
  I.advertiser_id,
  I.local_date,
  SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent/100) * (1 + I.platform_markup_percent/100)) AS FLOAT64) AS gross_spending_usd,
  SUM(I.imp) AS imp,
FROM
  imp_t AS I
GROUP BY ALL


/* which model is applied in my campaign? */
select
  bid.model.pricing_function AS pricing_function,
  bid.model.prediction_logs[SAFE_OFFSET(1)].type AS model_type,
  bid.model.prediction_logs[SAFE_OFFSET(1)].tf_model_name AS model_name,
from `focal-elf-631.prod_stream_sampled.imp_1to1000`
where date(timestamp) = CURRENT_DATE()
and api.campaign.id IN  ('otvftPJXj0TTRykz')
group by 1 ,2,3
order by 1 ,2,3


/* 
  Impression per user (maid)
*/

DECLARE run_from_date DATE DEFAULT "2025-02-01";
DECLARE run_to_date DATE DEFAULT "2025-02-28";
 

SELECT
  api.product.app.store_id as app_market_bundle,
  COUNT(DISTINCT bid.maid) AS imp_user
FROM `focal-elf-631.prod_stream_view.imp` AS I
WHERE DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
  AND api.product.app.store_id = 'closet.match.pair.matching.games'
GROUP BY 1


/* Impression to Install (at user level) */ 

WITH imp AS (

  SELECT
    api.product.app.store_id as app_market_bundle,
    COUNT(DISTINCT bid.maid) AS imp_user
  FROM `focal-elf-631.prod_stream_view.imp` AS I
  WHERE DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
    AND api.product.app.store_id = 'closet.match.pair.matching.games'
  GROUP BY 1

), 

install AS (
  SELECT
    api.product.app.store_id as app_market_bundle,
    COUNT(DISTINCT bid.maid) AS install_user
  FROM `focal-elf-631.prod_stream_view.cv` AS C 
  WHERE DATE(timestamp) BETWEEN run_from_date AND run_to_date
    AND api.product.app.store_id = 'closet.match.pair.matching.games'
    AND LOWER(cv.event) = 'install'
  GROUP BY 1
)

SELECT
  imp.app_market_bundle,
  imp_user,
  install_user,
  ROUND(SAFE_DIVIDE(install_user, imp_user), 4) AS install_conversion
FROM imp LEFT JOIN install using(app_market_bundle)


/* compare user reach between two campaigns 
  Nol / Tving Case : https://colab.research.google.com/drive/1VB8Yfr_SNfnu6TUcG2l5dMTY15RLW6jT#scrollTo=xOLldxOyzOFK

*/

  DECLARE start_date DATE DEFAULT '{start_date}';
  DECLARE end_date DATE DEFAULT '{end_date}';

  WITH imp_bau AS (
    SELECT
      bid.maid, 
      COUNT(1) AS cnt_imp_user
    FROM 
      `focal-elf-631.prod_stream_view.imp` AS I
    WHERE DATE(I.timestamp, 'Asia/Seoul') BETWEEN start_date AND end_date
      AND I.api.campaign.id = '{campaign_bau}'
    GROUP BY 1
  ), 

  imp_tving AS (
    SELECT
      bid.maid, 
      COUNT(1) AS cnt_imp_user
    FROM
      `focal-elf-631.prod_stream_view.imp` AS I
    WHERE DATE(I.timestamp, 'Asia/Seoul') BETWEEN start_date AND end_date
      AND I.api.campaign.id = '{campaign_tving}'
    GROUP BY 1
  ),

  joined AS (
    SELECT
      imp_bau.maid AS maid_bau,
      imp_tving.maid AS maid_tving
    FROM imp_bau 
    FULL OUTER JOIN imp_tving USING(maid)
  )

  SELECT
    COUNTIF(maid_bau IS NOT NULL AND maid_tving IS NOT NULL) AS cnt_imp_user_both,
    COUNTIF(maid_bau IS NOT NULL AND maid_tving IS NULL) AS cnt_imp_user_bau_only,
    COUNTIF(maid_bau IS NULL AND maid_tving IS NOT NULL) AS cnt_imp_user_tving_only
  FROM joined;