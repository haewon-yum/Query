-- report_final_skan
-- 

DECLARE pa_enabled ARRAY<string> DEFAULT [
    '6470362045',
    '6463715971',
    '6449925651',
    '1509886058',
    '1465591510',
    '1333256716',
    '1017551780'
];
DECLARE pa_disabled ARRAY<string> DEFAULT [
    '6451441170',
    '1662742277',
    '1485219703'
];


WITH product AS(
    SELECT 
        DISTINCT
            advertiser.mmp_bundle_id,
            product_id
    FROM `moloco-ae-view.athena.fact_dsp_core`
    WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY) AND CURRENT_DATE()
        AND advertiser.mmp_bundle_id IN UNNEST(pa_enabled)

)
SELECT
    FORMAT_DATE('%y-%m', time_bucket) AS mon,
    platform,
    s.product_id,
    campaign_id,
    -- traffic_lat,
    -- SKAN_Fidelity_Type,
    -- SKAN_conversionValue,
    -- SKAN_ConversionCount,
    -- conversion_event,
    CASE WHEN p.mmp_bundle_id IN UNNEST(pa_disabled) THEN 'pa_disabled' ELSE 'pa_enabled' END AS pa_status,
    SUM(Spend) AS spend,
    SUM(SKAN_ConversionCount) as conversion_count,
    SUM(SKAN_ConversionEventRevenueMinSum) AS SKAN_Revenue_min,
    SUM(SKAN_ConversionEventRevenueMaxSum) AS SKAN_Revenue_max
FROM `focal-elf-631.standard_report_v1_view.report_final_skan` s
    LEFT JOIN product p ON s.Product_ID = p.product_id
WHERE
    (p.mmp_bundle_id IN UNNEST(pa_disabled) OR p.mmp_bundle_id IN UNNEST(pa_enabled) )
    AND date(time_bucket) between DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY) AND CURRENT_DATE()
GROUP BY ALL
ORDER BY 1,2


/* 
[SKAN only apps]
- check daily pa status 
- if there are turning point (OFF->ON), let's compare the performance pre/post


*/

DECLARE 
    skan_primary ARRAY<STRING> DEFAULT [
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


WITH campaign_digest AS(
-- 0701-0903 campaign enabled 된 앱
    SELECT
        -- product_category,
        store_bundle,
        tracking_bundle
    FROM `focal-elf-631.prod.campaign_digest_merged_20*`
    WHERE
        _TABLE_SUFFIX between FORMAT_DATE('%y%m%d', DATE('2024-07-01')) AND FORMAT_DATE('%y%m%d', DATE('2024-09-03'))
        AND store_bundle IN UNNEST(skan_primary)
    GROUP BY ALL
),
pa_status AS(
    SELECT
        b.store_bundle,
        c.dataai.app_name,
        dataai.genre,
        dataai.sub_genre,
        dataai.is_gaming,
        utc_date,
        CASE WHEN verdict.fp_status = 'ENABLED' then 'ENABLED' ELSE 'DISABLED' END AS status2
    FROM `focal-elf-631.mmp_pb_summary.app_status` a
        JOIN campaign_digest b ON a.tracking_bundle = b.tracking_bundle
        LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = c.app_market_bundle
    WHERE
        utc_date between "2024-07-01" AND "2024-09-03"
    GROUP BY ALL
)
SELECT *
FROM pa_status
ORDER BY 1,2,6