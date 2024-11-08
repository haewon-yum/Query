/* 

- focal-elf-631.standard_digest.latest_digest
- This table contains 1 entry per entity AND platform (its latest update). 
    It contains ALL entities (campaign, product, advertiser)
- Notes
    + same JSON objects found in MOCAS. Can be processed with JSON functions.
    + filter by the type column to select a particular entity, e.g. type = “CAMPAIGN”. 
    The id column contains the ID for that entity (campaign_id, advertiser_id, etc).

*/


SELECT
 JSON_VALUE(original_json,
   "$.ad_tracking_allowance") AS ad_tracking_allowance
FROM
 `focal-elf-631.standard_digest.latest_digest`
WHERE
 type = "CAMPAIGN"
 AND id = "FhVyOU2xN3gyO1LM"
 AND platform = "MOLOCO"