/* bid request trace  */

SELECT
  bid_trace_id,
  exchange,
  app_bundle,
  inventory_format,
  country,
  os,
  raw_json,
  timestamp,
  rate,
FROM
  `focal-elf-631.prod.trace20*`
WHERE
  _table_suffix BETWEEN '251125' AND '251201'
  AND campaign LIKE '%M6giJLigPtuM53zz%'
  AND app_bundle = 'com.kakao.talk'
LIMIT 1000


-- adxr_20251113223240787977020056:1763040760940804178