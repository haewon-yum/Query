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


WITH app AS(
    SELECT 
        DISTINCT
            app_market_bundle,
            dataai.app_name
    FROM `moloco-ae-view.athena.dim1_app`
    WHERE 1=1
        AND (app_market_bundle IN UNNEST(pa_enabled) OR app_market_bundle IN UNNEST(pa_disabled))

)


SELECT
    FORMAT_DATE('%y-%m', timestamp) AS mon,
    b.app_name,
    app.bundle,
    CASE WHEN app.bundle IN UNNEST(pa_enabled) THEN 'pa_enabled' ELSE 'pa_disabled' END AS pa_status,
    event.name,
    COUNT(1) as cnt
FROM `focal-elf-631.prod_stream_view.pb` a
    LEFT JOIN app b ON a.app.bundle = b.app_market_bundle
WHERE
    moloco.attributed is FALSE
    AND (app.bundle IN UNNEST(pa_enabled) OR app.bundle IN UNNEST(pa_disabled))
    AND DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY) AND CURRENT_DATE()
GROUP BY ALL