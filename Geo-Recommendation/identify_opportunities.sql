DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);
DECLARE end_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH country_spend AS (
	SELECT
		product.app_market_bundle,
		campaign.os,
		campaign.country,
		SUM(gross_spend_usd) AS total_spend,
		SUM(gross_spend_usd) / 90 AS drr,				
	FROM `moloco-ae-view.athena.fact_dsp_core`
	WHERE
		date_utc BETWEEN start_date AND end_date
		AND campaign.os IN ('ANDROID','IOS')
	GROUP BY ALL
	HAVING SUM(gross_spend_usd) > 0
),

campaign_targeting_geo_one AS (
	
	SELECT 
		app_market_bundle, 
		os,
		COUNT(country)
	FROM country_spend
	GROUP BY ALL
	HAVING COUNT(country) = 1
	
), 

tracking_bundles AS (
  SELECT DISTINCT app_store_bundle, tracking_bundle
  FROM `focal-elf-631.standard_digest.product_digest`
  WHERE app_store_bundle IN (SELECT app_market_bundle FROM campaign_targeting_geo_one)
),
base_events AS (
  SELECT
    pb.app.bundle AS bundle,
    tb.app_store_bundle AS app_market_bundle,
    pb.device.country AS country,
    pb.device.os AS os,
    pb.event.name AS event_name,
    pb.event.revenue_usd.amount AS revenue,
    pb.event.install_at AS install_ts,
    pb.timestamp,
    pb.moloco.attributed AS is_attributed,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(pb.device.ifv) THEN 'ifv:' || device.ifv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(pb.device.ifa) THEN 'ifa:' || device.ifa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (pb.mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_id
  FROM `focal-elf-631.prod_stream_view.pb` pb
  	JOIN tracking_bundles tb
  	ON pb.app.bundle = tb.tracking_bundle
  WHERE DATE(timestamp) BETWEEN start_date AND end_date
),
installs AS (
  SELECT DISTINCT 
  	app_market_bundle,
  	bundle AS tracking_bundle,   	
  	os, 
  	country, 
  	user_id, 
  	is_attributed
  FROM base_events
  WHERE LOWER(event_name) = 'install' AND user_id IS NOT NULL
    AND DATE(timestamp) BETWEEN start_date AND end_date
),
revenue_events AS (
	SELECT
		app_market_bundle,
	  	bundle AS tracking_bundle,   	
	  	os, 
	  	country, 
	  	user_id, 
	  	is_attributed
	FROM base_events
	WHERE revenue > 0
		AND DATE(timestamp) BETWEEN start_date AND end_date
),
revenue_event_bundles AS (
	SELECT DISTINCT
		app_market_bundle,
		os
	FROM revenue_events
),

final AS (
  SELECT
    i.app_market_bundle, 
    i.tracking_bundle,
    i.os, 
    i.country,
    COUNT(DISTINCT IF(is_attributed = TRUE,  i.user_id, NULL)) AS attributed_installs,
    COUNT(DISTINCT IF(is_attributed = FALSE, i.user_id, NULL)) AS unattributed_installs,
    COUNT(DISTINCT i.user_id) AS install_users,
  FROM installs i  
  GROUP BY ALL
  HAVING unattributed_installs > 50000
)
SELECT
  final.app_market_bundle, 
  country_spend.country AS running_country,
  final.os, 
  final.country AS not_running_country,
  attributed_installs, unattributed_installs,
  ROUND(SAFE_DIVIDE(attributed_installs, attributed_installs + unattributed_installs) * 100, 2) AS moloco_share_of_installs,
  install_users, 
FROM final 
JOIN revenue_event_bundles reb
	ON final.app_market_bundle = reb.app_market_bundle
	AND final.os = reb.os
LEFT JOIN country_spend
	ON final.app_market_bundle = country_spend.app_market_bundle
ORDER BY app_market_bundle, os, unattributed_installs DESC;
