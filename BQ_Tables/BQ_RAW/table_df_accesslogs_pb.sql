/* 
- focal-elf-631.df_accesslog.pb
- This table contains all available postbacks and is fully unsampled but may not have all the columns available in prod_stream_view.pb

SCHEMA
- tiestamp
- type
- mmp
    - ...
- attribution
    - ...
- moloco
    - mtid
    - is_test
    - campaign_id
    - creative_id
    - cohort_id
- app
    - bundle
    - name
    - store
    - version
    - sdk_version
- pub
    - app_bundle
- device
    - ip
    - ua
    - os
    - osv
    - idfa
    - idfv
    - country
    - session_count
    - user_bucket
    - language_est
    - name
    - model_est
    - appsetid
- event
    - name
    - imp_at
    - click_at
    - download_at
    - install_at
    - event_at
    - revenue_raw
        - currency
        - amount
    - revenue_usd
        - currency
        - amount
    - page_uri
    - custom_info
        - key
        - value
- request


column_name	data_type	is_nullable
timestamp	TIMESTAMP	NO
type	STRING	NO
mmp	"STRUCT<name STRING, network STRING, ip STRING, platform STRING, event_source STRING, device_id STRING>"	YES
attribution	"STRUCT<method STRING, attributed BOOL, view_through BOOL, reengagement BOOL, organic BOOL, rejection_reason STRING, raw_method STRING, assisted BOOL, rejected BOOL>"	YES
moloco	"STRUCT<mtid STRUCT<raw STRING, valid BOOL, maid STRUCT<id_type STRING, id STRING>>, is_test BOOL, campaign_id STRING, creative_id STRING, cohort_id STRING>"	YES
app	"STRUCT<bundle STRING, name STRING, store STRING, version STRING, sdk_version STRING>"	YES
pub	STRUCT<app_bundle STRING>	YES
device	"STRUCT<model STRING, language STRING, ip STRING, ua STRING, os STRING, osv STRING, idfa STRING, idfv STRING, country STRING, session_count INT64, user_bucket INT64, language_est STRING, name STRING, model_est STRING, appsetid STRING>"	YES
event	"STRUCT<name STRING, imp_at TIMESTAMP, click_at TIMESTAMP, download_at TIMESTAMP, install_at TIMESTAMP, event_at TIMESTAMP, revenue_raw STRUCT<currency STRING, amount FLOAT64>, revenue_usd STRUCT<currency STRING, amount FLOAT64>, page_uri STRING, custom_info ARRAY<STRUCT<key STRING, value STRING>>>"	YES
request	"STRUCT<url STRING, queries ARRAY<STRUCT<key STRING, value STRING>>, trace_id STRING>"	YES

*/