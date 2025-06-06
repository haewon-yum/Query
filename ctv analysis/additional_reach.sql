### Additional Reach Calculation ###

DECLARE mobile_imp_table STRING DEFAULT "`moloco-ods.haewon.ctv_PMG_Fanatics Sportsbook_mobile_imp_250311_250407`";
DECLARE ctv_imp_table STRING DEFAULT "`moloco-ods.haewon.ctv_PMG_Fanatics Sportsbook_ctv_imp_250311_250407`";

EXECUTE IMMEDIATE FORMAT("""
  WITH mobile_imp AS (
    SELECT * FROM %s
  ), 
  mobile_imp_cr AS (
    SELECT * FROM %s
    WHERE cr_format <> 'ib'
  ),
  ctv_imp AS (
    SELECT DISTINCT ip, ctv_imp, ctv_spend FROM %s
  ),
  full_joined AS (
    SELECT 
      m.ip AS ip_mobile,
      m.cr_format,
      c.ip AS ip_ctv
    FROM mobile_imp m 
    FULL OUTER JOIN ctv_imp c 
    USING(ip)
  ),
  full_joined_cr AS (
    SELECT 
      m.ip AS ip_mobile,
      m.cr_format,
      c.ip AS ip_ctv
    FROM mobile_imp_cr m 
    FULL OUTER JOIN ctv_imp c 
    USING(ip)
  ),
  summary AS (
    SELECT 
      ROUND(only_mobile / (only_mobile + only_ctv + in_both) * 100, 1) AS only_mobile_perc,
      ROUND(only_ctv / (only_mobile + only_ctv + in_both) * 100, 1) AS only_ctv_perc,
      ROUND(in_both / (only_mobile + only_ctv + in_both) * 100, 1) AS in_both_perc,
      only_mobile,
      only_ctv, 
      in_both
    FROM (
      SELECT
        COUNTIF(ip_mobile IS NOT NULL AND ip_ctv IS NULL) AS only_mobile,
        COUNTIF(ip_mobile IS NULL AND ip_ctv IS NOT NULL) AS only_ctv,
        COUNTIF(ip_mobile IS NOT NULL AND ip_ctv IS NOT NULL) AS in_both
      FROM full_joined
    )
  ),
  summary_cr AS (
    SELECT 
      ROUND(only_mobile / (only_mobile + only_ctv + in_both) * 100, 1) AS only_mobile_perc_wo_ib,
      ROUND(only_ctv / (only_mobile + only_ctv + in_both) * 100, 1) AS only_ctv_perc_wo_ib,
      ROUND(in_both / (only_mobile + only_ctv + in_both) * 100, 1) AS in_both_perc_wo_ib, 
      only_mobile AS only_mobile_wo_ib,
      only_ctv AS only_ctv_wo_ib,
      in_both AS in_both_wo_ib
    FROM (
      SELECT
        COUNTIF(ip_mobile IS NOT NULL AND ip_ctv IS NULL) AS only_mobile,
        COUNTIF(ip_mobile IS NULL AND ip_ctv IS NOT NULL) AS only_ctv,
        COUNTIF(ip_mobile IS NOT NULL AND ip_ctv IS NOT NULL) AS in_both
      FROM full_joined_cr
    )
  )
  SELECT 
    only_mobile_perc,
    only_ctv_perc,
    in_both_perc,
    only_mobile_perc_wo_ib,
    only_ctv_perc_wo_ib,
    in_both_perc_wo_ib,
    only_mobile,
    only_ctv,
    in_both,
    only_mobile_wo_ib,
    only_ctv_wo_ib,
    in_both_wo_ib
  FROM summary, summary_cr
""",
mobile_imp_table, mobile_imp_table, ctv_imp_table
);


  

### additional reach for the selected platform who actively ran CTV campaigns ###

DECLARE platform STRING DEFAULT 'PLAYTIKA';
DECLARE unified_app_name STRING DEFAULT 'WSOP';
DECLARE start_date DATE DEFAULT '2024-07-01';
DECLARE end_date DATE DEFAULT '2025-04-15';

DECLARE full_table_name_mobile STRING;

-- 날짜를 YYMMDD 형식으로 포맷하고 테이블명 만들기
SET full_table_name_mobile = FORMAT(
  "`moloco-ods.haewon.ctv_%s_%s_mobile_imp_%s_%s`",
  platform,
  unified_app_name,
  FORMAT_DATE('%y%m%d', start_date),
  FORMAT_DATE('%y%m%d', end_date)
);

SELECT full_table_name_mobile;

EXECUTE IMMEDIATE FORMAT("""
    WITH 
    t_advertiser AS (
        SELECT
        *,
        COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), '%s') AS last_effective_date_local,
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
            DATE_DIFF('%s', effective_date_local, DAY) >=0 ) 
        ),

    t_ctv_target AS (
    SELECT
        DISTINCT 
            campaign_id, 
            target_bundle
    FROM (
        SELECT
            campaign_id,
            ARRAY_CONCAT_AGG([COALESCE(JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.ANDROID"), ''), 
                                COALESCE( JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.IOS"), '')]) AS target_bundles
        FROM
        `focal-elf-631.standard_digest.campaign_digest`
        WHERE
            campaign_os = 'CTV'
            -- AND DATE(timestamp) BETWEEN start_date AND end_date
            AND platform = '%s'
        GROUP BY ALL
    ), UNNEST(target_bundles) AS target_bundle
    ),
    t_mobile_imp AS (
        SELECT
            app.app_name,
            app.unified_app_name,
            api.product.app.tracking_bundle,
            app.is_gaming,
            app.genre,
            app.sub_genre,
            DATE(t_imp.timestamp) AS utc_date,
            DATE(t_imp.timestamp, t_advertiser.advertiser_timezone) AS local_date,
            req.device.ip,
            api.creative.cr_format,
            t_advertiser.platform_serving_cost_percent,
            t_advertiser.platform_markup_percent,
            SUM(imp.win_price_adv.amount_micro / 1e6) win_price,
            COUNT(1) AS imp_count
        FROM
        `focal-elf-631.prod_stream_view.imp` AS t_imp
            JOIN
            t_advertiser
            ON
            t_imp.platform_id=t_advertiser.platform_id
            AND t_imp.advertiser_id=t_advertiser.advertiser_id
            AND t_advertiser.effective_date_local<=DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)
            AND DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)<=t_advertiser.last_effective_date_local
            JOIN
            `moloco-ae-view.athena.dim1_product`
            ON api.product.id = product_id
        WHERE
            DATE(timestamp) BETWEEN '%s' AND '%s'
            AND req.device.ip IS NOT NULL
            AND req.device.ip != ''
            AND req.device.geo.country = 'USA'
            AND api.product.app.tracking_bundle IN (
                SELECT
                    target_bundle
                FROM
                    t_ctv_target
                )
            AND app.unified_app_name = '%s'
        GROUP BY
        ALL 
        ),
    t_mobile_imp_spend AS (
        SELECT
            app_name,
            unified_app_name,
            is_gaming,
            genre,
            sub_genre,
            tracking_bundle,
            ip,
            cr_format,
            SAFE_CAST(SUM(win_price * (1 + platform_serving_cost_percent/100) * (1 + platform_markup_percent/100)) AS FLOAT64) AS spend,
            SUM(imp_count) AS imp_count
        FROM
            t_mobile_imp
        GROUP BY
            ALL )
    SELECT
        '%s' AS `start_date`,
        '%s' AS `end_date`,
        'mobile' AS imp_src,
        unified_app_name,
        is_gaming,
        genre,
        sub_genre,
        tracking_bundle,
        ip,
        cr_format,
        COALESCE(t_mobile_imp_spend.imp_count, 0) AS mobile_imp,
        COALESCE(t_mobile_imp_spend.spend, 0) AS mobile_spend
    FROM
        t_mobile_imp_spend

""", full_table_name_mobile, 
    FORMAT_DATE('%Y-%m-%d', end_date),
    FORMAT_DATE('%Y-%m-%d', end_date),
    platform,
    FORMAT_DATE('%Y-%m-%d', start_date),  -- 여기서도 String 변환 필요
    FORMAT_DATE('%Y-%m-%d', end_date),
    unified_app_name,
    FORMAT_DATE('%Y-%m-%d', start_date),  -- 여기서도 String 변환 필요
    FORMAT_DATE('%Y-%m-%d', end_date))
-- CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_scorewarrior_totalbattle_mobile_imp` AS
-- CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_playtika_wsop_mobile_imp` AS



### CTV IMP ###

DECLARE platform STRING DEFAULT 'PLAYTIKA';
DECLARE unified_app_name STRING DEFAULT 'WSOP';
DECLARE start_date DATE DEFAULT '2024-07-01';
DECLARE end_date DATE DEFAULT '2025-04-15';

DECLARE full_table_name_mobile STRING;

-- 날짜를 YYMMDD 형식으로 포맷하고 테이블명 만들기
SET full_table_name_mobile = FORMAT(
  "`moloco-ods.haewon.ctv_%s_%s_ctv_imp_%s_%s`",
  platform,
  unified_app_name,
  FORMAT_DATE('%y%m%d', start_date),
  FORMAT_DATE('%y%m%d', end_date)
);

SELECT full_table_name_mobile;


EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE %s AS

    WITH 
    t_advertiser AS (
        SELECT
        *,
        COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), '%s') AS last_effective_date_local,
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
            DATE_DIFF('%s', effective_date_local, DAY) >=0 ) 
        ),

    t_ctv_target AS (
    SELECT
        DISTINCT 
            campaign_id, 
            ANY_VALUE(unified_app_name) AS unified_app_name,
            ARRAY_AGG(target_bundle) AS target_bundles
    FROM (
        SELECT
            campaign_id,
            ARRAY_CONCAT_AGG([COALESCE(JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.ANDROID"), ''), 
                                COALESCE( JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.IOS"), '')]) AS target_bundles
        FROM
        `focal-elf-631.standard_digest.campaign_digest`
        WHERE
            campaign_os = 'CTV'
            -- AND DATE(timestamp) BETWEEN start_date AND end_date
            AND platform = '%s'
        GROUP BY ALL
    ), UNNEST(target_bundles) AS target_bundle
        LEFT JOIN (
            SELECT
                ANY_VALUE(app.unified_app_name) AS unified_app_name,
                mmp_bundle_id,
            FROM
                `moloco-ae-view.athena.dim1_product`
            GROUP BY
                ALL )
            ON
            target_bundle = mmp_bundle_id
        GROUP BY ALL
    ),
    t_ctv_imp AS (
        SELECT
            unified_app_name,
            target_bundles,
            DATE(t_imp.timestamp) AS utc_date,
            DATE(t_imp.timestamp, t_advertiser.advertiser_timezone) AS local_date,
            req.device.ip,
            api.creative.cr_format,
            t_advertiser.platform_serving_cost_percent,
            t_advertiser.platform_markup_percent,
            SUM(imp.win_price_adv.amount_micro / 1e6) win_price,
            COUNT(1) AS imp_count
        FROM
            `focal-elf-631.prod_stream_view.imp` AS t_imp
        JOIN
            t_ctv_target
            ON
            api.campaign.id = t_ctv_target.campaign_id
        JOIN
            t_advertiser
            ON
            t_imp.platform_id=t_advertiser.platform_id
            AND t_imp.advertiser_id=t_advertiser.advertiser_id
            AND t_advertiser.effective_date_local<=DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)
            AND DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)<=t_advertiser.last_effective_date_local
        WHERE
            DATE(timestamp) BETWEEN '%s' AND '%s'
            AND req.device.ip IS NOT NULL
            AND req.device.ip != ''
            AND req.device.geo.country = 'USA'
            AND unified_app_name = '%s'
        GROUP BY
        ALL ),
        t_ctv_imp_spend AS (
        SELECT
            unified_app_name,
            target_bundles,
            ip,
            cr_format,
            SAFE_CAST(SUM(win_price * (1 + platform_serving_cost_percent/100) * (1 + platform_markup_percent/100)) AS FLOAT64) AS spend,
            SUM(imp_count) AS imp_count
        FROM
            t_ctv_imp
        GROUP BY
        ALL )
    SELECT
        '%s' AS `start_date`,
        '%s' AS `end_date`,
        'ctv' AS imp_src,
        unified_app_name,
        target_bundles,
        ip,
        cr_format,
        COALESCE(t_ctv_imp_spend.imp_count, 0) AS ctv_imp,
        COALESCE(t_ctv_imp_spend.spend, 0) AS ctv_spend
    FROM
        t_ctv_imp_spend
""", full_table_name_mobile, 
    FORMAT_DATE('%Y-%m-%d', end_date),
    FORMAT_DATE('%Y-%m-%d', end_date),
    platform,
    FORMAT_DATE('%Y-%m-%d', start_date),  -- 여기서도 String 변환 필요
    FORMAT_DATE('%Y-%m-%d', end_date),
    unified_app_name,
    FORMAT_DATE('%Y-%m-%d', start_date),  -- 여기서도 String 변환 필요
    FORMAT_DATE('%Y-%m-%d', end_date))








### 민기님 레퍼런스 ###

DECLARE
  start_date date DEFAULT '2024-09-01';
DECLARE
  end_date date DEFAULT '2024-12-31';
CREATE OR REPLACE TABLE
  `moloco-ods.minki.odsb_10682_imp_mobile` AS (
  WITH
    t_advertiser AS (
    SELECT
      *,
      COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), end_date) AS last_effective_date_local,
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
        DATE_DIFF(end_date, effective_date_local, DAY) >=0 ) ),
    t_ctv_target AS (
    SELECT
      DISTINCT campaign_id,
      target_bundle
    FROM (
      SELECT
        campaign_id,
        ARRAY_CONCAT_AGG([COALESCE(JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.ANDROID"), ''), 
                          COALESCE( JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.IOS"), '')]) AS target_bundles
      FROM
        `focal-elf-631.standard_digest.campaign_digest`
      WHERE
        campaign_os = 'CTV'
      GROUP BY campaign_id),
      UNNEST(target_bundles) AS target_bundle ),
    t_mobile_imp AS (
    SELECT
      app.app_name,
      app.unified_app_name,
      api.product.app.tracking_bundle,
      app.is_gaming,
      app.genre,
      app.sub_genre,
      DATE(t_imp.timestamp, t_advertiser.advertiser_timezone) AS local_date,
      req.device.ip,
      t_advertiser.platform_serving_cost_percent,
      t_advertiser.platform_markup_percent,
      SUM(imp.win_price_adv.amount_micro / 1e6) win_price,
      COUNT(1) AS imp_count
    FROM
      `focal-elf-631.prod_stream_view.imp` AS t_imp
    JOIN
      t_advertiser
    ON
      t_imp.platform_id=t_advertiser.platform_id
      AND t_imp.advertiser_id=t_advertiser.advertiser_id
      AND t_advertiser.effective_date_local<=DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)
      AND DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)<=t_advertiser.last_effective_date_local
    JOIN
      `moloco-ae-view.athena.dim1_product`
    ON api.product.id = product_id
    WHERE
      DATE(timestamp) BETWEEN start_date
      AND end_date
      AND req.device.ip IS NOT NULL
      AND req.device.ip != ''
      AND req.device.geo.country = 'USA'
      AND api.product.app.tracking_bundle IN (
      SELECT
        target_bundle
      FROM
        t_ctv_target)
    GROUP BY
      ALL ),
    t_mobile_imp_spend AS (
    SELECT
      app_name,
      unified_app_name,
      is_gaming,
      genre,
      sub_genre,
      tracking_bundle,
      ip,
      SAFE_CAST(SUM(win_price * (1 + platform_serving_cost_percent/100) * (1 + platform_markup_percent/100)) AS FLOAT64) AS spend,
      SUM(imp_count) AS imp_count
    FROM
      t_mobile_imp
    GROUP BY
      ALL )
  SELECT
    unified_app_name,
    is_gaming,
    genre,
    sub_genre,
    tracking_bundle,
    ip,
    COALESCE(t_mobile_imp_spend.imp_count, 0) AS mobile_imp,
    COALESCE(t_mobile_imp_spend.spend, 0) AS mobile_spend,
  FROM
    t_mobile_imp_spend)

DECLARE
  start_date date DEFAULT '2024-09-01';
DECLARE
  end_date date DEFAULT '2024-12-31';
CREATE OR REPLACE TABLE
  `moloco-ods.minki.odsb_10682_imp_ctv` AS (
  WITH
    t_advertiser AS (
    SELECT
      *,
      COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), end_date) AS last_effective_date_local,
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
        DATE_DIFF(end_date, effective_date_local, DAY) >=0 ) ),
    t_ctv_target AS (
    SELECT
      campaign_id,
      ANY_VALUE(unified_app_name) AS unified_app_name,
      ARRAY_AGG(target_bundle) AS target_bundles
    FROM (
      SELECT
        campaign_id,
        ARRAY_CONCAT_AGG([COALESCE(JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.ANDROID"), ''), COALESCE( JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.IOS"), '')]) AS target_bundles
      FROM
        `focal-elf-631.standard_digest.campaign_digest`
      WHERE
        campaign_os = 'CTV'
      GROUP BY
        ALL),
      UNNEST(target_bundles) target_bundle
    LEFT JOIN (
      SELECT
        ANY_VALUE(app.unified_app_name) AS unified_app_name,
        mmp_bundle_id,
      FROM
        `moloco-ae-view.athena.dim1_product`
      GROUP BY
        ALL )
    ON
      target_bundle = mmp_bundle_id
    GROUP BY
      ALL),
    t_ctv_imp AS (
    SELECT
      unified_app_name,
      target_bundles,
      DATE(t_imp.timestamp, t_advertiser.advertiser_timezone) AS local_date,
      req.device.ip,
      t_advertiser.platform_serving_cost_percent,
      t_advertiser.platform_markup_percent,
      SUM(imp.win_price_adv.amount_micro / 1e6) win_price,
      COUNT(1) AS imp_count
    FROM
      `focal-elf-631.prod_stream_view.imp` AS t_imp
    JOIN
      t_ctv_target
    ON
      api.campaign.id = t_ctv_target.campaign_id
    JOIN
      t_advertiser
    ON
      t_imp.platform_id=t_advertiser.platform_id
      AND t_imp.advertiser_id=t_advertiser.advertiser_id
      AND t_advertiser.effective_date_local<=DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)
      AND DATE(t_imp.timestamp, t_advertiser.advertiser_timezone)<=t_advertiser.last_effective_date_local
    WHERE
      DATE(timestamp) BETWEEN start_date
      AND end_date
      AND req.device.ip IS NOT NULL
      AND req.device.ip != ''
      AND req.device.geo.country = 'USA'
    GROUP BY
      ALL ),
    t_ctv_imp_spend AS (
    SELECT
      unified_app_name,
      target_bundles,
      ip,
      SAFE_CAST(SUM(win_price * (1 + platform_serving_cost_percent/100) * (1 + platform_markup_percent/100)) AS FLOAT64) AS spend,
      SUM(imp_count) AS imp_count
    FROM
      t_ctv_imp
    GROUP BY
      ALL )
  SELECT
    unified_app_name,
    target_bundles,
    ip,
    COALESCE(t_ctv_imp_spend.imp_count, 0) AS ctv_imp,
    COALESCE(t_ctv_imp_spend.spend, 0) AS ctv_spend,
  FROM
    t_ctv_imp_spend)


CREATE OR REPLACE TABLE
  `moloco-ods.minki.odsb_10682_imp` AS (
  WITH
    t_mobile AS (
    SELECT
      unified_app_name,
      ip,
      ANY_VALUE(is_gaming) AS is_gaming,
      ANY_VALUE(genre) AS genre,
      ANY_VALUE(sub_genre) AS sub_genre,
      SUM(mobile_imp) AS mobile_imp,
      SUM(mobile_spend) AS mobile_spend
    FROM
      `moloco-ods.minki.odsb_10682_imp_mobile`
    GROUP BY
      ALL ),
    t_ctv AS (
    SELECT
      unified_app_name,
      ip,
      SUM(ctv_imp) AS ctv_imp,
      SUM(ctv_spend) AS ctv_spend
    FROM
      `moloco-ods.minki.odsb_10682_imp_ctv`
    GROUP BY
      ALL )
  SELECT
    unified_app_name,
    ip,
    COALESCE(ctv_imp, 0) ctv_imp,
    COALESCE(mobile_imp, 0) mobile_imp,
    COALESCE(ctv_spend, 0) ctv_spend,
    COALESCE(mobile_spend, 0) mobile_spend,
  FROM
    t_ctv
  FULL JOIN
    t_mobile
  USING
    (unified_app_name,
      ip))