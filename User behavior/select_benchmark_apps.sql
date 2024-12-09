/* 
    select benchmark apps for competitor analysis
*/

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
WITH
  t_top_spender AS (
  SELECT
    product.app_name,
    ARRAY_AGG(distinct advertiser.mmp_bundle_id) AS mmp_bundle_ids,
    ARRAY_AGG(distinct product.app_market_bundle) AS app_market_bundle_ids,
    SUM(
    IF
      (campaign.country = 'TWN', gross_spend_usd, NULL)) AS spend_twn,
    SUM(
    IF
      (campaign.country = 'JPN', gross_spend_usd, NULL)) AS spend_jpn,
  FROM
    `moloco-ae-view.athena.fact_dsp_core`
  WHERE
    date_utc BETWEEN '2024-01-01'
    AND '2024-06-30'
    AND campaign.country IN ('TWN',
      'JPN')
    AND product.app_market_bundle IS NOT NULL
    AND product.is_gaming
    AND product.genre != 'Casino'
  GROUP BY
    ALL
  HAVING
    spend_twn > 10000
    AND spend_jpn > 50000),
  t_revenue AS (
  SELECT
    app_name,
    mmp_bundle_ids,
    spend_jpn,
    spend_twn,
    SUM(
    IF
      (device.country = 'TWN', event.revenue_usd.amount, NULL)) AS pb_revenue_twn,
    SUM(
    IF
      (device.country = 'JPN', event.revenue_usd.amount, NULL)) AS pb_revenue_jpn,
  FROM
    `focal-elf-631.prod_stream_view.pb` t_pb
  INNER JOIN
    t_top_spender
  ON
    app.bundle IN UNNEST(mmp_bundle_ids)
  WHERE
    DATE(timestamp) BETWEEN '2024-01-01'
    AND '2024-06-30'
    AND device.country IN ('TWN',
      'JPN')
  GROUP BY
    ALL)
SELECT
  *,
  ROW_NUMBER() OVER(ORDER BY pb_revenue_twn DESC) AS revenue_rank_twn,
  ROW_NUMBER() OVER(ORDER BY pb_revenue_jpn DESC) AS revenue_rank_jpn,
  ROW_NUMBER() OVER(ORDER BY pb_revenue_twn DESC) + ROW_NUMBER() OVER(ORDER BY pb_revenue_jpn DESC) AS revenue_rank_sum,
FROM
  t_revenue
ORDER BY
  revenue_rank_sum