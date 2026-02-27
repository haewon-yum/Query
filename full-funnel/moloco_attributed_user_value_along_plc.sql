### SCOPE: Bundles where MLC fully engaged for the first 150 days


DECLARE start_date DEFAULT DATE('2024-04-24'); #app_release_date
DECLARE end_date DEFAULT DATE_ADD(start_date, INTERVAL 150 DAY);

WITH t_rev AS (
  SELECT
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_id,
    device.os,
    device.country,
    app.bundle AS mmp_bundle_id,
    moloco.attributed,
    DATE(event.install_at) AS install_dt, 
    TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
    event.revenue_usd.amount AS revenue
    FROM
    `focal-elf-631.prod_stream_view.pb`
    WHERE
        DATE(TIMESTAMP) >= start_date
        AND DATE(event.install_at) BETWEEN start_date AND end_date
        AND DATE(event.event_at) >= start_date
        AND event.revenue_usd.amount > 0
        AND event.revenue_usd.amount < 10000
        AND (LOWER(event.name) LIKE '%purchase%'
          OR LOWER(event.name) LIKE '%iap'
          OR LOWER(event.name) LIKE '%revenue%') 
        AND app.bundle IN ("id6483211224")
      ),

t_first_last AS (
      SELECT
        user_id,
        os,
        mmp_bundle_id,
        country,
        attributed,
        install_dt,
        MIN(diff_hour) / 24 AS first_purchase_day,
        MAX(diff_hour) / 24 AS last_purchase_day,
        COUNT(1) AS purchase_count,
        ARRAY_AGG(revenue ORDER BY diff_hour)[OFFSET(0)] AS first_purchase_amount,
        SUM(
        IF
          (diff_hour < 7 * 24, revenue, NULL)) AS d7_revenue,
        SUM(revenue) AS revenue,
      FROM
        t_rev
      GROUP BY
        ALL
        ),

t_agg AS (
  SELECT 
    *, 
    PERCENTILE_CONT(first_purchase_day, 0.5) OVER (PARTITION BY os, mmp_bundle_id, country) AS median_first_purchase_day,
    PERCENTILE_CONT(d7_revenue, 0.5) OVER (PARTITION BY os, mmp_bundle_id, country) AS median_d7_revenue,
    PERCENTILE_CONT(first_purchase_amount, 0.5) OVER (PARTITION BY os, mmp_bundle_id, country) AS median_first_purchase_amt,
  FROM t_first_last
)
SELECT
  mmp_bundle_id,
  os,
  country,
  attributed,
  install_dt,
  AVG(first_purchase_day) AS avg_first_purchase_day,
  ANY_VALUE(median_first_purchase_day) AS median_first_purchase_day,
  AVG(d7_revenue) AS avg_d7_revenue,
  ANY_VALUE(median_d7_revenue) AS median_d7_revenue,
  AVG(first_purchase_amount) AS avg_first_purchase_amt,
  ANY_VALUE(median_first_purchase_amt) AS median_first_purchase_amt,
  SUM(revenue) / COUNT(1) AS arppu,
  SUM(d7_revenue) / COUNT(1) AS d7_arppu
FROM t_agg
GROUP BY ALL