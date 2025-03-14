/*
- Table: focal-elf-631.prod.bidrequest*
- This table contains sampled data of the bid requests that we receive from the exchanges, 
  including contextual data such as publisher, location, creative requirements... 
- Key: bid_id
- Sampling ratio: 1/10000
- The number of bid requests is massively big, so each day is a different table. 
    We can use wildcard to basically union them in 1 clean query, for e.g. using FROM `focal-elf-631.prod.bidrequest2024*` WHERE _TABLE_SUFFIX >= '0701'
- DS team can use this data to diagnose anomalies related to exchanges, find market trends, or get an idea of market size for a specific region or operating system.
*/

/* SCHEMA 


*/

-- Example
SELECT 
    timestamp,
    bid_id,
    bidfloor, 
    idfa,
    exchange,
    os, 
    country, 
    region, 
    city, 
    app_bundle, 
    user_gender, 
    geo_lat,
    geo_lon,
    user_bucket,
    bid_region,

FROM `focal-elf-631.prod.bidrequest2024*`
WHERE _TABLE_SUFFIX >= '0901'
LIMIT 100


/* Xiaomi device in IND */

SELECT
    CASE WHEN 
    timestamp,
    bid_id,
    bidfloor, 
    idfa,
    exchange,
    os, 
    country, 
    region, 
    city, 
    app_bundle, 
    user_gender, 
    geo_lat,
    geo_lon,
    user_bucket,
    bid_region,

FROM `focal-elf-631.prod.bidrequest2024*`
WHERE _TABLE_SUFFIX >= '0901'
LIMIT 100
