### 민기님 레퍼런스 ### 

DECLARE
  start_date date DEFAULT '2024-09-01';
DECLARE
  end_date date DEFAULT '2024-11-30';
DECLARE
  campaign_ids ARRAY<string> DEFAULT ['rxrVd3nD68rvrSke',
  'btIZQMFG6hCRDavg',
  'EMauFzTmVFM9hALV',
  'ONmr2FLjKZ5HoffM',
  'IWtvomxSPQtQgcfw',
  'BnyGc57kJEoPrxdW',
  'VBnWxKikoKxWVkVa',
  'uTgzLo6zxbedLax4'];
WITH
  t_campaign_digest AS (
  SELECT
    platform_name,
    platform_serving_cost_percent,
    platform_markup_percent,
    MIN(DATE(timestamp)) AS effective_date,
    MAX(DATE(timestamp)) AS latest_effective_date
  FROM
    `focal-elf-631.prod.campaign_digest*`
  WHERE
    _table_suffix BETWEEN FORMAT_DATE('%Y%m%d', start_date)
    AND FORMAT_DATE('%Y%m%d', end_date)
    AND state = ""ACTIVE""
  GROUP BY
    ALL),
  t_imp AS (
  SELECT
    *,
    imp.win_price_adv.amount_micro / 1e6 win_price,
  FROM
    `focal-elf-631.prod_stream_view.imp`
  WHERE
    DATE(timestamp) BETWEEN start_date
    AND end_date
    AND api.campaign.id IN UNNEST(campaign_ids)),
  t_imp_pb_diff AS (
  SELECT
    req.device.ifa AS idfa,
    platform_id,
    api.campaign.id AS campaign_id,
    imp.win_price_usd.amount_micro / 1e6 win_price,
    t_pb.timestamp AS last_action_at,
    t_imp.timestamp AS imp_at,
    TIMESTAMP_DIFF(t_imp.timestamp, t_pb.timestamp, day) AS diff_day
  FROM
    `focal-elf-631.df_accesslog.pb` AS t_pb
  RIGHT JOIN
    t_imp
  ON
    device.idfa = req.device.ifa
    AND app.bundle = api.product.app.tracking_bundle
    AND t_pb.timestamp < t_imp.timestamp
  WHERE
    DATE(t_pb.timestamp) BETWEEN start_date - 30
    AND end_date
  QUALIFY
    ROW_NUMBER() OVER(PARTITION BY idfa, campaign_id ORDER BY t_pb.timestamp DESC) = 1),
  t_cv AS (
  SELECT
    api.campaign.id AS campaign_id,
    req.device.ifa AS idfa,
    SUM(
    IF
      (TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 1, cv.revenue_usd.amount, NULL)) AS d1_revenue,
    SUM(
    IF
      (TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 7, cv.revenue_usd.amount, NULL)) AS d7_revenue,
  FROM
    `focal-elf-631.prod_stream_view.cv`
  WHERE
    DATE(timestamp) BETWEEN start_date
    AND end_date + 7
    AND api.campaign.id IN UNNEST(campaign_ids)
    AND DATE(imp.happened_at) BETWEEN start_date
    AND end_date
  GROUP BY
    ALL)
SELECT
  campaign_id,
  diff_day,
  COUNT(1) imp,
  SUM(win_price * (1+platform_serving_cost_percent/100) * (1+platform_markup_percent/100)) AS gross_spending,
  SUM(d1_revenue) AS d1_revenue,
  SUM(d7_revenue) AS d7_revenue
FROM
  t_imp_pb_diff
LEFT JOIN
  t_campaign_digest
ON
  platform_id = platform_name
  AND DATE(imp_at) > effective_date 
  AND DATE(imp_at) <= latest_effective_date
LEFT JOIN
  t_cv
USING
  (campaign_id,
    idfa)
GROUP BY
  ALL


## https://mlc.atlassian.net/browse/ODSB-11720
## defined inactivity window based on the purchase
    ## Include: Users who made a purchase within the last 90 days

DECLARE
  start_date date DEFAULT '2025-01-01';
DECLARE
  end_date date DEFAULT '2025-04-16'; # end date of the campaign or current_date 
DECLARE
  campaign_ids ARRAY<string> DEFAULT ['SI56UQzr273x0y1f'];
WITH
  t_campaign_digest AS (
  SELECT
    platform_name,
    platform_serving_cost_percent,
    platform_markup_percent,
    MIN(DATE(timestamp)) AS effective_date,
    MAX(DATE(timestamp)) AS latest_effective_date
  FROM
    `focal-elf-631.prod.campaign_digest*`
  WHERE
    _table_suffix BETWEEN FORMAT_DATE('%Y%m%d', start_date)
    AND FORMAT_DATE('%Y%m%d', end_date)
    AND state = "ACTIVE"
  GROUP BY
    ALL),
  t_imp AS (
  SELECT
    *,
    imp.win_price_adv.amount_micro / 1e6 win_price,
  FROM
    `focal-elf-631.prod_stream_view.imp`
  WHERE
    DATE(timestamp) BETWEEN start_date AND end_date
    AND api.campaign.id IN UNNEST(campaign_ids)),
  t_imp_pb_diff AS (
  SELECT
    req.device.ifa AS idfa,
    platform_id,
    api.campaign.id AS campaign_id,
    imp.win_price_usd.amount_micro / 1e6 win_price,
    t_pb.timestamp AS last_purchase_at,
    t_imp.timestamp AS imp_at,
    TIMESTAMP_DIFF(t_imp.timestamp, t_pb.timestamp, day) AS diff_day
  FROM
    (
     SELECT * 
     FROM `focal-elf-631.prod_stream_view.pb`
     WHERE event.revenue_usd.amount > 0
        AND app.bundle = 'com.bagelcode.slots1'
     ) AS t_pb  
  RIGHT JOIN
    t_imp
  ON
    device.ifa = req.device.ifa
    AND app.bundle = api.product.app.tracking_bundle
    AND t_pb.timestamp < t_imp.timestamp
  WHERE
    DATE(t_pb.timestamp) BETWEEN start_date - 90 AND end_date
  QUALIFY
    ROW_NUMBER() OVER(PARTITION BY idfa, campaign_id ORDER BY t_pb.timestamp DESC) = 1),

t_cv AS (
  SELECT
    api.campaign.id AS campaign_id,
    req.device.ifa AS idfa,
    COUNT(CASE WHEN cv.revenue_usd.amount > 0 THEN 1 ELSE NULL END) AS purchase_cnt,
    COUNT(IF(cv.revenue_usd.amount > 0 AND TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 1, 1, NULL)) AS d1_purchase_cnt,
    COUNT(IF(cv.revenue_usd.amount > 0 AND TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 7, 1, NULL)) AS d7_purchase_cnt,
    COUNT(CASE WHEN LOWER(cv.event_pb) = 'reattribution' THEN 1 ELSE NULL END) AS cnt_reattribution,
    SUM(IF(TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 1, cv.revenue_usd.amount, NULL)) AS d1_revenue,
    SUM(IF(TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 7, cv.revenue_usd.amount, NULL)) AS d7_revenue,
  FROM
    `focal-elf-631.prod_stream_view.cv`
  WHERE
    DATE(timestamp) BETWEEN start_date AND end_date + 7
    AND api.campaign.id IN UNNEST(campaign_ids)
    AND DATE(imp.happened_at) BETWEEN start_date AND end_date
  GROUP BY
    ALL)

SELECT
  idfa,
  diff_day,
  win_price * (1+platform_serving_cost_percent/100) * (1+platform_markup_percent/100) AS spend,
  d1_purchase_cnt,
  d7_purchase_cnt,
  cnt_reattribution,
  d1_revenue,
  d7_revenue
FROM
  t_imp_pb_diff
LEFT JOIN
  t_campaign_digest
ON
  platform_id = platform_name
  AND DATE(imp_at) > effective_date 
  AND DATE(imp_at) <= latest_effective_date
LEFT JOIN
  t_cv
USING
  (campaign_id,
    idfa)



#### UPDATE 2025.04.21 ####
DECLARE start_date date DEFAULT '2024-10-01';
DECLARE end_date date DEFAULT '2025-04-16'; # end date of the campaign or current_date 
DECLARE campaign_ids ARRAY<string> DEFAULT ['SI56UQzr273x0y1f'];
WITH
  t_campaign_digest AS (
  SELECT
    platform_name,
    platform_serving_cost_percent,
    platform_markup_percent,
    MIN(DATE(timestamp)) AS effective_date,
    MAX(DATE(timestamp)) AS latest_effective_date
  FROM
    `focal-elf-631.prod.campaign_digest*`
  WHERE
    _table_suffix BETWEEN FORMAT_DATE('%Y%m%d', start_date)
    AND FORMAT_DATE('%Y%m%d', end_date)
    AND state = "ACTIVE"
  GROUP BY
    ALL),
  t_imp AS (
  SELECT
    *,
    imp.win_price_usd.amount_micro / 1e6 win_price,
  FROM
    `focal-elf-631.prod_stream_view.imp`
  WHERE
    DATE(timestamp) BETWEEN start_date AND end_date
    AND api.campaign.id IN UNNEST(campaign_ids)),

  wp AS (
    SELECT 
      req.device.ifa AS idfa,
      SUM(win_price) AS win_price
    FROM t_imp
    GROUP BY 1
  ),
 purchase_imp AS (
  SELECT
    req.device.ifa AS idfa,
    platform_id,
    api.campaign.id AS campaign_id,
    -- win_price,
    t_pb.timestamp AS purchase_at,
    t_imp.timestamp AS imp_at,
    TIMESTAMP_DIFF(t_imp.timestamp, t_pb.timestamp, day) AS diff_day
  FROM
    (
      SELECT * 
      FROM `focal-elf-631.prod_stream_view.pb`
      WHERE event.revenue_usd.amount > 0
        AND app.bundle = 'com.bagelcode.slots1'
        -- AND moloco.campaign_id IN UNNEST(campaign_ids)
      ) AS t_pb  
  RIGHT JOIN
    t_imp
  ON
    device.ifa = req.device.ifa
    AND app.bundle = api.product.app.tracking_bundle
    AND t_pb.timestamp < t_imp.timestamp
  WHERE
    DATE(t_pb.timestamp) BETWEEN start_date - 90
    AND end_date
),


 t_imp_pb_diff AS(
    
    SELECT
        idfa,
        platform_id,
        campaign_id,
        ANY_VALUE(win_price) AS win_price,
        MAX(purchase_at) AS last_purchase_at,
        MAX(imp_at) AS last_imp_at,
        MIN(imp_at) AS first_imp_at,
        TIMESTAMP_DIFF(MAX(imp_at), MAX(purchase_at), day) AS diff_day_max,
        TIMESTAMP_DIFF(MIN(imp_at), MAX(purchase_at), day) AS diff_day_min,
    FROM purchase_imp 
        LEFT JOIN wp USING(idfa)
    GROUP BY 1, 2, 3

)
,


t_cv AS (
  SELECT
    api.campaign.id AS campaign_id,
    req.device.ifa AS idfa,
    COUNT(CASE WHEN cv.revenue_usd.amount > 0 THEN 1 ELSE NULL END) AS purchase_cnt,
    COUNT(IF(cv.revenue_usd.amount > 0 AND TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 1, 1, NULL)) AS d1_purchase_cnt,
    COUNT(IF(cv.revenue_usd.amount > 0 AND TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 7, 1, NULL)) AS d7_purchase_cnt,
    COUNT(CASE WHEN LOWER(cv.event_pb) = 'reattribution' THEN 1 ELSE NULL END) AS cnt_reattribution,
    SUM(IF(TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 1, cv.revenue_usd.amount, NULL)) AS d1_revenue,
    SUM(IF(TIMESTAMP_DIFF(cv.happened_at, imp.happened_at, day) < 7, cv.revenue_usd.amount, NULL)) AS d7_revenue,
  FROM
    `focal-elf-631.prod_stream_view.cv`
  WHERE
    DATE(timestamp) BETWEEN start_date AND end_date + 7
    AND api.campaign.id IN UNNEST(campaign_ids)
    AND DATE(imp.happened_at) BETWEEN start_date AND end_date
  GROUP BY
    ALL)

SELECT
  idfa,
  diff_day_max,
  diff_day_min,
  win_price * (1+platform_serving_cost_percent/100) * (1+platform_markup_percent/100) AS spend,
  d1_purchase_cnt,
  d7_purchase_cnt,
  cnt_reattribution,
  d1_revenue,
  d7_revenue
FROM
  t_imp_pb_diff
LEFT JOIN
  t_campaign_digest
ON
  platform_id = platform_name
  AND DATE(first_imp_at) > effective_date 
  AND DATE(first_imp_at) <= latest_effective_date
LEFT JOIN
  t_cv
USING
  (campaign_id,
    idfa)
