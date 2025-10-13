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

column_name	data_type	is_nullable
timestamp	TIMESTAMP	YES
sample_rate	FLOAT64	YES
bid_id	STRING	YES
bidfloor	FLOAT64	YES
idfa	STRING	YES
exchange	STRING	YES
os	STRING	YES
country	STRING	YES
region	STRING	YES
city	STRING	YES
app_bundle	STRING	YES
site_domain	STRING	YES
site_page	STRING	YES
dev_type	STRING	YES
dev_model	STRING	YES
dev_ip	STRING	YES
connection_type	STRING	YES
categories	STRING	YES
imp_count	INT64	YES
imp_has_banner	BOOL	YES
imp_has_video	BOOL	YES
imp_has_native	BOOL	YES
imp_w	INT64	YES
imp_h	INT64	YES
imp_wmin	INT64	YES
imp_hmin	INT64	YES
imp_wmax	INT64	YES
imp_hmax	INT64	YES
user_id	STRING	YES
user_yob	INT64	YES
user_gender	STRING	YES
user_keywords	STRING	YES
geo_lat	FLOAT64	YES
geo_lon	FLOAT64	YES
geo_type	INT64	YES
adx_geo_canonical	STRING	YES
adx_billing_ids	STRING	YES
imp_has_pmp	BOOL	YES
imp_pmp_exclusive	BOOL	YES
imp_tag_id	STRING	YES
geo_zip	STRING	YES
geo_utc_offset	INT64	YES
id_type	INT64	YES
deal_ids	STRING	YES
deal_bidfloors	STRING	YES
deal_types	STRING	YES
language	STRING	YES
imp_native_format	STRING	YES
user_bucket	INT64	YES
bid_region	STRING	YES
region_raw	STRING	YES
city_raw	STRING	YES
geo_code	STRING	YES
metric_ctr	FLOAT64	YES
metric_viewability	FLOAT64	YES
metric_completion_rate	FLOAT64	YES
dev_w	INT64	YES
dev_h	INT64	YES
imp_has_native_video	BOOL	YES
imp_is_interstitial	BOOL	YES
imp_banner_mraid_ver	INT64	YES
imp_banner_vpaid_ver	INT64	YES
display_manager	STRING	YES
display_manager_ver	STRING	YES
imp_formats	STRING	YES
video_type	INT64	YES
is_test	BOOL	YES
has_upt_access	BOOL	YES
tfserving_invoke_count	INT64	YES
min_duration	INT64	YES
max_duration	INT64	YES
ip_type	INT64	YES
device_carrier	STRING	YES
session_depth	INT64	YES
encoded_app_bundle	STRING	YES
is_web	BOOL	YES
auction_type	STRING	YES
imp_native_plcmtcnt	INT64	YES
app_content_url	STRING	YES
inventory_format	STRING	YES
pub_id	STRING	YES
idfv	STRING	YES
skadn	"STRUCT<version STRING, request_versions ARRAY<STRING>, skoverlay_eligible BOOL, autostore_eligible BOOL>"	YES
dev_hwv	STRING	YES
dev_osv	STRING	YES
metro	STRING	YES
atts	INT64	YES
video_skip	BOOL	YES
video_skip_after	INT64	YES
playable_type	STRING	YES
tmax	INT64	YES
misc_json	STRING	YES
adunitname	STRING	YES
app_ver	STRING	YES
double_endcard_eligible	BOOL	YES
imp_has_native_image	BOOL	YES
app_set_id	STRING	YES
auction_id	STRING	YES
bidding_type	STRING	YES
dev_ipv6	STRING	YES
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