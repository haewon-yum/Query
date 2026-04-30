-- Step 3: Check training examples generated for a bundle × event (last 14 days)
-- Replace '6739246483' with the numeric bundle ID (e.g. '1112407590' — no leading 'id')
-- Replace 'af_purchase' with the KPI event name (e.g. 'zp_npuall')

SELECT
  DATE(partition_timestamp) AS date,
  b_product_app_bundle_dev_os_kpi_action,
  b_campaign AS campaign_id,
  COUNT(*) AS num_examples
FROM `moloco-dsp-ml-prod.training_dataset_prod.tfexample_action_campaignlog_imp_v2`
WHERE DATE(partition_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
  AND b_product_app_bundle_dev_os_kpi_action LIKE CONCAT('%', '6739246483', '%', 'af_purchase', '%')
GROUP BY 1, 2, 3
ORDER BY 1 DESC
