/*
 - moloco-ae-view.athena.fact_dsp_core

 SCHEMA
 - advertiser
    - mmp_bundle_id
 - advertiser_id
 - ad_group
 - campaign
 - campaign_id
 - date_local
 - date_utc
 - exchange
 - is_complete_date_utc
 - moloco_product
 - platform
 - platform_id
 - product
    - app_market_bundle

FULL SCHEMA
    column_name	data_type	is_nullable
    advertiser	"STRUCT<account_age_group STRING, agency_id STRING, agency_title STRING, analyst STRING, currency STRING, first_launch_date DATE, gm STRING, growth_pod STRING, is_sge_op BOOL, is_small_advertiser BOOL, migrated_platform STRING, mmp_bundle_id STRING, nbs STRING, netsuite_id STRING, office STRING, office_plus_sge STRING, office_region STRING, sgm STRING, tier STRING, timezone STRING, title STRING, title_id STRING, sdr STRING>"	YES
    advertiser_id	STRING	YES
    ad_group	"STRUCT<id STRING, title STRING>"	YES
    campaign	"STRUCT<country STRING, current_budget_mode STRING, daily_budget_local FLOAT64, goal STRING, is_flexible_budget_spending BOOL, is_lat BOOL, is_multi_geo BOOL, kpi_actions STRING, main_tkpi NUMERIC, main_tkpi_metric STRING, os STRING, payout_event STRING, roas_type STRING, sub_tkpi1 NUMERIC, sub_tkpi1_metric STRING, sub_tkpi2 NUMERIC, sub_tkpi2_metric STRING, target_actions ARRAY<STRUCT<event_name STRING, event_type STRING>>, title STRING, title_id STRING, tracking_entity STRING, type STRING, weekday_budget_local_json STRING, weekly_flexible_budget_local FLOAT64, observed_actions ARRAY<STRING>>"	YES
    campaign_id	STRING	YES
    date_local	DATE	YES
    date_utc	DATE	YES
    exchange	STRING	YES
    is_complete_date_utc	BOOL	YES
    moloco_product	STRING	YES
    platform	"STRUCT<client_type STRING, month_tier STRING, quarter_tier STRING, last_month_tier STRING, last_quarter_tier STRING>"	YES
    platform_id	STRING	YES
    product	"STRUCT<app_market_bundle STRING, app_name STRING, company_name STRING, genre STRING, gtm_segment STRING, gtm_sub_segment STRING, has_ads BOOL, has_iap BOOL, iab_category STRING, iab_category_desc STRING, is_gaming BOOL, mmp_name STRING, parent_company_name STRING, sub_genre STRING, title STRING, iab_categories ARRAY<STRING>>"	YES
    product_id	STRING	YES
    skan_conversion_value	NUMERIC	YES
    actions_d1	INT64	YES
    actions_d3	INT64	YES
    actions_d7	INT64	YES
    actions_d14	INT64	YES
    actions_d30	INT64	YES
    bids	INT64	YES
    bid_price_usd	NUMERIC	YES
    capped_kpi_revenue_d1	NUMERIC	YES
    capped_kpi_revenue_d3	NUMERIC	YES
    capped_kpi_revenue_d7	NUMERIC	YES
    capped_kpi_revenue_d14	NUMERIC	YES
    capped_kpi_revenue_d30	NUMERIC	YES
    capped_revenue_d1	NUMERIC	YES
    capped_revenue_d3	NUMERIC	YES
    capped_revenue_d7	NUMERIC	YES
    capped_revenue_d14	NUMERIC	YES
    capped_revenue_d30	NUMERIC	YES
    clicks	INT64	YES
    clicks_ev	INT64	YES
    conversions	INT64	YES
    gross_spend_local	NUMERIC	YES
    gross_spend_usd	NUMERIC	YES
    impressions	INT64	YES
    installs	INT64	YES
    installs_ct	INT64	YES
    installs_rejected	INT64	YES
    installs_vt	INT64	YES
    kpi_actions	INT64	YES
    kpi_actions_d1	INT64	YES
    kpi_actions_d3	INT64	YES
    kpi_actions_d7	INT64	YES
    kpi_actions_d14	INT64	YES
    kpi_actions_d30	INT64	YES
    kpi_payers_d1	INT64	YES
    kpi_payers_d3	INT64	YES
    kpi_payers_d7	INT64	YES
    kpi_payers_d14	INT64	YES
    kpi_payers_d30	INT64	YES
    kpi_pb_revenue_d1	NUMERIC	YES
    kpi_pb_revenue_d3	NUMERIC	YES
    kpi_pb_revenue_d7	NUMERIC	YES
    kpi_pb_revenue_d14	NUMERIC	YES
    kpi_pb_revenue_d30	NUMERIC	YES
    kpi_pb_revenue_d1_local	NUMERIC	YES
    kpi_pb_revenue_d3_local	NUMERIC	YES
    kpi_pb_revenue_d7_local	NUMERIC	YES
    kpi_pb_revenue_d14_local	NUMERIC	YES
    kpi_pb_revenue_d30_local	NUMERIC	YES
    kpi_pb_revenue_local	NUMERIC	YES
    kpi_pb_revenue_usd	NUMERIC	YES
    kpi_purchases_d1	INT64	YES
    kpi_purchases_d3	INT64	YES
    kpi_purchases_d7	INT64	YES
    kpi_purchases_d14	INT64	YES
    kpi_purchases_d30	INT64	YES
    kpi_users_d1	INT64	YES
    kpi_users_d3	INT64	YES
    kpi_users_d7	INT64	YES
    kpi_users_d14	INT64	YES
    kpi_users_d30	INT64	YES
    media_cost_usd	NUMERIC	YES
    payers_d1	INT64	YES
    payers_d3	INT64	YES
    payers_d7	INT64	YES
    payers_d14	INT64	YES
    payers_d30	INT64	YES
    pb_revenue_local	NUMERIC	YES
    pb_revenue_usd	NUMERIC	YES
    purchases_d1	INT64	YES
    purchases_d3	INT64	YES
    purchases_d7	INT64	YES
    purchases_d14	INT64	YES
    purchases_d30	INT64	YES
    retained_users_d1	NUMERIC	YES
    retained_users_d3	NUMERIC	YES
    retained_users_d7	NUMERIC	YES
    retained_users_d14	NUMERIC	YES
    retained_users_d30	NUMERIC	YES
    retained_users_w1	NUMERIC	YES
    retained_users_w2	NUMERIC	YES
    retained_users_w3	NUMERIC	YES
    retained_users_w4	NUMERIC	YES
    revenue_before_discounts_local	NUMERIC	YES
    revenue_before_discounts_usd	NUMERIC	YES
    revenue_d1	NUMERIC	YES
    revenue_d3	NUMERIC	YES
    revenue_d7	NUMERIC	YES
    revenue_d14	NUMERIC	YES
    revenue_d30	NUMERIC	YES
    revenue_d1_local	NUMERIC	YES
    revenue_d3_local	NUMERIC	YES
    revenue_d7_local	NUMERIC	YES
    revenue_d14_local	NUMERIC	YES
    revenue_d30_local	NUMERIC	YES
    skan_installs	INT64	YES
    users_d1	INT64	YES
    users_d3	INT64	YES
    users_d7	INT64	YES
    users_d14	INT64	YES
    users_d30	INT64	YES
    video_play_starts	INT64	YES
    video_play_1q	INT64	YES
    video_play_2q	INT64	YES
    video_play_3q	INT64	YES
    video_play_4q	INT64	YES
    clicks_ec	INT64	YES
    attribution	STRING	YES
    installs_ev	INT64	YES
    skan_installs_ct	INT64	YES
    skan_installs_vt	INT64	YES
 
*/

WITH app AS (
    SELECT 
        app_market_bundle,
        os,
        dataai.app_name,
        dataai.app_release_date_utc,
    FROM `moloco-ae-view.athena.dim1_app`
    WHERE DATE(dataai.app_release_date_utc) >= '2024-01-01'
)
SELECT
    advertiser,
    advertiser_id,
    advertiser.office,
    product.title, 
    product_id,
    a.product.app_market_bundle,
    b.app_release_date_utc,
    gross_spend_usd,


FROM `moloco-ae-view.athena.fact_dsp_core` a JOIN app b 
    ON a.product.app_market_bundle = b.app_market_bundle
WHERE
    DATE(date_utc) >= '2024-01-01'
    AND DATE(b.app_release_date_utc) >= '2024-01-01'
    AND gross_spend_usd > 0

    

### Genre-level top spenders ### 

DECLARE app_market_bundle STRING DEFAULT 'com.netmarble.kofafk';
DECLARE start_date DATE DEFAULT '2025-09-01';
DECLARE end_date DATE DEFAULT '2025-09-15';

WITH target_genre AS (
    SELECT
        DISTINCT
            product.genre,
            product.sub_genre
    FROM `moloco-ae-view.athena.fact_dsp_core`
    WHERE
        date_utc BETWEEN start_date AND end_date             
        AND product.app_market_bundle = app_market_bundle

),

 app AS (
    SELECT 
        app_market_bundle,
        dataai.unified_app_id,
        dataai.unified_app_name,
    FROM `moloco-ae-view.athena.dim1_app`
    WHERE DATE(dataai.app_release_date_utc) >= '2024-01-01'
)

SELECT 
    unified_app_id,
    unified_app_name,
    product.app_market_bundle,
    SUM(gross_spend_usd) AS gross_spend
FROM `moloco-ae-view.athena.fact_dsp_core` core
    JOIN target_genre
        ON core.product.genre = target_genre.genre 
        AND core.product.sub_genre = target_genre.sub_genre
    LEFT JOIN app ON product.app_market_bundle = app.app_market_bundle
WHERE 
    date_utc BETWEEN start_date AND end_date     
    AND product.os IN ('IOS','ANDROID')
GROUP BY ALL
HAVING SUM(gross_spend_usd) > 0
ORDER BY gross_spend DESC
LIMIT 10
            
