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


/* 

Netmarble's user reach out of KOR reachable users for a single day

*/ 

-- Netmarble's user reach for the past 45 days (for the bundle: com.netmarble.kofafk) within Kakao talk. 
DECLARE start_date DATE DEFAULT '2025-10-13';
DECLARE end_date   DATE DEFAULT '2025-10-19';

WITH kor_rtb_kakao AS (
  SELECT
    distinct idfa
  FROM `focal-elf-631.df_user_data_v3.rtb_lifetime`, UNNEST(apps) apps
  WHERE TRUE 
    AND country = 'KOR'
    AND os = 'ANDROID'
    AND `moloco-ods.general_utils.is_idfa_truly_available`(idfa)
    AND DATE(user_last_timestamp) BETWEEN start_date AND end_date
    AND apps.bundle = 'com.kakao.talk'
),

netmarble_kakao_reach AS (
  SELECT 
    DISTINCT 
      req.device.ifa AS idfa
  FROM `focal-elf-631.prod_stream_view.imp`
  WHERE api.product.app.store_id = 'com.netmarble.kofafk'
    AND req.device.geo.country = 'KOR'
    AND DATE(timestamp) BETWEEN start_date AND end_date
    AND `moloco-ods.general_utils.is_idfa_truly_available`(req.device.ifa)
    AND req.app.bundle = 'com.kakao.talk'
)


SELECT 
  COUNT(kor_rtb_kakao.idfa) AS kor_rtb_kakao,
  COUNT(netmarble_kakao_reach.idfa) AS count_netmarble_kakao,
  ROUND(SAFE_DIVIDE(COUNT(netmarble_kakao_reach.idfa), COUNT(kor_rtb_kakao.idfa))*100,3) AS user_reach
FROM kor_rtb_kakao LEFT JOIN netmarble_kakao_reach using(idfa)