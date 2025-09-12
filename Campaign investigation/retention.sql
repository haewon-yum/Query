### G-Star Reference, by @jamie ###

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
WITH
  gaming_apps AS (
    SELECT
      product.app_market_bundle AS app_market_bundle,
      COALESCE(SUM(gross_spend_usd), 0) AS gross_spend_usd
    FROM
        `moloco-ae-view.athena.fact_dsp_daily`
    WHERE
        date_utc >= '2024-09-01' AND date_utc <= '2024-09-07'
        AND product.is_gaming = TRUE
    GROUP BY
        app_market_bundle
    HAVING
        gross_spend_usd > 0
  ),

  installs AS (
  SELECT idfa,
    country,
    attribution,
    bundle,
    os,
    min(timestamp) as timestamp
  FROM(
      SELECT
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN device.ifa
        ELSE ''
        END AS idfa,
        device.os,
        device.country,
        CASE WHEN moloco.attributed = TRUE Then 'Moloco' ELSE 'Unattributed' END as attribution,
        app.bundle,
        event.event_at AS timestamp,
      FROM
        `focal-elf-631.prod_stream_view.pb`
      WHERE
        app.bundle in (SELECT app_market_bundle FROM gaming_apps)
        AND DATE(timestamp) >= '2024-09-01' AND DATE(timestamp) <= '2024-09-07'
        AND event_name = 'install'
        AND device.country IN ('KOR', 'USA', 'CAN', 'GBR', 'FRA', 'DEU', 'TWN', 'JPN', 'HKG')
    )
    WHERE idfa IS NOT NULL
      AND idfa != ""
    GROUP BY 1,2,3,4,5
    ),

  actions AS (
  SELECT * FROM (
    SELECT
        CASE
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN device.idfv
            WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN device.idfa
          ELSE ''
        END AS idfa,
        app.bundle,
      timestamp,
      CASE WHEN attribution.attributed = TRUE Then 'Moloco' ELSE 'Unattributed' END as attribution,
    FROM
      `focal-elf-631.df_accesslog.pb`
    WHERE
      app.bundle in (SELECT app_market_bundle FROM gaming_apps)
      AND DATE(timestamp) >= '2024-09-01' AND DATE(timestamp) <= '2024-10-07'
      AND LOWER(event.name) NOT LIKE "%ltv%"
      AND event.name != 'install'
      AND lower(event.name) NOT IN ('reinstall', 'reattribution')
      AND lower(event.name) NOT LIKE '%conver%'
      AND lower(event.name) NOT LIKE '%pecan%'
      AND device.country IN ('KOR', 'USA', 'CAN', 'GBR', 'FRA', 'DEU', 'TWN', 'JPN', 'HKG')
    )
  WHERE idfa IS NOT NULL
    AND idfa != ""
  ),

  T as (
    SELECT
      installs.idfa as inst_idfa,
      actions.idfa as action_idfa,
      installs.attribution,
      installs.bundle,
      os,
      installs.country,
      TIMESTAMP_DIFF(actions.timestamp, installs.timestamp, DAY) as day_diff,
      COUNT(DISTINCT installs.idfa) OVER(PARTITION BY installs.bundle, installs.os, installs.country, installs.attribution) AS installs_for_group,
    FROM
      installs
    LEFT JOIN
      actions
    ON
      actions.idfa = installs.idfa
      AND actions.bundle = installs.bundle
      AND actions.attribution = installs.attribution
      AND actions.timestamp > installs.timestamp
  )

SELECT
  bundle,
  os,
  attribution,
  CASE
    WHEN country IN ('KOR') THEN 'KOR'
    WHEN country IN ('USA', 'CAN') THEN 'NA'
    WHEN country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
    WHEN country IN ('TWN', 'JPN', 'HKG') THEN 'NEA'
    ELSE 'Other'
  END AS market,
  country,
  day_diff,
  ANY_VALUE(installs_for_group) AS installs,
  COUNT(DISTINCT action_idfa) AS retention_for_day
FROM T
WHERE day_diff < 30
GROUP BY
  1,2,3,4,5,6
ORDER BY
  1,2,3,4,5,6



### UA Society 2025 ###

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

DECLARE start_date DEFAULT DATE('{start_date}');
DECLARE end_date DEFAULT DATE('{end_date}');

WITH
  t_app AS (
      SELECT
        product.app_market_bundle,
        advertiser.mmp_bundle_id,
        SUM(gross_spend_usd) AS revenue
      FROM
        `moloco-ae-view.athena.fact_dsp_core`
      WHERE
        date_utc BETWEEN start_date AND end_date
        AND ({query_tmp})
      GROUP BY 1, 2
    ),

  installs AS (
  SELECT 
    user_id,
    os,
    app_market_bundle,
    mmp_bundle_id,
    region,
    min(timestamp) as timestamp
  FROM(
      SELECT
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id,
        device.os,
        app_market_bundle,
        mmp_bundle_id,
        CASE
          WHEN device.country = 'KOR' THEN 'KR'
          WHEN device.country IN ('USA','CAN') THEN 'NA'
          WHEN device.country IN ('GBR', 'FRA', 'DEU') THEN 'EU'
          WHEN device.country IN ('JPN','HKG','TWN') THEN 'NEA'
          ELSE 'ETC' END AS region,        
        event.event_at AS timestamp,
      FROM
        `focal-elf-631.prod_stream_view.pb`
      JOIN 
        t_app
      ON app.bundle = mmp_bundle_id
      WHERE 1=1
        AND DATE(timestamp) >= start_date AND DATE(timestamp) <= end_date
        AND event_name = 'install'
        AND device.country IN ('KOR', 'USA', 'CAN', 'GBR', 'FRA', 'DEU', 'TWN', 'JPN', 'HKG')
    )
    WHERE user_id IS NOT NULL
    GROUP BY 1,2,3,4,5
    ),

  actions AS (
  SELECT * 
  FROM (
    SELECT
        CASE
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
          WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
          WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
          ELSE NULL
        END AS user_id,
        app_market_bundle,
        mmp_bundle_id,
      timestamp
    FROM
      `focal-elf-631.df_accesslog.pb`
    JOIN 
        t_app
    ON 
        app.bundle = mmp_bundle_id
    WHERE 1=1
      AND DATE(timestamp) >= start_date AND DATE(timestamp) <= DATE_ADD(end_date, INTERVAL 30 DAY)
      AND event.name != 'install'
      AND LOWER(event.name) NOT LIKE "%ltv%"
      AND lower(event.name) NOT IN ('reinstall', 'reattribution')
      AND lower(event.name) NOT LIKE '%conver%'
      AND lower(event.name) NOT LIKE '%pecan%'
      AND device.country IN ('KOR', 'USA', 'CAN', 'GBR', 'FRA', 'DEU', 'TWN', 'JPN', 'HKG')
    )
  WHERE user_id IS NOT NULL
  ),

  T as (
    SELECT
      installs.user_id as inst_user_id,
      actions.user_id as action_user_id,      
      installs.app_market_bundle,
      installs.mmp_bundle_id,
      os,
      installs.region,
      TIMESTAMP_DIFF(actions.timestamp, installs.timestamp, DAY) as day_diff,
      COUNT(DISTINCT installs.user_id) OVER 
        (PARTITION BY installs.app_market_bundle, installs.os, installs.country) AS installs_for_group,
    FROM
      installs
    LEFT JOIN
      actions
    ON
      installs.user_id = installs.user_id
      AND installs.app_market_bundle = actions.app_market_bundle
      AND installs.mmp_bundle_id = actions.mmp_bundle_id
      AND actions.timestamp > installs.timestamp
  )

SELECT
  app_market_bundle,
  mmp_bundle_id,
  os,
  region,
  day_diff,
  ANY_VALUE(installs_for_group) AS installs,
  COUNT(DISTINCT action_user_id) AS retention_for_day
FROM T
WHERE day_diff < 30
GROUP BY
  1,2,3,4,5
ORDER BY
  1,2,3,4,5



### NOL RE Campaign After TVing ###
https://colab.research.google.com/drive/1VB8Yfr_SNfnu6TUcG2l5dMTY15RLW6jT#scrollTo=_EjyhgH_2AVn


  #@title build query with re-engagement event
  start_date = '2025-05-08'
  end_date = '2025-05-28'


  def build_query():

    condition = "AND cv.pb.event.name NOT IN  ('install', 'reengagement', 'reattribution')"

    query_retention = f"""

      DECLARE start_date DATE DEFAULT '{start_date}';
      DECLARE end_date DATE DEFAULT '{end_date}';


      WITH reengagement AS (

        SELECT
          bid.maid,
          api.campaign.id AS campaign_id,
          MIN(timestamp) AS first_reengagement_at
        FROM `focal-elf-631.prod_stream_view.cv`
        WHERE
          LOWER(cv.pb.event.name) = 'reengagement'
          AND DATE(timestamp, 'Asia/Seoul') BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY)
          AND cv.pb.app.bundle = 'com.cultsotry.yanolja.nativeapp'
          AND req.device.geo.country = 'KOR'
          AND api.campaign.id IN ('{campaign_bau}', '{campaign_tving}')
        GROUP BY 1,2

      ),

      actions AS (
        SELECT
          bid.maid,
          api.campaign.id AS campaign_id,
          timestamp AS action_at

        FROM
          `focal-elf-631.prod_stream_view.cv`

        WHERE 1=1
          AND DATE(timestamp) >= start_date AND DATE(timestamp) <= DATE_ADD(end_date, INTERVAL 14 DAY)
          {condition}
          AND cv.pb.app.bundle = 'com.cultsotry.yanolja.nativeapp'
          AND req.device.geo.country = 'KOR'
          AND api.campaign.id IN ('{campaign_bau}', '{campaign_tving}')
        ),

      joined AS (

        SELECT
            reengagement.campaign_id,
            reengagement.maid as reengagement_maid,
            actions.maid as action_maid,
            TIMESTAMP_DIFF(action_at, first_reengagement_at, DAY) as day_diff,
            COUNT(DISTINCT reengagement.maid) OVER
              (PARTITION BY reengagement.campaign_id) AS reengagement_for_group,
          FROM
            reengagement
          LEFT JOIN
            actions
          ON
            reengagement.maid = actions.maid
            AND reengagement.campaign_id = actions.campaign_id
            AND action_at > first_reengagement_at

      )

      SELECT
        day_diff,
        campaign_id,
        ANY_VALUE(reengagement_for_group) AS reengagement_cnt,
        COUNT(DISTINCT action_maid) AS retention_for_day
      FROM joined
      WHERE day_diff < 14
      GROUP BY
        1,2
      ORDER BY
        1,2

    """
    return query_retention
