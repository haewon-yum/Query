/* US Market performance 
    - aggregation of App bundles across different platforms and advertisers
*/

DECLARE
run_from_date DATE DEFAULT '2024-07-01';
DECLARE
run_to_date DATE DEFAULT '2024-10-20';
DECLARE
platform_id ARRAY<STRING> DEFAULT [    
    'MYGAMES',
    'Lessmore',
    'TREEPLLA',
    'PLAYTIKA',
    'FUSEBOX',
    'RANXUN'
];
-- DECLARE
-- advertiser_id STRING DEFAULT 't52aeGmi7ov3wppl';
DECLARE
app_bundle ARRAY<STRING> DEFAULT [
    'com.fuseboxgames.loveisland2.gp',
    'fi.reworks.redecor',
    'com.vjsjlqvlmp.wearewarriors',
    'com.einckla.breaktea',
    'com.kidultlovin.royalsolitairesonic.bubbleshoot.classic',
    'com.tree.idle.cat.office',
    'com.lquilwe.fhuela',
    'com.my.defense'
];

WITH
osm_temp_t AS (
    SELECT
        CASE
            WHEN osm_id = 165475 THEN 'California'
            WHEN osm_id = 1116270 THEN 'Alaska'
            WHEN osm_id = 161950 THEN 'Alabama'
            WHEN osm_id = 161646 THEN 'Arkansas'
            WHEN osm_id = 162018 THEN 'Arizona'
            WHEN osm_id = 161961 THEN 'Colorado'
            WHEN osm_id = 165794 THEN 'Connecticut'
            WHEN osm_id = 162110 THEN 'Delaware'
            WHEN osm_id = 162050 THEN 'Florida'
            WHEN osm_id = 161957 THEN 'Georgia'
            WHEN osm_id = 166563 THEN 'Hawaii'
            WHEN osm_id = 161650 THEN 'Iowa'
            WHEN osm_id = 162116 THEN 'Idaho'
            WHEN osm_id = 122586 THEN 'Illinois'
            WHEN osm_id = 161816 THEN 'Indiana'
            WHEN osm_id = 161644 THEN 'Kansas'
            WHEN osm_id = 161655 THEN 'Kentucky'
            WHEN osm_id = 224922 THEN 'Louisiana'
            WHEN osm_id = 61315 THEN 'Massachusetts'
            WHEN osm_id = 162112 THEN 'Maryland'
            WHEN osm_id = 63512 THEN 'Maine'
            WHEN osm_id = 165789 THEN 'Michigan'
            WHEN osm_id = 165471 THEN 'Minnesota'
            WHEN osm_id = 161638 THEN 'Missouri'
            WHEN osm_id = 161943 THEN 'Mississippi'
            WHEN osm_id = 162115 THEN 'Montana'
            WHEN osm_id = 224045 THEN 'North Carolina'
            WHEN osm_id = 161653 THEN 'North Dakota'
            WHEN osm_id = 161648 THEN 'Nebraska'
            WHEN osm_id = 67213 THEN 'New Hampshire'
            WHEN osm_id = 224951 THEN 'New Jersey'
            WHEN osm_id = 162014 THEN 'New Mexico'
            WHEN osm_id = 165473 THEN 'Nevada'
            WHEN osm_id = 61320 THEN 'New York'
            WHEN osm_id = 162061 THEN 'Ohio'
            WHEN osm_id = 161645 THEN 'Oklahoma'
            WHEN osm_id = 165476 THEN 'Oregon'
            WHEN osm_id = 162109 THEN 'Pennsylvania'
            WHEN osm_id = 392915 THEN 'Rhode Island'
            WHEN osm_id = 224040 THEN 'South Carolina'
            WHEN osm_id = 161652 THEN 'South Dakota'
            WHEN osm_id = 161838 THEN 'Tennessee'
            WHEN osm_id = 114690 THEN 'Texas'
            WHEN osm_id = 161993 THEN 'Utah'
            WHEN osm_id = 224042 THEN 'Virginia'
            WHEN osm_id = 60759 THEN 'Vermont'
            WHEN osm_id = 165479 THEN 'Washington'
            WHEN osm_id = 165466 THEN 'Wisconsin'
            WHEN osm_id = 162068 THEN 'West Virginia'
            WHEN osm_id = 161991 THEN 'Wyoming'
        END AS osm_city,
        osm_id,
        geometry,
        ROW_NUMBER() OVER (PARTITION BY osm_id ORDER BY osm_id) AS rn
    FROM
        `bigquery-public-data.geo_openstreetmap.planet_layers`
    WHERE
        osm_id IN (165475,
        1116270,
        161950,
        161646,
        162018,
        161961,
        165794,
        162110,
        162050,
        161957,
        166563,
        161650,
        162116,
        122586,
        161816,
        161644,
        161655,
        224922,
        61315,
        162112,
        63512,
        165789,
        165471,
        161638,
        161943,
        162115,
        224045,
        161653,
        161648,
        67213,
        224951,
        162014,
        165473,
        61320,
        162061,
        161645,
        165476,
        162109,
        392915,
        224040,
        161652,
        161838,
        114690,
        161993,
        224042,
        60759,
        165479,
        165466,
        162068,
        161991) 
),
osm_t AS (
    SELECT
        osm_id,
        geometry,
        osm_city
    FROM
        osm_temp_t
    WHERE
        rn = 1 
),
ip_t AS (
    SELECT
        ipv4num_start,
        ipv4num_end,
        ip_start,
        CASE
            WHEN osm_id = 165475 THEN 'California'
            WHEN osm_id = 1116270 THEN 'Alaska'
            WHEN osm_id = 161950 THEN 'Alabama'
            WHEN osm_id = 161646 THEN 'Arkansas'
            WHEN osm_id = 162018 THEN 'Arizona'
            WHEN osm_id = 161961 THEN 'Colorado'
            WHEN osm_id = 165794 THEN 'Connecticut'
            WHEN osm_id = 162110 THEN 'Delaware'
            WHEN osm_id = 162050 THEN 'Florida'
            WHEN osm_id = 161957 THEN 'Georgia'
            WHEN osm_id = 166563 THEN 'Hawaii'
            WHEN osm_id = 161650 THEN 'Iowa'
            WHEN osm_id = 162116 THEN 'Idaho'
            WHEN osm_id = 122586 THEN 'Illinois'
            WHEN osm_id = 161816 THEN 'Indiana'
            WHEN osm_id = 161644 THEN 'Kansas'
            WHEN osm_id = 161655 THEN 'Kentucky'
            WHEN osm_id = 224922 THEN 'Louisiana'
            WHEN osm_id = 61315 THEN 'Massachusetts'
            WHEN osm_id = 162112 THEN 'Maryland'
            WHEN osm_id = 63512 THEN 'Maine'
            WHEN osm_id = 165789 THEN 'Michigan'
            WHEN osm_id = 165471 THEN 'Minnesota'
            WHEN osm_id = 161638 THEN 'Missouri'
            WHEN osm_id = 161943 THEN 'Mississippi'
            WHEN osm_id = 162115 THEN 'Montana'
            WHEN osm_id = 224045 THEN 'North Carolina'
            WHEN osm_id = 161653 THEN 'North Dakota'
            WHEN osm_id = 161648 THEN 'Nebraska'
            WHEN osm_id = 67213 THEN 'New Hampshire'
            WHEN osm_id = 224951 THEN 'New Jersey'
            WHEN osm_id = 162014 THEN 'New Mexico'
            WHEN osm_id = 165473 THEN 'Nevada'
            WHEN osm_id = 61320 THEN 'New York'
            WHEN osm_id = 162061 THEN 'Ohio'
            WHEN osm_id = 161645 THEN 'Oklahoma'
            WHEN osm_id = 165476 THEN 'Oregon'
            WHEN osm_id = 162109 THEN 'Pennsylvania'
            WHEN osm_id = 392915 THEN 'Rhode Island'
            WHEN osm_id = 224040 THEN 'South Carolina'
            WHEN osm_id = 161652 THEN 'South Dakota'
            WHEN osm_id = 161838 THEN 'Tennessee'
            WHEN osm_id = 114690 THEN 'Texas'
            WHEN osm_id = 161993 THEN 'Utah'
            WHEN osm_id = 224042 THEN 'Virginia'
            WHEN osm_id = 60759 THEN 'Vermont'
            WHEN osm_id = 165479 THEN 'Washington'
            WHEN osm_id = 165466 THEN 'Wisconsin'
            WHEN osm_id = 162068 THEN 'West Virginia'
            WHEN osm_id = 161991 THEN 'Wyoming'
            END AS OSM_City
    FROM (
        SELECT
            ipv4num_start,
            ipv4num_end,
            ip_start,
            osm_id,
            ROW_NUMBER() OVER (PARTITION BY ipv4num_start, ipv4num_end, ip_start ORDER BY osm_id ) AS rn
        FROM
            `focal-elf-631.geopoint_data.ip2location_to_osm_latest`,
            UNNEST(osm_ids) AS osm_id
        WHERE
            osm_id IN (165475,
            1116270,
            161950,
            161646,
            162018,
            161961,
            165794,
            162110,
            162050,
            161957,
            166563,
            161650,
            162116,
            122586,
            161816,
            161644,
            161655,
            224922,
            61315,
            162112,
            63512,
            165789,
            165471,
            161638,
            161943,
            162115,
            224045,
            161653,
            161648,
            67213,
            224951,
            162014,
            165473,
            61320,
            162061,
            161645,
            165476,
            162109,
            392915,
            224040,
            161652,
            161838,
            114690,
            161993,
            224042,
            60759,
            165479,
            165466,
            162068,
            161991)
        )
    WHERE
        rn = 1
    GROUP BY
    1,
    2,
    3,
    4
),
advertiser AS (
    SELECT
    *,
    COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), run_to_date) AS last_effective_date_local,
    FROM (
        SELECT
            DISTINCT effective_date_local,
            platform.id AS platform_id,
            advertiser.id AS advertiser_id,
            advertiser.timezone AS advertiser_timezone,
            platform.serving_cost_percent AS platform_serving_cost_percent,
            platform.contract_markup_percent AS platform_markup_percent
        FROM
            `moloco-dsp-data-source.costbook.costbook`
        WHERE
            campaign.country = 'USA'
            AND platform.id IN UNNEST(platform_id)
            AND DATE_DIFF(run_to_date, effective_date_local, DAY) >=0 
    ) 
),
advertiser_timezone AS (
    SELECT
        DISTINCT platform_id,
        advertiser_id,
        advertiser_timezone
    FROM
        advertiser 
),
imp_t AS (
    SELECT
        I.platform_id,
        I.advertiser_id,
        I.api.product.app.store_id,
        I.api.campaign.id AS campaign_id,
        I.api.campaign.title AS campaign_title,
        DATE(I.timestamp) AS date_utc,
        DATE(I.timestamp, A.advertiser_timezone) AS local_date,
        A.platform_serving_cost_percent,
        A.platform_markup_percent,
        I.req.device.os,
        CASE
            WHEN I.req.device.geo.lon BETWEEN -180 AND 180 AND I.req.device.geo.lat BETWEEN -90 AND 90 THEN I.req.device.geo.lat
            ELSE NULL
        END AS lat,
        CASE
            WHEN I.req.device.geo.lon BETWEEN -180 AND 180 AND I.req.device.geo.lat BETWEEN -90 AND 90 THEN I.req.device.geo.lon
            ELSE NULL
        END AS lon,
        `moloco-ods.general_utils.normalize_ip`(req.device.ip) AS ip,
        api.creative.cr_format AS cr_format,
        SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
        COUNT(*) AS imp
    FROM `focal-elf-631.prod_stream_view.imp` AS I
        INNER JOIN advertiser AS A ON
            I.platform_id = A.platform_id AND
            I.advertiser_id = A.advertiser_id AND
            A.effective_date_local <= DATE(I.timestamp, A.advertiser_timezone) AND DATE(I.timestamp, A.advertiser_timezone) <= A.last_effective_date_local
    WHERE
        DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
        AND req.device.geo.country = 'USA'
        AND api.product.app.store_id IN UNNEST(app_bundle)

        -- AND I.api.campaign.id IN UNNEST(campaign_id)
        -- AND api.creative.cr_format = 'vi'
    GROUP BY ALL
),
imp_usa_t AS (
    SELECT
        I.platform_id,
        I.advertiser_id,
        I.store_id,
        I.campaign_id,
        I.campaign_title,
        I.os,
        I.date_utc,
        I.local_date,
        COALESCE(O.osm_city, IF(I.lon IS NULL OR I.lon = 0, IP.osm_city, 'n/a'), 'other') AS city,
        I.cr_format,
        SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent / 100) * (1 + I.platform_markup_percent / 100)) AS FLOAT64) AS gross_spending_usd,
        SUM(I.imp) AS imp
    FROM imp_t AS I
        LEFT JOIN osm_t AS O ON ST_CONTAINS(O.geometry, ST_GEOGPOINT(I.lon, I.lat)) AND I.lon != 0
        LEFT JOIN ip_t IP ON
            NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(I.ip), 16) = NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(IP.ip_start), 16) AND
            NET.IPV4_TO_INT64(NET.SAFE_IP_FROM_STRING(I.ip)) BETWEEN IP.ipv4num_start AND IP.ipv4num_end
    GROUP BY ALL
),
-- cv_raw_t AS (
--     SELECT
--         platform_id,
--         advertiser_id,
--         C.api.campaign.id AS campaign_id,
--         C.api.campaign.title AS campaign_title,
--         C.req.device.os,
--         C.cv.event,
--         C.cv.event_pb,
--         C.click.happened_at AS click_happened_at,
--         api.creative.cr_format AS cr_format,
--         DATE(C.timestamp) AS date_utc,
--         DATE(C.timestamp, A.advertiser_timezone) AS local_date,
--         CASE WHEN C.req.device.geo.lon BETWEEN -180 AND 180 AND C.req.device.geo.lat BETWEEN -90 AND 90 THEN C.req.device.geo.lat ELSE NULL END AS lat,
--         CASE WHEN C.req.device.geo.lon BETWEEN -180 AND 180 AND C.req.device.geo.lat BETWEEN -90 AND 90 THEN C.req.device.geo.lon
--         ELSE NULL END AS lon,
--         `moloco-ods.general_utils.normalize_ip`(req.device.ip) AS ip,
--         bid.mtid,
--         C.cv.revenue_usd.amount AS revenue_usd
--     FROM `focal-elf-631.prod_stream_view.cv` AS C
--         INNER JOIN advertiser_timezone AS A USING (platform_id, advertiser_id)
--     WHERE DATE(C.timestamp) BETWEEN run_from_date AND run_to_date
--         AND api.product.app.store_id = app_bundle 
--         -- AND C.api.campaign.id IN UNNEST(campaign_id)
-- ),
-- cv_usa_t AS (
--     SELECT
--         C.platform_id,
--         C.advertiser_id,
--         C.campaign_id,
--         C.campaign_title,
--         C.os,
--         C.date_utc,
--         C.local_date,
--         COALESCE(O.osm_city, IF(C.lon IS NULL OR C.lon = 0, IP.osm_city, 'n/a'), 'other') AS city,
--         -- cr_format,
--         SUM(IF(C.event = 'INSTALL' AND C.click_happened_at IS NOT NULL, 1, 0)) AS ct_install,
--         SUM(IF(C.event = 'INSTALL', 1, 0)) AS install,
--         SUM(IF(C.event = 'CUSTOM_KPI_ACTION', 1, 0)) AS action,
--         SUM(IF(C.event_pb = 'inApp_revenue', 1, 0)) AS event_pb_action
--     FROM cv_raw_t AS C
--         LEFT JOIN osm_t AS O ON ST_CONTAINS(O.geometry, ST_GEOGPOINT(C.lon, C.lat)) AND C.lon != 0
--         LEFT JOIN ip_t IP ON
--             NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(C.ip), 16) = NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(IP.ip_start), 16) AND
--             NET.IPV4_TO_INT64(NET.SAFE_IP_FROM_STRING(C.ip)) BETWEEN IP.ipv4num_start AND IP.ipv4num_end
--     GROUP BY ALL
-- ),
cv_raw_t AS (
    SELECT
        *,
        MAX(install_utc) OVER (PARTITION BY platform_id, advertiser_id, store_id, campaign_id, os, mtid) AS install_at,
        IF(LOWER(event) NOT LIKE '%install%', TIMESTAMP_DIFF(timestamp, MAX(install_utc) OVER (PARTITION BY platform_id, advertiser_id, store_id, campaign_id, os, mtid), day), NULL) AS i_to_e_day_diff
    FROM(
        SELECT
            C.timestamp,
            platform_id,
            advertiser_id,
            api.product.app.store_id,
            C.api.campaign.id AS campaign_id,
            C.api.campaign.title AS campaign_title,
            C.req.device.os,
            C.cv.event,
            C.cv.event_pb,
            C.click.happened_at AS click_happened_at,
            CASE WHEN LOWER(C.cv.event) = 'install' or LOWER(C.cv.event_pb) = 'installs' THEN C.timestamp ELSE NULL END AS install_utc,
            api.creative.cr_format AS cr_format,
            DATE(C.timestamp) AS date_utc,
            DATE(C.timestamp, A.advertiser_timezone) AS local_date,
            CASE WHEN C.req.device.geo.lon BETWEEN -180 AND 180 AND C.req.device.geo.lat BETWEEN -90 AND 90 THEN C.req.device.geo.lat ELSE NULL END AS lat,
            CASE WHEN C.req.device.geo.lon BETWEEN -180 AND 180 AND C.req.device.geo.lat BETWEEN -90 AND 90 THEN C.req.device.geo.lon
            ELSE NULL END AS lon,
            `moloco-ods.general_utils.normalize_ip`(req.device.ip) AS ip,
            bid.mtid,
            C.cv.revenue_usd.amount AS revenue_usd,
        FROM `focal-elf-631.prod_stream_view.cv` AS C
            INNER JOIN advertiser_timezone AS A USING (platform_id, advertiser_id)
        WHERE DATE(C.timestamp) BETWEEN run_from_date AND run_to_date
            AND api.product.app.store_id IN UNNEST(app_bundle)
            AND C.req.device.geo.country = 'USA'
            -- AND C.api.campaign.id IN UNNEST(campaign_id)
    )t
),
cv_usa_t AS (
    SELECT
        C.platform_id,
        C.advertiser_id,
        C.store_id,
        C.campaign_id,
        C.campaign_title,
        C.os,
        C.date_utc,
        C.local_date,
        COALESCE(O.osm_city, IF(C.lon IS NULL OR C.lon = 0, IP.osm_city, 'n/a'), 'other') AS city,
        cr_format,
        SUM(IF(C.event = 'INSTALL' AND C.click_happened_at IS NOT NULL, 1, 0)) AS ct_install,
        SUM(IF(C.event = 'INSTALL', 1, 0)) AS install,
        SUM(IF(C.event = 'CUSTOM_KPI_ACTION', 1, 0)) AS action,
        SUM(IF(C.event_pb = 'inApp_revenue', 1, 0)) AS event_pb_action,
        COUNT(DISTINCT IF(i_to_e_day_diff=0, mtid, NULL)) as d0_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=1, mtid, NULL)) as d1_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=3, mtid, NULL)) as d3_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=7, mtid, NULL)) as d7_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=30, mtid, NULL)) as d30_retention,
    FROM cv_raw_t AS C
        LEFT JOIN osm_t AS O ON ST_CONTAINS(O.geometry, ST_GEOGPOINT(C.lon, C.lat)) AND C.lon != 0
        LEFT JOIN ip_t IP ON
            NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(C.ip), 16) = NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(IP.ip_start), 16) AND
            NET.IPV4_TO_INT64(NET.SAFE_IP_FROM_STRING(C.ip)) BETWEEN IP.ipv4num_start AND IP.ipv4num_end
    GROUP BY ALL
),
d7_roas_t AS (
    SELECT
        platform_id,
        advertiser_id,
        store_id,
        campaign_id,
        campaign_title,
        os,
        inst.date_utc,
        inst.local_date,
        inst.lon,
        inst.lat,
        inst.ip,
        COALESCE(inst.cr_format, act.cr_format) AS cr_format,
        SUM(act.revenue_usd) AS d7_revenue_usd,
        COUNT(DISTINCT mtid) AS d7_payer,
        COUNT(mtid) AS d7_rev_actions
    FROM (
            SELECT * FROM cv_raw_t WHERE LOWER(event) LIKE '%install%'
        ) AS inst
        INNER JOIN (
            SELECT * FROM cv_raw_t WHERE event_pb LIKE '%revenue%' OR event_pb LIKE '%purchase%' 
        ) AS act USING (mtid, platform_id, advertiser_id, store_id, campaign_id, campaign_title, os)
    WHERE DATE_DIFF(act.date_utc, inst.date_utc, DAY) < 7
    GROUP BY ALL
),
d7_roas_usa_t AS (
    SELECT
        R.platform_id,
        R.advertiser_id,
        R.store_id,
        R.campaign_id,
        R.campaign_title,
        R.os,
        R.date_utc,
        R.local_date,
        COALESCE(O.osm_city, IF(R.lon IS NULL OR R.lon = 0, IP.osm_city, 'n/a'), 'other') AS city,
        cr_format,
        SUM(R.d7_revenue_usd) AS d7_revenue_usd,
        SUM(R.d7_payer) AS d7_payer,
        SUM(R.d7_rev_actions) AS d7_rev_actions
    FROM d7_roas_t AS R
        LEFT JOIN osm_t AS O ON ST_CONTAINS(geometry, ST_GEOGPOINT(R.lon, R.lat)) AND R.lon != 0
        LEFT JOIN ip_t IP ON
            NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(R.ip), 16) = NET.IP_TRUNC(NET.SAFE_IP_FROM_STRING(IP.ip_start), 16) AND
            NET.IPV4_TO_INT64(NET.SAFE_IP_FROM_STRING(R.ip)) BETWEEN IP.ipv4num_start AND IP.ipv4num_end
    GROUP BY ALL
),
final AS (
    SELECT
        DATE_TRUNC(DATE(local_date), WEEK(MONDAY)) AS week,
        store_id,
        campaign_title,
        campaign_id,
        city,
        I.cr_format,
        os,
        COALESCE(SUM(I.gross_spending_usd), 0) AS gross_spending_usd,
        COALESCE(SUM(I.imp), 0) AS imp,
        COALESCE(SUM(CV.install), 0) AS install,
        COALESCE(SUM(CV.ct_install), 0) AS ct_install,
        COALESCE(SUM(CV.action), 0) AS action,
        COALESCE(SUM(CV.d0_retention), 0) AS d0_retention,
        COALESCE(SUM(CV.d1_retention), 0) AS d1_retention,
        COALESCE(SUM(CV.d3_retention), 0) AS d3_retention,
        COALESCE(SUM(CV.d7_retention), 0) AS d7_retention,
        COALESCE(SUM(CV.d30_retention), 0) AS d30_retention,
        COALESCE(SUM(R.d7_revenue_usd), 0) AS d7_revenue_usd,
        COALESCE(SUM(R.d7_payer), 0) AS d7_payer,
        COALESCE(SUM(R.d7_rev_actions), 0) AS d7_rev_actions,        
    FROM imp_usa_t AS I
        LEFT JOIN cv_usa_t AS CV USING (platform_id, advertiser_id, store_id, campaign_id, campaign_title, os, date_utc, local_date, city, cr_format)
        LEFT JOIN d7_roas_usa_t AS R USING (platform_id, advertiser_id, store_id, campaign_id, campaign_title, os, date_utc, local_date, city, cr_format)
    GROUP BY ALL
)
SELECT
    week,
    city,
    SUM(gross_spending_usd) AS spend,
    SUM(imp) AS imp,
    SUM(install) AS installs,
    SUM(d7_revenue_usd) AS d7_revenue_usd,
    SUM(d7_payer) AS d7_payer,
    SUM(d7_rev_actions) AS d7_rev_actions,
    SUM(d0_retention) AS d0_retention,
    SUM(d1_retention) AS d1_retention,
    SUM(d3_retention) AS d3_retention,
    SUM(d7_retention) AS d7_retention,
    SUM(d30_retention) AS d30_retention,
FROM final
-- WHERE LOWER(os) = 'android' AND cr_format = 'vi';
GROUP BY ALL