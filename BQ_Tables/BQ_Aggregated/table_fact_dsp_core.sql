/*
 - moloco-ae-view.athena.fact_dsp_core

 SCHEMA
 - advertiser
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
 - ... 
 
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

    