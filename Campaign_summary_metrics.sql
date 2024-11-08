-- spend, imp, install, actions by office, advertiser, os, campaign
WITH title_lookup_table AS (select
          * except (timestamp),
          timestamp as added_timestamp,
          CONCAT(IF(advertiser_title = "" OR advertiser_title IS NULL, advertiser_id, advertiser_title),  "(" , advertiser_id, ")") AS advertiser,
          CONCAT(IF(campaign_title = "" OR campaign_title IS NULL, campaign_id, campaign_title),  "(" , campaign_id, ")") AS campaign,
         from
          `focal-elf-631.standard_digest.title_lookup_table`)
  ,  campaign_digest_merged_latest AS (SELECT t1.*,
      t3.advertiser AS advertiser,
      t3.campaign AS campaign,
      t3.advertiser_title as advertiser_title,
      t3.campaign_title as campaign_title,
      t2.Category AS category_content
    FROM (
        SELECT
          platform_name,
          advertiser_name,
          advertiser_display_name,
          campaign_name,
          campaign_display_name,
          product_name,
          product_display_name,
          store_bundle,
          tracking_bundle,
          tracking_company,
          created_timestamp_nano,
          timestamp,
          timestamp(left(inactive_since,10)) as inactive_since,
          type,
          country,
          os,
          payout.currency AS currency,
          advertiser_timezone AS timezone,
          TRIM(JSON_EXTRACT(campaign_goal, '$.type'),'"') AS campaign_goal,
          state,
          enabled,
          product_category,
          kpi_actions,
          platform_markup_percent,
          platform_serving_cost_percent
        FROM
          `focal-elf-631.prod.campaign_digest_merged_latest`
        ) t1
      LEFT JOIN `focal-elf-631.common.app_category_iab`  t2
      ON t1.product_category = t2.Criterion_ID
      LEFT JOIN title_lookup_table t3
      ON t1.campaign_name = t3.campaign_id
      AND t1.platform_name = t3.platform
)
SELECT
    campaign_summary_metrics.office  AS office,
    campaign_summary_metrics.advertiser  AS advertiser,
    campaign_digest_merged_latest.product_display_name  AS app,
    campaign_summary_metrics.os  AS os,
    campaign_summary_metrics.campaign_id  AS campaign_id,
    campaign_digest_merged_latest.campaign_display_name  AS campaign_name,
    COALESCE(SUM(campaign_summary_metrics.revenue ), 0) AS spending,
    COALESCE(SUM(campaign_summary_metrics.imp ), 0) AS imps,
    COALESCE(SUM(campaign_summary_metrics.install ), 0) AS installs,
    COALESCE(SUM(campaign_summary_metrics.kpi_tot ), 0) AS actions
FROM `moloco-ae-view.looker.campaign_summary_metrics_view`  AS campaign_summary_metrics
LEFT JOIN campaign_digest_merged_latest ON campaign_summary_metrics.campaign_id = campaign_digest_merged_latest.campaign_name
WHERE ((( TIMESTAMP(campaign_summary_metrics.local_date)  ) >= (TIMESTAMP('2024-08-13 00:00:00')) 
    AND ( TIMESTAMP(campaign_summary_metrics.local_date)  ) < (TIMESTAMP('2024-09-12 00:00:00')))) 
    AND (campaign_summary_metrics.office ) IN ('CHN', 'IND', 'JPN', 'KOR', 'SGP') 
    AND (campaign_digest_merged_latest.campaign_goal ) = 'OPTIMIZE_ROAS_FOR_APP_UA'
    
GROUP BY 1,2,3,4,5,6
ORDER BY 1,2,3,4
-- LIMIT 500