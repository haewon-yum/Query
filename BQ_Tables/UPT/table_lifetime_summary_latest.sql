/* 

focal-elf-631.user_data_v2_avro.lifetime_summary_latest
This table contains data of IDFA users that we have bidded on in a lifetime 
Note: Useful to check bid against audience, such as in Reengagement / RTG.


SCHEMA: 
column_name	data_type	is_nullable
os	STRING	YES
idfa	STRING	YES
country	STRING	YES
region	STRING	YES
city	STRING	YES
zip	STRING	YES
num_apps	INT64	YES
age_in_days	INT64	YES
device	"STRUCT<make STRING, model STRING, os STRING, osv STRING, type STRING, language STRING, carrier STRING>"	YES
device_language	STRING	YES
first_date_time	STRING	YES
latest_date_time	STRING	YES
dev_carrier	STRING	YES
stat	"STRUCT<req_cnt FLOAT64, bid_cnt FLOAT64, video_cnt FLOAT64, reward_cnt FLOAT64>"	YES

*/

