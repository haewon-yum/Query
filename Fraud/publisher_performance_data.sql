DECLARE start_date DATE DEFAULT '2024-08-12';
DECLARE end_date DATE DEFAULT '2024-09-12';


WITH installs AS (SELECT
  bid.mtid,
  cv.happened_at AS install_at,
  req.app.bundle
FROM `focal-elf-631.prod_stream_view.cv`
WHERE timestamp BETWEEN start_date AND end_date
AND cv.event = "INSTALL"
), events AS (
  SELECT
    bid.mtid,
    cv.event_pb,
    cv.revenue_usd.amount AS postback_revenue,
    cv.happened_at AS event_at,
    LOWER(cv.event_pb) LIKE "%purchase%" OR LOWER(cv.event_pb) LIKE "%iap%" AS is_purchase
  FROM `focal-elf-631.prod_stream_view.cv`
WHERE timestamp >= start_date
AND cv.event <> "INSTALL"
),
  rejected AS (
  SELECT
    req.app.bundle AS bundle,
    COUNT(*) AS rejected_installs,
    STRING_AGG(DISTINCT cv.mmp, ", " ORDER BY cv.mmp ASC) AS mmp_flag
  FROM
    `focal-elf-631.prod_stream_view.cv`
  WHERE
    timestamp BETWEEN start_date
    AND end_date
    AND cv.event_pb LIKE "%rejected%"
    AND cv.pb.attribution.rejection_reason IN ("bots()","Engagement injection","Anonymous traffic")
    GROUP BY 1 ),
    summary AS (
      SElECT
      app_bundle AS bundle,
      SUM(imp) AS impressions
      FROM `moloco-ae-view.looker.campaign_raw_metrics_view`
      WHERE utc_date BETWEEN start_date
      AND end_date
      GROUP BY 1
    )
SELECT
*
FROM (
SELECT
  bundle,
  COUNT(DISTINCT installs.mtid) AS installs,
  SUM(IF(TIMESTAMP_DIFF(event_at, install_at, DAY) < 7, postback_revenue, 0)) AS d7_revenue,
  COUNT(DISTINCT CASE WHEN is_purchase AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 7 THEN events.mtid ELSE NULL END) AS unique_payer_d7,
  COUNT(DISTINCT CASE WHEN NOT is_purchase AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 7 THEN events.mtid ELSE NULL END) AS unique_revenue_producer_d7,
  COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN events.mtid ELSE NULL END) AS d3_retention,
  COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN events.mtid ELSE NULL END) AS d7_retention
FROM installs
LEFT JOIN events
ON events.mtid = installs.mtid
AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
GROUP BY 1  )
LEFT JOIN rejected USING (bundle)
LEFT JOIN summary USING(bundle)
