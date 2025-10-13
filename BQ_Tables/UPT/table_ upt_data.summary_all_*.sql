/* 

focal-elf-631.upt_data.summary_all_*: information on users MOLOCO has seen before.

SCHEMA

column_name	data_type	is_nullable
os	STRING	YES
idfa	STRING	YES
country	STRING	YES
bt_zone	STRING	YES
audience_length	INT64	YES
audience_site_length	INT64	YES
first_rtb_millis	INT64	YES
top_frequent_countries	STRING	YES
device	"STRUCT<make STRING, model STRING, os STRING, osv STRING, type STRING, language STRING, carrier STRING>"	YES
gender	"STRUCT<score FLOAT64, source STRING, last_computed_at INT64>"	YES
ages	STRING	YES
*/