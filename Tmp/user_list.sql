/* 

https://mlc.atlassian.net/browse/ODSB-13835

-- REF --

찾았어여 혜원님!!! :face_holding_back_tears: 저도 사실 처음 조회해보는건데 아직 유효하네여 꺄 다행다행…
https://moloco.slack.com/archives/C03U3P211J7/p1675848523685459



chaeyoung
customer set id면 저는
SELECT
  SUBSTR(key, -1 * LENGTH(key) + 2) AS idfa,
  qualifier
FROM
  `focal-elf-631.df_bigtable.upt_tagging_latest`
WHERE
  qualifier IN ('_m:audience:Cred#k9xoCBFsyNgvL0Tv',
    '_m:audience:E6oxZpMp2HinxNgE#k9xoCBFsyNgvL0Tv')
요런 식으로 qualifier에 _m:audience:{advertiser_id}#{customer_set_id} 아님 _m:audience:{platform_id}#{customer_set_id} 조건 넣어서 뽑았어요


*/

DECLARE target_ids ARRAY<STRING> DEFAULT [
  'KGzV9ADJwOKQk2Gx',
  'L4RCKC2zvbCAAvrT',
  'ZqLhykgWVP4Oj6Bm',
  'gggMRMEof6Tk2eDh',
  'uWpa7CGj0QRZsg7P'
];
DECLARE platform STRING DEFAULT  'MIRAEPMP';
DECLARE advertiser_id STRING DEFAULT  'iqdJi1v2hJWKcnfB';

WITH ids AS (
  SELECT target_id
  FROM UNNEST(target_ids) AS target_id
),

audience_target AS (
  SELECT
    i.target_id,
    SUBSTR(key, -1 * LENGTH(key) + 2) AS idfa,
    qualifier
  FROM
    `focal-elf-631.df_bigtable.upt_tagging_latest`, ids i
  WHERE
    qualifier IN (CONCAT('_m:audience:', platform,'#',i.target_id),
                  CONCAT('_m:audience:', advertiser_id,'#',i.target_id))
),

rtb_user AS (
    SELECT
        os,
        idfa,
        country
    FROM `focal-elf-631.user_data_v2_avro.lifetime_summary_latest`
    WHERE TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), PARSE_TIMESTAMP("%F %T %Z", latest_date_time), DAY) < 30
    AND country = 'KOR'
)

SELECT
  tg.target_id,
  COUNT(DISTINCT tg.idfa) AS target_user_count,
  COUNT(DISTINCT rtb_user.idfa) AS available_user_count,
  ROUND(100 * SAFE_DIVIDE(
          COUNT(DISTINCT rtb_user.idfa),
          COUNT(DISTINCT tg.idfa)
        ), 2) AS match_rate_pct
FROM audience_target tg
LEFT JOIN rtb_user USING (idfa)
GROUP BY tg.target_id
ORDER BY tg.target_id;

-- SELECT
--     target_id AS user_list,
--     COUNT(DISTINCT audience_target.idfa) target_user_count,
--     COUNT(DISTINCT rtb_user.idfa) available_user_count,
--     ROUND(SAFE_DIVIDE(COUNT(DISTINCT rtb_user.idfa), COUNT(DISTINCT audience_target.idfa) ) * 100, 2) match_rate
-- FROM audience_target LEFT JOIN rtb_user USING(idfa)