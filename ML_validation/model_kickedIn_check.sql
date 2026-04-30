-- Reference: https://docs.google.com/document/d/1A6IA38wOHl1ATelo2Ykf6rdQ0oOO_Qw_3a6lvXoQ2jc/edit
SELECT
*
FROM
    (select 
    date(timestamp) as date, 
    --IF(STARTS_WITH(bid.maid, ""k:""), ""LAT"", ""IDFA"") as traffic_type,
    api.campaign.id,
    bid.model.pricing_function AS pricing_function,
    avg(bid.model.prediction_logs[SAFE_OFFSET(1)].pred) AS i2a_pred_avg,
    avg(bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) as i2a_norm_avg,
    avg(bid.bid_price.amount_micro)/1e6 as bid_price,
    avg(bid.model.multipliers.converted_target) as tcm,
    avg(bid.model.prediction_logs[safe_OFFSET(1)].pred) as i2a_pred,
    avg(bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) AS normalizer,
    avg(safe_divide(bid.model.prediction_logs[SAFE_OFFSET(1)].pred, bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer)) as i2a_norm,
    avg(bid.model.prediction_logs[SAFE_OFFSET(2)].pred / bid.model.prediction_logs[SAFE_OFFSET(2)].wrapper.normalizer) as rev_mult,
    count(*) as imp_cnt
    from `focal-elf-631.prod_stream_sampled.imp_1to1000` 
    where date(timestamp) >= '2024-09-01'
    and api.product.app.tracking_bundle IN  ('com.nexon.maplem.global')
    group by 1,2,3
    ) t1
LEFT JOIN 
    (SELECT
    date(cv.happened_at) as date,
    api.campaign.id,
    count(distinct bid.mtid) as payer_cnt
    FROM `focal-elf-631.prod_stream_view.cv`
        WHERE date(timestamp) >= '2024-09-01'
        and api.product.app.tracking_bundle IN  ('com.nexon.maplem.global')
        and cv.event = 'CUSTOM_KPI_ACTION'
        and TIMESTAMP_DIFF(cv.happened_at, install.happened_at, DAY) < 7 
        group by 1,2) t2
on t1.id = t2.id
and t1.date = t2.date
ORDER BY 1,2,3,4,5


/* 
    Action model kick-in leadtime distribution (at day level)
*/

    DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 10 DAY);
    DECLARE end_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY);

    WITH cpa_campaigns AS (
        SELECT
            platform_name,
            advertiser_name AS advertiser_id,
            store_bundle,
            os,
            product_display_name AS product_name,
            campaign_name AS campaign_id,
            DATE(created_timestamp_nano) AS created_date,
            JSON_EXTRACT(campaign_goal, '$.type') AS goal
        FROM `focal-elf-631.prod.campaign_digest_merged_latest`
        WHERE JSON_EXTRACT(campaign_goal, '$.type') LIKE "%OPTIMIZE_CPA_FOR_APP_UA%"
            AND DATE(created_timestamp_nano) BETWEEN start_date AND end_date
    ),

    spend AS (
        SELECT 
            cpa_campaigns.campaign_id,
            DATE(date_utc) AS date_utc,
            SUM(gross_spend_usd) AS gross_spend,         
        FROM `moloco-ae-view.athena.fact_dsp_core` dsp_core
            INNER JOIN cpa_campaigns USING(campaign_id)
        WHERE date_utc BETWEEN start_date AND end_date
            AND campaign.goal LIKE '%CPA%'
        GROUP BY 1, 2
        HAVING gross_spend > 0
    ),

    summary AS (
        SELECT *,
        MIN(DATE(date_utc)) OVER (PARTITION BY campaign_id) AS launch_date,
        MAX(DATE(date_utc)) OVER (PARTITION BY campaign_id) AS latest_date
        FROM cpa_campaigns
        LEFT JOIN spend USING(campaign_id)
        ORDER BY campaign_id, date_utc
    ), 

    summary_pricing AS (
        SELECT 
            summary.platform_name,
            summary.advertiser_id,
            summary.store_bundle,
            summary.os,
            summary.product_name,
            api.campaign.id AS campaign_id,
            launch_date,
            latest_date,
            date(timestamp) as date, 
            bid.model.pricing_function AS pricing_function,
            count(*) as imp_cnt
        FROM `focal-elf-631.prod_stream_sampled.imp_1to1000` imp
            INNER JOIN summary 
            ON imp.api.campaign.id = summary.campaign_id
            AND DATE(imp.timestamp) BETWEEN summary.launch_date AND summary.latest_date
        where date(timestamp) BETWEEN start_date AND end_date
        group by 1,2,3,4,5,6,7,8,9,10

    )

    SELECT 
    *,
    DATE_DIFF(model_applied_date, launch_date, DAY) AS date_diff
    FROM(
    SELECT 
        platform_name,
        advertiser_id,
        store_bundle,
        os,
        product_name,
        campaign_id,
        launch_date,
        latest_date,
        pricing_function,
        MIN(date) AS model_applied_date,
    FROM summary_pricing
    GROUP BY 1,2,3,4,5,6,7,8,9
    -- ORDER BY 1,2
    )
    ORDER BY date_diff DESC


/* 
    Action model kick-in lead time (at timestamp level)
*/


DECLARE start_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 35 DAY);
DECLARE end_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 5 DAY);

CREATE OR REPLACE TABLE `moloco-ods.haewon.ua_cpa_campaigns_l30_days_250530_v2` AS
    WITH cpa_campaigns AS (
        SELECT
            platform_name,
            advertiser_name AS advertiser_id,
            store_bundle,
            os,
            product_display_name AS product_name,
            campaign_name AS campaign_id,
            created_timestamp_nano AS created_ts,
            JSON_EXTRACT(campaign_goal, '$.type') AS goal,
            JSON_EXTRACT(campaign_goal, '$.optimize_cpa_for_app_ua.action') AS kpi_event
        FROM `focal-elf-631.prod.campaign_digest_merged_latest`
        WHERE JSON_EXTRACT(campaign_goal, '$.type') LIKE "%OPTIMIZE_CPA_FOR_APP_UA%"
            AND DATE(created_timestamp_nano) BETWEEN start_date AND end_date
    ),

    spend AS (
        SELECT 
            cpa_campaigns.campaign_id,
            DATE(date_utc) AS date_utc,
            SUM(gross_spend_usd) AS gross_spend,         
        FROM `moloco-ae-view.athena.fact_dsp_core` dsp_core
            INNER JOIN cpa_campaigns USING(campaign_id)
        WHERE date_utc BETWEEN start_date AND end_date
            AND campaign.goal LIKE '%CPA%'
        GROUP BY 1, 2
        HAVING gross_spend > 0
    ),

    campaigns_2 AS (
        ## add luanch (first spending date) date and latest date (latest : 2025-05-30) ##
        SELECT cpa_campaigns.*,
            MIN(DATE(date_utc)) OVER (PARTITION BY campaign_id) AS launch_date,
            MAX(DATE(date_utc)) OVER (PARTITION BY campaign_id) AS latest_date
        FROM cpa_campaigns
          LEFT JOIN spend USING(campaign_id)
    ),

    summary AS (
        ## Add first imp timestamp
      SELECT campaigns_2.*,
        MIN(imp.timestamp) AS first_imp_ts,
      FROM campaigns_2
        LEFT JOIN (SELECT 
                        api.campaign.id AS campaign_id,
                        timestamp 
                    FROM `focal-elf-631.prod_stream_view.imp` 
                    WHERE DATE(timestamp) BETWEEN start_date AND end_date) imp 
            ON campaigns_2.campaign_id = imp.campaign_id
            AND DATE(imp.timestamp) = campaigns_2.launch_date
      GROUP BY ALL
    )

    SELECT *
    FROM summary

#### combining with the pricing function
    DECLARE start_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 35 DAY);
    DECLARE end_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 5 DAY);


    WITH imp_sampled AS (
        SELECT *
        FROM `focal-elf-631.prod_stream_sampled.imp_1to1000`
        WHERE DATE(timestamp) BETWEEN start_date AND end_date
        ), 

        kpi_event AS (
        SELECT
            campaign_name AS campaign_id,
            CAST(JSON_EXTRACT(campaign_goal, '$.optimize_cpa_for_app_ua.action') AS String) AS kpi_event
        FROM `focal-elf-631.prod.campaign_digest_merged_latest`
        WHERE JSON_EXTRACT(campaign_goal, '$.type') LIKE "%OPTIMIZE_CPA_FOR_APP_UA%"
            AND DATE(created_timestamp_nano) BETWEEN start_date AND end_date
        ), 
    
    model_lead_time AS (

        SELECT 
            summary.platform_name,
            summary.advertiser_id,
            summary.store_bundle,
            summary.os,
            summary.product_name,
            api.campaign.id AS campaign_id,
            kpi_event.kpi_event,
            summary.launch_date,
            summary.latest_date,
            summary.first_imp_ts,
            bid.model.pricing_function AS pricing_function,
            MIN(timestamp) AS model_applied_ts,
            TIMESTAMP_DIFF(MIN(timestamp), first_imp_ts, HOUR) AS hour_diff
        FROM imp_sampled imp
            INNER JOIN `moloco-ods.haewon.ua_cpa_campaigns_l30_days_250530` summary
            ON imp.api.campaign.id = summary.campaign_id
            AND DATE(imp.timestamp) BETWEEN summary.launch_date AND summary.latest_date
            LEFT JOIN kpi_event ON summary.campaign_id = kpi_event.campaign_id
        group by 1,2,3,4,5,6,7,8,9,10, 11
    )

    SELECT 
        platform_name,
        advertiser_id,
        product_name,
        store_bundle,
        os,
        kpi_event,
        SPLIT(pricing_function, ":")[OFFSET(0)] AS model_type,
        ARRAY_AGG(campaign_id) AS campaigns,
        MIN(first_imp_ts) AS min_first_imp_ts,
        MIN(model_applied_ts) AS min_model_applied_ts,
        TIMESTAMP_DIFF(MIN(model_applied_ts), MIN(first_imp_ts), HOUR) AS hour_diff
    FROM model_lead_time
    GROUP BY 1,2,3,4,5,6,7


#### combining withe the pricing function (with version 2) table

DECLARE start_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 35 DAY);
DECLARE end_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 5 DAY);


CREATE OR REPLACE TABLE `moloco-ods.haewon.ua_cpa_campaigns_l30_days_250530_v2_model` AS

 WITH imp_sampled AS (
      SELECT *
      FROM `focal-elf-631.prod_stream_sampled.imp_1to1000`
      WHERE DATE(timestamp) BETWEEN start_date AND end_date
    ), 

  model_lead_time AS (

    SELECT 
        summary.platform_name,
        summary.advertiser_id,
        summary.store_bundle,
        summary.os,
        summary.product_name,
        api.campaign.id AS campaign_id,
        summary.kpi_event,
        summary.created_ts,
        summary.launch_date,
        summary.latest_date,
        summary.first_imp_ts,
        bid.model.pricing_function AS pricing_function,
        MIN(timestamp) AS model_applied_ts,
        TIMESTAMP_DIFF(MIN(timestamp), first_imp_ts, HOUR) AS hour_diff
    FROM imp_sampled imp
        INNER JOIN `moloco-ods.haewon.ua_cpa_campaigns_l30_days_250530_v2` summary
          ON imp.api.campaign.id = summary.campaign_id
          AND DATE(imp.timestamp) BETWEEN summary.launch_date AND summary.latest_date
    group by 1,2,3,4,5,6,7,8,9,10,11,12
  )


## Summarize at os:bundle:kpi_evet level
  SELECT 
    platform_name,
    advertiser_id,
    product_name,
    os,
    store_bundle,
    kpi_event,
    CONCAT(os,":",store_bundle,":",kpi_event) AS bundle_kpi,
    SPLIT(pricing_function, ":")[OFFSET(0)] AS model_type,
    ARRAY_AGG(DISTINCT campaign_id) AS campaigns,
    MIN(created_ts) AS min_creation_ts,
    MIN(first_imp_ts) AS min_first_imp_ts,
    MIN(model_applied_ts) AS min_model_applied_ts,
    TIMESTAMP_DIFF(MIN(model_applied_ts), MIN(first_imp_ts), HOUR) AS model_imp_diff,
    TIMESTAMP_DIFF(MIN(first_imp_ts), MIN(created_ts), HOUR) AS imp_creation_diff,
  FROM model_lead_time
  GROUP BY 1,2,3,4,5,6,7,8


#### Deep-dive OS:Bundle:kpi_event ####

DECLARE start_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 35 DAY);
DECLARE end_date DATE DEFAULT DATE_SUB('2025-06-04', INTERVAL 5 DAY);


    WITH bundle_kpi AS (
        SELECT 
            os,
            store_bundle,
            kpi_event,
            bundle_kpi,
            model_type,
            campaigns,
            min_creation_ts,
            min_first_imp_ts,
            min_model_applied_ts,
            model_imp_diff,
            imp_creation_diff
        FROM `moloco-ods.haewon.ua_cpa_campaigns_l30_days_250530_v2_model`
        WHERE model_imp_diff > 48
            AND model_type = 'ua_install_with_action'
    ),

    target_campaigns AS (
        SELECT
            c AS campaign_id, 
            os,
            store_bundle,
            kpi_event,
            bundle_kpi
        FROM bundle_kpi, UNNEST(campaigns) as c
    ),

    app_info AS (
        SELECT 
          app_market_bundle,
          os,
          dataai.app_name,
          dataai.app_release_date_utc,
        FROM `moloco-ae-view.athena.dim1_app`
    ),

    budget_history AS (
    # Reference: https://op.moloco.cloud/v2/tools/watch-viewer?from=1745971200000&to=1748736000000&fo=general_selector&f=campaign%21%29fOEJOD2ahdSZ1mpX-%29campaign%21%29uO24EJUyTvFuMkzh-%29campaign%21%29Hh6PfXi90lKonDQg&g=&ro=interval_selector&r=%7B%22interval%22%3A%7B%22days%22%3A1%7D%7D#N4Ig7ghgLgxgFgUQCYEsoHsBOAVApgDyhAC4QUliACAVwBsoUBbCAWgHMkBnFgVQHEWARgAcAVgA6AO0y4Abik4p0kqoKmRYcYlMqUA1ikkVKAZWwBBAHIARcwCVrAfQDq57AGEAEjsqpOAB1oIAE9HSQhGXCoAIWokNlwoSngISQSfJFxOGEwUfwZlKgAfFh9dbDgFZLgITCTOOHQwTkooOFxKACM4hKSUtI7adDZKSs4MTGCAOikyynNJXBgkdCgIWko5clxJGA6AM0x0RlGFCZQYdeSI-wgUNkkWw1RLqCzWmqTrAHZKOwB5cwmVo7LitdC%2BJa0QwdMDtSRdHqJFq1DqGHK4CCcXBISiHXAAR2oOygtGClCwXXJigeKH2F1SSQi6GokignBmkjmzg6Mhgx0iRkoECQACtqONDCM2h1uvFEpRDIrdjJBeyKftKAAmAAMAFIKQiIJQwLhcHoyV0sVUMMLZOhyJR7UEGLQOv5cJh9lhmLsDrRqDAoNRoEpHlNKABNFnXI20TgQgDab3GAF0ABRwKBQfycYgAenzKxgHLY6GGbqm-MY%2Bf8MmxbNDyiL%2BcEjEEACkAFomABq0QAkoIALLCYd8RidTjmAAyM4AXlAAAolgCKfAAGv9PKLvv5vnU9AhRO50ABpAAsOvzOLQAGJONDMgBechTNhamDCTrCGCiXAAJwwPsjg6o4gjfIIACUJqfIqLQyhS%2BRMFccq9HilLBCymDXIwtz3JInK6JEUC5CWjhEp6wTaAiujJBKGCMI4nAErQFHEpMNF0XRlGTI4bx4S6USUAAfKUtHcboJgIDOCDuNgcySZQABUil0QAYgCw6UOmancdJsnyXpknKQANMZ3EzuYfDpkgdxko4aGJDB-y9ggdg6Uu9jYAOPn-JYlDRJGuH4Q8lD-A47mBcFdlvPMJjuDBQKUHWWwspwjlIlAFmUJp-zabpElKXRBlyQpRXFXR7j%2Be4bjph2Jj%2BY4vazjwCDpiSaChKKCaSKZlAAOQACRTH4gQhGEES4ANUH9eIIC6SA-WXHhdwPI45BzSAUHzUlwIraFfU5dxtjYO1DCROMNx7b40C4OZFWVZQtXScdknOJ4CABQ1TWrm1diRh1bJdY4PXKP1w1TBKnqOJc-gepgUxOVAUymuadmhMjM2UAOwKWP82CUJYPBzpQ2CfQFA12SgDkwAxxwDW93EfV9lA-ZYjh-e5gOdVA3W9RDI3Q5gsMQPDnpI1lUw7BAnRuo4%2BxuvgKBy7gmXylAzEekYUrY7jRME0TJMzmTFODWjFqhIrBAq26jOPZVMmvQ7T1U-ZVsoPgOL209klfdYTPxfRmAyGy6u9I4jDoJkD2%2B9x7PNa17W8-z4ODSNdMhzsMDBNjyWZ6HOex3HugvQgge6Cz32NRzXMA0DDB86DAvp1D2Ii3DCOSxrqNmnoGPh4ket44bxOk%2BTrMAjwNjpumL3YPVNeJzObUNyDYN9a3wui%2BLiPI736MTfvw7KBjefAupM6AtgABsF4wQA1M9QILwnLUr8nwNNxvgttzDncS33hbAe%2B9sDEk4GfG6l9r530fs-Mwi8mrv1XinZuadIbbwAXvKWwCj5Sx5EgRYECQjn1ylfNwsDKBP3nogjmyDP6N1TpvDB7cd5dyAX3EBUsKjUEwMQ3OUDyG33vlQ%2BBr8l70LXt-FuLD-5i3YTgzheCe7qVyJAoO0CKEiOoS-Why8UFfyYb-TB8jAGKMPpjKWJhoC8PUclTRwi4E0LfknKRRit6sKwd3XoB9%2B7KJ8SYVkdiL5CNgTBfMlBvg7RdkpJ25cYnFSnjPZxEjXGoJ-h4uRu9vGJFGu7QeUBSEOLCYHf2gdkrUwcsjYuvs8rDkDgAAyjkMfkLBo4cgOmtSQaDCKVOCA0t6LM7DxJLroYAwBWhMDVpgVICRHAEDrItC6WQ1h4XmhDeauodQ3xYDqQQuytTzWxgAX2OeUmwlBxl4hpm8EWqBBSKGUMxUii1xpQG9JgRgu1KCnPOdYS5Ez6T0BhvcnYjzunrBQFiZ5mBFoilkJ6Bg7d1mUHmvCxFCgYbkG%2Bb8hJ3ErD-KuUC25jhQWPDDI4SF0Lxiwvmp0giKK6U3C6RtJAOKzl4rogSygV04rPkGuYeSA43I%2B1GdymWqtcQwWiZVIZIynqpXkOlApOM8bGxyhFFKMglUShVQAQn5X0gpak1iYAjkgToMQBx8DrpGNSJEyJ5mMiwYOodNbI0jtHXAzrXXZ2CD6o1yMfWKqULqoNj1llXTwrDdAAZGAqFum8HwbAjjUH8FQOgF0ICOA4JwHw8hOAhmhPOJsjwuJ0RdeQKgBbwImtlm6ctSl%2BRxrLTlStxh6UPDeo3Btz1mUMs5ZkfYEBM3MSwAwNIjgsCZEwFQIE7g22KmMLFb1nKe3CWsHdbtwQPRUFOvK32Q6R30DHXUKUU7MAzr3QgBKb0HUXH4lMqN6bWiYGJIuqtvqw4eqjpkbtaBe3uF4W6xEGtKC-tXb7dtVAC5%2Bv-aSYSQGs67H9Qk6Dt0aaWI1vB3tm7MOgd6Nu3dRthzRHch%2B4wIblXhpLuuqgS5tWhpaDRuOfNiPE1I%2BRl2zbqDxtZRlD5G1JBoChWxBMZ60iNuKi6ztXJJAgGOUAA

        SELECT
          *, 
          (daily_budget-previous_budget) AS diff_budget
        FROM (
          SELECT
            *,
            LAG(daily_budget) OVER (PARTITION BY campaign ORDER BY date ASC) AS previous_budget
          FROM (
            SELECT
              campaign_id,
              CONCAT(JSON_VALUE(entity_json, '$.display_name'), "(", campaign_id, ")") AS campaign,
              DATE(timestamp) AS date,
              CASE
                WHEN JSON_QUERY(entity_json, '$.user_capper.budget.weekday_budget') IS NOT NULL THEN 'daily_custom'
                WHEN JSON_QUERY(entity_json, '$.user_capper.budget.enable_flexible_budget_spending') IS NOT NULL THEN 'weekly_flexible'
              ELSE
                'daily_fixed'
              END
              AS current_budget_mode,
              JSON_VALUE(entity_json, '$.currency') AS currency,
              CASE
                WHEN JSON_QUERY(entity_json, '$.user_capper.budget.weekday_budget') IS NOT NULL THEN ROUND((CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Monday') AS FLOAT64) + CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Tuesday') AS FLOAT64) + CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Wednesday') AS FLOAT64) + CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Thursday') AS FLOAT64) + CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Friday') AS FLOAT64) + CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Saturday') AS FLOAT64) + CAST(JSON_VALUE(entity_json, '$.user_capper.budget.weekday_budget.Sunday') AS FLOAT64)) / 7)
              ELSE
                ROUND(CAST(JSON_VALUE(entity_json, '$.user_capper.budget.daily_budget') AS FLOAT64))
              END
              AS daily_budget,
            FROM
              `moloco-ods.campaign_json.daily`
            WHERE
              DATE(timestamp) BETWEEN start_date AND end_date
            --   AND campaign_id IN ('fOEJOD2ahdSZ1mpX')
              AND state = 'ACTIVE'
              AND enabled ) )
        WHERE
          previous_budget IS NULL
          OR previous_budget != daily_budget

    )

    SELECT 
        bundle_kpi.*,
        app_info.app_name,
        app_info.app_release_date_utc,
        target_campaigns.campaign_id,
        MIN(pb.timestamp) AS min_pb_ts
    FROM bundle_kpi 
        LEFT JOIN app_info ON bundle_kpi.store_bundle = app_info.app_market_bundle
        LEFT JOIN (SELECT app.bundle, timestamp , event.name AS event_name
                    FROM `focal-elf-631.df_accesslog.pb` 
                    WHERE DATE(timestamp) BETWEEN start_date AND end_date) pb 
            ON bundle_kpi.store_bundle = pb.bundle 
                AND pb.timestamp >= bundle_kpi.min_creation_ts
                AND pb.event_name = REPLACE(bundle_kpi.kpi_event,'"','')
        LEFT JOIN target_campaigns USING bundle_kpi
        
    GROUP BY ALL
-- WITH cpa_campaigns AS (
--         SELECT
--             platform_name,
--             advertiser_name AS advertiser_id,
--             store_bundle,
--             os,
--             product_display_name AS product_name,
--             campaign_name AS campaign_id,
--             created_timestamp_nano AS created_ts,
--             JSON_EXTRACT(campaign_goal, '$.type') AS goal,
--             JSON_EXTRACT(campaign_goal, '$.optimize_cpa_for_app_ua.action') AS kpi_event
--         FROM `focal-elf-631.prod.campaign_digest_merged_latest`
--         WHERE JSON_EXTRACT(campaign_goal, '$.type') LIKE "%OPTIMIZE_CPA_FOR_APP_UA%"
--             AND DATE(created_timestamp_nano) BETWEEN start_date AND end_date
--             JSON_EXTRACT(campaign_goal, '$.optimize_cpa_for_app_ua.action') = "trial_start"
--             AND store_bundle = "net.workoutinc.seven_7minutesfitness_forwomen"
--     ),

    # First postback received

    # bundle information





#### DEPRECATED ####

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 35 DAY);
DECLARE end_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY);

WITH cpa_campaigns AS (
    SELECT
        platform_name,
        advertiser_name AS advertiser_id,
        store_bundle,
        os,
        product_display_name AS product_name,
        campaign_name AS campaign_id,
        DATE(created_timestamp_nano) AS created_date,
        JSON_EXTRACT(campaign_goal, '$.type') AS goal
    FROM `focal-elf-631.prod.campaign_digest_merged_latest`
    WHERE JSON_EXTRACT(campaign_goal, '$.type') LIKE "%OPTIMIZE_CPA_FOR_APP_UA%"
        AND DATE(created_timestamp_nano) BETWEEN start_date AND end_date
)

spend AS (
    SELECT 
        cpa_campaigns.campaign_id,
        DATE(date_utc) AS date_utc,
        SUM(gross_spend_usd) AS gross_spend,         
    FROM `moloco-ae-view.athena.fact_dsp_core` dsp_core
        INNER JOIN cpa_campaigns USING(campaign_id)
    WHERE date_utc BETWEEN start_date AND end_date
        AND campaign.goal LIKE '%CPA%'
    GROUP BY 1, 2
    HAVING gross_spend > 0
), 

summary AS (
    SELECT *,
    MIN(DATE(date_utc)) OVER (PARTITION BY campaign_id) AS launch_date,
    MAX(DATE(date_utc)) OVER (PARTITION BY campaign_id) AS latest_date
    FROM cpa_campaigns
    LEFT JOIN spend USING(campaign_id)
    ORDER BY campaign_id, date_utc
), 

pricing_model AS (
    SELECT 
        date(timestamp) as date, 
        --IF(STARTS_WITH(bid.maid, ""k:""), ""LAT"", ""IDFA"") as traffic_type,
        api.campaign.id,
        DATE(imp.timestamp) AS imp_date,
        bid.model.pricing_function AS pricing_function,
        -- avg(bid.model.prediction_logs[SAFE_OFFSET(1)].pred) AS i2a_pred_avg,
        -- avg(bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) as i2a_norm_avg,
        -- avg(bid.bid_price.amount_micro)/1e6 as bid_price,
        -- avg(bid.model.multipliers.converted_target) as tcm,
        -- avg(bid.model.prediction_logs[safe_OFFSET(1)].pred) as i2a_pred,
        -- avg(bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) AS normalizer,
        -- avg(safe_divide(bid.model.prediction_logs[SAFE_OFFSET(1)].pred, bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer)) as i2a_norm,
        -- avg(bid.model.prediction_logs[SAFE_OFFSET(2)].pred / bid.model.prediction_logs[SAFE_OFFSET(2)].wrapper.normalizer) as rev_mult,
        count(*) as imp_cnt
    FROM `focal-elf-631.prod_stream_sampled.imp_1to1000` imp
        LEFT JOIN summary 
        ON imp.api.campaign.id = summary.campaign_id
        AND DATE(imp.timestamp) BETWEEN summary.launch_date AND summary.latest_date
    where date(timestamp) BETWEEN start_date AND end_date
    group by 1,2,3, 4

)

