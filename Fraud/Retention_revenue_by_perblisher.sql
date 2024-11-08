WITH title_lookup_table AS (select
          * except (timestamp),
          timestamp as added_timestamp,
          CONCAT(IF(advertiser_title = "" OR advertiser_title IS NULL, advertiser_id, advertiser_title),  "(" , advertiser_id, ")") AS advertiser,
          CONCAT(IF(campaign_title = "" OR campaign_title IS NULL, campaign_id, campaign_title),  "(" , campaign_id, ")") AS campaign,
          --CASE
          --  WHEN advertiser_title IS NULL THEN advertiser_id
          --  WHEN advertiser_title = '' THEN advertiser_id
          --  WHEN advertiser_id =  advertiser_title THEN advertiser_id
          --  ELSE concat(advertiser_title, "#", advertiser_id)
          --END AS advertiser,
          --CASE
          --  WHEN campaign_title IS NULL THEN campaign_id
          --  WHEN campaign_title = '' THEN campaign_id
          --  WHEN campaign_id =  campaign_title THEN campaign_id
          --  ELSE concat(campaign_title, "#", campaign_id)
          --END AS campaign
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
  ,  app_profile_latest AS (SELECT
      app_bundle,
      exchange,
      type,
      app_name,
      publisher_name,
      app_categories,
      first_date,
      last_date,
      bid_cnt,
      no_bid_cnt
    FROM (
      SELECT
        app_bundle,
        exchange,
        type,
        app_name,
        publisher_name,
        app_categories,
        first_date,
        last_date,
        bid_cnt,
        no_bid_cnt,
        ROW_NUMBER() OVER(PARTITION BY app_bundle ORDER BY BYTE_LENGTH(app_name) DESC) AS rank
      FROM
        `focal-elf-631.df_app_profile.lifetime_app_latest`)
    WHERE
      rank = 1)
  ,  prod_cluster_cv AS (SELECT
        cv.*,
        CASE
          WHEN cv.req.device.lmt = FALSE AND cv.req.device.os = "ANDROID" THEN 1
          WHEN cv.req.device.lmt = FALSE AND cv.req.device.os = "IOS" THEN 2
          WHEN cv.req.device.lmt = TRUE AND cv.req.device.os = "ANDROID" THEN 5
          WHEN cv.req.device.lmt = TRUE AND cv.req.device.os = "IOS" THEN 6
          WHEN cv.req.device.lmt = FALSE AND cv.req.device.os = "CTV" THEN 10
          WHEN cv.req.device.lmt = TRUE AND cv.req.device.os = "CTV" THEN 11
        END AS id_type,
        tlt.advertiser as advertiser,
        tlt.campaign as campaign
      FROM `focal-elf-631.prod_stream_view.cv` as cv
        LEFT JOIN title_lookup_table as tlt
        ON cv.api.campaign.id = tlt.campaign_id
        AND cv.platform_id = tlt.platform
)
  ,  retention_by_app_bundle AS (WITH zone_table AS (
        SELECT
          campaign,
          timezone,
          category_content
        FROM
          campaign_digest_merged_latest
        WHERE
          -- (campaign LIKE '%EzGFcTmWvMAIDFzu%')
          advertiser_name LIKE 'gez3LMPdQulTcYEq' 
          AND 1=1 -- no filter on 'retention_by_app_bundle.selected_advertiser'

        GROUP BY
          1,
          2,
          3),
        app_name AS (
              select
                app_bundle  as app_bundle,
                app_name as name
              from
                app_profile_latest
              group by
               1,
               2),
        adv_raw AS
        (
          SELECT
            *
          FROM
            (
            SELECT
              DATE(local_date) as local_date,
              advertiser,
              app_bundle,
              ad_group,
              cr_group,
              cr_id,
              campaign,
              os,
              sum(install) AS install,
              sum(kpi_tot) as kpi,
              sum(imp) as imp,
              sum(click) as click,
              sum(revenue) as revenue
            FROM `moloco-ae-view.looker.campaign_raw_all_view`
            WHERE
              ((( TIMESTAMP(local_date) ) >= (TIMESTAMP('2024-09-26 00:00:00')) AND ( TIMESTAMP(local_date) ) < (TIMESTAMP('2024-10-07 00:00:00'))))
              AND 1=1 -- no filter on 'retention_by_app_bundle.selected_advertiser'
              AND advertiser_id LIKE '%gez3LMPdQulTcYEq%'

              -- AND (campaign LIKE '%EzGFcTmWvMAIDFzu%')
              AND 1=1 -- no filter on 'retention_by_app_bundle.filter_country'

              AND 1=1 -- no filter on 'retention_by_app_bundle.filter_os'

            GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
            )
            LEFT JOIN app_name USING (app_bundle)),
        app_profile AS
        (
          SELECT app_market_bundle AS app_bundle, v2.genre, v2.sub_genre
          FROM `moloco-ae-view.athena.dim1_app`
        ),

        cv_table_install AS (
        SELECT
          *
        FROM (
        SELECT
            --CASE
            --  WHEN api.advertiser.title IS NULL THEN advertiser_id
            --  WHEN api.advertiser.title = '' THEN advertiser_id
            --  WHEN advertiser_id =  api.advertiser.title THEN advertiser_id
            --  ELSE CONCAT(api.advertiser.title, "#", advertiser_id)
            --END AS advertiser,
            --CASE
            --  WHEN api.campaign.title IS NULL THEN api.campaign.id
            --  WHEN api.campaign.title = '' THEN api.campaign.id
            --  WHEN api.campaign.id = api.campaign.title THEN api.campaign.id
            --  ELSE CONCAT(api.campaign.title, "#", api.campaign.id)
            --END AS campaign,
            advertiser,
            campaign,
            req.app.bundle AS app_bundle,
            api.adgroup.id AS ad_group,
            api.crgroup.id AS cr_group,
            api.creative.crid AS cr_id,
            timestamp,
            req.bid_id AS bid_id,
            req.device.geo.country AS country,
            req.device.os AS os,
            cv.event_pb AS pb_event,
            cv.event AS event
          FROM
            prod_cluster_cv
            --`focal-elf-631.prod_stream_view.cv`
          WHERE
            timestamp >= TIMESTAMP_ADD(TIMESTAMP('2024-09-26 00:00:00'), INTERVAL -24 hour)
            AND 1=1 -- no filter on 'retention_by_app_bundle.selected_advertiser'
            AND advertiser_id LIKE '%gez3LMPdQulTcYEq%'
            -- AND (campaign LIKE '%EzGFcTmWvMAIDFzu%')
            AND 1=1 -- no filter on 'retention_by_app_bundle.filter_country'

            AND 1=1 -- no filter on 'retention_by_app_bundle.filter_os'

            AND (LOWER(cv.event_pb) = 'install' or LOWER(cv.event_pb) = 'installs')
        )
        LEFT JOIN
          zone_table
        USING
          (campaign)
        LEFT JOIN
         app_profile
        USING
        (app_bundle)),
        cv_table_retention AS (
        SELECT
            --CASE
            --  WHEN api.advertiser.title IS NULL THEN advertiser_id
            --  WHEN api.advertiser.title = '' THEN advertiser_id
            --  WHEN advertiser_id =  api.advertiser.title THEN advertiser_id
            --  ELSE CONCAT(api.advertiser.title, "#", advertiser_id)
            --END AS advertiser,
            --CASE
            --  WHEN api.campaign.title IS NULL THEN api.campaign.id
            --  WHEN api.campaign.title = '' THEN api.campaign.id
            --  WHEN api.campaign.id = api.campaign.title THEN api.campaign.id
            --  ELSE CONCAT(api.campaign.title, "#", api.campaign.id)
            --END AS campaign,
            advertiser,
            campaign,
            req.app.bundle AS app_bundle,
            api.adgroup.id AS ad_group,
            api.crgroup.id AS cr_group,
            api.creative.crid AS cr_id,
            timestamp,
            req.bid_id AS bid_id,
            req.device.geo.country AS country,
            req.device.os AS os,
            cv.event_pb AS pb_event,
            cv.event AS event
          FROM
            prod_cluster_cv
            --`focal-elf-631.prod_stream_view.cv`
          WHERE
            timestamp >= TIMESTAMP_ADD(TIMESTAMP('2024-09-26 00:00:00'), INTERVAL -24 hour)
            AND 1=1 -- no filter on 'retention_by_app_bundle.selected_advertiser'
            AND advertiser_id LIKE '%gez3LMPdQulTcYEq%'
            -- AND (campaign LIKE '%EzGFcTmWvMAIDFzu%')
            AND 1=1 -- no filter on 'retention_by_app_bundle.filter_country'

            AND 1=1 -- no filter on 'retention_by_app_bundle.filter_os'

            AND (LOWER(cv.event_pb) != 'install' or LOWER(cv.event_pb) != 'installs')
            AND 1=1 -- no filter on 'retention_by_app_bundle.pb_event_retention'
),
        cr_status AS (
        SELECT
          crid,
          original_file_name,
          row_number() over (partition by crid order by max(dumped_at) desc) AS rn
        FROM `focal-elf-631.prod.creative_status*`
        WHERE
            _TABLE_SUFFIX BETWEEN FORMAT_TIMESTAMP('%Y%m%d',TIMESTAMP_ADD(TIMESTAMP('2024-08-12 00:00:00'), interval -24 hour))
            AND FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP_ADD(TIMESTAMP('2024-10-07 00:00:00'), interval 24 hour))
        GROUP BY
          1,
          2)

        SELECT
          local_date,
          advertiser,
          campaign,
          app_bundle,
          sub_genre,
          ad_group,
          cr_group,
          cr_id,
          original_file_name,
          name,
          adv_raw.os as os,
          d0_retention,
          d1_retention,
          d3_retention,
          d7_retention,
          d30_retention,
          d0_install,
          revenue,
          imp,
          install,
          click,
          kpi,
          category_content
        from
        (
        SELECT
          DATE(inst_at, timezone) AS local_date,
          advertiser as advertiser,
          campaign as campaign,
          app_bundle as app_bundle,
          sub_genre as sub_genre,
          ad_group as ad_group,
          cr_group as cr_group,
          cr_id as cr_id,
          os AS os,
          category_content AS category_content,
          count(distinct bid_id) as d0_install,
          count(distinct IF( day_diff = 0, bid_id, NULL)) as d0_retention,
          count(distinct IF( day_diff = 1, bid_id, NULL)) as d1_retention,
          count(distinct IF( day_diff = 3, bid_id, NULL)) as d3_retention,
          count(distinct IF( day_diff = 7, bid_id, NULL))  as d7_retention,
          count(distinct IF( day_diff = 30, bid_id, NULL))  as d30_retention
        FROM (
          SELECT
            i.advertiser as advertiser,
            i.inst_at AS inst_at,
            r.timestamp AS open_at,
            i.campaign as campaign,
            i.app_bundle as app_bundle,
            i.sub_genre as sub_genre,
            i.ad_group as ad_group,
            i.cr_group,
            i.cr_id,
            i.category_content,
            bid_id,
            os,
            timezone,
            TIMESTAMP_DIFF(r.timestamp, i.inst_at, day) AS day_diff
          FROM (
            SELECT
              bid_id,
              os,
              advertiser,
              campaign,
              ad_group,
              cr_group,
              cr_id,
              app_bundle,
              sub_genre,
              timezone,
              timestamp AS inst_at,
              category_content
            FROM cv_table_install
          GROUP BY
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12)
              AS i
          LEFT JOIN (
            SELECT
              timestamp,
              bid_id,
              app_bundle,
              ad_group,
              cr_group,
              cr_id,
              os,
              campaign
            FROM cv_table_retention
            GROUP BY
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8) AS r
          USING (bid_id, os, campaign, app_bundle, ad_group, cr_group, cr_id))
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
        HAVING local_date BETWEEN DATE(TIMESTAMP('2024-09-26 00:00:00')) AND DATE(TIMESTAMP('2024-10-07 00:00:00'))
        )
        RIGHT JOIN adv_raw USING (advertiser, campaign, app_bundle, ad_group, local_date, cr_group, cr_id)
        LEFT JOIN cr_status
          ON adv_raw.cr_id = cr_status.crid
          AND cr_status.rn = 1
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
  ),
retention_summary AS (
SELECT
    retention_by_app_bundle.os  AS retention_by_app_bundle_os,
    retention_by_app_bundle.app_bundle  AS bundle,
    COALESCE(SUM(retention_by_app_bundle.revenue), 0) AS spend,
    COALESCE(SUM(retention_by_app_bundle.install), 0) AS install,
    COALESCE(SUM(retention_by_app_bundle.d1_retention), 0) / NULLIF(COALESCE(SUM(retention_by_app_bundle.D0_install ), 0), 0) * 100 AS d1_retention_rate,
    COALESCE(SUM(retention_by_app_bundle.d3_retention), 0) / NULLIF(COALESCE(SUM(retention_by_app_bundle.D0_install ), 0), 0) * 100 AS d3_retention_rate
FROM retention_by_app_bundle
WHERE (retention_by_app_bundle.advertiser ) IS NOT NULL
GROUP BY
    1,
    2
ORDER BY
    4 DESC
LIMIT 500
),
revenue_summary AS(
  SELECT
      app_profile_latest.app_bundle  AS bundle,
      COALESCE(SUM(campaign_raw_metrics.revenue ), 0) AS spend,
      COALESCE(SUM(campaign_raw_metrics.install ), 0) AS install,
      COALESCE(SUM(campaign_raw_metrics.count_distinct_kpi_d7 ), 0) AS kpi_d7,
      COALESCE(SUM(campaign_raw_metrics.total_revenue_d7 ), 0) AS revenue_d7
  FROM `moloco-ae-view.looker.campaign_raw_metrics_view`  AS campaign_raw_metrics
  LEFT JOIN app_profile_latest ON campaign_raw_metrics.app_bundle = app_profile_latest.app_bundle
  WHERE ((( TIMESTAMP(campaign_raw_metrics.local_date)  ) >= (TIMESTAMP('2024-09-26 00:00:00')) 
    AND ( TIMESTAMP(campaign_raw_metrics.local_date)  ) < (TIMESTAMP('2024-10-07 00:00:00')))) 
    AND (campaign_raw_metrics.advertiser_id) LIKE '%gez3LMPdQulTcYEq%'
    -- AND (campaign_raw_metrics.campaign) LIKE '%EzGFcTmWvMAIDFzu%'
  GROUP BY
      1
  ORDER BY
      2 DESC
  LIMIT 500
)
SELECT 
  t1.*, 
  t2.kpi_d7,
  t2.revenue_d7,  
FROM retention_summary t1 
  LEFT JOIN revenue_summary t2 USING(bundle)
ORDER BY spend DESC