/*
- moloco-ae-view.athena.dim1_app

SCHEMA
- app_market_bundle
- os
- v2
- dataai
  - app_name
  - is_gaming
  - genre
  - sub_genre,
  ...

SCHEMA
    column_name	data_type	is_nullable
    app_market_bundle	STRING	YES
    os	STRING	YES
    dataai	"STRUCT<app_current_release_date_utc DATE, app_id NUMERIC, app_name STRING, app_name_translated STRING, app_description STRING, app_release_date_utc DATE, company_hq_country STRING, company_hq_region STRING, company_id NUMERIC, company_name STRING, company_website_url STRING, genre STRING, gtm_genre STRING, gtm_sub_genre STRING, has_ads BOOL, has_iap BOOL, is_gaming BOOL, is_published BOOL, last_30d_downloads NUMERIC, last_30d_revenue NUMERIC, last_published_date_utc DATE, parent_company_id NUMERIC, parent_company_name STRING, publisher_id NUMERIC, publisher_name STRING, publisher_website_url STRING, sub_genre STRING, unified_app_id NUMERIC, unified_app_name STRING>"	YES
    matters42	"STRUCT<app_name STRING, genre STRING, iab_cat_v1 ARRAY<STRUCT<name STRING>>, iab_cat_v2 ARRAY<STRUCT<name STRING>>, iab_cat_v3 ARRAY<STRUCT<name STRING>>, is_published BOOL, last_updated_date DATE, normalized_content_rating STRING, publisher_name STRING, publisher_website_url STRING, store_content_rating STRING, store_url STRING>"	YES
    sensortower	"STRUCT<app_id STRING, app_name STRING, byte_size INT64, company_id STRING, company_name STRING, content_rating STRING, country STRING, current_release_date_utc DATE, current_version STRING, description STRING, genre STRING, gtm_genre STRING, gtm_sub_genre STRING, has_ads BOOL, has_game_center BOOL, has_iap BOOL, has_imsg BOOL, icon_url STRING, is_gaming BOOL, is_published BOOL, language STRING, last_30d_downloads INT64, last_30d_revenue INT64, last_updated_time_utc TIMESTAMP, original_price FLOAT64, price_usd FLOAT64, privacy_policy_url STRING, promotional_text STRING, publisher_id STRING, publisher_name STRING, publisher_website STRING, region STRING, first_release_date_utc DATE, store_url STRING, sub_genre ARRAY<STRING>, subtitle STRING, support_url STRING, unified_app_id STRING, unified_app_name STRING, whats_new STRING>"	YES
      
*/


SELECT 
  app_market_bundle,
  os,
  dataai.app_name,
  dataai.app_release_date_utc,
FROM `moloco-ae-view.athena.dim1_app`
WHERE DATE(dataai.app_release_date_utc) >= '2024-01-01'
