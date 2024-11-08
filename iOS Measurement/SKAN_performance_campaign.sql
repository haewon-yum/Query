SELECT
    Extract(MONTH FROM time_bucket) AS mon,
    campaign_id,
    SUM(Spend) AS spend,
    SUM(SKAN_ConversionEventRevenueMinSum),
    SUM(SKAN_ConversionEventRevenueMaxSum)
FROM `focal-elf-631.standard_report_v1_view.report_final_skan`
WHERE
    product_id = 'ge0sqa8atEFVNIW5'
    AND date(time_bucket) between "2024-01-01" AND "2024-09-30"
GROUP BY ALL
ORDER BY 1,2


-- 24.10 Binance SKAN performance check after turning on PA
SELECT 
  Extract(MONTH FROM time_bucket) AS mon,
  -- traffic_lat,
  -- SKAN_Fidelity_Type,
  -- conversion_event,
  SUM(SKAN_ConversionCount),
  SUM(spend),
  SUM(SKAN_ConversionEventRevenueMinSum),
  SUM(SKAN_ConversionEventRevenueMaxSum)
FROM `focal-elf-631.standard_report_v1_view.report_final_skan`
WHERE
    product_id = 'ge0sqa8atEFVNIW5'
    AND date(time_bucket) between "2024-01-01" AND "2024-10-23"
GROUP BY ALL


SELECT
    Extract(MONTH FROM time_bucket) AS mon,
    campaign_id,
    -- traffic_lat,
    SKAN_Fidelity_Type,
    SKAN_conversion_value,
    SKAN_Conversion_Count
    -- conversion_event,
    SUM(Spend) AS spend,
    SUM(conversion_Count) as conversion_count,
    SUM(SKAN_ConversionEventRevenueMinSum) AS SKAN_Revenue_min,
    SUM(SKAN_ConversionEventRevenueMaxSum) AS SKAN_Revenue_max,
FROM `focal-elf-631.standard_report_v1_view.report_final_skan`
WHERE
    product_id = 'ge0sqa8atEFVNIW5'
    AND date(time_bucket) between "2024-01-01" AND "2024-10-23"
GROUP BY ALL
ORDER BY 1,2


-- 22.07 37Games
SELECT 
  Date(time_bucket) AS date,
  -- traffic_lat,
  -- SKAN_Fidelity_Type,
  -- conversion_event,
  SUM(SKAN_ConversionCount),
  SUM(spend),
  SUM(SKAN_ConversionEventRevenueMinSum),
  SUM(SKAN_ConversionEventRevenueMaxSum)
FROM `focal-elf-631.standard_report_v1_view.report_final_skan`
WHERE
    Campaign_ID = 'fiSv7bobAAj6lUB2'
    AND date(time_bucket) between "2021-07-01" AND "2021-07-31"
GROUP BY ALL