### 특정 앱 사용 유저가 어떤 앱들을 쓰고 있는지 ### 

DECLARE
  start_date DATE DEFAULT '2024-12-01';
DECLARE
  end_date DATE DEFAULT '2024-12-31';

WITH
  -- Step 1: Get the users from the ""com.ssfshop.app"" app
  users AS (
    SELECT DISTINCT req.device.ifa
    FROM `focal-elf-631.prod_stream_view.cv`
    WHERE api.product.app.tracking_bundle = 'com.ssfshop.app'
      AND cv.pb.event.name = 'af_purchase'
      AND DATE(timestamp) BETWEEN start_date AND end_date
      AND `moloco-ods.general_utils.is_userid_truly_available`(req.device.ifa)
  ),

  -- Step 2a: Get non-Coupang postback data from the avro table
  non_coupang_data AS (
    SELECT 
      app_bundle,
      idfa
    FROM `focal-elf-631.user_data_v2_avro.pb_raw_latest`
    WHERE DATE(TIMESTAMP_MILLIS(latest_millis)) BETWEEN start_date AND end_date
    GROUP BY ALL
  ),

  -- Step 2b: Get Coupang postback data
  coupang_data AS (
    SELECT
      app_id AS app_bundle,
      device.ifa AS idfa
    FROM `focal-elf-631.ingest_prod.app_event`
    WHERE DATE(timestamp) BETWEEN start_date AND end_date
      AND app_id = 'com.coupang.mobile'
      AND `moloco-ods.general_utils.is_userid_truly_available`(device.ifa)
    GROUP BY ALL
  ),

  -- Combine both postback data sources
  all_data AS (
    SELECT * FROM non_coupang_data
    UNION ALL
    SELECT * FROM coupang_data
  )

  -- Final join to count the distinct user records per app bundle
, apps AS (
  SELECT
    app_bundle,
    COUNT(DISTINCT users.ifa) AS idfa_count
  FROM all_data
  RIGHT JOIN users
    ON users.ifa = all_data.idfa
  GROUP BY 1
)

SELECT
  DISTINCT app_bundle,
  dataai.app_name,
  dataai.genre,
  dataai.sub_genre,
  dataai.is_gaming,
  idfa_count
FROM
  apps
LEFT JOIN `moloco-ae-view.athena.dim1_app` as profile on profile.app_market_bundle = apps.app_bundle
WHERE app_bundle != 'com.ssfshop.app'
ORDER BY 6 DESC


#### 브롤스타즈 유저 ####
 DECLARE bundles ARRAY<STRING> DEFAULT [
   'com.supercell.brawlstars',
   'id1229016807',
   'id1504236603'
 ];
 DECLARE lookback_window INT64 DEFAULT 90 ;
 DECLARE tgt_country STRING DEFAULT 'KOR';


 -- rtb
 WITH rtb AS (
   SELECT
     DISTINCT
       idfa
   FROM
     `focal-elf-631.user_data_v2_avro.lifetime_summary_latest`
   WHERE
     TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), PARSE_TIMESTAMP("%F %T %Z", latest_date_time), DAY) < 30
     AND (country = tgt_country)
 ),
  -- postback
 upt AS (
   SELECT DISTINCT
       idfa,
       top_frequent_countries
     FROM `focal-elf-631.upt_data.summary_all_2025*`
     WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL lookback_window DAY)) AND FORMAT_DATE('%m%d', CURRENT_DATE())
 ),




 postback AS (
   SELECT
       DISTINCT idfa
   FROM `focal-elf-631.user_data_v2_avro.pb_raw_latest`
     JOIN upt USING(idfa)
   WHERE DATE(TIMESTAMP_MILLIS(latest_millis)) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL lookback_window DAY) AND CURRENT_DATE()
     AND app_bundle IN UNNEST(bundles)
     AND JSON_VALUE(top_frequent_countries, '$[0].country') = tgt_country
 ),


 lookback AS (
   SELECT
     COUNT(DISTINCT idfa) AS rtb_user_count
     FROM postback
     JOIN rtb
     USING (idfa)
 )


 SELECT
   cnt_pb,
   rtb_user_count ,
   SAFE_DIVIDE(rtb_user_count, cnt_pb) AS match_rate
 FROM lookback, (SELECT count(DISTINCT idfa) AS cnt_pb FROM postback)

  
  


#### GenZ가 사용할 것 같은 앱 (한국) ####
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


DECLARE end_date DATE DEFAULT '2025-09-14';

--- rtb (for the past 45 days)
SELECT
  apps.bundle,
  COUNT(DISTINCT maid) cnt_maid
FROM `focal-elf-631.df_user_data_v3.rtb_lifetime`, UNNEST(apps) apps
WHERE apps.bundle IN UNNEST(bundles)
AND country = 'KOR'
GROUP BY 1
ORDER BY 2 DESC


WITH mmp_bundles AS (
    SELECT DISTINCT
        app_store_bundle,
        tracking_bundle
    FROM `focal-elf-631.standard_digest.product_digest`
    WHERE app_store_bundle IN UNNEST(bundles)
), 

upt AS (
    SELECT DISTINCT 
        idfa,
        country
    FROM `focal-elf-631.upt_data.summary_all_2025*`
    WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%m%d', DATE_SUB(end_date, INTERVAL 90 DAY)) AND FORMAT_DATE('%m%d', end_date)
)

SELECT
    app_bundle,
    COUNT(DISTINCT idfa) AS cnt_idfa
FROM `focal-elf-631.user_data_v2_avro.pb_raw_latest`
        JOIN upt USING(idfa)
WHERE DATE(TIMESTAMP_MILLIS(latest_millis)) BETWEEN DATE_SUB(end_date, INTERVAL 90 DAY) AND end_date
    AND app_bundle IN (SELECT tracking_bundle FROM mmp_bundles)
    AND country = 'KOR'
GROUP BY ALL