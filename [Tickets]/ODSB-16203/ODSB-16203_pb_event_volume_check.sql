/*
    Check postback volume for com.towneers.www
    Events: click_pay_payment, click_pay_payment_ad
    Last 7 days
*/

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

-- Daily breakdown by event and attribution status
SELECT
    DATE(timestamp) AS date_utc,
    event.name AS event_name,
    moloco.attributed,
    COUNT(*) AS event_count,
    COUNT(DISTINCT device.ifa) AS unique_devices
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN start_date AND end_date
    AND app.bundle = 'com.towneers.www'
    AND LOWER(event.name) IN ('click_pay_payment', 'click_pay_payment_ad')
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;


-- Summary totals
SELECT
    event.name AS event_name,
    moloco.attributed,
    COUNT(*) AS total_events,
    COUNT(DISTINCT device.ifa) AS unique_devices,
    ROUND(COUNT(*) / 7.0, 1) AS avg_daily_events
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN start_date AND end_date
    AND app.bundle = 'com.towneers.www'
    AND LOWER(event.name) IN ('click_pay_payment', 'click_pay_payment_ad')
GROUP BY 1, 2
ORDER BY 1, 2;


-- Grand total (for RE model eligibility check)
SELECT
    'TOTAL' AS summary,
    COUNT(*) AS total_events,
    COUNT(DISTINCT device.ifa) AS unique_devices,
    ROUND(COUNT(*) / 7.0, 1) AS avg_daily_events,
    CASE 
        WHEN COUNT(*) / 7.0 >= 30 THEN '✅ Sufficient (>=30/day)'
        WHEN COUNT(*) / 7.0 >= 10 THEN '⚠️ Low but usable (10-30/day)'
        ELSE '❌ Insufficient (<10/day)'
    END AS volume_status
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN start_date AND end_date
    AND app.bundle = 'com.towneers.www'
    AND LOWER(event.name) IN ('click_pay_payment', 'click_pay_payment_ad');
