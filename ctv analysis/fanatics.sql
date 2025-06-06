## USER COHORT : Users with both mobile and CTV impressions before install ### -- DEPRECATED

  DECLARE start_date DATE DEFAULT  '2025-03-25';
  DECLARE end_date DATE DEFAULT '2025-03-25';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];


  WITH mobile_campaigns AS (

    SELECT 
      campaign_id,
      SUM(gross_spend_usd) AS gross_spend
    FROM `moloco-ae-view.athena.fact_dsp_core`
    WHERE date_utc BETWEEN start_date AND end_date
      AND product.app_market_bundle IN UNNEST(store_bundles)
    GROUP BY 1
    HAVING gross_spend > 0
    ORDER BY 2 DESC


  ),

  install AS (   

      # (from colab) https://colab.research.google.com/drive/1D8_CA2lJX-ifrFtolF8-3rQ2iePh5-1J#scrollTo=_eCTxUGLyFdP
      # sum of the total install = 176931
      # if excluding top 500 ips in terms of the number of installs per ip = 86431

      SELECT
          req.device.os AS req_os,
          bid.maid, # moloco user id
          CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifv) THEN "ifv:" || cv.pb.device.ifv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifa) THEN "ifa:" || cv.pb.device.ifa
            WHEN `moloco-ml.lat_utils.is_userid_truly_available` (cv.pb.mmp.device_id) THEN 'device:' || cv.pb.mmp.device_id
            ELSE NULL
          END AS user_id, # external user id
          bid.mtid,
          cv.pb.device.ip, 
          timestamp AS install_at,
          cv.pb.app.bundle AS install_bundle
      FROM `focal-elf-631.prod_stream_view.cv`
      WHERE 1=1
          AND LOWER(cv.pb.event.name) = 'install'
          AND DATE(timestamp) BETWEEN start_date AND end_date
          AND cv.pb.app.bundle IN UNNEST(mmp_bundles)
          AND req.device.os IN ('CTV', 'ANDROID', 'IOS')
          AND req.device.geo.country = 'USA'
  )

  , mobile_imp AS (

      SELECT
          bid.maid,
          bid.mtid AS mobile_mtid,
          req.device.ip,
          timestamp AS mobile_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE 1=1
          AND api.campaign.id IN (SELECT campaign_id FROM mobile_campaigns)
          AND DATE(timestamp) BETWEEN start_date AND end_date

  ),

  ctv_imp AS (
    SELECT
        bid.maid,
        bid.mtid AS ctv_mtid,
        req.device.ip,
        timestamp AS ctv_imp_at
    FROM `focal-elf-631.prod_stream_view.imp`
    WHERE 1=1
        AND api.campaign.id IN UNNEST(ctv_campaign_id)
        AND DATE(timestamp) BETWEEN start_date AND end_date 
  ),

  shared_ip AS (
    # TOP 500 high install IPs (will be excluded from the further analysis) #
      SELECT 
          ip,
          SUM(imp_cnt) AS imp_cnt,
          SUM(win_price_sum) AS win_price_sum,
          SUM(ass_install) AS ass_install,
          SUM(att_install) AS att_install
      FROM `moloco-ods.kyungrin.ctv_perf_by_ip` 
      WHERE utc_date BETWEEN '2025-03-07' AND '2025-04-11'
          AND campaign_id IN UNNEST(ctv_campaign_id)
      GROUP BY 1
      ORDER BY att_install DESC
      LIMIT 500
  ),

  summary AS (

      # the number of the distinct maid = 72230 (excluding shared_ip)
      # without excluding, distinct maid = 76495??

    SELECT
      install.req_os, # install from a mobile device (either Android or iOS)
      install.maid AS install_maid,
      install.mtid AS install_mtid,
      install.user_id AS install_user_id, # idfa
      install.install_at, 
      install.install_bundle,
      install.ip AS install_ip,
      IF(shared_ip.ip IS NOT NULL, 'shared_ip', NULL) AS is_shared_ip,
      mobile_imp.maid AS mobile_maid,
      mobile_imp.mobile_mtid,
      mobile_imp.ip AS mobile_imp_ip,
      mobile_imp.mobile_imp_at,
      ctv_imp.maid AS ctv_maid,
      ctv_imp.ctv_mtid,
      ctv_imp.ip AS ctv_imp_ip,
      ctv_imp.ctv_imp_at 
    FROM install
        LEFT JOIN mobile_imp ON install.ip = mobile_imp.ip
        LEFT JOIN ctv_imp ON install.ip = ctv_imp.ip
        LEFT JOIN shared_ip ON install.ip = shared_ip.ip
    WHERE 
        (mobile_imp.mobile_imp_at < install_at
        OR ctv_imp.ctv_imp_at < install_at)
      --   AND install.ip NOT IN (SELECT ip FROM shared_ip)
  ),

  cnt_ctv_only AS (
    # can a single mtid have multiple install_at timestamps?
    SELECT 
      COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_ctv_only_all_maid_install_at, 
      COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_ctv_only_all_mtid_install_at, #31537
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_only_all_mtid, #19138
      COUNT(DISTINCT CONCAT(install_maid)) AS cnt_ctv_only_all_maid
    FROM summary
    WHERE 
      mobile_imp_at IS NULL 
      AND ctv_imp_at IS NOT NULL
  ),

  cnt_mobile_only AS (
    SELECT 
      COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_mobile_only_all_maid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_mobile_only_all_mtid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_mobile_only_all_mtid,
      COUNT(DISTINCT CONCAT(install_maid)) AS cnt_mobile_only_all_maid,
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NULL
  ), 

  cnt_ctv_mobile AS (
    SELECT 
      COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_ctv_mobile_only_all_maid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_ctv_mobile_only_all_mtid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_mobile_only_all_mtid,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_mobile_only_all_maid,
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NOT NULL
      AND ctv_imp_at < install_at
      AND mobile_imp_at < install_at
  ) ,

  cnt_ctv_only_adj AS (
    SELECT 
      COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_ctv_only_all_maid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_ctv_only_all_mtid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_only_all_mtid,
      COUNT(DISTINCT CONCAT(install_maid)) AS cnt_ctv_only_all_maid
    FROM summary
    WHERE 
      (mobile_imp_at IS NULL 
      AND ctv_imp_at IS NOT NULL)
      AND ctv_imp_ip NOT IN (Select ip FROM shared_ip)
  ),

  cnt_mobile_only_adj AS (
    SELECT 
      COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_mobile_only_all_maid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_mobile_only_all_mtid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_mobile_only_all_mtid,
      COUNT(DISTINCT CONCAT(install_maid)) AS cnt_mobile_only_all_maid,
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NULL
  ), 

  cnt_ctv_mobile_adj AS (
    SELECT 
      COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_ctv_mobile_only_all_maid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_ctv_mobile_only_all_mtid_install_at,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_mobile_only_all_mtid,
      COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_mobile_only_all_maid,
    FROM summary
    WHERE 
      (mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NOT NULL)
      AND ctv_imp_ip NOT IN (Select ip FROM shared_ip)
      AND ctv_imp_at < install_at
      AND mobile_imp_at < install_at
  ),

  -- SELECT *
  -- FROM cnt_ctv_only, cnt_mobile_only, cnt_ctv_mobile, cnt_ctv_only_adj, cnt_mobile_only_adj, cnt_ctv_mobile_adj

  mobile_ctv AS (

      ## one maid could have multiple mobile imps or ctv imps ## 

      SELECT 
          install_maid,
          install_ip,
          install_at,
          install_bundle,
          mobile_imp_ip,
          mobile_imp_at,
          ctv_maid,
          ctv_imp_ip,
          ctv_imp_at
      FROM summary 
      WHERE 1=1 
          AND mobile_imp_at IS NOT  NULL
          AND ctv_imp_at IS NOT NULL
          AND mobile_imp_at < install_at
          AND ctv_imp_at < install_at
  ), 

  mobile_only AS (

      ## one maid could have multiple mobile imps ## 

      SELECT 
          install_maid,
          install_ip,
          install_at,
          install_bundle,
          mobile_imp_ip,
          mobile_imp_at,
          ctv_maid,
          ctv_imp_ip,
          ctv_imp_at
      FROM summary 
      WHERE 1=1 
          AND mobile_imp_at IS NOT NULL
          AND ctv_imp_at IS NULL
          AND mobile_imp_at < install_at

  ), 

  ctv_only AS (

      ## one maid could have multiple ctv imps ## 

      SELECT 
          install_maid,
          install_ip,
          install_at,
          install_bundle,
          mobile_imp_ip,
          mobile_imp_at,
          ctv_maid,
          ctv_imp_ip,
          ctv_imp_at
      FROM summary 
      WHERE 1=1 
          AND mobile_imp_at IS  NULL
          AND ctv_imp_at IS NOT NULL
          AND ctv_imp_at < install_at

  ), 

  events AS (

      SELECT 
          C.bid.mtid,
          C.bid.maid,
          C.req.device.ip,
          C.cv.event_pb,
          C.cv.happened_at AS event_at
      FROM `focal-elf-631.prod_stream_view.cv` AS C
      WHERE DATE(timestamp) >= start_date
          AND LOWER(C.cv.event) <> "install"
          AND C.cv.pb.app.bundle IN UNNEST(mmp_bundles)

  ),

  retention_ctv_mobile AS (

      SELECT 
          'mobile_ctv' AS user_cohort,
          COUNT(DISTINCT ip) AS cnt_ip,
          COUNT(DISTINCT CONCAT(mtid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_ctv.maid ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_ctv.maid ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_ctv.maid ELSE NULL END) AS d7_retention,
      FROM mobile_ctv
          LEFT JOIN events
          ON mobile_ctv.ip = events.ip AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
  ),

  retention_ctv AS (

      SELECT 
          'ctv_only' AS user_cohort,
          COUNT(DISTINCT ctv_only.maid) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN ctv_only.maid ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN ctv_only.maid ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN ctv_only.maid ELSE NULL END) AS d7_retention,
      FROM ctv_only
          LEFT JOIN events
          ON ctv_only.maid = events.maid AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14

  ),

  retention_mobile AS (
      SELECT 
          'mobile_only' AS user_cohort,
          COUNT(DISTINCT mobile_only.maid) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_only.maid ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_only.maid ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_only.maid ELSE NULL END) AS d7_retention,
      FROM mobile_only
          LEFT JOIN events
          ON mobile_only.maid = events.maid AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14

  )

  SELECT *
  FROM retention_ctv_mobile
  UNION ALL 
  SELECT *
  FROM retention_ctv
  UNION ALL 
  SELECT *
  FROM retention_mobile

/* user reach based on imp , at IP level , without shared IPs */

  ## tmp table for a single day: `moloco-ods.haewon.ctv_fanatics_imp_2503025_tmp` ##

  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_imp_250307_0411` AS
    WITH mobile_campaigns AS (

      SELECT 
        campaign_id,
        SUM(gross_spend_usd) AS gross_spend
      FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE date_utc BETWEEN start_date AND end_date
        AND product.app_market_bundle IN UNNEST(store_bundles)
      GROUP BY 1
      HAVING gross_spend > 0
      ORDER BY 2 DESC
    ),

    mobile_imp AS (

        SELECT
            bid.maid,
            bid.mtid AS mobile_mtid,
            req.device.ip,
            timestamp AS mobile_imp_at
        FROM `focal-elf-631.prod_stream_view.imp`
        WHERE 1=1
            AND api.campaign.id IN (SELECT campaign_id FROM mobile_campaigns)
            AND DATE(timestamp) BETWEEN start_date AND end_date

    ),

    shared_ip AS (
      # TOP 500 high install IPs (will be excluded from the further analysis) #
        SELECT 
            ip,
            SUM(imp_cnt) AS imp_cnt,
            SUM(win_price_sum) AS win_price_sum,
            SUM(ass_install) AS ass_install,
            SUM(att_install) AS att_install
        FROM `moloco-ods.kyungrin.ctv_perf_by_ip` 
        WHERE utc_date BETWEEN start_date AND end_date
            AND campaign_id IN UNNEST(ctv_campaign_id)
        GROUP BY 1
        ORDER BY att_install DESC
        LIMIT 500
    ),

    ctv_imp AS (
      SELECT
          bid.maid,
          bid.mtid AS ctv_mtid,
          req.device.ip,
          timestamp AS ctv_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE 1=1
          AND api.campaign.id IN UNNEST(ctv_campaign_id)
          AND DATE(timestamp) BETWEEN start_date AND end_date 
          AND req.device.ip NOT IN (SELECT ip FROM shared_ip)
    ),

    summary AS (

      SELECT
        mobile_imp.maid AS mobile_maid,
        mobile_imp.mobile_mtid,
        mobile_imp.ip AS mobile_imp_ip,
        mobile_imp.mobile_imp_at,
        ctv_imp.maid AS ctv_maid,
        ctv_imp.ctv_mtid,
        ctv_imp.ip AS ctv_imp_ip,
        ctv_imp.ctv_imp_at 
      FROM mobile_imp 
          FULL OUTER JOIN ctv_imp ON mobile_imp.ip = ctv_imp.ip
      -- WHERE 
      --     (mobile_imp.mobile_imp_at < install_at
      --     OR ctv_imp.ctv_imp_at < install_at)
        --   AND install.ip NOT IN (SELECT ip FROM shared_ip)
    )

    SELECT *
    FROM summary


/* Create User Cohort Table 
  - ctv only: `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411`
  - mobile only: `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411`
    SELECT *
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NULL

  - both: `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411`
      SELECT *
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NOT NULL
      AND mobile_imp_at < install_at
      AND ctv_imp_at < install_at
*/

## tmp table: `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411`

## Install USER COHORT : Users with both mobile and CTV impressions before install ### 
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411` AS
    WITH mobile_campaigns AS (

      SELECT 
        campaign_id,
        SUM(gross_spend_usd) AS gross_spend
      FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE date_utc BETWEEN start_date AND end_date
        AND product.app_market_bundle IN UNNEST(store_bundles)
      GROUP BY 1
      HAVING gross_spend > 0
      ORDER BY 2 DESC
    ),

    install AS (   

        # (from colab) https://colab.research.google.com/drive/1D8_CA2lJX-ifrFtolF8-3rQ2iePh5-1J#scrollTo=_eCTxUGLyFdP
        # sum of the total install = 176931
        # if excluding top 500 ips in terms of the number of installs per ip = 86431

        SELECT
            req.device.os AS req_os,
            bid.maid, # moloco user id
            CASE
              WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifv) THEN "ifv:" || cv.pb.device.ifv
              WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifa) THEN "ifa:" || cv.pb.device.ifa
              WHEN `moloco-ml.lat_utils.is_userid_truly_available` (cv.pb.mmp.device_id) THEN 'device:' || cv.pb.mmp.device_id
              ELSE NULL
            END AS user_id, # external user id
            bid.mtid,
            cv.pb.device.ip, 
            timestamp AS install_at,
            cv.pb.app.bundle AS install_bundle
        FROM `focal-elf-631.prod_stream_view.cv`
        WHERE 1=1
            AND LOWER(cv.pb.event.name) = 'install'
            AND DATE(timestamp) BETWEEN start_date AND end_date
            AND cv.pb.app.bundle IN UNNEST(mmp_bundles)
            AND req.device.os IN ('CTV', 'ANDROID', 'IOS')
            AND req.device.geo.country = 'USA'
    ), 
    
    mobile_imp AS (

        SELECT
            bid.maid,
            bid.mtid AS mobile_mtid,
            req.device.ip,
            timestamp AS mobile_imp_at
        FROM `focal-elf-631.prod_stream_view.imp`
        WHERE 1=1
            AND api.campaign.id IN (SELECT campaign_id FROM mobile_campaigns)
            AND DATE(timestamp) BETWEEN start_date AND end_date

    ),

    ctv_imp AS (
      SELECT
          bid.maid,
          bid.mtid AS ctv_mtid,
          req.device.ip,
          timestamp AS ctv_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE 1=1
          AND api.campaign.id IN UNNEST(ctv_campaign_id)
          AND DATE(timestamp) BETWEEN start_date AND end_date 
    ),

    shared_ip AS (
      # TOP 500 high install IPs (will be excluded from the further analysis) #
        SELECT 
            ip,
            SUM(imp_cnt) AS imp_cnt,
            SUM(win_price_sum) AS win_price_sum,
            SUM(ass_install) AS ass_install,
            SUM(att_install) AS att_install
        FROM `moloco-ods.kyungrin.ctv_perf_by_ip` 
        WHERE utc_date BETWEEN start_date AND end_date
            AND campaign_id IN UNNEST(ctv_campaign_id)
        GROUP BY 1
        ORDER BY att_install DESC
        LIMIT 500
    ),

    summary AS (

        # the number of the distinct maid = 72230 (excluding shared_ip)
        # without excluding, distinct maid = 76495??

      SELECT
        install.req_os, # install from a mobile device (either Android or iOS)
        install.maid AS install_maid,
        install.user_id,
        install.mtid AS install_mtid,
        install.install_at, 
        install.install_bundle,
        install.ip AS install_ip,
        IF(shared_ip.ip IS NOT NULL, 'shared_ip', NULL) AS is_shared_ip,
        mobile_imp.maid AS mobile_maid,
        mobile_imp.mobile_mtid,
        mobile_imp.ip AS mobile_imp_ip,
        mobile_imp.mobile_imp_at,
        ctv_imp.maid AS ctv_maid,
        ctv_imp.ctv_mtid,
        ctv_imp.ip AS ctv_imp_ip,
        ctv_imp.ctv_imp_at 
      FROM install
          LEFT JOIN mobile_imp ON install.ip = mobile_imp.ip
          LEFT JOIN ctv_imp ON install.ip = ctv_imp.ip
          LEFT JOIN shared_ip ON install.ip = shared_ip.ip
      WHERE 
          (mobile_imp.mobile_imp_at < install_at
          OR ctv_imp.ctv_imp_at < install_at)
        --   AND install.ip NOT IN (SELECT ip FROM shared_ip)
    ),

    cnt_ctv_only AS (
      # can a single mtid have multiple install_at timestamps?
      SELECT 
        COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_ctv_only_all_maid_install_at, 
        COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_ctv_only_all_mtid_install_at, #31537
        COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_only_all_mtid, #19138
        COUNT(DISTINCT CONCAT(install_maid)) AS cnt_ctv_only_all_maid
      FROM summary
      WHERE 
        mobile_imp_at IS NULL 
        AND ctv_imp_at IS NOT NULL
    )

    SELECT *
    FROM summary
    WHERE 
      mobile_imp_at IS NULL 
      AND ctv_imp_at IS NOT NULL



##### Retention #####
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  WITH events AS (

      SELECT 
          C.bid.mtid,
          C.bid.maid,
          CASE
              WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifv) THEN "ifv:" || cv.pb.device.ifv
              WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifa) THEN "ifa:" || cv.pb.device.ifa
              WHEN `moloco-ml.lat_utils.is_userid_truly_available` (cv.pb.mmp.device_id) THEN 'device:' || cv.pb.mmp.device_id
              ELSE NULL
            END AS user_id, # external user id
          C.req.device.ip,
          C.cv.event_pb,
          timestamp AS event_at
      FROM `focal-elf-631.prod_stream_view.cv` AS C
      WHERE DATE(timestamp) >= start_date
          AND LOWER(C.cv.event) <> "install"
          AND C.cv.pb.app.bundle IN UNNEST(mmp_bundles)

  ),

  retention_ctv_mobile AS (

      SELECT 
          'mobile_ctv' AS user_cohort,
          COUNT(DISTINCT mobile_ctv.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          COUNT(DISTINCT CONCAT(mobile_ctv.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_ctv.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_ctv.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_ctv.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411` mobile_ctv
          LEFT JOIN events
          ON mobile_ctv.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE mobile_ctv.user_id IS NOT NULL
        AND is_shared_ip IS NULL
  ),

  retention_ctv AS (

      SELECT 
          'ctv_only' AS user_cohort,
          COUNT(DISTINCT ctv_only.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          COUNT(DISTINCT CONCAT(ctv_only.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN ctv_only.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN ctv_only.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN ctv_only.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411` ctv_only
          LEFT JOIN events
          ON ctv_only.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE ctv_only.user_id IS NOT NULL
        AND is_shared_ip IS NULL

  ),

  retention_mobile AS (
      SELECT 
          'mobile_only' AS user_cohort,
          COUNT(DISTINCT mobile_only.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          COUNT(DISTINCT CONCAT(mobile_only.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_only.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_only.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_only.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411` mobile_only
          LEFT JOIN events
          ON mobile_only.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE mobile_only.user_id IS NOT NULL
        AND is_shared_ip IS NULL

  ), 

  joined AS (  
    SELECT *
    FROM retention_ctv_mobile
    UNION ALL 
    SELECT *
    FROM retention_ctv
    UNION ALL 
    SELECT *
    FROM retention_mobile
  )

  SELECT 
    *,
    d1_retention / cnt_user AS d1_rr, 
    d3_retention / cnt_user AS d3_rr, 
    d7_retention / cnt_user AS d7_rr
  FROM joined


##### Check - Revenue Events #####
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  SELECT  
      cv.event_pb,
      COUNT(1) AS cnt_event
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE 1=1
    AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 30 DAY)
    AND cv.pb.app.bundle IN UNNEST(mmp_bundles)
    AND cv.revenue_usd.amount > 0
  GROUP BY 1
  

##### Conversion #####
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];


  WITH t_rev_raw AS (
    # users with revenue > 0 after re-engagement

    SELECT
      bid.maid,
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifv) THEN "ifv:" || cv.pb.device.ifv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifa) THEN "ifa:" || cv.pb.device.ifa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available` (cv.pb.mmp.device_id) THEN 'device:' || cv.pb.mmp.device_id
        ELSE NULL
      END AS user_id, # external user id
      TIMESTAMP_DIFF(timestamp, install.happened_at, hour) AS diff_hour,
      SUM(cv.revenue_usd.amount) AS revenue,
    FROM `focal-elf-631.prod_stream_view.cv`
    WHERE 1=1
      AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 30 DAY) # considering the conversion within Xdays after install
      AND cv.pb.app.bundle IN UNNEST(mmp_bundles)
      AND cv.revenue_usd.amount > 0
    GROUP BY 1,2,3
  ),

  ctv_only_payer AS (

    SELECT 
      'ctv_only' AS user_cohort,
      *
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411` ctv_only
      LEFT JOIN t_rev_raw USING(user_id)
    WHERE 
      ctv_only.user_id IS NOT NULL 
      AND is_shared_ip IS NULL    
  ),

  mobile_only_payer AS (

    SELECT 
      'mobile_only' AS user_cohort,
      *
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411` mobile_only
      LEFT JOIN t_rev_raw USING(user_id)
    WHERE 
      mobile_only.user_id IS NOT NULL 
      AND is_shared_ip IS NULL    
  ),

  both_payer AS (
    SELECT 
      'both' AS user_cohort,
      *
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411` both
      LEFT JOIN t_rev_raw USING(user_id)
    WHERE 
      both.user_id IS NOT NULL 
      AND is_shared_ip IS NULL    
  ), 

  summary AS (
    SELECT 
      DISTINCT
        user_cohort,
        user_id,
        install_at,
        install_bundle,
        install_ip,
        diff_hour,
        revenue
    FROM ctv_only_payer
    
    UNION ALL
    
    SELECT 
      DISTINCT
        user_cohort,
        user_id,
        install_at,
        install_bundle,
        install_ip,
        diff_hour,
        revenue
    FROM mobile_only_payer

    UNION ALL
    
    SELECT 
      DISTINCT
        user_cohort,
        user_id,
        install_at,
        install_bundle,
        install_ip,
        diff_hour,
        revenue
    FROM both_payer
  ),

  summary2 AS (
    SELECT
      *,
      COUNT(DISTINCT user_id) OVER (PARTITION BY user_cohort) AS user_cnt_all,
      COUNT(DISTINCT IF(revenue>0, user_id, NULL)) OVER (PARTITION BY user_cohort) AS payer_cnt_all
    FROM summary
  )

  ## conversion along the days after install
  SELECT 
    user_cohort,
    DIV(diff_hour, 24) AS diff_day,
    ANY_VALUE(user_cnt_all) AS user_cnt_all,
    ANY_VALUE(payer_cnt_all) AS payer_cnt_all,
    SUM(revenue) daily_revenue_sum,
    COUNT(DISTINCT IF(revenue>0, user_id, NULL)) daily_payer_cnt
  FROM summary2
  WHERE DIV(diff_hour, 24) BETWEEN 0 AND 30
  GROUP BY 1, 2


## Reference for the retention ##
/* 
    events AS (
        SELECT
            C.bid.mtid,
            D.click_device_type,
            C.cv.event_pb,
            C.cv.happened_at AS event_at
        FROM `focal-elf-631.prod_stream_view.cv` AS C
            LEFT JOIN device_type AS D
            ON C.bid.mtid = D.mtid
        WHERE DATE(timestamp) >= start_date
        AND LOWER(cv.event) <> "install"
        ),

    retention AS (
    SELECT 
        installs.click_device_type,
        COUNT(DISTINCT installs.mtid) AS installs,
        COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN events.mtid ELSE NULL END) AS d1_retention,
        COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN events.mtid ELSE NULL END) AS d3_retention,
        COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN events.mtid ELSE NULL END) AS d7_retention
    FROM installs 
        LEFT JOIN events
        ON installs.mtid = events.mtid AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
    GROUP BY 1
    ) 
*/