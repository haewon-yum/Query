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