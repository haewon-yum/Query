-- Step 1: Check postback existence for a bundle × event (last 14 days)
-- Replace 'id6739246483' with the app bundle ID (e.g. 'id1112407590')
-- Replace 'af_ad_revenue' with the event name (e.g. 'zp_npuall')

SELECT
  DATE(timestamp) AS date,
  event.name AS event_name,
  COUNT(*) AS postback_count
FROM `focal-elf-631.df_accesslog.pb`
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
  AND app.bundle = 'id6739246483'
  AND LOWER(event.name) = LOWER('af_ad_revenue')
GROUP BY 1, 2
ORDER BY 1 DESC
LIMIT 14
