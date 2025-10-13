/* 
- focal-elf-631.user_data_v2_avro.pb_raw_latest

SCHEMA
    column_name	data_type	is_nullable
    platform	STRING	NO
    maid	STRING	NO
    cohortid_v2_input	"STRUCT<ipv4 STRING, model STRING, osv STRING, language STRING>"	YES
    os	STRING	NO
    idfa	STRING	NO
    app_bundle	STRING	NO
    event	STRING	NO
    count	INT64	NO
    moloco_attr_count	INT64	NO
    latest_millis	INT64	NO
    first_millis	INT64	NO
    daily_activity	ARRAY<INT64>	NO
    latest_daily_activity	ARRAY<INT64>	NO
    revenue_millis	ARRAY<INT64>	NO
    revenue_bucketized	ARRAY<INT64>	NO
    dmp_user_attr_values_int	ARRAY<INT64>	NO
    dmp_user_attr_actions	ARRAY<STRING>	NO
    job_date	TIMESTAMP	YES

Table meta
    
*/


DECLARE start_date DATE DEFAULT '2024-12-01';
DECLARE end_date DATE DEFAULT '2025-09-14';

SELECT
    app_bundle,
    COUNT(DISTINCT idfa) AS cnt_idfa
FROM `focal-elf-631.user_data_v2_avro.pb_raw_latest`
WHERE DATE(TIMESTAMP_MILLIS(latest_millis)) BETWEEN DATE_SUB(end_date, INTERVAL 90 DAY) AND end_date
    app_bundle
GROUP BY ALL
