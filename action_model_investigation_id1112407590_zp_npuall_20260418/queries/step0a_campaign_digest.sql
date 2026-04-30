-- Step 0a: Find all campaigns for a given bundle × event
-- Replace 'id1112407590' with the tracking bundle ID (e.g. 'id1112407590')
-- Replace 'zp_npuall' with the KPI event name (e.g. 'zp_npuall')

SELECT
  campaign_name,
  kpi_actions,
  inactive_since,
  tracking_bundle
FROM `focal-elf-631.prod.campaign_digest_merged_latest`
WHERE tracking_bundle = 'id1112407590'
  AND kpi_actions LIKE CONCAT('%', 'zp_npuall', '%')
