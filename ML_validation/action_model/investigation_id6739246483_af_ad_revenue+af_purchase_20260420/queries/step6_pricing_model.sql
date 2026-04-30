-- Step 6: Check current pricing model applied in serving (last 3 days)
-- Source: mems_prod.api_log — request-level log from the pricing service
-- Replace 'IV7TA5O07K4JNsjn' with the campaign ID (e.g. 'OTh3FqM3vteUsp7f')

SELECT
  DATE(timestamp) AS date,
  JSON_VALUE(request, '$.pricing_metadata.type') AS pricing_metadata_type,
  JSON_VALUE(request, '$.pricing_metadata.tfserving_data.prediction_type') AS prediction_type,
  JSON_VALUE(request, '$.pricing_metadata.tfserving_data.conditional_data.normalizer') AS normalizer,
  COUNT(*) AS request_count
FROM `focal-elf-631.mems_prod.api_log`
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
  AND method LIKE '%PricingMetadata%'
  AND JSON_VALUE(request, '$.pricing_metadata.tfserving_data.campaign_id') = 'IV7TA5O07K4JNsjn'
  AND status = 'OK'
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC
