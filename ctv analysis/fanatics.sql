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

/* user reach based on imp , at IP level , without shared IPs - create based table */

  ## tmp table for a single day: `moloco-ods.haewon.ctv_fanatics_imp_2503025_tmp` ##
  ## tmp table for 3 days: `moloco-ods.haewon.ctv_fanatics_imp_250325_0327_tmp` ##
  

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
        WHERE utc_date BETWEEN '2025-03-11' AND '2025-04-07'
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

    install AS (   

        # (from colab) https://colab.research.google.com/drive/1D8_CA2lJX-ifrFtolF8-3rQ2iePh5-1J#scrollTo=_eCTxUGLyFdP
        # sum of the total install = 176931
        # if excluding top 500 ips in terms of the number of installs per ip = 86431

        SELECT
            req.device.os AS req_os,
            req.device.ip AS req_ip,
            bid.maid, # moloco user id
            CASE
              WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifv) THEN "ifv:" || cv.pb.device.ifv
              WHEN `moloco-ods.general_utils.is_idfa_truly_available`(cv.pb.device.ifa) THEN "ifa:" || cv.pb.device.ifa
              WHEN `moloco-ml.lat_utils.is_userid_truly_available` (cv.pb.mmp.device_id) THEN 'device:' || cv.pb.mmp.device_id
              ELSE NULL
            END AS user_id, # external user id
            bid.mtid,
            cv.pb.device.ip AS install_ip, 
            timestamp AS install_at,
            cv.pb.app.bundle AS install_bundle
        FROM `focal-elf-631.prod_stream_view.cv`
        WHERE 1=1
            AND LOWER(cv.pb.event.name) = 'install'
            AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY)
            AND cv.pb.app.bundle IN UNNEST(mmp_bundles)
            AND req.device.os IN ('CTV', 'ANDROID', 'IOS')
            AND req.device.geo.country = 'USA'
    ), 

    summary_imp AS (

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
    ),
    
    summary_install AS (
      SELECT *
      FROM summary_imp LEFT JOIN install
        ON summary_imp.mobile_imp_ip = install.req_ip 
        OR summary_imp.ctv_imp_ip = install.req_ip
        OR summary_imp.mobile_imp_ip = install.install_ip
        OR summary_imp.ctv_imp_ip = install.install_ip
    )

    SELECT *
    FROM summary_install


/* user reach */

  WITH ctv_only AS (

    SELECT
      'ctv_only' AS cohort,
      COUNT(DISTINCT ctv_imp_ip) AS cnt_ip_ctv_only
    FROM
      `moloco-ods.haewon.ctv_fanatics_imp_2503025_tmp`
    WHERE
      mobile_imp_at IS NULL
      AND ctv_imp_at IS NOT NULL
  ),
  mobile_only AS (
    SELECT
      'mobile_only' AS cohort,
      COUNT(DISTINCT mobile_imp_ip) AS cnt_ip_mobile_only
  FROM
    `moloco-ods.haewon.ctv_fanatics_imp_2503025_tmp`
  WHERE
    mobile_imp_at IS NOT NULL
    AND ctv_imp_at IS NULL

  ),
  both AS (
    SELECT
      'both' AS cohort,
    COUNT(DISTINCT ctv_imp_ip) AS cnt_ip_both
  FROM
    `moloco-ods.haewon.ctv_fanatics_imp_2503025_tmp`
  WHERE
    mobile_imp_at IS NOT NULL
    AND ctv_imp_at IS NOT NULL

  )

  (SELECT * FROM ctv_only)
  UNION ALL
  (SELECT * FROM mobile_only)
  UNION ALL
  (SELECT * FROM both)


/* install conversion */

  ### for a single day ### 
  WITH ctv_imp_install AS (
    SELECT 
      'ctv_only' AS cohort,
      install_at IS NOT NULL AS is_install,
      COUNT(DISTINCT ctv_imp_ip) AS cnt_ctv_ip
    FROM  `moloco-ods.haewon.ctv_fanatics_imp_250325_tmp`
    WHERE mobile_imp_at IS NULL
      AND ctv_imp_at IS NOT NULL 
      AND ctv_imp_ip <> ""
    GROUP BY 1, 2 ## 4.3%
  ), 
  mobile_imp_install AS (
    SELECT 
      'mobile_only' AS cohort,
      install_at IS NOT NULL AS is_install,
      COUNT(DISTINCT mobile_imp_ip) AS cnt_mobile_ip
    FROM  `moloco-ods.haewon.ctv_fanatics_imp_250325_tmp`
    WHERE mobile_imp_at IS NOT NULL
      AND ctv_imp_at IS  NULL 
      AND mobile_imp_ip <> ""
    GROUP BY 1, 2 ## 0.04%
  ), 

  both_imp_install AS (
    SELECT 
      'both' AS cohort,
      install_at IS NOT NULL AS is_install,
      COUNT(DISTINCT ctv_imp_ip) AS cnt_ctv_ip
    FROM  `moloco-ods.haewon.ctv_fanatics_imp_250325_tmp`
    WHERE mobile_imp_at IS NOT NULL
      AND ctv_imp_at IS NOT NULL 
      AND mobile_imp_ip <> ""
      AND ctv_imp_ip <> ""
    GROUP BY 1, 2 ## 5.1%

  )

  SELECT * FROM ctv_imp_install
  UNION ALL
  SELECT * FROM mobile_imp_install
  UNION ALL
  SELECT * FROM both_imp_install




/* Create User Cohort Table 
  - ctv only: 
    `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411`, 
    `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_i2i`
    `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb` : from pb table
  - mobile only: 
    `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411`, 
    `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_i2i`
    `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb`
    
    # CONDITION #
    SELECT *
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NULL

  - both: 
    `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411`, 
    `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_i2i`,
    `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_pb`
    
    # CONDITION #
    SELECT *
    FROM summary
    WHERE 
      mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NOT NULL
      AND mobile_imp_at < install_at
      AND ctv_imp_at < install_at

  - non-moloco: 
    - `moloco-ods.haewon.ctv_fanatics_user_cohort_non_250307_0411_pb` : from pb table

  - one-stop:
    - `moloco-ods.haewon.ctv_fanatics_user_cohort_250325_pb_tmp` for a single day
    - `moloco-ods.haewon.ctv_fanatics_user_cohort_250307_0411_pb` for the entire period -> runtime error
    - `moloco-ods.haewon.ctv_fanatics_user_cohort_250311_0325_pb` : for the separted period 0311 to 0325
    - `moloco-ods.haewon.ctv_fanatics_user_cohort_250326_0407_pb` : for the sencond part of the period 0326 to 0407
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

## Install USER COHORT with i2i prediction: Users with both mobile and CTV impressions before install ### 
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_i2i` AS
    WITH mobile_campaigns AS (
      SELECT 
        campaign_id,
        SUM(gross_spend_usd) AS gross_spend
      FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE date_utc BETWEEN start_date AND end_date
        AND product.app_market_bundle IN UNNEST(store_bundles)
        AND campaign.country = 'USA'
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
            timestamp AS mobile_imp_at,
            bid.model.prediction_logs[SAFE_OFFSET(0)].pred AS i2i,
            log(bid.model.prediction_logs[SAFE_OFFSET(0)].pred) AS i2i_log,
        
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
          timestamp AS ctv_imp_at,
          bid.model.prediction_logs[SAFE_OFFSET(0)].pred AS i2i,
          log(bid.model.prediction_logs[SAFE_OFFSET(0)].pred) AS i2i_log,
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
        mobile_imp.i2i_log AS mobile_i2i_log,
        ctv_imp.maid AS ctv_maid,
        ctv_imp.ctv_mtid,
        ctv_imp.ip AS ctv_imp_ip,
        ctv_imp.ctv_imp_at,
        ctv_imp.i2i_log AS ctv_i2i_log
      FROM install
          LEFT JOIN mobile_imp ON install.ip = mobile_imp.ip
          LEFT JOIN ctv_imp ON install.ip = ctv_imp.ip
          LEFT JOIN shared_ip ON install.ip = shared_ip.ip
      WHERE 
          (mobile_imp.mobile_imp_at < install_at
          OR ctv_imp.ctv_imp_at < install_at)
        --   AND install.ip NOT IN (SELECT ip FROM shared_ip)
    )

    -- cnt_ctv_only AS (
    --   # can a single mtid have multiple install_at timestamps?
    --   SELECT 
    --     COUNT(DISTINCT CONCAT(install_maid, install_at)) AS cnt_ctv_only_all_maid_install_at, 
    --     COUNT(DISTINCT CONCAT(install_mtid, install_at)) AS cnt_ctv_only_all_mtid_install_at, #31537
    --     COUNT(DISTINCT CONCAT(install_mtid)) AS cnt_ctv_only_all_mtid, #19138
    --     COUNT(DISTINCT CONCAT(install_maid)) AS cnt_ctv_only_all_maid
    --   FROM summary
    --   WHERE 
    --     mobile_imp_at IS NULL 
    --     AND ctv_imp_at IS NOT NULL
    -- )

    SELECT *
    FROM summary
    WHERE 
      mobile_imp_at IS NULL 
      AND ctv_imp_at IS NOT NULL


## Install USER COHORT based on mobile / ctv impressions ; for all installs from PB data / one-stop for all cohorts ###  TIME OUT ERROR 
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_250307_0411_pb` AS

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
      SELECT
        device.os AS os,
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id, # external user id
        device.ip,
        -- timestamp AS install_at,
        event.event_at AS install_at,
        app.bundle AS install_bundle
      FROM `focal-elf-631.prod_stream_view.pb`
      WHERE 1=1
        AND LOWER(event.name) = 'install'
        AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY) # one more day for install 
        AND app.bundle IN UNNEST(mmp_bundles)
        AND device.country = 'USA'
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
      SELECT
        install.os, # install device os (either Android or iOS)
        install.user_id,
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
          ((mobile_imp.mobile_imp_at < install_at
          OR ctv_imp.ctv_imp_at < install_at))
          OR (mobile_imp.mobile_imp_at IS NULL AND ctv_imp.ctv_imp_at IS NULL) # non-moloco (without any moloco impressions)
        --   AND install.ip NOT IN (SELECT ip FROM shared_ip)
    )

    SELECT 
      CASE WHEN mobile_imp_at IS NULL and ctv_imp_at IS NOT NULL THEN 'ctv_only'
           WHEN mobile_imp_at IS NOT NULL and ctv_imp_at IS NULL THEN 'mobile_only'
           WHEN mobile_imp_at IS NOT NULL and ctv_imp_at IS NOT NULL THEN 'both'
           ELSE 'non_moloco' END AS user_cohort,
      *
    FROM summary
    WHERE 1=1
      AND is_shared_ip IS NULL # exclude shared IPs
      AND user_id IS NOT NULL

#### Install User Cohort based on PB / CTV ONLY `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb`##
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb` AS

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
      SELECT
        device.os AS os,
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id, # external user id
        device.ip,
        -- timestamp AS install_at,
        event.event_at AS install_at,
        app.bundle AS install_bundle
      FROM `focal-elf-631.prod_stream_view.pb`
      WHERE 1=1
        AND LOWER(event.name) = 'install'
        AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY) # one more day for install 
        AND app.bundle IN UNNEST(mmp_bundles)
        AND device.country = 'USA'
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
      SELECT
        install.os, # install device os (either Android or iOS)
        install.user_id,
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
          ((mobile_imp.mobile_imp_at < install_at
          OR ctv_imp.ctv_imp_at < install_at))
          OR (mobile_imp.mobile_imp_at IS NULL AND ctv_imp.ctv_imp_at IS NULL) # non-moloco (without any moloco impressions)
        --   AND install.ip NOT IN (SELECT ip FROM shared_ip)
    )

    SELECT 
      -- CASE WHEN mobile_imp_at IS NULL and ctv_imp_at IS NOT NULL THEN 'ctv_only'
      --      WHEN mobile_imp_at IS NOT NULL and ctv_imp_at IS NULL THEN 'mobile_only'
      --      WHEN mobile_imp_at IS NOT NULL and ctv_imp_at IS NOT NULL THEN 'both'
      --      ELSE 'non_moloco' END AS user_cohort,
      *
    FROM summary
    WHERE 1=1
      AND is_shared_ip IS NULL # exclude shared IPs
      AND user_id IS NOT NULL
      AND mobile_imp_at IS NULL 
      AND ctv_imp_at IS NOT NULL

#### Install User Cohort based on PB / BOTH : timeout error keep occuring ... Refactorying the code!! ##

  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_pb` AS
    -- 이건 중간 필터 테이블
    WITH known_user_ids AS (
      SELECT user_id FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb`
      UNION ALL
      SELECT user_id FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb`
      UNION ALL
      SELECT user_id FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_non_250307_0411_pb`
    )

    , install_filtered AS (
      SELECT
        device.os AS os,
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id,
        device.ip,
        event.event_at AS install_at,
        app.bundle AS install_bundle
      FROM `focal-elf-631.prod_stream_view.pb`
      WHERE LOWER(event.name) = 'install'
        AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY)
        AND app.bundle IN UNNEST(mmp_bundles)
        AND device.country = 'USA'
        AND CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END NOT IN (SELECT user_id FROM known_user_ids)
    )
    , ctv_imp_filtered AS (
      SELECT
        bid.maid,
        bid.mtid AS ctv_mtid,
        req.device.ip,
        timestamp AS ctv_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE DATE(timestamp) BETWEEN start_date AND end_date 
        AND api.campaign.id IN UNNEST(ctv_campaign_id)
    )

    , mobile_campaigns AS (
      SELECT campaign_id
      FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE date_utc BETWEEN start_date AND end_date
        AND product.app_market_bundle IN UNNEST(store_bundles)
      GROUP BY 1
    )

    , mobile_imp_filtered AS (
      SELECT
        bid.maid,
        bid.mtid AS mobile_mtid,
        req.device.ip,
        timestamp AS mobile_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE DATE(timestamp) BETWEEN start_date AND end_date
        AND api.campaign.id IN (SELECT campaign_id FROM mobile_campaigns)
    )
    , shared_ip AS (
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

    , summary AS (
      SELECT
        i.os,
        i.user_id,
        i.install_at,
        i.install_bundle,
        i.ip AS install_ip,
        IF(s.ip IS NOT NULL, 'shared_ip', NULL) AS is_shared_ip,
        m.maid AS mobile_maid,
        m.mobile_mtid,
        m.ip AS mobile_imp_ip,
        m.mobile_imp_at,
        c.maid AS ctv_maid,
        c.ctv_mtid,
        c.ip AS ctv_imp_ip,
        c.ctv_imp_at 
      FROM install_filtered i
        LEFT JOIN mobile_imp_filtered m ON i.ip = m.ip AND m.mobile_imp_at < i.install_at
        LEFT JOIN ctv_imp_filtered c ON i.ip = c.ip AND c.ctv_imp_at < i.install_at
        LEFT JOIN shared_ip s ON i.ip = s.ip
    )

    SELECT *
    FROM summary
    WHERE is_shared_ip IS NULL
      AND user_id IS NOT NULL
      AND mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NOT NULL


#### Install User Cohort based on PB / Mobile without ib format ##

  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb_woib` AS
    WITH known_user_ids AS (
      SELECT user_id FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb`
      UNION ALL
      -- SELECT user_id FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb`
      -- UNION ALL
      SELECT user_id FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_non_250307_0411_pb`
    ),

    install_filtered AS (
      SELECT
        device.os AS os,
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id,
        device.ip,
        event.event_at AS install_at,
        app.bundle AS install_bundle
      FROM `focal-elf-631.prod_stream_view.pb`
      WHERE LOWER(event.name) = 'install'
        AND DATE(timestamp) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY)
        AND app.bundle IN UNNEST(mmp_bundles)
        AND device.country = 'USA'
        AND CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END NOT IN (SELECT user_id FROM known_user_ids)
    )
    , ctv_imp_filtered AS (
      SELECT
        bid.maid,
        bid.mtid AS ctv_mtid,
        req.device.ip,
        timestamp AS ctv_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE DATE(timestamp) BETWEEN start_date AND end_date 
        AND api.campaign.id IN UNNEST(ctv_campaign_id)
    )

    , mobile_campaigns AS (
      SELECT campaign_id
      FROM `moloco-ae-view.athena.fact_dsp_core`
      WHERE date_utc BETWEEN start_date AND end_date
        AND product.app_market_bundle IN UNNEST(store_bundles)
      GROUP BY 1
    )

    , mobile_imp_filtered AS (
      SELECT
        bid.maid,
        bid.mtid AS mobile_mtid,
        req.device.ip,
        timestamp AS mobile_imp_at
      FROM `focal-elf-631.prod_stream_view.imp`
      WHERE DATE(timestamp) BETWEEN start_date AND end_date
        AND api.campaign.id IN (SELECT campaign_id FROM mobile_campaigns)
        AND api.creative.cr_format <> 'ib'
    )
    , shared_ip AS (
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
      SELECT
        i.os,
        i.user_id,
        i.install_at,
        i.install_bundle,
        i.ip AS install_ip,
        IF(s.ip IS NOT NULL, 'shared_ip', NULL) AS is_shared_ip,
        m.maid AS mobile_maid,
        m.mobile_mtid,
        m.ip AS mobile_imp_ip,
        m.mobile_imp_at,
        c.maid AS ctv_maid,
        c.ctv_mtid,
        c.ip AS ctv_imp_ip,
        c.ctv_imp_at 
      FROM install_filtered i
        LEFT JOIN mobile_imp_filtered m ON i.ip = m.ip AND m.mobile_imp_at < i.install_at
        LEFT JOIN ctv_imp_filtered c ON i.ip = c.ip AND c.ctv_imp_at < i.install_at
        LEFT JOIN shared_ip s ON i.ip = s.ip
    )

    SELECT *
    FROM summary
    WHERE is_shared_ip IS NULL
      AND user_id IS NOT NULL
      AND mobile_imp_at IS NOT NULL 
      AND ctv_imp_at IS NULL

#### Install User Cohort / install by bundle ####
  SELECT
    'both' AS user_cohort,
    install_bundle,
    COUNT(DISTINCT user_id)
  FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_pb`
  GROUP BY 1,2

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

#### Retention within i2i bucket #### RUNNING
  DECLARE start_date DATE DEFAULT  '2025-03-11';
    DECLARE end_date DATE DEFAULT '2025-04-07';
    DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
    DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
    DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];


    CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_retention_250307_0411_i2i` AS

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
            ctv_i2i_bucket,
            mobile_i2i_bucket,
            COUNT(DISTINCT mobile_ctv.user_id) AS cnt_user,
            COUNT(DISTINCT ip) AS cnt_ip,
            COUNT(DISTINCT CONCAT(mobile_ctv.install_maid, install_at)) AS installs,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_ctv.user_id ELSE NULL END) AS d1_retention,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_ctv.user_id ELSE NULL END) AS d3_retention,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_ctv.user_id ELSE NULL END) AS d7_retention,
        FROM (SELECT *, 
                CAST(ctv_i2i_log AS INT64) AS ctv_i2i_bucket,
                CAST(mobile_i2i_log AS INT64) AS mobile_i2i_bucket,
              FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_i2i`) mobile_ctv
            LEFT JOIN events
            ON mobile_ctv.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
        WHERE mobile_ctv.user_id IS NOT NULL
          AND is_shared_ip IS NULL
        GROUP BY 1,2,3
    ),

    retention_ctv AS (

        SELECT 
            'ctv_only' AS user_cohort,
            ctv_i2i_bucket,
            mobile_i2i_bucket,
            COUNT(DISTINCT ctv_only.user_id) AS cnt_user,
            COUNT(DISTINCT ip) AS cnt_ip,
            COUNT(DISTINCT CONCAT(ctv_only.install_maid, install_at)) AS installs,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN ctv_only.user_id ELSE NULL END) AS d1_retention,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN ctv_only.user_id ELSE NULL END) AS d3_retention,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN ctv_only.user_id ELSE NULL END) AS d7_retention,
        FROM (SELECT *,
                CAST(ctv_i2i_log AS INT64) AS ctv_i2i_bucket,
                CAST(mobile_i2i_log AS INT64) AS mobile_i2i_bucket
              FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_i2i`) ctv_only
            LEFT JOIN events
            ON ctv_only.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
        WHERE ctv_only.user_id IS NOT NULL
          AND is_shared_ip IS NULL
        GROUP BY 1,2,3

    ),

    retention_mobile AS (
        SELECT 
            'mobile_only' AS user_cohort,
            ctv_i2i_bucket,
            mobile_i2i_bucket,
            COUNT(DISTINCT mobile_only.user_id) AS cnt_user,
            COUNT(DISTINCT ip) AS cnt_ip,
            COUNT(DISTINCT CONCAT(mobile_only.install_maid, install_at)) AS installs,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_only.user_id ELSE NULL END) AS d1_retention,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_only.user_id ELSE NULL END) AS d3_retention,
            COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_only.user_id ELSE NULL END) AS d7_retention,
        FROM (SELECT *,
                CAST(ctv_i2i_log AS INT64) AS ctv_i2i_bucket,
                CAST(mobile_i2i_log AS INT64) AS mobile_i2i_bucket
              FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_i2i`) mobile_only
            LEFT JOIN events
            ON mobile_only.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
        WHERE mobile_only.user_id IS NOT NULL
          AND is_shared_ip IS NULL
        GROUP BY 1,2,3

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
    
    SELECT *
    FROM joined 
    -- SELECT 
    --   *,
    --   d1_retention / cnt_user AS d1_rr, 
    --   d3_retention / cnt_user AS d3_rr, 
    --   d7_retention / cnt_user AS d7_rr
    -- FROM joined

  # calculate retention within i2i bucket 
    SELECT 
      user_cohort,
      -- ctv_i2i_bucket,
      mobile_i2i_bucket,
      SUM(d1_retention) / SUM(cnt_user) AS d1_rr,
      SUM(d3_retention) / SUM(cnt_user) AS d3_rr,
      SUM(d7_retention) / SUM(cnt_user) AS d7_rr,
    FROM `moloco-ods.haewon.ctv_fanatics_retention_250307_0411_i2i`
    GROUP BY 1,2

#### Retention v2 (one-stop; with PB table) ####

  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_retention_250307_0411_pb` AS

  WITH events_pb AS (

    SELECT 
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
        ELSE NULL
      END AS user_id, # external user
      device.ip,
      event.name AS event_pb,
      event.event_at AS event_at
    FROM `focal-elf-631.df_accesslog.pb`
    WHERE DATE(timestamp) >= start_date
      AND LOWER(event.name) <> "install"
      AND app.bundle IN UNNEST(mmp_bundles)
  ),

  retention AS (
    SELECT
      user_cohort,
      COUNT(DISTINCT cohort.user_id) AS cnt_user,
      COUNT(DISTINCT cohort.ip) AS cnt_ip,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN cohort.user_id ELSE NULL END) AS d1_retention,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN cohort.user_id ELSE NULL END) AS d3_retention,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN cohort.user_id ELSE NULL END) AS d7_retention
    FROM (SELECT * FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_250311_0325_pb` 
          UNION ALL SELECT * FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_250326_0407_pb`) cohort
        LEFT JOIN events_pb
        ON cohort.user_id = events_pb.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
    GROUP BY 1
  )
 
  SELECT 
    *,
    d1_retention / cnt_user AS d1_rr, 
    d3_retention / cnt_user AS d3_rr, 
    d7_retention / cnt_user AS d7_rr
  FROM retention

#### Retention v2 break-down / PB table ####
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_retention_250307_0411_pb` AS

  WITH events_pb AS (

    SELECT 
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
        ELSE NULL
      END AS user_id, # external user
      device.ip,
      event.name AS event_pb,
      event.event_at AS event_at
    FROM `focal-elf-631.df_accesslog.pb`
    WHERE DATE(timestamp) >= start_date
      AND LOWER(event.name) <> "install"
      AND app.bundle IN UNNEST(mmp_bundles)
  ),

  retention_ctv_mobile AS (

      SELECT 
          'mobile_ctv' AS user_cohort,
          COUNT(DISTINCT mobile_ctv.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          -- COUNT(DISTINCT CONCAT(mobile_ctv.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_ctv.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_ctv.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_ctv.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_pb` mobile_ctv
          LEFT JOIN events_pb
          ON mobile_ctv.user_id = events_pb.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE mobile_ctv.user_id IS NOT NULL
        AND is_shared_ip IS NULL
  ),

  retention_ctv AS (

      SELECT 
          'ctv_only' AS user_cohort,
          COUNT(DISTINCT ctv_only.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          -- COUNT(DISTINCT CONCAT(ctv_only.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN ctv_only.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN ctv_only.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN ctv_only.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb` ctv_only
          LEFT JOIN events_pb
          ON ctv_only.user_id = events_pb.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE ctv_only.user_id IS NOT NULL
        AND is_shared_ip IS NULL

  ),

  retention_mobile AS (
      SELECT 
          'mobile_only' AS user_cohort,
          COUNT(DISTINCT mobile_only.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          -- COUNT(DISTINCT CONCAT(mobile_only.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_only.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_only.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_only.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb` mobile_only
          LEFT JOIN events_pb
          ON mobile_only.user_id = events_pb.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE mobile_only.user_id IS NOT NULL
        AND is_shared_ip IS NULL

  ), 
  
  retention_non AS (
    SELECT 
      'non_moloco' AS user_cohort,
      COUNT(DISTINCT non_moloco.user_id) AS cnt_user,
      COUNT(DISTINCT ip) AS cnt_ip,
      -- COUNT(DISTINCT CONCAT(non_moloco.install_maid, install_at)) AS installs,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN non_moloco.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN non_moloco.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN non_moloco.user_id ELSE NULL END) AS d7_retention,
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_non_250307_0411_pb` non_moloco
        LEFT JOIN events_pb
        ON non_moloco.user_id = events_pb.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
    WHERE non_moloco.user_id IS NOT NULL
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
    UNION ALL 
    SELECT *
    FROM retention_non
  )

  SELECT 
    *,
    d1_retention / cnt_user AS d1_rr, 
    d3_retention / cnt_user AS d3_rr, 
    d7_retention / cnt_user AS d7_rr
  FROM joined


##### Retention: vs Organic #####
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_retention_org_250307_0411` AS
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

  events_pb AS (

    SELECT 
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
        ELSE NULL
      END AS user_id, # external user
      device.ip,
      event.name AS event_pb,
      timestamp AS event_at
    FROM `focal-elf-631.df_accesslog.pb`
    WHERE DATE(timestamp) >= start_date
      AND LOWER(event.name) <> "install"
      AND app.bundle IN UNNEST(mmp_bundles)
  ),

  retention_organic AS (
    SELECT
      'organic' AS user_cohort,
      COUNT(DISTINCT organic.user_id) AS cnt_user,
      COUNT(DISTINCT organic.ip) AS cnt_ip,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN organic.user_id ELSE NULL END) AS d1_retention,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN organic.user_id ELSE NULL END) AS d3_retention,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN organic.user_id ELSE NULL END) AS d7_retention
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_organic_inst_250307_0411` organic
        LEFT JOIN events_pb
        ON organic.user_id = events_pb.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
    WHERE organic.user_id IS NOT NULL
  ),
  

  retention_ctv_mobile AS (

      SELECT 
          'mobile_ctv' AS user_cohort,
          COUNT(DISTINCT mobile_ctv.user_id) AS cnt_user,
          COUNT(DISTINCT ip) AS cnt_ip,
          -- COUNT(DISTINCT CONCAT(mobile_ctv.install_maid, install_at)) AS installs,
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
          -- COUNT(DISTINCT CONCAT(ctv_only.install_maid, install_at)) AS installs,
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
          -- COUNT(DISTINCT CONCAT(mobile_only.install_maid, install_at)) AS installs,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN mobile_only.user_id ELSE NULL END) AS d1_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN mobile_only.user_id ELSE NULL END) AS d3_retention,
          COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN mobile_only.user_id ELSE NULL END) AS d7_retention,
      FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411` mobile_only
          LEFT JOIN events
          ON mobile_only.user_id = events.user_id AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 14
      WHERE mobile_only.user_id IS NOT NULL
        -- AND is_shared_ip IS NULL

  ), 

  joined AS (  
    SELECT *
    FROM retention_organic
    UNION ALL 
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

#### Retention / PB / Refactored ####

  DECLARE start_date DATE DEFAULT '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_retention_250307_0411_pb` AS

  WITH events_pb AS (
    SELECT 
      CASE
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
        WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
        WHEN `moloco-ml.lat_utils.is_userid_truly_available`(mmp.device_id) THEN "device:" || mmp.device_id
        ELSE NULL
      END AS user_id,
      device.ip,
      event.name AS event_pb,
      event.event_at AS event_at
    FROM `focal-elf-631.df_accesslog.pb`
    WHERE timestamp >= TIMESTAMP(start_date)
      AND LOWER(event.name) <> "install"
      AND app.bundle IN UNNEST(mmp_bundles)
  ),

  cohorts AS (
    SELECT 
      'mobile_ctv' AS user_cohort, 
      user_id,
      install_at
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_pb`
    UNION ALL
    SELECT 
      'ctv_only' AS user_cohort,
      user_id,
      install_at
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb`
    UNION ALL
    SELECT 
      'mobile_only' AS user_cohort,
      user_id,
      install_at
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb`
    UNION ALL
    SELECT 
      'non_moloco' AS user_cohort,
      user_id,
      install_at
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_non_250307_0411_pb`
  ),

  retention_summary AS (
    SELECT
      c.user_cohort,
      COUNT(DISTINCT c.user_id) AS cnt_user,
      COUNT(DISTINCT e.ip) AS cnt_ip,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(e.event_at, c.install_at, DAY) = 1 THEN c.user_id END) AS d1_retention,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(e.event_at, c.install_at, DAY) = 3 THEN c.user_id END) AS d3_retention,
      COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(e.event_at, c.install_at, DAY) = 7 THEN c.user_id END) AS d7_retention
    FROM cohorts c
    LEFT JOIN events_pb e
      ON c.user_id = e.user_id AND TIMESTAMP_DIFF(e.event_at, c.install_at, DAY) < 14
    GROUP BY c.user_cohort
  )

  SELECT 
    *,
    SAFE_DIVIDE(d1_retention, cnt_user) AS d1_rr,
    SAFE_DIVIDE(d3_retention, cnt_user) AS d3_rr,
    SAFE_DIVIDE(d7_retention, cnt_user) AS d7_rr
  FROM retention_summary;


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

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_rev_250307_0411` AS

  WITH t_rev_raw AS (
    # users with revenue > 0 

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

  SELECT *
  FROM summary2


  ##############################################################################################

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
  ORDER BY 1, 2

 ## Dx LTV (cumulative ARPPU)
  SELECT 
    user_cohort,
    DIV(diff_hour, 24) AS diff_day,
    ANY_VALUE(user_cnt_all) AS user_cnt_all,
    ANY_VALUE(payer_cnt_all) AS payer_cnt_all,
    SUM(revenue) AS daily_revenue_sum,
    COUNT(DISTINCT IF(revenue>0, user_id, NULL)) daily_payer_cnt
  FROM summary2
  WHERE DIV(diff_hour, 24) BETWEEN 0 AND 30
  GROUP BY 1, 2
 
##### Conversion with i2i bucket ##### RUNNING
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_rev_250307_0411_mobile_i2i` AS

  WITH t_rev_raw AS (
    # users with revenue > 0 

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
    FROM (SELECT *,
              CAST(ctv_i2i_log AS INT64) AS ctv_i2i_bucket,
              CAST(mobile_i2i_log AS INT64) AS mobile_i2i_bucket
          FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_i2i`) ctv_only
      LEFT JOIN t_rev_raw USING(user_id)
    WHERE 
      ctv_only.user_id IS NOT NULL 
      AND is_shared_ip IS NULL    
  ),

  mobile_only_payer AS (

    SELECT 
      'mobile_only' AS user_cohort,
      *
    FROM (SELECT *,
            CAST(ctv_i2i_log AS INT64) AS ctv_i2i_bucket,
            CAST(mobile_i2i_log AS INT64) AS mobile_i2i_bucket
          FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_i2i`) mobile_only
      LEFT JOIN t_rev_raw USING(user_id)
    WHERE 
      mobile_only.user_id IS NOT NULL 
      AND is_shared_ip IS NULL    
  ),

  both_payer AS (
    SELECT 
      'both' AS user_cohort,
      *
    FROM (SELECT *,
            CAST(ctv_i2i_log AS INT64) AS ctv_i2i_bucket,
            CAST(mobile_i2i_log AS INT64) AS mobile_i2i_bucket
          FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_i2i`) both
      LEFT JOIN t_rev_raw USING(user_id)
    WHERE 
      both.user_id IS NOT NULL 
      AND is_shared_ip IS NULL    
  ), 

  summary AS (
    SELECT 
      DISTINCT
        user_cohort,
        ctv_i2i_bucket,
        mobile_i2i_bucket,
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
        ctv_i2i_bucket,
        mobile_i2i_bucket,
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
        ctv_i2i_bucket,
        mobile_i2i_bucket,
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
      COUNT(DISTINCT IF(revenue>0, user_id, NULL)) OVER (PARTITION BY user_cohort) AS payer_cnt_all,
      COUNT(DISTINCT user_id) OVER (PARTITION BY user_cohort, mobile_i2i_bucket) AS user_cnt_bucket,
      COUNT(DISTINCT IF(revenue>0, user_id, NULL)) OVER (PARTITION BY user_cohort, mobile_i2i_bucket) AS payer_cnt_bucket
    FROM summary
  )

  SELECT *
  FROM summary2

  ## conversion along the days after install within mobile i2i bucket
  SELECT 
    user_cohort,
    mobile_i2i_bucket,
    DIV(diff_hour, 24) AS diff_day,
    ANY_VALUE(user_cnt_all) AS user_cnt_all,
    ANY_VALUE(payer_cnt_all) AS payer_cnt_all,
    SUM(revenue) daily_revenue_sum,
    COUNT(DISTINCT IF(revenue>0, user_id, NULL)) daily_payer_cnt
  FROM summary2
  WHERE DIV(diff_hour, 24) BETWEEN 0 AND 30
  GROUP BY 1, 2, 3
  ORDER BY 1, 2, 3

 ## Dx LTV (cumulative ARPPU)
  SELECT 
    user_cohort,
    DIV(diff_hour, 24) AS diff_day,
    ANY_VALUE(user_cnt_all) AS user_cnt_all,
    ANY_VALUE(payer_cnt_all) AS payer_cnt_all,
    SUM(revenue) AS daily_revenue_sum,
    COUNT(DISTINCT IF(revenue>0, user_id, NULL)) daily_payer_cnt
  FROM summary2
  WHERE DIV(diff_hour, 24) BETWEEN 0 AND 30
  GROUP BY 1, 2

#### Conversion: vs Organic ##### RUNNING...

  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_rev_org_250307_0411` AS

  WITH t_rev_raw AS (
    # users with revenue > 0 

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

  t_rev_raw_pb AS (
    # users with revenue > 0 
    SELECT
      CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
      END AS user_id, # external user id
      TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
      SUM(event.revenue_usd.amount) AS revenue
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE 1=1
      AND DATE(timestamp) >= start_date
      AND DATE(event.event_at) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 30 DAY) # considering the conversion within Xdays after install
      AND app.bundle IN UNNEST(mmp_bundles)
      AND event.revenue_usd.amount > 0
    GROUP BY 1,2
  ),

  organic_payer AS (
    SELECT 
      'organic' AS user_cohort,
      *
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_organic_inst_250307_0411` organic
      LEFT JOIN t_rev_raw_pb USING(user_id)
    WHERE
      organic.user_id IS NOT NULL
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
        ip AS install_ip,
        diff_hour,
        revenue
    FROM organic_payer
    
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

  SELECT *
  FROM summary2

#### Conversion V2 (with PB table) ####
  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_rev_250307_0411_pb` AS
  
  WITH t_rev_raw_pb AS (
    # users with revenue > 0 
    SELECT
      CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
      END AS user_id, # external user id
      TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
      SUM(event.revenue_usd.amount) AS revenue
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE 1=1
      AND timestamp >= TIMESTAMP(start_date)
      AND DATE(event.event_at) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 30 DAY) # considering the conversion within Xdays after install
      AND app.bundle IN UNNEST(mmp_bundles)
      AND event.revenue_usd.amount > 0
    GROUP BY 1,2
  ),

    cohorts AS (
    SELECT 
      DISTINCT
      'mobile_ctv' AS user_cohort, 
      user_id,
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411_pb`
    UNION ALL
    SELECT 
      DISTINCT
      'ctv_only' AS user_cohort,
      user_id,
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411_pb`
    UNION ALL
    SELECT 
      DISTINCT
      'mobile_only' AS user_cohort,
      user_id,
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411_pb`
    UNION ALL
    SELECT 
      DISTINCT
      'non_moloco' AS user_cohort,
      user_id,
    FROM `moloco-ods.haewon.ctv_fanatics_user_cohort_non_250307_0411_pb`
  ),

    payer AS (
      SELECT 
        user_cohort,
        user_id,
        diff_hour,
        revenue,
        COUNT(DISTINCT user_id) OVER (PARTITION BY user_cohort) AS user_cnt_all,
        COUNT(DISTINCT IF(revenue>0, user_id, NULL)) OVER (PARTITION BY user_cohort) AS payer_cnt_all
      FROM cohorts
        LEFT JOIN t_rev_raw_pb USING(user_id)
    )

    SELECT *
    FROM payer



#### Organic User Cohort Define #### (without Mobile or CTV impressions)

  DECLARE start_date DATE DEFAULT  '2025-03-11';
  DECLARE end_date DATE DEFAULT '2025-04-07';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  ### Organic User Cohort / USA / iOS ###

  CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_user_cohort_organic_inst_250307_0411` AS

  WITH install AS (

    SELECT
        device.os AS os,
        -- bid.maid, # moloco user id
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id, # external user id
        -- bid.mtid,
        device.ip, 
        timestamp AS install_at,
        app.bundle AS install_bundle
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE 1=1
        AND LOWER(event_name) = 'install'
        AND DATE(timestamp) BETWEEN start_date AND end_date
        AND app.bundle = 'id1616738407'
        AND device.os = 'IOS'
        AND device.country = 'USA'      
  )

  SELECT install.*
  FROM install
    LEFT JOIN `moloco-ods.haewon.ctv_fanatics_user_cohort_ctv_250307_0411` ctv USING(user_id)
    LEFT JOIN `moloco-ods.haewon.ctv_fanatics_user_cohort_mobile_250307_0411` mobile USING(user_id)
    LEFT JOIN `moloco-ods.haewon.ctv_fanatics_user_cohort_both_250307_0411` both USING(user_id)
  WHERE 
    ctv.user_id IS NULL 
    AND mobile.user_id IS NULL
    AND both.user_id IS NULL


#### PB Revenue Value Sanity Check ####
  DECLARE start_date DATE DEFAULT  '2025-03-25';
  DECLARE end_date DATE DEFAULT '2025-03-25';
  DECLARE ctv_campaign_id ARRAY<STRING> DEFAULT ['mSAVdPPzNQMXyjdb'];
  DECLARE mmp_bundles   ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', 'id1616738407'];
  DECLARE store_bundles ARRAY<STRING> DEFAULT ['com.betfanatics.sportsbook.android', '1616738407'];

  -- CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_fanatics_rev_250307_0411_pb` AS
  
  WITH t_rev_raw_pb AS (
    # users with revenue > 0 
    SELECT
      CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
      END AS user_id, # external user id
      TIMESTAMP_DIFF(event.event_at, event.install_at, hour) AS diff_hour,
      SUM(event.revenue_usd.amount) AS revenue
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE 1=1
      AND DATE(timestamp) >= start_date
      AND DATE(event.event_at) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 30 DAY) # considering the conversion within Xdays after install
      AND app.bundle IN UNNEST(mmp_bundles)
      AND event.revenue_usd.amount > 0
    GROUP BY 1,2
  )

  ## check p95, p99 values to determine a capping logic ##
  ## Result) p95: 450.0, p99: 1939.0 ##
    SELECT
      APPROX_QUANTILES(revenue, 100)[OFFSET(95)] AS p95,
      APPROX_QUANTILES(revenue, 100)[OFFSET(99)] AS p99
    FROM
      t_rev_raw_pb;





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


