/* Dx ARPPU (based on PB)
    Reference: https://colab.research.google.com/drive/1_HNTDMY2nmOXdDOw1QRXXksCuwJ7f28J#scrollTo=kQlNhHz6BAQG
*/ 


    #THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

    DECLARE start_date DEFAULT DATE('{start_date}');
    DECLARE end_date DEFAULT DATE('{end_date}');


    CREATE OR REPLACE TABLE `{table_dx_ltv}` AS (
      WITH
        t_app AS (
          SELECT
              product.app_market_bundle,
              advertiser.mmp_bundle_id,
              # campaign.os,
              SUM(gross_spend_usd) AS revenue
          FROM
            `moloco-ae-view.athena.fact_dsp_core`
          WHERE
            date_utc BETWEEN start_date AND end_date
            AND product.app_market_bundle IN ({str_target_titles})
            AND advertiser_id = '{advertiser_id}'
            AND campaign.goal LIKE '%UA%'
          GROUP BY 1, 2
          HAVING revenue > 0
        ),
      t_rev AS (
        SELECT
          CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
            WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
            ELSE NULL
          END AS user_id,
          device.os,
          device.country,
          app_market_bundle,
          mmp_bundle_id,
          TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
          event.revenue_usd.amount AS revenue,
          CASE WHEN event.name IN ('client_ad_revenue', '__ADMON_USER_LEVEL_REVENUE__', 'af_ad_view', 'af_ad_revenue') THEN event.revenue_usd.amount ELSE 0 END AS revenue_iaa,
          CASE WHEN event.name NOT IN ('client_ad_revenue', '__ADMON_USER_LEVEL_REVENUE__', 'af_ad_view', 'af_ad_revenue') THEN event.revenue_usd.amount ELSE 0 END AS revenue_iap,
        FROM
          `focal-elf-631.prod_stream_view.pb`
        JOIN
          t_app
        ON
          app.bundle = mmp_bundle_id
        WHERE
          DATE(TIMESTAMP) >= start_date
          AND DATE(event.install_at) BETWEEN start_date AND end_date
          AND DATE(event.event_at) >= start_date
          AND event.revenue_usd.amount > 0
          AND event.revenue_usd.amount < 10000
          AND (LOWER(event.name) LIKE '%purchase%'
            OR LOWER(event.name) LIKE '%iap'
            OR LOWER(event.name) LIKE '%revenue%'
            OR LOWER(event.name) LIKE '%_ad_%'
            OR LOWER(event.name) IN ('af_top_up', 'pay', '0ofw9', 'h9bsc')
            OR LOWER(event.name) LIKE '%deposit%')
          AND LOWER(event.name) NOT LIKE '%ltv%'
          AND event.name NOT IN ('Purcahse=3', 'BOARD_3')
        )
      ,

      t_user_day_revenue AS (
          SELECT
          user_id,
          os,
          app_market_bundle,
          mmp_bundle_id,
          country,
          FLOOR(diff_hour / 24) + 1 AS diff_day,
          SUM(revenue) AS revenue,
          FROM
              t_rev
          WHERE
              user_id IS NOT NULL
              AND diff_hour < 30 * 24
          GROUP BY
              user_id, os, app_market_bundle, mmp_bundle_id, region, country, diff_day
      ),

      t_user_summary AS (
          SELECT
              user_id,
              MIN(diff_hour) / 24 AS first_purchase_day,
              MAX(diff_hour) / 24 AS last_purchase_day,
              COUNT(1) AS purchase_count,
              ARRAY_AGG(revenue ORDER BY diff_hour)[OFFSET(0)] AS first_purchase_amount
          FROM
              t_rev
          WHERE
              user_id IS NOT NULL
          GROUP BY
              user_id
    )

      SELECT
          d.user_id,
          d.diff_day,
          d.revenue,
          s.first_purchase_day,
          s.last_purchase_day,
          s.purchase_count,
          s.first_purchase_amount,
          d.os,
          d.country,
          d.app_market_bundle,
          d.mmp_bundle_id
      FROM
          t_user_day_revenue d
      LEFT JOIN
          t_user_summary s
      ON
          d.user_id = s.user_id

    )


/* 
    Dx ARPI (based on PB)
*/

    DECLARE start_date DEFAULT DATE('{start_date}');
    DECLARE end_date DEFAULT DATE('{end_date}');


      WITH
        t_app AS (
          SELECT
              product.app_market_bundle,
              advertiser.mmp_bundle_id,
              # campaign.os,
              SUM(gross_spend_usd) AS revenue
          FROM
            `moloco-ae-view.athena.fact_dsp_core`
          WHERE
            date_utc BETWEEN start_date AND end_date
            AND product.app_market_bundle IN ({str_target_titles})
            AND advertiser_id = '{advertiser_id}'
            AND campaign.goal LIKE '%UA%'
          GROUP BY 1, 2
          HAVING revenue > 0
        ),

      t_install AS (
        SELECT
            CASE    
                WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
                WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
                WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
                ELSE NULL
            END AS user_id,
            device.os,
            device.country,
            app_market_bundle,
            mmp_bundle_id,
            timestamp AS install_at
        FROM 
            `focal-elf-631.prod_stream_view.pb`
            JOIN t_app
            ON app.bundle = mmp_bundle_id
        WHERE 
            DATE(TIMESTAMP) BETWEEN start_date AND end_date
            AND LOWER(event.name) = 'install'                        
      )

      t_rev AS (
        SELECT
          CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
            WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
            ELSE NULL
          END AS user_id,
          device.os,
          device.country,
          app_market_bundle,
          mmp_bundle_id,
          TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
          event.revenue_usd.amount AS revenue
        FROM
          `focal-elf-631.prod_stream_view.pb`
        JOIN
          t_app
        ON
          app.bundle = mmp_bundle_id
        WHERE
          DATE(TIMESTAMP) >= start_date
          AND DATE(event.install_at) BETWEEN start_date AND end_date
          AND DATE(event.event_at) >= start_date
          AND event.revenue_usd.amount > 0
          AND event.revenue_usd.amount < 10000
          AND (LOWER(event.name) LIKE '%purchase%'
            OR LOWER(event.name) LIKE '%iap'
            OR LOWER(event.name) LIKE '%revenue%'
            OR LOWER(event.name) LIKE '%_ad_%'
            OR LOWER(event.name) IN ('af_top_up', 'pay', '0ofw9', 'h9bsc')
            OR LOWER(event.name) LIKE '%deposit%')
          AND LOWER(event.name) NOT LIKE '%ltv%'
          AND event.name NOT IN ('Purcahse=3', 'BOARD_3')
        )
      ,

      joined AS (
        SELECT
          i.user_id AS install_user_id,
          i.os,
          i.country,
          i.app_market_bundle,
          i.mmp_bundle_id,
          i.install_at,
          r.user_id AS rev_user_id,
          DIV(r.diff_hour, 24) AS diff_day,
          r.revenue
        FROM 
          t_install i
        LEFT JOIN 
          t_rev r
        ON 
          i.user_id = r.user_id
          AND i.app_market_bundle = r.app_market_bundle        
      ),

      diff_intervals AS (
        SELECT day
        FROM UNNEST(GENERATE_ARRAY(0, 180)) AS day
      ),

      country_country_day_metrics AS (
        SELECT  
            d.day AS diff_day_th,
            j.app_market_bundle,
            j.country,
            COUNT(DISTINCT j.install_user_id) AS install_user_count,
            COUNT(DISTINCT CASE WHEN j.rev_user_id IS NOT NULL AND j.diff_day <= d.day THEN j.rev_user_id END) AS purchase_users,
            SUM(CASE WHEN j.rev_user_id IS NOT NULL AND j.diff_day <= d.day THEN j.revenue ELSE 0 END) AS cumulative_revenue
        FROM diff_intervals d 
        CROSS JOIN(
            SELECT DISTINCT app_market_bundle,country FROM joined
        )bc
        LEFT JOIN joined j
            ON j.app_market_bundle = bc.app_market_bundle
            AND j.country = bc.country
        GROUP BY 1, 2, 3
      )
      
      CREATE OR REPLACE TABLE `{table_dx_arpi}` AS 
      SELECT *
      FROM country_country_day_metrics
      ORDER BY app_market_bundle, country, diff_day_th;
