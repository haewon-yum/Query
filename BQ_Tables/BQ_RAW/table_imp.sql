/*
- focal-elf-631.prod_stream_view.imp
- impression from a Moloco campaign
- Sampled? 1/1
- DS team can join this table with other tables to calculate CTR, identify specific types of fraud and actual i2i rates.
- If really need imp level data for a long period of time, can use this table: focal-elf-631.prod_stream_sampled.imp_1to100

Ref
- ML validation i2i
*/



imp_t AS (
    SELECT
        I.platform_id,
        I.advertiser_id,
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
        AND api.product.app.store_id = app_bundle

        -- AND I.api.campaign.id IN UNNEST(campaign_id)
        -- AND api.creative.cr_format = 'vi'
    GROUP BY ALL
),
imp_usa_t AS (
    SELECT
        I.platform_id,
        I.advertiser_id,
        I.api.product.app.store_id,
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
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
),
