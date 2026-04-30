-- Step 0b: Get recent state history for a campaign
-- Replace 'Nu3RqJ9SKxUQHmK4' with the campaign ID (campaign_name from campaign_digest)
-- Run once per campaign found in Step 0a

SELECT
  JSON_VALUE(json_entity, '$.name') AS campaign_id,
  JSON_VALUE(json_entity, '$.state') AS state,
  timestamp
FROM `focal-elf-631.entity_history.prod_entity_history`
WHERE entity_type = 'CAMPAIGN'
  AND JSON_VALUE(json_entity, '$.name') = 'Nu3RqJ9SKxUQHmK4'
  AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY timestamp DESC
LIMIT 3
