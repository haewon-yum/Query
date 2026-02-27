/* 
SCHEMA

column_name	data_type	is_nullable
advertiser	"STRUCT<account_age_group STRING, agency_id STRING, agency_title STRING, analyst STRING, currency STRING, first_launch_date DATE, gm STRING, growth_pod STRING, is_sge_op BOOL, migrated_platform STRING, mmp_bundle_id STRING, nbs STRING, netsuite_id STRING, office STRING, office_plus_sge STRING, office_region STRING, sgm STRING, tier STRING, timezone STRING, title STRING, title_id STRING, sdr STRING>"	YES
advertiser_id	STRING	YES
ad_group	"STRUCT<id STRING, title STRING>"	YES
campaign	"STRUCT<country STRING, current_budget_mode STRING, daily_budget_local FLOAT64, goal STRING, is_flexible_budget_spending BOOL, is_lat BOOL, is_multi_geo BOOL, kpi_actions STRING, main_tkpi NUMERIC, main_tkpi_metric STRING, os STRING, payout_event STRING, roas_type STRING, sub_tkpi1 NUMERIC, sub_tkpi1_metric STRING, sub_tkpi2 NUMERIC, sub_tkpi2_metric STRING, target_actions ARRAY<STRUCT<event_name STRING, event_type STRING>>, title STRING, title_id STRING, tracking_entity STRING, type STRING, weekday_budget_local_json STRING, weekly_flexible_budget_local FLOAT64, observed_actions ARRAY<STRING>>"	YES
campaign_id	STRING	YES
date_local	DATE	YES
date_utc	DATE	YES
exchange	STRING	YES
is_complete_date_utc	BOOL	YES
moloco_product	STRING	YES
platform	STRUCT<client_type STRING>	YES
platform_id	STRING	YES
product	"STRUCT<app_market_bundle STRING, app_name STRING, company_name STRING, genre STRING, gtm_segment STRING, gtm_sub_segment STRING, has_ads BOOL, has_iap BOOL, iab_category STRING, iab_category_desc STRING, is_gaming BOOL, mmp_name STRING, parent_company_name STRING, sub_genre STRING, title STRING, iab_categories ARRAY<STRING>>"	YES
product_id	STRING	YES
publisher	"STRUCT<app_market_bundle STRING, is_small_publisher BOOL>"	YES
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
installs_ev	INT64	YES

*/


# top 10 publisher by date 
# ODSB-13833

-- 일자별 gross_spend_usd TOP 10
WITH fact_dsp_publisher AS (
  SELECT *
  FROM `ads-bpd-guard-china.athena.fact_dsp_publisher`
  WHERE TIMESTAMP(date_utc) >= TIMESTAMP('2025-08-01 00:00:00')
    AND TIMESTAMP(date_utc) <  TIMESTAMP('2025-09-24 00:00:00')
    -- 아래의 1=1 필터들은 불필요해서 제거했어요 (필요하면 되살리면 됩니다)
),
agg AS (
  SELECT
    DATE(TIMESTAMP(date_utc)) AS utc_date,
    publisher.app_market_bundle AS app_market_bundle,
    SUM(gross_spend_usd) AS gross_spend_usd
  FROM fact_dsp_publisher
  WHERE (campaign.title_id) = 'MolocoDSPInstall_NxK_UAGL_AOS(Ne6jBHMofOsE811P)'
  GROUP BY 1, 2
)
SELECT
  utc_date,
  app_market_bundle,
  gross_spend_usd
FROM agg
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY utc_date
  ORDER BY gross_spend_usd DESC
) <= 10
ORDER BY utc_date DESC, gross_spend_usd DESC;



## top 10 publishers with spend and i2p 

-- 일자별 gross_spend_usd TOP 10
WITH fact_dsp_publisher AS (
  SELECT *
  FROM `ads-bpd-guard-china.athena.fact_dsp_publisher`
  WHERE TIMESTAMP(date_utc) >= TIMESTAMP('2025-09-12 00:00:00')
    AND TIMESTAMP(date_utc) <  TIMESTAMP('2025-09-24 00:00:00')
    -- 아래의 1=1 필터들은 불필요해서 제거했어요 (필요하면 되살리면 됩니다)
),
agg AS (
  SELECT
    DATE(TIMESTAMP(date_utc)) AS utc_date,
    publisher.app_market_bundle AS app_market_bundle,
    SUM(installs) AS installs,
    SUM(kpi_payers_d7) AS kpi_payers,
    SAFE_DIVIDE(COALESCE(SUM(kpi_payers_d7), 0), COALESCE(SUM(installs ), 0)) AS i2p_d7,
    SUM(gross_spend_usd) AS gross_spend_usd
  FROM fact_dsp_publisher
  WHERE (campaign_id) = 'byJy685EjCDQ8Mri'
  GROUP BY 1, 2
)
SELECT
  utc_date,
  app_market_bundle,
  i2p_d7,
  gross_spend_usd
FROM agg
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY utc_date
  ORDER BY gross_spend_usd DESC
) <= 10
ORDER BY utc_date DESC, gross_spend_usd DESC;


## top 10 publishers by Country/OS

    DECLARE start_date DATE DEFAULT DATE('${startDate}');
    DECLARE end_date   DATE DEFAULT DATE('${endDate}');
    DECLARE target_countries ARRAY<STRING> DEFAULT [${countrySqlList}];
    DECLARE target_os ARRAY<STRING> DEFAULT [${osSqlList}];

    WITH publisher_spend AS (
      SELECT
        campaign.country AS country,
        UPPER(campaign.os) AS os,
        publisher.app_market_bundle AS publisher_bundle,
        dim1_app.dataai.genre AS genre,
        SUM(gross_spend_usd) AS spend_usd
      FROM `moloco-ae-view.athena.fact_dsp_publisher`
      LEFT JOIN `ads-bpd-guard-china.athena.dim1_app` AS dim1_app
        ON publisher.app_market_bundle = dim1_app.app_market_bundle
      WHERE
        date_utc BETWEEN start_date AND end_date
        AND campaign.country IN UNNEST(target_countries)
        AND UPPER(campaign.os) IN UNNEST(target_os)
        AND gross_spend_usd > 0
      GROUP BY country, os, publisher_bundle, genre
    ),
    total_spend_by_country_os AS (
      SELECT
        country,
        os,
        SUM(spend_usd) AS total_spend_usd
      FROM publisher_spend
      GROUP BY country, os
    ),
    ranked_publishers AS (
      SELECT
        ps.country,
        ps.os,
        ps.publisher_bundle,
        ps.genre,
        ps.spend_usd,
        ts.total_spend_usd,
        SAFE_DIVIDE(ps.spend_usd, ts.total_spend_usd) * 100 AS spend_pct,
        ROW_NUMBER() OVER (
          PARTITION BY ps.country, ps.os
          ORDER BY ps.spend_usd DESC
        ) AS publisher_rank
      FROM publisher_spend ps
      JOIN total_spend_by_country_os ts
        ON ps.country = ts.country
       AND ps.os = ts.os
    )
    SELECT
      rp.country,
      rp.os,
      rp.publisher_rank,
      rp.publisher_bundle,
      COALESCE(da.dataai.app_name, rp.publisher_bundle) AS publisher_app_name,
      rp.genre,
      rp.spend_usd,
      rp.spend_pct,
      rp.total_spend_usd AS total_country_os_spend
    FROM ranked_publishers rp
    LEFT JOIN `moloco-ae-view.athena.dim1_app` da
      ON rp.publisher_bundle = da.app_market_bundle
    WHERE rp.publisher_rank <= 10
    ORDER BY rp.country, rp.os, rp.publisher_rank

## Publisher genre mix for the given country/OS


