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


SELECT 
  *,
  JSON_EXTRACT(raw, '$.app.cat') AS categories
FROM `focal-elf-631.prod.bidrequest_raw20250328` 
LIMIT 1000



SELECT 
  CASE WHEN JSON_EXTRACT(raw, '$.user.yob') <> '' or JSON_EXTRACT(raw, '$.user.yob') IS NOT NULL THEN 1 ELSE NULL END AS is_yob,
  COUNT(1) AS cnt
FROM `focal-elf-631.prod.bidrequest_raw20250328` 



### CTV bid request <-> Mobile bid request Incremental supply ###
DECLARE start_date DEFAULT DATE('2025-04-02');
DECLARE start_date_str DEFAULT  '250402';

DECLARE end_date DEFAULT DATE('2025-04-02');
DECLARE end_date_str DEFAULT  '250402';

WITH
  ctv_ip AS (
    SELECT
      DISTINCT dev_ip
    FROM
    `focal-elf-631.prod.bidrequest20*`
    WHERE
    _TABLE_SUFFIX BETWEEN start_date_str AND end_date_str
    AND DATE(timestamp) BETWEEN start_date AND end_date
    AND UPPER(os) = 'CTV'
    AND dev_ip IS NOT NULL
    AND dev_ip != ''
  ),
  mobile_ip AS (
    SELECT
      DISTINCT dev_ip
    FROM
    `focal-elf-631.prod.bidrequest20*`
    WHERE
    _TABLE_SUFFIX BETWEEN start_date_str AND end_date_str
    AND DATE(timestamp) BETWEEN start_date AND end_date
    AND UPPER(os) IN ('ANDROID', 'IOS')
    AND dev_ip IS NOT NULL
    AND dev_ip != ''
  ),
  ctv_only AS (
    SELECT dev_ip FROM ctv_ip 
    EXCEPT DISTINCT 
    SELECT dev_ip FROM mobile_ip
  ),
  mobile_only AS (
    SELECT dev_ip FROM mobile_ip
    EXCEPT DISTINCT
    SELECT dev_ip FROM ctv_ip
  ),
  both AS (
    SELECT dev_ip FROM ctv_ip
    INTERSECT DISTINCT
    SELECT dev_ip FROM mobile_ip
  )
  SELECT 
    (SELECT COUNT(*) FROM ctv_only) AS ctv_only_cnt,
    (SELECT COUNT(*) FROM mobile_only) AS mobile_only_cnt,
    (SELECT COUNT(*) FROM both) AS both_cnt,