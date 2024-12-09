/*

- focal-elf-631.prod_stream_view.pb
- All postbacks including attributed, unattributed (which likely include organic).
- Some MMPs can pass is_organic flag, but it’s not reliable yet.
- Sampled: 1/100 in general, except some cases
    + Non-sampled cases: 
    (1) attributed events 
    (2) all the installs (attributed + unattributed) 
    (3) all the revenue events (attributed + unattributed)

SCHEMA
- timestamp
- mmp_name
- event_name
- mmp
    - ...
- attribution
    - method
    - raw_method
    - viewthrough
    - reengagement
    - organic
    - reject_reason
- moloco
    - attributed
    - mtid
    - is_test
    - compaign_id
    - creative_id
    - ...
- app
    - name
    - bundle = MMP Bundle
    - store
    - version
    - sdk_version
- event
    - name
    - event_at
    - click_at
    - download_at
    - install_at
    - revenue_raw
        -...
    - revenue_usd
        - currency
        - amount
- device
    - ifa
    - ...
    - user_bucket (?) -- maybe used in experimentation
    - os
    - osv
    - model
    - model_norm - normalized format of model (e.g. model: SM-S918U1 => model_norm: sms918u)
    - session_count ?? 
    -...
    - country
- publisher
- payload
*/

SELECT *
FROM `focal-elf-631.prod_stream_view.pb`
WHERE date(timestamp) = current_date()
LIMIT 10


-- https://colab.research.google.com/drive/1sHhhAcMcDbJt0N3eX_f7UE6Kn0lHrmA6#scrollTo=F1GI23VmvH0u
-- Revenue by Market
CREATE OR REPLACE TABLE {table_market_moloco_v3} AS
WITH apps AS (
    SELECT
        advertiser.mmp_bundle_id,
        product.genre,
        product.sub_genre
    FROM `moloco-ae-view.athena.fact_dsp_core`
    WHERE date_utc BETWEEN '2024-09-01' AND '2024-09-30'
    AND product.is_gaming IS TRUE
    GROUP BY ALL
    HAVING SUM(gross_spend_usd) > 0
)

SELECT
    device.country,
    CASE WHEN device.country IN ('KOR') THEN 'KOR'
        WHEN device.country IN ('USA', 'CAN') THEN 'NA'
        WHEN device.country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
        WHEN device.country IN ('TWN', 'JPN', 'HKG') THEN 'NEA'
    END AS market,
    device.os,
    apps.genre,
    apps.sub_genre,
    COUNT(DISTINCT `moloco-ml.lat_utils.is_userid_truly_available`(device.ifa)) AS cnt_device,
    SUM(event.revenue_usd.amount) AS revenue,
    SUM(
    CASE WHEN event.revenue_usd.amount > 200 THEN 200
            ELSE event.revenue_usd.amount END
    ) AS capped_revenue
FROM `focal-elf-631.prod_stream_view.pb` pb
    JOIN apps ON pb.app.bundle = apps.mmp_bundle_id
WHERE date(timestamp) BETWEEN '2024-09-01' AND '2024-09-30'
    AND (LOWER(event.name) like '%revenue%'
    OR LOWER(event.name) like '%purchase%'
    OR LOWER(event.name) like '%iap%'
    OR LOWER(event.name) like '%iaa%')
    AND event.revenue_usd.amount < 10000
GROUP BY ALL


/* 
    ARPPU for attributed + unattributed 
    Use case; geo expansion. new country proposal
*/

DECLARE start_date DATE DEFAULT '2024-11-27';
DECLARE end_date DATE DEFAULT '2024-12-08';

WITH
    t_rev AS (
    SELECT
        device.ifa AS idfa, 
        device.country,
        TIMESTAMP_DIFF(event.event_at, event.install_at, DAY) AS diff, 
        event.revenue_usd.amount AS revenue
    FROM
      `focal-elf-631.prod_stream_view.pb`
    WHERE
      DATE(timestamp) BETWEEN start_date AND end_date
      AND DATE(event.install_at) BETWEEN start_date AND end_date
      AND app.bundle = 'com.kabam.knights.legends'
    --   AND TIMESTAMP_DIFF(timestamp, cv.install_at_pb, DAY) < 7
      AND event.revenue_usd.amount > 0
      AND event.revenue_usd.amount < 10000
    ),
    t_rev_sum AS (
        SELECT
        idfa,
        country,
        diff,
        COUNT(1) AS purchase,
        SUM(revenue) AS revenue
        FROM
        t_rev
        GROUP BY
        ALL
        )
SELECT
    country,
    diff,
    COUNT(DISTINCT idfa) AS num_payer,
    SUM(purchase) AS num_purchsae,
    SUM(revenue) AS revenue
FROM t_rev_sum
GROUP BY ALL


/* 
    I2A
*/

DECLARE start_date DATE DEFAULT '2024-11-27';
DECLARE end_date DATE DEFAULT '2024-12-08';

SELECT
    device.country,
    COUNT (DISTINCT CASE WHEN lower(event.name) IN ('install', 'installs') THEN device.ifa ELSE NULL END) AS num_install_user,
    COUNT (DISTINCT CASE WHEN event.revenue_usd.amount > 0 THEN device.ifa ELSE NULL END) AS num_payer
FROM
      `focal-elf-631.prod_stream_view.pb`
WHERE
    DATE(timestamp) BETWEEN start_date AND end_date
    AND DATE(event.install_at) BETWEEN start_date AND end_date
    AND app.bundle = 'com.kabam.knights.legends' 
GROUP BY ALL