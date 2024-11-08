WITH t_summary AS (
    SELECT utc_date, os, country, 
           COALESCE(SUM(revenue), 0) AS spend, 
           COALESCE(SUM(imp), 0) AS imp, 
           COALESCE(SUM(click), 0) AS click, 
           COALESCE(SUM(install), 0) AS install 
    FROM `moloco-ae-view.looker.campaign_summary_metrics_view` 
    WHERE advertiser_id = 'yfg0At8VksGnt6EO' 
      AND tracking_bundle IN ('com.netmarble.nanarise') 
      AND utc_date BETWEEN '2024-08-13' AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) 
    GROUP BY 1, 2, 3
),
pb_inst AS (
    SELECT moloco.mtid AS mtid, device.os, device.country, timestamp AS install_timestamp 
    FROM `focal-elf-631.prod_stream_view.pb` 
    WHERE DATE(timestamp) BETWEEN '2024-08-13' AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) 
      AND app.bundle IN ('com.netmarble.nanarise') 
      AND moloco.attributed = TRUE 
      AND event.name = 'install'
),
pb_act AS (
    SELECT moloco.mtid AS mtid, MIN(timestamp) AS login_timestamp 
    FROM `focal-elf-631.prod_stream_view.pb` 
    WHERE DATE(timestamp) BETWEEN '2024-08-13' AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) 
      AND app.bundle IN ('com.netmarble.nanarise') 
      AND moloco.attributed = TRUE 
      AND event.name = 'login' 
    GROUP BY 1
),
t_cv AS (
    SELECT DATE(pb_inst.install_timestamp) AS utc_date, os, country, 
           COUNT(DISTINCT pb_inst.mtid) AS d1_login 
    FROM pb_inst 
    JOIN pb_act ON pb_inst.mtid = pb_act.mtid 
    WHERE TIMESTAMP_DIFF(pb_act.login_timestamp, pb_inst.install_timestamp, HOUR) < 24 
    GROUP BY 1, 2, 3
)
SELECT *, 
       SAFE_DIVIDE(d1_login, install) AS login_conversion, 
       SAFE_DIVIDE(click, imp) AS CTR, 
       SAFE_DIVIDE(install, click) AS CVR, 
       SAFE_DIVIDE(spend, install) AS CPI, 
       SAFE_DIVIDE(spend, d1_login) AS CPA 
FROM t_summary 
JOIN t_cv USING (utc_date, os, country) 
ORDER BY 1, 2, 3, 4, 5;