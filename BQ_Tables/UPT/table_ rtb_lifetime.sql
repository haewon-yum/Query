/* 
`focal-elf-631.df_user_data_v3.rtb_lifetime`

focal-elf-631.df_user_data_v3.rtb_lifetime: information on users from which we got bid requests in the last 45 days.
Extremely useful to assess the reach of user audiences / customer sets.

column_name	data_type	is_nullable
os	STRING	YES
idfa	STRING	YES
idfa_prefix	STRING	YES
country	STRING	YES
region	STRING	YES
city	STRING	YES
age_in_days	INT64	YES
stat_d30	"STRUCT<req_cnt FLOAT64, bid_cnt FLOAT64, video_cnt FLOAT64, reward_cnt FLOAT64>"	YES
user_first_timestamp	TIMESTAMP	YES
user_last_timestamp	TIMESTAMP	YES
apps	"ARRAY<STRUCT<bundle STRING, stat_d30 STRUCT<req_cnt FLOAT64, bid_cnt FLOAT64, video_cnt FLOAT64, reward_cnt FLOAT64>, app_first_timestamp TIMESTAMP, app_last_timestamp TIMESTAMP>>"	NO
device	"STRUCT<make STRING, model STRING, osv STRING, type STRING, LANGUAGE STRING, carrier STRING>"	YES
maid	STRING	YES
*/




에브리타임(com.everytime.v2, 642416310), 
X('333903271', 'com.twitter.android'), Pinterest('429047995', 'com.pinterest'), 
네이버 웹툰, 
지그재그(?), 
브롤스타즈, 
무신사, 에이블리(?), 번개장터


DECLARE bundles ARRAY<STRING> DEFAULT [
    'com.everytime.v2', '642416310', -- everytime
    '333903271', 'com.twitter.android', -- X
    '429047995', 'com.pinterest', -- pinterest
    'com.naver.linewebtoon','com.nhn.android.webtoon','894546091','315795555', -- NAVER Webtoon
    '976131101', 'com.croquis.zigzag', -- ZigZag
    '1229016807', 'com.supercell.brawlstars', '1504236603',-- Brawl Stars id1229016807
    'com.musinsa.store','com.musinsa.global','1003139529','1637547116', -- Musinsa
    'com.banhala.android', '1084960428',-- ABLY, 
    'kr.co.quicket', '395672275'-- 번개장터
];

SELECT
  apps.bundle,
  COUNT(DISTINCT maid) cnt_maid
FROM `focal-elf-631.df_user_data_v3.rtb_lifetime`, UNNEST(apps) apps
WHERE apps.bundle IN UNNEST(bundles)
AND country = 'KOR'
GROUP BY 1
ORDER BY 2 DESC



---





