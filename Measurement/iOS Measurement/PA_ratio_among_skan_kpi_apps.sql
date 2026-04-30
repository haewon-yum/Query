-- SKAN-only 가 primary인 커스터머 중 PA ENABLED 된 앱 비중		
WITH campaign_digest AS(																								
-- 0701-0903 campaign enabled 된 앱																								
    SELECT																								
    -- product_category,																								
    store_bundle,																								
    tracking_bundle																								
    FROM `focal-elf-631.prod.campaign_digest_merged_20*`																								
    WHERE																								
    _TABLE_SUFFIX between FORMAT_DATE('%y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AND FORMAT_DATE('%y%m%d', CURRENT_DATE())																								
    AND enabled = TRUE																								
    GROUP BY ALL																								
),																								
pa_status AS(																								
SELECT																								
    dataai.genre,																								
    dataai.sub_genre,																								
    dataai.is_gaming,																								
    CASE WHEN verdict.fp_status = 'ENABLED' then 'ENABLED' ELSE 'DISABLED' END AS status2,																								
    dataai.app_id,																								
    count(utc_date) as cnt_date,																								
FROM																								
    `focal-elf-631.mmp_pb_summary.app_status` a																								
    JOIN campaign_digest b ON a.tracking_bundle = b.tracking_bundle																								
    LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = CAST(c.dataai.app_id AS String)																								
WHERE																								
utc_date between DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND CURRENT_DATE()							
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
GROUP BY 1,2,3,4,5																								
),																								
                                                                                                
-- 0701-0903 기간 중 ENABLED 기간이 DISABLED 기간 보다 많으면, "ENABLED"로 카운트.																								
pa_status_summary AS(																								
SELECT																								
    is_gaming,																								
    app_id,																								
    COALESCE(MAX(cnt_enabled_date),0) as cnt_enabled_date,																								
    COALESCE(MAX(cnt_disabled_date),0) as cnt_disabled_date																								
FROM(																								
SELECT																								
    is_gaming,																								
    app_id,																								
    CASE WHEN status2 = 'ENABLED' then cnt_date END as cnt_enabled_date,																								
    CASE WHEN status2 = 'DISABLED' then cnt_date END AS cnt_disabled_date																								
FROM pa_status																								
)t																								
GROUP BY 1,2																								
)																								
SELECT																								
    is_gaming,																								
    COUNT(CASE WHEN cnt_enabled_date >= cnt_disabled_date then 1 else NULL END) AS cnt_enabled_app,																								
    COUNT(CASE WHEN cnt_enabled_date < cnt_disabled_date then 1 else NULL END) AS cnt_disabled_app,																								
FROM pa_status_summary																								
GROUP BY 1																								





/* 
    UPDATE:
         - Include Platform ID 
         - Using the last 1yr data
    Notes:
         -  `focal-elf-631.mmp_pb_summary.app_status` 테이블은 최근 90일의 데이터만을 저장한다. 
*/


DECLARE skan_only_str ARRAY<STRING> DEFAULT [
    '1638368439',																								
    '1577316192',																								
    '1635215598',																								
    '6451441170',																								
    '295646461',																								
    '930441707',																								
    '1447274646',																								
    '1641218070',																								
    '359578668',																								
    '788953250',																								
    '1375031369',																								
    '1375031369',																								
    '1509886058',																								
    '1077137248',																								
    '477967747',																								
    '6470362045',																								
    '545599256',																								
    '1017551780',																								
    '1333256716',																								
    '1091496983',																								
    '6463715971',																								
    '284815942',																								
    '6449925651',																								
    '6478001589',																								
    '429047995',																								
    '1465591510',																								
    '1364215562',																								
    '1608880742',																								
    '369649855',																								
    '331177714',																								
    '1485219703',																								
    '835599320',																								
    '524123600',																								
    '6469305531',																								
    '1639287909',																								
    '1662742277',																								
    '1658717149'
];

-- SKAN-only 가 primary인 커스터머 중 PA ENABLED 된 앱 비중		
WITH campaign_digest AS(																																										
    SELECT																								
        platform_name,
        advertiser_name,
        advertiser_display_name,
        product_display_name,																						
        store_bundle,																								
        tracking_bundle																								
    FROM `focal-elf-631.prod.campaign_digest_merged_latest`																								
    WHERE																								
        store_bundle in ( -- SKAN-primary Apps as of 2024 Q2																		
            '1638368439',																								
            '1577316192',																								
            '1635215598',																								
            '6451441170',																								
            '295646461',																								
            '930441707',																								
            '1447274646',																								
            '1641218070',																								
            '359578668',																								
            '788953250',																								
            '1375031369',																								
            '1375031369',																								
            '1509886058',																								
            '1077137248',																								
            '477967747',																								
            '6470362045',																								
            '545599256',																								
            '1017551780',																								
            '1333256716',																								
            '1091496983',																								
            '6463715971',																								
            '284815942',																								
            '6449925651',																								
            '6478001589',																								
            '429047995',																								
            '1465591510',																								
            '1364215562',																								
            '1608880742',																								
            '369649855',																								
            '331177714',																								
            '1485219703',																								
            '835599320',																								
            '524123600',																								
            '6469305531',																								
            '1639287909',																								
            '1662742277',																								
            '1658717149'																								
        )					
    GROUP BY ALL																								
),																								
pa_status AS(																								
SELECT
    platform_name,
    advertiser_name,
    advertiser_display_name,
    product_display_name,
    store_bundle,
    dataai.genre,																								
    dataai.sub_genre,																								
    dataai.is_gaming,																								
    CASE WHEN verdict.fp_status = 'ENABLED' then 'ENABLED' ELSE 'DISABLED' END AS status2,																																																
    count(utc_date) as cnt_date,																								
FROM																								
    `focal-elf-631.mmp_pb_summary.app_status` a																								
    JOIN campaign_digest b ON a.tracking_bundle = b.tracking_bundle																								
    LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = c.app_market_bundle
WHERE																								
    utc_date between DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND CURRENT_DATE()
    AND app_market_bundle in UNNEST(skan_only_str)
GROUP BY ALL
),
                                                                                                
-- 최근 90일 기간 중 ENABLED 기간이 DISABLED 기간 보다 많으면, "ENABLED"로 카운트.																								
pa_status_summary AS(																								
SELECT
    platform_name,
    advertiser_name,
    advertiser_display_name,
    product_display_name,
    store_bundle,
    is_gaming,																								
    COALESCE(MAX(cnt_enabled_date),0) as cnt_enabled_date,																								
    COALESCE(MAX(cnt_disabled_date),0) as cnt_disabled_date																								
FROM(																								
    SELECT		
        platform_name,
        advertiser_name,
        advertiser_display_name,
        store_bundle,
        product_display_name,																				
        is_gaming,																								
        CASE WHEN status2 = 'ENABLED' then cnt_date END as cnt_enabled_date,																								
        CASE WHEN status2 = 'DISABLED' then cnt_date END AS cnt_disabled_date																								
    FROM pa_status
)t																								
GROUP BY ALL
),

pa_status_summary2 AS(
    SELECT 
        platform_name,
        advertiser_name,
        advertiser_display_name,
        store_bundle,
        product_display_name,
        is_gaming,
        CASE
            WHEN cnt_enabled_app = 1 AND cnt_disabled_app = 1 then 'ENABLED' 
            WHEN cnt_enabled_app = 1 then 'ENABLED'
            WHEN cnt_disabled_app = 1 then 'DISABLED'
        END AS pa_status 
    FROM(
        SELECT	
            platform_name,
            advertiser_name,
            advertiser_display_name,
            store_bundle,
            product_display_name,
            is_gaming,
            COUNT(CASE WHEN cnt_enabled_date >= cnt_disabled_date then 1 else NULL END) AS cnt_enabled_app,																								
            COUNT(CASE WHEN cnt_enabled_date < cnt_disabled_date then 1 else NULL END) AS cnt_disabled_app,																								
        FROM pa_status_summary																								
        GROUP BY ALL																								
    )t
),
-- 대상 앱들의 최근 1년간의 성과
fact_dsp_core AS (SELECT * FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE
          ((( TIMESTAMP(date_utc) ) >= ((TIMESTAMP_TRUNC(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), YEAR))) AND ( TIMESTAMP(date_utc) ) 
          < ((TIMESTAMP(DATETIME_ADD(DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), YEAR)), INTERVAL 1 YEAR))))))

          )
SELECT
    fact_dsp_core.product.genre  AS genre,
    fact_dsp_core.platform_id  AS platform_id,
    fact_dsp_core.advertiser.title_id AS advertiser,
    fact_dsp_core.product.app_name  AS app_name,
    store_bundle,
    pa_status, -- based on the last 90 days
    SAFE_DIVIDE(COALESCE(SUM(fact_dsp_core.revenue_d7 ), 0), COALESCE(SUM(fact_dsp_core.gross_spend_usd ), 0)) AS roas_d7
FROM fact_dsp_core  JOIN pa_status_summary2 b 
        ON fact_dsp_core.platform_id = b.platform_name 
        AND fact_dsp_core.advertiser_id = b.advertiser_name
        AND fact_dsp_core.product.app_market_bundle = b.store_bundle
WHERE ((( TIMESTAMP(fact_dsp_core.date_utc)  ) >= ((TIMESTAMP_TRUNC(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), YEAR))) 
    AND ( TIMESTAMP(fact_dsp_core.date_utc)  ) < ((TIMESTAMP(DATETIME_ADD(DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), YEAR)), INTERVAL 1 YEAR)))))) 
    AND (fact_dsp_core.product.app_market_bundle ) IN UNNEST(skan_only_str) 
    AND (fact_dsp_core.campaign.goal ) = 'OPTIMIZE_ROAS_FOR_APP_UA'
GROUP BY ALL
ORDER BY
    5 DESC