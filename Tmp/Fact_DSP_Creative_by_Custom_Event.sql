-- raw sql results do not include filled-in values for 'fact_dsp_custom_event_creative.date_utc'


WITH fact_dsp_custom_event_creative AS (WITH
        cohort_raw AS (
          SELECT
            DATE(install_time_bucket) AS date_utc,
            platform_id,
            advertiser_id,
            campaign_id,
            exchange,
            ad_group_id,
            cr_group_id,
            cr_format,
            SPLIT(cr_id, ":")[SAFE_OFFSET(2)] AS cr_id,
            country,
            os,
            is_lat,
            on_day,
            count_event AS events,
            total_revenue AS revenue,
            mtid AS users
          FROM `focal-elf-631.standard_cs_v5_view.i2a_rolling`
          WHERE ((( DATE(install_time_bucket) ) >= ((DATE_ADD(CURRENT_DATE('UTC'), INTERVAL -6 DAY))) AND ( DATE(install_time_bucket) ) < ((DATE_ADD(DATE_ADD(CURRENT_DATE('UTC'), INTERVAL -6 DAY), INTERVAL 7 DAY)))))
            AND 1=1 -- no filter on 'fact_dsp_custom_event_creative.selected_platform'

            AND (advertiser_id = 't52aeGmi7ov3wppl')
            AND 1=1 -- no filter on 'fact_dsp_custom_event_creative.selected_campaign'

            AND (pb_event = 'af_hunt_pass_purchase')
            AND on_day BETWEEN 0 AND 30
            AND IS_INF(total_revenue) IS FALSE

          UNION ALL

          SELECT
            DATE(click_time_bucket) AS date_utc,
            platform_id,
            advertiser_id,
            campaign_id,
            exchange,
            ad_group_id,
            cr_group_id,
            cr_format,
            SPLIT(cr_id, ":")[SAFE_OFFSET(2)] AS cr_id,
            country,
            os,
            is_lat,
            on_day,
            count_event AS events,
            total_revenue AS revenue,
            mtid AS users
          FROM `focal-elf-631.standard_cs_v5_view.c2a_rolling`
          WHERE ((( DATE(click_time_bucket) ) >= ((DATE_ADD(CURRENT_DATE('UTC'), INTERVAL -6 DAY))) AND ( DATE(click_time_bucket) ) < ((DATE_ADD(DATE_ADD(CURRENT_DATE('UTC'), INTERVAL -6 DAY), INTERVAL 7 DAY)))))
            AND 1=1 -- no filter on 'fact_dsp_custom_event_creative.selected_platform'

            AND (advertiser_id = 't52aeGmi7ov3wppl')
            AND 1=1 -- no filter on 'fact_dsp_custom_event_creative.selected_campaign'

            AND (pb_event = 'af_hunt_pass_purchase')
            AND on_day BETWEEN 0 AND 30
            AND IS_INF(total_revenue) IS FALSE
        ),

        cohort_union AS (
          SELECT
            date_utc,
            platform_id,
            advertiser_id,
            campaign_id,
            exchange,
            ad_group_id,
            cr_group_id,
            cr_format,
            cr_id,
            country,
            os,
            is_lat,
            SUM(IF(on_day < 1, events, 0)) AS actions_d1,
            COUNT(DISTINCT IF(on_day < 1, users, NULL)) AS users_d1,
            SUM(IF(on_day < 1, revenue, 0)) AS revenue_d1,
            COUNT(DISTINCT IF(on_day = 1, users, NULL)) AS retained_users_d1,
            SUM(IF(on_day < 7, events, 0)) AS actions_d7,
            COUNT(DISTINCT IF(on_day < 7, users, NULL)) AS users_d7,
            SUM(IF(on_day < 7, revenue, 0)) AS revenue_d7,
            COUNT(DISTINCT IF(on_day = 7, users, NULL)) AS retained_users_d7,
            SUM(IF(on_day < 30, events, 0)) AS actions_d30,
            COUNT(DISTINCT IF(on_day < 30, users, NULL)) AS users_d30,
            SUM(IF(on_day < 30, revenue, 0)) AS revenue_d30,
            COUNT(DISTINCT IF(on_day = 30, users, NULL)) AS retained_users_d30,
            COUNT(DISTINCT IF(on_day BETWEEN 1 AND 7, users, NULL)) AS retained_users_w1,
            COUNT(DISTINCT IF(on_day BETWEEN 8 AND 14, users, NULL)) AS retained_users_w2,
            COUNT(DISTINCT IF(on_day BETWEEN 15 AND 21, users, NULL)) AS retained_users_w3,
            COUNT(DISTINCT IF(on_day BETWEEN 22 AND 28, users, NULL)) AS retained_users_w4
          FROM cohort_raw
          GROUP BY ALL
        ),

        fact AS (
          SELECT
            date_utc,
            platform_id,
            product.app_market_bundle,
            product_id,
            product.title AS product_title,
            advertiser.currency,
            advertiser.mmp_bundle_id,
            advertiser_id,
            advertiser.title AS advertiser_title,
            ad_group.id AS ad_group_id,
            ad_group.title AS ad_group_title,
            campaign_id,
            campaign.title AS campaign_title,
            campaign.goal AS campaign_goal,
            campaign.country,
            campaign.os,
            campaign.is_lat,
            creative.format AS cr_format,
            creative.group_id AS cr_group_id,
            creative.group_title AS cr_group_title,
            creative.id AS cr_id,
            exchange,
            SUM(gross_spend_usd) AS gross_spend_usd,
            SUM(impressions) AS impressions,
            SUM(clicks) AS clicks,
            SUM(installs) AS installs,
            SUM(installs_ct) AS ct_installs,
            SUM(skan_installs) AS skan_installs,
          FROM `moloco-ae-view.athena.fact_dsp_creative`
          WHERE ((( date_utc ) >= ((DATE_ADD(CURRENT_DATE('UTC'), INTERVAL -6 DAY))) AND ( date_utc ) < ((DATE_ADD(DATE_ADD(CURRENT_DATE('UTC'), INTERVAL -6 DAY), INTERVAL 7 DAY)))))
            AND 1=1 -- no filter on 'fact_dsp_custom_event_creative.selected_platform'

            AND (advertiser_id = 't52aeGmi7ov3wppl')
            AND 1=1 -- no filter on 'fact_dsp_custom_event_creative.selected_campaign'

          GROUP BY ALL
        )

      SELECT
        fact.ad_group_id,
        fact.ad_group_title,
        fact.advertiser_id,
        fact.advertiser_title,
        fact.app_market_bundle,
        fact.campaign_id,
        fact.campaign_title,
        fact.country,
        fact.cr_format,
        fact.cr_group_id,
        fact.cr_group_title,
        fact.cr_id,
        fact.currency,
        fact.date_utc,
        fact.exchange,
        fact.is_lat,
        fact.mmp_bundle_id,
        fact.os,
        fact.platform_id,
        fact.product_title,
        DATE_TRUNC(fact.date_utc, WEEK (MONDAY)) AS `week`,
        fact.gross_spend_usd,
        fact.impressions,
        fact.clicks,
        fact.installs,
        fact.ct_installs,
        fact.skan_installs,
        cohort_union.actions_d1,
        cohort_union.users_d1,
        cohort_union.revenue_d1,
        cohort_union.retained_users_d1,
        cohort_union.actions_d7,
        cohort_union.users_d7,
        cohort_union.revenue_d7,
        cohort_union.retained_users_d7,
        cohort_union.actions_d30,
        cohort_union.users_d30,
        cohort_union.revenue_d30,
        cohort_union.retained_users_d30,
        cohort_union.retained_users_w1,
        cohort_union.retained_users_w2,
        cohort_union.retained_users_w3,
        cohort_union.retained_users_w4
      FROM fact
      LEFT JOIN cohort_union
        USING (date_utc, platform_id, advertiser_id, campaign_id, country, os, ad_group_id, cr_group_id, cr_format, cr_id, exchange, is_lat))
SELECT
    (fact_dsp_custom_event_creative.date_utc ) AS fact_dsp_custom_event_creative_date_utc,
    COALESCE(SUM(fact_dsp_custom_event_creative.gross_spend_usd ), 0) AS fact_dsp_custom_event_creative_gross_spend_usd,
            COALESCE(SUM(fact_dsp_custom_event_creative.revenue_d7 ), 0) / NULLIF(COALESCE(SUM(fact_dsp_custom_event_creative.gross_spend_usd ), 0), 0) * 100 AS fact_dsp_custom_event_creative_d7_roas,
    COALESCE(SUM(fact_dsp_custom_event_creative.revenue_d7 ), 0) AS fact_dsp_custom_event_creative_revenue_d7
FROM fact_dsp_custom_event_creative
WHERE (fact_dsp_custom_event_creative.country ) = 'USA'
GROUP BY
    1
ORDER BY
    1
LIMIT 500