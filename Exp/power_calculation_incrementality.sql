# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
# Power calculation based on historical conversion and reach - KPI_ACTION

DECLARE _target_countries ARRAY<STRING> DEFAULT ['DEU', 'FRA','ESP'];
DECLARE _app_bundle STRING DEFAULT ""de.traderepublic.app"";
DECLARE _tracking_company STRING DEFAULT ""ADJUST"";
DECLARE kpi_action_ STRING DEFAULT 'mlc_onboarding_completed_backend';
DECLARE _date DATE DEFAULT CURRENT_DATE();
DECLARE _start_date DATE DEFAULT DATE_SUB(_date, INTERVAL 14 DAY);
DECLARE _end_date DATE DEFAULT DATE_SUB(_date, INTERVAL 1 DAY);

WITH digest AS (
  SELECT 
  campaign_name AS campaign_id,
  tracking_bundle
  FROM `focal-elf-631.prod.campaign_digest_merged_latest`
  WHERE type = 'APP_USER_ACQUISITION' 
    AND tracking_bundle = _app_bundle
),
spend AS (
  SELECT 
  country,
  COUNT(DISTINCT date_utc) AS spending_days,
  SUM(total_moloco_spent) AS total_moloco_spent,
  SUM(count_install) AS count_install
  FROM (
    SELECT 
    date_utc,
    campaign_id,
    campaign.country as country,
    SUM(media_cost_usd) total_moloco_spent,
    SUM(installs) AS count_install
    FROM `moloco-ae-view.athena.fact_dsp_daily`
    WHERE date_utc BETWEEN _start_date AND _end_date
      AND campaign.country IN UNNEST(_target_countries) 
      AND campaign_id IN (SELECT DISTINCT campaign_id FROM digest)
    GROUP BY 1,2,3
    HAVING total_moloco_spent > 0
  ) JOIN digest USING (campaign_id)
  GROUP BY 1
  HAVING spending_days = DATE_DIFF(_end_date, _start_date, DAY)+1
    AND count_install > 100
),
target_user AS (
  SELECT 
  req.device.country,
  req.device.idfa,
  MIN(timestamp) AS targeted_ts
  FROM (
    SELECT 
      *
    FROM `focal-elf-631.df_bid.bid_dump_*`
    WHERE PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) BETWEEN _start_date AND _end_date
      AND req.device.os = 'ANDROID'
      AND req.device.id_type = 'ANDROID_IDFA'
      AND bid.campaign IN (SELECT DISTINCT campaign_id FROM digest)
      AND req.device.country IN UNNEST(_target_countries) 
  ) bid_log
  GROUP BY 1,2
),
pb_install AS (
  SELECT 
  device.ifa AS idfa,
  app.bundle AS tracking_bundle,
  MIN(timestamp) AS pb_install_ts,
  FROM `focal-elf-631.prod_stream_view.pb`
  WHERE DATE(timestamp) BETWEEN _start_date AND _end_date
    AND LOWER(event.name) = 'install'
    AND app.bundle = _app_bundle
    AND mmp.name = _tracking_company
    AND device.os = 'ANDROID'
    AND device.ifa IS NOT NULL 
    AND device.ifa NOT IN ('', '0000-0000', '00000000-0000-0000-0000-000000000000')
  GROUP BY 1,2
),
cv_install AS (
  SELECT
      req.device.ifa AS idfa,
      MIN(timestamp) AS cv_install_ts
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE DATE(timestamp) BETWEEN _start_date AND _end_date
      AND lower(cv.event) = 'install'
      AND api.product.app.tracking_bundle = _app_bundle
      AND NOT req.device.lmt
      AND req.device.os = 'ANDROID'
      AND api.campaign.id IN (SELECT DISTINCT campaign_id FROM digest)
  GROUP BY 1
),
pb_action AS (
  SELECT
  device.idfa AS idfa,
  app.bundle AS tracking_bundle,
  MIN(timestamp) AS pb_action_ts,
  FROM `focal-elf-631.df_accesslog.pb` # for full unattr pb
  WHERE DATE(timestamp) BETWEEN _start_date AND _end_date
    AND LOWER(event.name) = kpi_action_
    AND app.bundle = _app_bundle
    AND mmp.name = _tracking_company
    AND device.os = 'ANDROID'
    AND device.idfa IS NOT NULL
    AND device.country IN UNNEST(_target_countries) #
    AND device.idfa NOT IN ('', '0000-0000', '00000000-0000-0000-0000-000000000000')
  GROUP BY 1,2
),
cv_action AS (
  SELECT
      req.device.ifa AS idfa,
      MIN(timestamp) AS cv_action_ts,
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE DATE(timestamp) BETWEEN _start_date AND _end_date
      AND LOWER(cv.event_pb) = kpi_action_
      AND api.product.app.tracking_bundle = _app_bundle
      AND NOT req.device.lmt
      AND req.device.os = 'ANDROID'
      AND api.campaign.id IN (SELECT DISTINCT campaign_id FROM digest)
  GROUP BY 1
),
pb_i2a AS (
  SELECT 
    pb_install.idfa,
    ANY_VALUE(pb_install_ts) AS pb_install_ts,
    COUNT(DISTINCT pb_action.idfa) AS pb_d7_distinct_action,
    COUNT(pb_action.idfa) AS pb_d7_action 
  FROM pb_install LEFT JOIN pb_action 
  ON pb_install.idfa = pb_action.idfa
    AND pb_action_ts BETWEEN pb_install_ts AND TIMESTAMP_ADD(pb_install_ts, INTERVAL 7 DAY)
  GROUP BY 1
),
cv_i2a AS (
  SELECT 
    cv_install.idfa,
    ANY_VALUE(cv_install_ts) AS cv_install_ts,
    COUNT(DISTINCT cv_action.idfa) AS cv_d7_distinct_action,
    COUNT(cv_action.idfa) AS cv_d7_action 
  FROM cv_install LEFT JOIN cv_action 
  ON cv_install.idfa = cv_action.idfa
    AND cv_action_ts BETWEEN cv_install_ts AND TIMESTAMP_ADD(cv_install_ts, INTERVAL 7 DAY)
  GROUP BY 1
)

SELECT 
  country, target_user, pb_install_user, moloco_install_user,
  pb_d7_distinct_action,cv_d7_distinct_action,
  pb_d7_action, cv_d7_action, 
  total_moloco_spent, count_install
FROM (
  SELECT 
  country,
  COUNT(DISTINCT target_user.idfa) AS target_user,
  COUNT(DISTINCT pb_i2a.idfa) AS pb_install_user,
  COUNT(DISTINCT cv_i2a.idfa) AS moloco_install_user,
  SUM(pb_d7_distinct_action) AS pb_d7_distinct_action,
  SUM(cv_d7_distinct_action) AS cv_d7_distinct_action,
  SUM(pb_d7_action) AS pb_d7_action,
  SUM(cv_d7_action) AS cv_d7_action
  FROM target_user LEFT JOIN pb_i2a USING (idfa)
  LEFT JOIN cv_i2a USING (idfa)
  GROUP BY 1
)
LEFT JOIN spend USING (country)
ORDER BY country

