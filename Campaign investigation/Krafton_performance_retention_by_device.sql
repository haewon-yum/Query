/* 
    - ticket: https://mlc.atlassian.net/browse/ODSB-11004
    Hi team,
    Krafton has requested us to investigate user and publisher analysis due to a significantly lower conversion rate 
    from install to NRU (new registered user/03_Login_completed) among Xiaomi device users, especially in Moloco.

    Timeline
        - Jan 23th 2025 - 5th Feb 2025

    Xiaomi Device Users / Non-Xiaomi Users << To compare each group

    Publisher id / Pub name / spend / D1 RR / D3 RR / D7 RR / CPA(03_Login_completed)

    If you find any insights that why Xiaomi users' conversion rate is lower than the others, please feel free to add any insights or comments slightly smiling face It would be really appreciate it

    Thanks!
*/


-- Model name check : xiomi ~8%
DECLARE run_from_date DATE DEFAULT '2025-01-23';
DECLARE run_to_date   DATE DEFAULT '2025-02-05';
DECLARE advertiser_id   STRING DEFAULT 'YFOd23KOzofKwEQy';
DECLARE campaign_id   STRING DEFAULT 'HNmHGztXiKtLdKNN';

WITH advertiser AS (
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
            campaign.country = 'IND'
            AND DATE_DIFF(run_to_date, effective_date_local, DAY) >=0 
            AND advertiser.id = advertiser_id
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
        -- I.platform_id,
        -- I.advertiser_id,
        -- I.api.product.app.store_id,
        I.api.campaign.id AS campaign_id,
        I.api.campaign.title AS campaign_title,
        CASE WHEN LOWER(req.device.make) LIKE '%xiaomi%' THEN TRUE ELSE FALSE END AS is_xiaomi,
        DATE(I.timestamp) AS date_utc,
        DATE(I.timestamp, A.advertiser_timezone) AS local_date,
        req.app.bundle AS publisher_bundle,
        req.app.publisher.id AS publisher_id,
        req.app.publisher.name AS publisher_name,
        A.platform_serving_cost_percent,
        A.platform_markup_percent,
        -- I.req.device.os,
        -- api.creative.cr_format AS cr_format,
        SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
        COUNT(*) AS imp
    FROM `focal-elf-631.prod_stream_view.imp` AS I
        INNER JOIN advertiser AS A ON
            I.platform_id = A.platform_id AND
            I.advertiser_id = A.advertiser_id AND
            A.effective_date_local <= DATE(I.timestamp, A.advertiser_timezone) AND DATE(I.timestamp, A.advertiser_timezone) <= A.last_effective_date_local
    WHERE
        DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
        AND req.device.geo.country = 'IND'
        -- AND api.product.app.store_id IN UNNEST(app_bundle)
        AND I.api.campaign.id = campaign_id
        -- AND api.creative.cr_format = 'vi'
    GROUP BY ALL
),
imp_spend_t AS (
    SELECT
        -- I.platform_id,
        -- I.advertiser_id,
        -- I.store_id,
        I.campaign_id,
        I.campaign_title,
        is_xiaomi,
        -- I.os,
        I.date_utc,
        I.local_date,        
        publisher_bundle,
        publisher_id,
        publisher_name,
        SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent / 100) * (1 + I.platform_markup_percent / 100)) AS FLOAT64) AS gross_spending_usd,
        SUM(I.imp) AS imp
    FROM imp_t AS I
    GROUP BY ALL
),


cv_raw_t AS (
    SELECT 
        *,
        MAX(install_utc) OVER (PARTITION BY mtid) AS install_at,
        IF(LOWER(event) <> 'install', TIMESTAMP_DIFF(timestamp, MAX(install_utc) OVER
                (PARTITION BY mtid), day), NULL) AS i_to_e_day_diff
    FROM(
        SELECT
            timestamp,
            CASE WHEN LOWER(req.device.make) LIKE '%xiaomi%' THEN TRUE ELSE FALSE END AS is_xiaomi,
            req.app.bundle AS publisher_bundle,
            req.app.publisher.id AS publisher_id,
            req.app.publisher.name AS publisher_name,
            cv.event,
            cv.event_pb,
            CASE WHEN LOWER(cv.event) = 'install' THEN timestamp ELSE NULL END AS install_utc,
            DATE(timestamp) AS date_utc,
            DATE(timestamp, A.advertiser_timezone) AS local_date,
            bid.mtid
        FROM `focal-elf-631.prod_stream_view.cv` 
            INNER JOIN advertiser_timezone A USING (platform_id, advertiser_id)
        WHERE DATE(timestamp) BETWEEN DATE_SUB(run_from_date, INTERVAL 7 DAY) AND run_to_date
            AND DATE(cv.received_at) BETWEEN run_from_date AND run_to_date
            AND api.campaign.id = campaign_id
    )t
),
cv_agg AS (
    SELECT
        C.date_utc,
        C.local_date,
        is_xiaomi,
        publisher_bundle,
        publisher_id,
        publisher_name,
        SUM(IF(C.event = 'INSTALL', 1, 0)) AS install,
        SUM(IF(i_to_e_day_diff<7 AND C.event_pb = '03_Login_completed', 1, 0)) AS d7_action, -- 03_Login_completed
        COUNT(DISTINCT IF(i_to_e_day_diff=0, mtid, NULL)) as d0_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=1, mtid, NULL)) as d1_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=3, mtid, NULL)) as d3_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=7, mtid, NULL)) as d7_retention
    FROM cv_raw_t AS C
    GROUP BY ALL
), 
final AS (
    SELECT 
        date_utc,
        is_xiaomi,
        publisher_bundle,
        publisher_id,
        publisher_name,
        COALESCE(SUM(I.gross_spending_usd), 0) AS gross_spending_usd,
        COALESCE(SUM(I.imp), 0) AS imp,
        COALESCE(SUM(CV.install), 0) AS install,
        COALESCE(SUM(CV.d7_action), 0) AS d7_action,
        COALESCE(SUM(CV.d0_retention), 0) AS d0_retention,
        COALESCE(SUM(CV.d1_retention), 0) AS d1_retention,
        COALESCE(SUM(CV.d3_retention), 0) AS d3_retention,
        COALESCE(SUM(CV.d7_retention), 0) AS d7_retention
    FROM imp_spend_t AS I
        LEFT JOIN cv_agg AS CV USING(date_utc, local_date, is_xiaomi, publisher_bundle, publisher_id, publisher_name)
    GROUP BY ALL
)


SELECT 
    is_xiaomi,
    publisher_bundle,
    publisher_id,
    publisher_name,
    SUM(gross_spending_usd) AS spend,
    SUM(imp) AS imp,
    SUM(install) AS installs,
    SUM(d7_action) AS d7_action,
    SUM(d0_retention) AS d0_retention,
    SUM(d1_retention) AS d1_retention,
    SUM(d3_retention) AS d3_retention,
    SUM(d7_retention) AS d7_retention
FROM final
GROUP BY ALL


/* 
    https://mlc.atlassian.net/browse/ODSB-11104
    [Data pull request]

Timeline: This year

Country: IND

Advertiser: 

CookieRun India(YFOd23KOzofKwEQy)

Bullet Echo India(BzLtUCCFmDBHhlNv)

Battlegrounds Mobile India(P0GsZeYiIRHdfCMq)

Metric:
Advertiser / Exchange / Xiaomi Device Users / Non-Xiaomi Users 

Measures:
Spend / IMP / D1 RR / D3 RR / D7 RR / CPI / D1 ROAS

[Additional Inquiry]
Will blocking Xiaomi devices in IND affect the huge traffic loss or performance issue? I want to understand how a portion of Xiaomi devices are in IND.

*/


-- Model name check : xiomi ~8%
DECLARE run_from_date DATE DEFAULT '2025-01-01';
DECLARE run_to_date   DATE DEFAULT '2025-03-03';
DECLARE advertiser_ids   ARRAY<STRING> DEFAULT ['YFOd23KOzofKwEQy','BzLtUCCFmDBHhlNv','P0GsZeYiIRHdfCMq'];

WITH advertiser AS (
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
            campaign.country = 'IND'
            AND DATE_DIFF(run_to_date, effective_date_local, DAY) >=0 
            AND advertiser.id IN UNNEST(advertiser_ids)
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
        -- I.platform_id,
        I.advertiser_id,
        -- I.api.product.app.store_id,
        -- I.api.campaign.id AS campaign_id,
        -- I.api.campaign.title AS campaign_title,
        I.req.exchange AS exchange,
        CASE WHEN LOWER(req.device.make) LIKE '%xiaomi%' THEN TRUE ELSE FALSE END AS is_xiaomi,
        DATE(I.timestamp) AS date_utc,
        -- DATE(I.timestamp, A.advertiser_timezone) AS local_date,
        -- req.app.bundle AS publisher_bundle,
        -- req.app.publisher.id AS publisher_id,
        -- req.app.publisher.name AS publisher_name,
        A.platform_serving_cost_percent,
        A.platform_markup_percent,
        -- I.req.device.os,
        -- api.creative.cr_format AS cr_format,
        SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
        COUNT(*) AS imp
    FROM `focal-elf-631.prod_stream_view.imp` AS I
        INNER JOIN advertiser AS A ON
            I.platform_id = A.platform_id AND
            I.advertiser_id = A.advertiser_id AND
            A.effective_date_local <= DATE(I.timestamp, A.advertiser_timezone) AND DATE(I.timestamp, A.advertiser_timezone) <= A.last_effective_date_local
    WHERE
        DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
        AND req.device.geo.country = 'IND'
        AND api.advertiser.id IN UNNEST (advertiser_ids)
        AND I.req.device.os = 'ANDROID'
        -- AND api.product.app.store_id IN UNNEST(app_bundle)
        -- AND I.api.campaign.id = campaign_id
        -- AND api.creative.cr_format = 'vi'
    GROUP BY ALL
),
imp_spend_t AS (
    SELECT
        -- I.platform_id,
        I.advertiser_id,
        -- I.store_id,
        -- I.campaign_id,
        -- I.campaign_title,
        I.exchange,
        is_xiaomi,
        -- I.os,
        I.date_utc,
        -- I.local_date,        
        -- publisher_bundle,
        -- publisher_id,
        -- publisher_name,
        SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent / 100) * (1 + I.platform_markup_percent / 100)) AS FLOAT64) AS gross_spending_usd,
        SUM(I.imp) AS imp
    FROM imp_t AS I
    GROUP BY ALL
),


cv_raw_t AS (
    SELECT 
        *,
        MAX(install_utc) OVER (PARTITION BY mtid) AS install_at,
        IF(LOWER(event) <> 'install', TIMESTAMP_DIFF(timestamp, MAX(install_utc) OVER
                (PARTITION BY mtid), day), NULL) AS i_to_e_day_diff
    FROM(
        SELECT
            timestamp,
            api.advertiser.id AS advertiser_id, 
            req.exchange AS exchange,
            CASE WHEN LOWER(req.device.make) LIKE '%xiaomi%' THEN TRUE ELSE FALSE END AS is_xiaomi,
            -- req.app.bundle AS publisher_bundle,
            -- req.app.publisher.id AS publisher_id,
            -- req.app.publisher.name AS publisher_name,
            cv.event,
            cv.event_pb,
            CASE WHEN LOWER(cv.event) = 'install' THEN timestamp ELSE NULL END AS install_utc,
            DATE(timestamp) AS date_utc,
            -- DATE(timestamp, A.advertiser_timezone) AS local_date,
            bid.mtid,
            cv.revenue_usd.amount AS revenue_usd
        FROM `focal-elf-631.prod_stream_view.cv` 
            INNER JOIN advertiser_timezone A USING (platform_id, advertiser_id)
        WHERE DATE(timestamp) BETWEEN DATE_SUB(run_from_date, INTERVAL 7 DAY) AND run_to_date
            AND DATE(cv.received_at) BETWEEN run_from_date AND run_to_date
            AND api.advertiser.id IN UNNEST(advertiser_ids)
            AND req.device.os = 'ANDROID'
            -- AND api.campaign.id = campaign_id
    )t
),
cv_agg AS (
    SELECT
        C.date_utc,
        -- C.local_date,
        advertiser_id,
        exchange,
        is_xiaomi,
        -- publisher_bundle,
        -- publisher_id,
        -- publisher_name,
        SUM(IF(C.event = 'INSTALL', 1, 0)) AS install,
        -- SUM(IF(i_to_e_day_diff<7 AND C.event_pb = '03_Login_completed', 1, 0)) AS d7_action, -- 03_Login_completed
        COUNT(DISTINCT IF(i_to_e_day_diff=0, mtid, NULL)) as d0_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=1, mtid, NULL)) as d1_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=3, mtid, NULL)) as d3_retention,
        COUNT(DISTINCT IF(i_to_e_day_diff=7, mtid, NULL)) as d7_retention
    FROM cv_raw_t AS C
    GROUP BY ALL
), 

d1_roas_t AS (
    SELECT
        inst.date_utc,
        -- inst.local_date,
        -- platform_id,
        advertiser_id,
        exchange,
        is_xiaomi,
        -- store_id,
        -- campaign_id,
        -- campaign_title,
        -- os,
        -- inst.lon,
        -- inst.lat,
        -- inst.ip,
        -- COALESCE(inst.cr_format, act.cr_format) AS cr_format,
        SUM(act.revenue_usd) AS d1_revenue_usd,
        COUNT(DISTINCT mtid) AS d1_payer,
        COUNT(mtid) AS d1_rev_actions
    FROM (
            SELECT * FROM cv_raw_t WHERE LOWER(event) LIKE '%install%'
        ) AS inst
        INNER JOIN (
            SELECT * FROM cv_raw_t WHERE event_pb LIKE '%revenue%' OR event_pb LIKE '%purchase%' 
        ) AS act USING (mtid, advertiser_id, exchange, is_xiaomi)
    WHERE DATE_DIFF(act.date_utc, inst.date_utc, DAY) < 1
    GROUP BY ALL
),
d1_roas_agg AS (
    SELECT
        -- R.platform_id,
        R.advertiser_id,
        exchange,
        is_xiaomi,
        -- R.store_id,
        -- R.campaign_id,
        -- R.campaign_title,
        -- R.os,
        R.date_utc,
        -- COALESCE(O.osm_city, IF(R.lon IS NULL OR R.lon = 0, IP.osm_city, 'n/a'), 'other') AS city,
        -- cr_format,
        SUM(R.d1_revenue_usd) AS d1_revenue_usd,
        SUM(R.d1_payer) AS d1_payer,
        SUM(R.d1_rev_actions) AS d1_rev_actions
    FROM d1_roas_t AS R
    GROUP BY ALL
),


final AS (
    SELECT 
        date_utc,
        advertiser_id,
        exchange,
        is_xiaomi,
        -- publisher_bundle,
        -- publisher_id,
        -- publisher_name,
        COALESCE(SUM(I.gross_spending_usd), 0) AS gross_spending_usd,
        COALESCE(SUM(I.imp), 0) AS imp,
        COALESCE(SUM(CV.install), 0) AS install,
        -- COALESCE(SUM(CV.d7_action), 0) AS d7_action,
        COALESCE(SUM(CV.d0_retention), 0) AS d0_retention,
        COALESCE(SUM(CV.d1_retention), 0) AS d1_retention,
        COALESCE(SUM(CV.d3_retention), 0) AS d3_retention,
        COALESCE(SUM(CV.d7_retention), 0) AS d7_retention,
        COALESCE(SUM(R.d1_revenue_usd), 0) AS d1_revenue,
        COALESCE(SUM(R.d1_payer), 0) AS d1_payer,
        COALESCE(SUM(R.d1_rev_actions), 0) AS d1_rev_actions,
    FROM imp_spend_t AS I
        LEFT JOIN cv_agg AS CV USING(date_utc, advertiser_id, exchange, is_xiaomi)
        LEFT JOIN d1_roas_agg AS R USING (date_utc, advertiser_id, exchange, is_xiaomi)
    GROUP BY ALL
)


SELECT 
    advertiser_id,
    exchange,
    is_xiaomi,
    -- publisher_bundle,
    -- publisher_id,
    -- publisher_name,
    SUM(gross_spending_usd) AS spend,
    SUM(imp) AS imp,
    SUM(install) AS installs,
    -- SUM(d7_action) AS d7_action,
    SUM(d0_retention) AS d0_retention,
    SUM(d1_retention) AS d1_retention,
    SUM(d3_retention) AS d3_retention,
    SUM(d7_retention) AS d7_retention,
    SUM(d1_revenue) AS d1_revenue,
    SUM(d1_payer) AS d1_payer,
    SUM(d1_rev_actions) AS d1_rev_actions
FROM final
GROUP BY ALL