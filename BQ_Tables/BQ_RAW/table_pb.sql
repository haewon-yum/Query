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
        - viewthrough (BOOLEAN)
        - reengagement
        - organic
        - reject_reason
    - moloco
        - attributed (BOOLEAN)
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

    column_name	data_type	is_nullable
    _uid_	STRING	YES
    timestamp	TIMESTAMP	YES
    mmp_name	STRING	YES
    event_name	STRING	YES
    mmp	"STRUCT<name STRING, network STRING, ip STRING, ua STRING, platform STRING, event_source STRING, device_id STRING>"	YES
    attribution	"STRUCT<method STRING, raw_method STRING, viewthrough BOOL, reengagement BOOL, organic BOOL, rejection_reason STRING, assisted BOOL, rejected BOOL>"	YES
    moloco	"STRUCT<attributed BOOL, mtid STRING, is_test BOOL, campaign_id STRING, creative_id STRING, mtid_ifa STRING, anonymized_mtid_ifa STRING, maid_type INT64>"	YES
    app	"STRUCT<name STRING, bundle STRING, store STRING, version STRING, sdk_version STRING>"	YES
    event	"STRUCT<name STRING, event_at TIMESTAMP, click_at TIMESTAMP, download_at TIMESTAMP, install_at TIMESTAMP, revenue_raw STRUCT<currency STRING, amount FLOAT64>, revenue_usd STRUCT<currency STRING, amount FLOAT64>, page_uri STRING>"	YES
    device	"STRUCT<ifa STRING, anonymized_ifa STRING, user_bucket INT64, os STRING, osv STRING, model STRING, model_norm STRING, ip STRING, iptype STRING, country STRING, session_count INT64, ua STRING, ifv STRING, anonymized_ifv STRING, language STRING, name STRING, appsetid STRING>"	YES
    publisher	STRUCT<app_bundle STRING>	YES
    payload	"STRUCT<custom_info STRING, raw STRING>"	YES
    skadn	"STRUCT<payload STRUCT<version STRING, ad_network_id STRING, campaign_id INT64, transaction_id STRING, app_id INT64, attribution_signature STRING, redownload BOOL, source_app_id INT64, fidelity_type INT64, conversion_value INT64, did_win BOOL, source_identifier STRING, source_domain STRING, coarse_conversion_value STRING, postback_sequence_index INT64>, forward STRUCT<mmp STRING, payload STRING>, ua_info STRUCT<device STRUCT<osv STRING, model STRING>>>"	YES
    compliance	STRUCT<is_anonymized BOOL>	YES
*/

SELECT *
FROM `5`
WHERE date(timestamp) = current_date()
LIMIT 10

/* 
    unattributed / attributed postback volume trend
*/

    DECLARE start_date DATE DEFAULT '2025-12-20';
    DECLARE end_date DATE DEFAULT '2026-01-01';
    DECLARE kpi_event STRING DEFAULT 'af_purchase';    

    SELECT
        DATE(timestamp, "Asia/Tokyo") AS date_local,
        moloco.attributed,
        COUNT(IF(LOWER(event.name)='install',1,NULL)) AS cnt_install,
        COUNT(IF(LOWER(event.name)=kpi_event,1,NULL)) AS cnt_kpi_event,
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE DATE(timestamp, "Asia/Tokyo") BETWEEN start_date AND end_date
        AND LOWER(event.name) in (kpi_event, 'install')
        AND app.bundle = 'id6744629457'
    GROUP BY date_local, moloco.attributed


/* 
    https://colab.research.google.com/drive/1sHhhAcMcDbJt0N3eX_f7UE6Kn0lHrmA6#scrollTo=F1GI23VmvH0u
    Revenue by Market
*/
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


/* 
    I2A - Modified
*/

DECLARE start_date DATE DEFAULT '2025-02-01';
DECLARE end_date DATE DEFAULT '2025-02-28';

WITH raw AS (

    SELECT
        CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
            WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
            ELSE NULL END AS user_id,
        device.os,
        CASE
            WHEN device.country = 'KOR' THEN 'KR'
            WHEN device.country IN ('USA','CAN') THEN 'NA'
            WHEN device.country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
            WHEN device.country IN ('JPN','HKG','TWN') THEN 'NEA'
            ELSE 'ETC' END AS region,
        app.bundle,
        event.name AS event_name,
        DATE_DIFF(timestamp, event.install_at, DAY) AS date_diff

    FROM
        `focal-elf-631.prod_stream_view.pb`
    WHERE
        DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 7 DAY)
        AND DATE(event.install_at) BETWEEN start_date AND end_date
        AND device.country IN ('KOR', 'USA','CAN', 'GBR', 'FRA', 'DEU', 'JPN','HKG','TWN')
        AND event.revenue_usd.amount > 0
        AND event.revenue_usd.amount < 10000
        AND (LOWER(event.name) IN ('install', 'installs') OR (LOWER(event.name) LIKE '%purchase%'
          OR LOWER(event.name) LIKE '%iap'
          OR LOWER(event.name) LIKE '%revenue%'
          OR LOWER(event.name) LIKE '%_ad_%'
          OR LOWER(event.name) IN ('af_top_up', 'pay', '0ofw9', 'h9bsc')
          OR LOWER(event.name) LIKE '%deposit%'))
        AND LOWER(event.name) NOT LIKE '%ltv%'
        AND event.name NOT IN ('Purcahse=3', 'BOARD_3')
        -- AND app.bundle = 'com.kabam.knights.legends' 

),

agg AS (

    SELECT 
        os,
        region,
        COUNT(DISTINCT CASE WHEN LOWER(event_name) IN ('install', 'installs') THEN user_id ELSE NULL END) AS install_user, 
        COUNT(DISTINCT CASE WHEN LOWER(event_name) NOT IN ('install', 'installs') AND date_diff < 7 THEN user_id ELSE NULL END) AS purchase_user,
    FROM raw
    GROUP BY 1,2
)

SELECT 
    os,
    region,
    install_user,
    purchase_user,
    ROUND(SAFE_DIVIDE(purchase_user, install_user), 4) AS purchase_conversion_rate
FROM agg

