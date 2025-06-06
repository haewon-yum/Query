/* 
    https://moloco.slack.com/archives/C03U3P211J7/p1675848523685459

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


SELECT
  SUBSTR(key, -1 * LENGTH(key) + 2) AS idfa,
  qualifier
FROM
  `focal-elf-631.df_bigtable.upt_tagging_latest`
WHERE
  qualifier IN ('_m:audience:YANOLJA#mNXgMJ5CyH2MQS2V',
    '_m:audience:Os7oojpjTo8JwHIt#mNXgMJ5CyH2MQS2V')


SELECT
  SUBSTR(key, -1 * LENGTH(key) + 2) AS idfa,
  qualifier
FROM
  `focal-elf-631.df_bigtable.upt_tagging_latest`
WHERE
  qualifier IN ('_m:audience:YANOLJA#yuKmJCRyfOYX08y4',
    '_m:audience:Os7oojpjTo8JwHIt#yuKmJCRyfOYX08y4')