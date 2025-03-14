/* 
 This table contains 1 entry per entity AND platform (its latest update). 
 It contains ALL entities (campaign, product, advertiser)
 Sample rate: n/a
+ same JSON objects found in MOCAS. Can be processed with JSON functions.
+ filter by the type column to select a particular entity, e.g. type = “CAMPAIGN”. The id column contains the ID for that entity (campaign_id, advertiser_id, etc).

*/

SELECT
  id,
  type,
  original_json,
  JSON_VALUE_ARRAY(original_json, "$.app_properties.categories") AS categories
FROM
  `focal-elf-631.standard_digest.latest_digest`
WHERE
  type = 'PRODUCT'
  AND JSON_VALUE_ARRAY(original_json, "$.app_properties.categories") IS NOT NULL
LIMIT
  10