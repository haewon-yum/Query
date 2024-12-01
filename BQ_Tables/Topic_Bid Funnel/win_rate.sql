/* 

- win rate : # of impressions / # of biddings 

*/

DECLARE
    platform_id STRING DEFAULT "NEXON"

WITH bid AS(
    SELECT 
        api.platform.id AS platform, 
        COUNT(DISTINCT bid.mtid) AS cnt_mtid
    FROM `focal-elf-631.prod_stream_view.bid`
    WHERE api.platform.id = platform_id
        AND timestamp BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 100 DAY) AND CURRENT_DATE()
)