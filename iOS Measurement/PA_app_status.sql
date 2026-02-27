### CHECK fp_status for an app bundle ###
## https://www.notion.so/How-to-check-and-Update-probabilistic-attribution-allowance-a5f7aa63892c456c9aa282caa785f68f?pvs=4
SELECT 
    utc_date, 
    mmp, 
    tracking_bundle, 
    fp_status_today, 
    fp_status_prior, 
    fp_status_2d_prior, 
    media_cost, 
    fp_status_today <> fp_status_prior AND fp_status_prior <> fp_status_2d_prior AS oscillating
  FROM (
    SELECT
      utc_date,
      mmp,
      tracking_bundle,
      verdict.fp_status AS fp_status_today,
      LEAD(verdict.fp_status, 1) OVER(PARTITION BY mmp, tracking_bundle ORDER BY utc_date DESC) AS fp_status_prior,
      LEAD(verdict.fp_status, 2) OVER(PARTITION BY mmp, tracking_bundle ORDER BY utc_date DESC) AS fp_status_2d_prior,
      ROUND(spend.total, 2) AS media_cost
    FROM
      `focal-elf-631.mmp_pb_summary.app_status`
    WHERE
      utc_date >= DATE_SUB(CURRENT_DATE("-8"), INTERVAL 3 DAY)
      AND tracking_bundle = @tracking_bundle)



-- PA status by genre (+sub genre) // (2024/07/01 이후 campaign enalbeld 된 iOS App 대상) 앱별 PA 설정 비율 (단위: 앱)
WITH campaign_digest AS(
  SELECT 
    -- product_category,
    store_bundle, 
    tracking_bundle
  FROM `focal-elf-631.prod.campaign_digest_merged_20*`
  WHERE
    _TABLE_SUFFIX between FORMAT_DATE('%y%m%d', DATE('2024-07-01')) AND FORMAT_DATE('%y%m%d', DATE('2024-09-03'))
    AND enabled = TRUE
  GROUP BY ALL
)

SELECT
  dataai.genre,
  dataai.sub_genre,
  dataai.is_gaming,
  verdict.fp_status AS fp_status,
  count(distinct dataai.app_id) as cnt
FROM
`focal-elf-631.mmp_pb_summary.app_status` a
    LEFT JOIN campaign_digest b ON a.tracking_bundle = b.store_bundle
    LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = CAST(c.dataai.app_id AS String)
WHERE
  utc_date between "2024-07-01" AND "2024-09-03"
  -- AND spend.total > 0
GROUP BY 1,2,3,4





-- PA status by genre (+sub genre) / KOR
ITH campaign_digest AS(
  SELECT 
    -- product_category,
    store_bundle, 
    tracking_bundle
  FROM `focal-elf-631.prod.campaign_digest_merged_20*`
  WHERE
    _TABLE_SUFFIX between FORMAT_DATE('%y%m%d', DATE('2024-07-01')) AND FORMAT_DATE('%y%m%d', DATE('2024-09-03'))
    AND enabled = TRUE
  GROUP BY ALL
)

SELECT
  dataai.genre,
  dataai.sub_genre,
  dataai.is_gaming,
  verdict.fp_status AS fp_status,
  count(distinct dataai.app_id) as cnt
FROM
`focal-elf-631.mmp_pb_summary.app_status` a
    LEFT JOIN campaign_digest b ON a.tracking_bundle = b.store_bundle
    LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = CAST(c.dataai.app_id AS String)
WHERE
  utc_date between "2024-07-01" AND "2024-09-03"
  AND dataai.company_hq_country = 'KOR'
  -- AND spend.total > 0
GROUP BY 1,2,3,4




-- SKAN only primary measurement app bundles (as of 24 Q2)
1638368439
1577316192
1635215598
6451441170
295646461
930441707
1447274646
1641218070
359578668
788953250
1375031369
1375031369
1509886058
1077137248
477967747
6470362045
545599256
1017551780
1333256716
1091496983
6463715971
284815942
6449925651
6478001589
429047995
1465591510
1364215562
1608880742
369649855
331177714
1485219703
835599320
524123600
6469305531
1639287909
1662742277
1658717149




-- SKAN-only로 보면서, PA enable한 customer list 확인
WITH campaign_digest AS(
  SELECT 
    -- product_category,
    store_bundle, 
    tracking_bundle
  FROM `focal-elf-631.prod.campaign_digest_merged_20*`
  WHERE
    _TABLE_SUFFIX between FORMAT_DATE('%y%m%d', DATE('2024-07-01')) AND FORMAT_DATE('%y%m%d', DATE('2024-09-03'))
    -- AND enabled = TRUE
  GROUP BY ALL
)

SELECT
  dataai.company_name,
  dataai.app_name,
  dataai.genre,
  dataai.sub_genre,
  dataai.is_gaming,
  verdict.fp_status AS fp_status
  
  -- ,
  -- count(distinct dataai.app_id) as cnt
FROM
`focal-elf-631.mmp_pb_summary.app_status` a
    LEFT JOIN campaign_digest b ON a.tracking_bundle = b.store_bundle
    LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = CAST(c.dataai.app_id AS String)
WHERE
  utc_date between "2024-07-01" AND "2024-09-03"
    AND dataai.app_id in (
        1638368439,
        1577316192,
        1635215598,
        6451441170,
        295646461,
        930441707,
        1447274646,
        1641218070,
        359578668,
        788953250,
        1375031369,
        1375031369,
        1509886058,
        1077137248,
        477967747,
        6470362045,
        545599256,
        1017551780,
        1333256716,
        1091496983,
        6463715971,
        284815942,
        6449925651,
        6478001589,
        429047995,
        1465591510,
        1364215562,
        1608880742,
        369649855,
        331177714,
        1485219703,
        835599320,
        524123600,
        6469305531,
        1639287909,
        1662742277,
        1658717149
    )
GROUP BY ALL
