DECLARE start_date DATE DEFAULT DATE('2025-06-05');
DECLARE end_date DATE DEFAULT DATE('2025-06-05');
DECLARE bundles ARRAY<STRING> DEFAULT ['com.netmarble.tskgb','6479595079'];
DECLARE purchase_events ARRAY<STRING> DEFAULT ['revenue'];

  -- tracking bundle mapping
  WITH tracking_bundle AS (
    SELECT
      DISTINCT
      app_store_bundle,
      tracking_bundle
    FROM `focal-elf-631.standard_digest.product_digest`
    WHERE app_store_bundle IN UNNEST(bundles)
  ),

  -- Base events
  base_events AS (
    SELECT
      app.bundle AS bundle,
      device.country AS country,
      device.os AS os,
      LOWER(event.name) AS event_name,
      event.revenue_usd.amount AS revenue,
      event.install_at AS install_ts,
      timestamp,
      moloco.attributed AS is_attributed,
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN 'ifv:' || device.ifv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN 'ifa:' || device.ifa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
        ELSE NULL
      END AS user_id
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE
      DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 7 DAY)
      AND app.bundle IN UNNEST(bundles)
  ),

  -- Installs
  installs AS (
    SELECT DISTINCT bundle, country, user_id, is_attributed
    FROM base_events
    WHERE 
      event_name = 'install' AND user_id IS NOT NULL
      AND DATE(timestamp) BETWEEN start_date AND end_date

  ),

  -- Purchases
  purchases AS (
    SELECT DISTINCT bundle, country, user_id
    FROM base_events
    WHERE event_name IN UNNEST(purchase_events) AND user_id IS NOT NULL
  ),

  -- Revenue within 7-day window after install
  revenue_events AS (
    SELECT
      bundle,
      country,
      os,
      user_id,
      COUNT(*) AS purchase_count,
      SUM(revenue) AS total_revenue
    FROM base_events
    WHERE
      user_id IS NOT NULL
      AND revenue IS NOT NULL
      AND revenue > 0
      AND revenue < 10000
      AND event_name IN UNNEST(purchase_events)
      AND install_ts IS NOT NULL
      AND DATE(install_ts) BETWEEN start_date AND end_date
      AND TIMESTAMP_DIFF(timestamp, install_ts, DAY) < 7
    GROUP BY bundle, country, os, user_id
  ),

  -- Aggregation
  final AS (
    SELECT
      i.bundle,
      i.country,
      COUNT(DISTINCT IF(is_attributed = TRUE, i.user_id, NULL)) AS attributed_installs,
      COUNT(DISTINCT IF(is_attributed = FALSE, i.user_id, NULL)) AS unattributed_installs,
      COUNT(DISTINCT i.user_id) AS install_users,
      COUNT(DISTINCT p.user_id) AS purchase_users,
      AVG(r.purchase_count) AS avg_purchase,
      AVG(r.total_revenue) AS arppu
    FROM installs i
    LEFT JOIN purchases p
      ON i.bundle = p.bundle AND i.country = p.country AND i.user_id = p.user_id
    LEFT JOIN revenue_events r
      ON i.bundle = r.bundle AND i.country = r.country AND i.user_id = r.user_id
    GROUP BY i.bundle, i.country
  )

  SELECT
    bundle,
    country,
    attributed_installs,
    unattributed_installs,
    ROUND(SAFE_DIVIDE(attributed_installs, attributed_installs + unattributed_installs) * 100, 2) AS moloco_share_of_installs,
    install_users,
    purchase_users,
    ROUND(SAFE_DIVIDE(purchase_users, install_users) * 100, 2) AS i2p_percentage,
    ROUND(avg_purchase, 2) AS avg_purchase,
    ROUND(arppu, 2) AS arppu
  FROM final
  ORDER BY bundle, unattributed_installs DESC;