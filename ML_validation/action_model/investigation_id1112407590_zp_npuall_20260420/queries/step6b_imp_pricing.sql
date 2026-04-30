-- Step 6b: Impression-level pricing execution from prod_stream_view.imp
-- Confirms what pricing model was actually applied at each won impression.
--
-- Parameters: 'RGPQHVtHfPNlSXcU'
--
-- Note: no flat pricing_metadata_type column exists in this table.
-- Interpret from bid.model.pricing_function + prediction_logs[].tf_model_name.

SELECT
  DATE(timestamp) AS date,
  bid.model.pricing_function,
  pl.type,
  pl.tf_model_name,
  pl.prediction_type,
  pl.wrapper.normalizer,
  COUNT(*) AS imp_count
FROM `focal-elf-631.prod_stream_view.imp`,
  UNNEST(bid.model.prediction_logs) AS pl
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
  AND api.campaign.id = 'RGPQHVtHfPNlSXcU'
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1 DESC
LIMIT 100
