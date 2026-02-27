
Winner studio custom event
100%
H2

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

WITH
  # raw table with all data
  event_t AS (
  SELECT * 
  FROM `focal-elf-631.prod_stream_view.pb`
  WHERE
    timestamp BETWEEN TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR), HOUR) - INTERVAL 7 DAY AND TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR), HOUR)
    AND app.bundle IN ("id6456324252")
    AND device.country = 'USA'
  ),
 
  # installs only
  install_event AS (
  SELECT 
    event.event_at AS install_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id
  FROM event_t
  WHERE LOWER(event.name) = "install" 
  ),

  # purchase only
  purchase_event AS (
  SELECT 
    event.event_at AS purchase_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id,
    event.revenue_usd.amount AS revenue
  FROM event_t
  WHERE LOWER(event.name) = "af_purchase" 
  ),
  
  # derived day x ltv
  ltv AS (
  SELECT 
    purchase_event.user_match_id,
    purchase_time,
    purchase_event.bundle,
    SUM(CASE WHEN DATE_DIFF(purchase_time,install_time,day) BETWEEN 0 AND 6 THEN revenue ELSE 0 END)
      OVER(PARTITION BY purchase_event.user_match_id ORDER BY purchase_time ASC) AS d7_ltv
  FROM install_event
  INNER JOIN purchase_event
  ON install_event.user_match_id = purchase_event.user_match_id
    AND install_event.bundle = purchase_event.bundle
  WHERE install_event.user_match_id IS NOT NULL
  ),

  # raw purchase events
  raw AS (
  SELECT *
  FROM `focal-elf-631.df_accesslog.pb_raw`
  WHERE timestamp BETWEEN TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR), HOUR) AND TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR), HOUR)
    AND LOWER(event.name) = "af_purchase" 
    AND app.bundle IN ("id6456324252")
    AND device.country = 'USA'
  )


# raw purchase events where day x ltv >= y, select only one hour purchase events to avoid duplications over previous run 
SELECT raw.*, 'wj_ios_purchase_value_d7_80' AS new_event_name
FROM raw
INNER JOIN ltv
ON CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END = ltv.user_match_id
AND raw.event.event_at = ltv.purchase_time
WHERE d7_ltv >= 80
;




DECLARE
  BIN_NUMBERS INT64 DEFAULT 20;
DECLARE
  _start_date DATE DEFAULT ""2025-07-04"";
DECLARE
  _end_date DATE DEFAULT ""2025-08-17"";
DECLARE
  _ctrl_id INT64 DEFAULT 10557;
DECLARE
  _test_id INT64 DEFAULT 10558;
WITH
  camp_list AS (
  SELECT
    campaign_name AS campaign_id,
    product_name AS product_id,
    JSON_VALUE(campaign_goal, '$.type') AS campaign_goal
  FROM
    `focal-elf-631.prod.campaign_digest_merged_latest`
  WHERE
    JSON_VALUE(campaign_goal, '$.type') IN (""OPTIMIZE_CPI_FOR_APP_UA"",
      ""OPTIMIZE_CPA_FOR_APP_UA"",
      ""OPTIMIZE_ROAS_FOR_APP_UA"") ),
  dim2_product_t AS (
  SELECT
    JSON_VALUE(original_json, '$.inventory_feature.acs_type') AS acs_type,
    `date` AS date_utc,
    JSON_VALUE(digest_json, '$.id') AS product_id,
  FROM
    `ads-bpd-guard-china.standard_digest.history_digest`
  WHERE
    type = 'PRODUCT'
    AND `date` >= _start_date
    AND `date` <= _end_date
    AND platform != 'MOLOCO'),
  acs_type_t AS (
  SELECT
    date_utc,
    product_id,
    acs_type
  FROM
    dim2_product_t
  GROUP BY
    ALL
  QUALIFY
    ROW_NUMBER() OVER (PARTITION BY product_id, date_utc ORDER BY acs_type DESC) = 1 ),
  acs_campaign_t AS (
  SELECT
    date_utc,
    product_id,
    campaign_id,
    acs_type,
    campaign_goal
  FROM
    acs_type_t
  INNER JOIN
    camp_list
  USING
    (product_id) ),
  basic_summary AS (
  SELECT
    utc_date,
    -- IF(is_lat, 'LAT', 'IDFA') AS traffic_type,
    os,
    cr_format,
    exp_group_id,
    campaign_id,
    bin_number,
    SUM(total_moloco_spent) total_moloco_spent,
    SUM(count_install) count_install,
    SUM(count_distinct_kpi_d7) count_distinct_kpi_d7,
    SUM(total_revenue_kpi_d7) total_revenue_kpi_d7,
    SUM(total_capped_revenue_kpi_d7) total_capped_revenue_kpi_d7,
  FROM
    `explab-298609.summary_v2.experiment_summary` experiment_summary
  WHERE
    utc_date BETWEEN _start_date
    AND _end_date
    AND exp_group_id IN (_ctrl_id,
      _test_id)
      AND EXISTS (
  SELECT 1
  FROM acs_campaign_t
  WHERE acs_type = 'ACS_STANDARD_RECOMMENDED'
    AND acs_campaign_t.date_utc = experiment_summary.utc_date
    AND acs_campaign_t.campaign_id = experiment_summary.campaign_id
)
    -- AND (utc_date,
    --   campaign_id) IN (
    -- SELECT
    --   (utc_date,
    --     campaign_id)
    -- FROM (
    --   SELECT
    --     date_utc AS utc_date,
    --     campaign_id
    --   FROM
    --     acs_type_t
    --   WHERE
    --     acs_type = 'ACS_STANDARD_RECOMMENDED'
    --   GROUP BY
    --     ALL))
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6 ),
  paired_summary AS (
  SELECT
    campaign_id,
    bin_number,
    os,
    cr_format,
    SUM(
    IF
      (exp_group_id=_ctrl_id, total_moloco_spent, 0)) AS ctrl_spent,
    SUM(
    IF
      (exp_group_id=_ctrl_id, count_install, 0)) AS ctrl_install,
    SUM(
    IF
      (exp_group_id=_ctrl_id, count_distinct_kpi_d7, 0)) AS ctrl_d7_action,
    SUM(
    IF
      (exp_group_id=_ctrl_id, total_revenue_kpi_d7, 0)) AS ctrl_d7_revenue,
    SUM(
    IF
      (exp_group_id=_ctrl_id, total_capped_revenue_kpi_d7, 0)) AS ctrl_d7_crevenue,
    SUM(
    IF
      (exp_group_id=_test_id, total_moloco_spent, 0)) AS test_spent,
    SUM(
    IF
      (exp_group_id=_test_id, count_install, 0)) AS test_install,
    SUM(
    IF
      (exp_group_id=_test_id, count_distinct_kpi_d7, 0)) AS test_d7_action,
    SUM(
    IF
      (exp_group_id=_test_id, total_revenue_kpi_d7, 0)) AS test_d7_revenue,
    SUM(
    IF
      (exp_group_id=_test_id, total_capped_revenue_kpi_d7, 0)) AS test_d7_crevenue,
  FROM
    basic_summary
  GROUP BY
    1,
    2,
    3,
    4 ),
  final_summary AS (
  SELECT
    campaign_id,
    os,
    cr_format,
    campaign_goal,
    bin_number,
    SUM(ctrl_spent) ctrl_spent,
    SUM(ctrl_install) installs_ctrl,
    SUM(ctrl_d7_action) d7_payer_ctrl,
    SUM(ctrl_d7_revenue) d7_revenue_ctrl,
    SUM(ctrl_d7_crevenue) d7_capped_revenue_ctrl,
    SUM(test_spent) test_spent,
    SUM(test_install) installs_test,
    SUM(test_d7_action) d7_payer_test,
    SUM(test_d7_revenue) d7_revenue_test,
    SUM(test_d7_crevenue) d7_capped_revenue_test
  FROM
    paired_summary
  JOIN
    camp_list
  USING
    (campaign_id)
  CROSS JOIN
    UNNEST([TRUE, FALSE]) AS agg_traffic_type
  GROUP BY
    1,
    2,
    3,
    4,
    5 ),
  target_combinations AS (
  SELECT
    campaign_id,
    os,
    cr_format,
    campaign_goal,
    bin_number,
    metric_type,
    test_spent AS test_metric_d,
    ctrl_spent AS ctrl_metric_d,
    test_metric_n,
    ctrl_metric_n
  FROM
    final_summary
  CROSS JOIN
    UNNEST( -- Unpivot metric summary
      [ STRUCT(""CPD_INSTALL"" AS metric_type,
        CAST(installs_test AS FLOAT64) AS test_metric_n,
        CAST(installs_ctrl AS FLOAT64) AS ctrl_metric_n), STRUCT(""CPD_DIST_ACT_D7"" AS metric_type,
        CAST(d7_payer_test AS FLOAT64) AS test_metric_n,
        CAST(d7_payer_ctrl AS FLOAT64) AS ctrl_metric_n), STRUCT(""ROAS_D7"" AS metric_type,
        d7_revenue_test AS test_metric_n,
        d7_revenue_ctrl AS ctrl_metric_n), STRUCT(""cROAS_D7"" AS metric_type,
        d7_capped_revenue_test AS test_metric_n,
        d7_capped_revenue_ctrl AS ctrl_metric_n) ] ) ),
  stat_summary AS (
  SELECT
    os,
    cr_format,
    campaign_goal,
    metric_type,
    `explab-298609.sangyeon.bayesian_1b_testing_method`( ARRAY_AGG(STRUCT( campaign_id,
          bin_number,
          test_metric_d,
          test_metric_n,
          ctrl_metric_d,
          ctrl_metric_n )),
      BIN_NUMBERS # bin_numbers
      ) AS stat
  FROM
    target_combinations
  WHERE
    (test_metric_d>0
      OR ctrl_metric_d>0)
    AND ( (campaign_goal = ""OPTIMIZE_ROAS_FOR_APP_UA""
        AND metric_type IN (""ROAS_D7"",
          ""cROAS_D7"",
          ""CPD_DIST_ACT_D7"",
          ""CPD_INSTALL""))
      OR (campaign_goal = ""OPTIMIZE_CPA_FOR_APP_UA""
        AND metric_type IN (""CPD_DIST_ACT_D7"",
          ""CPD_INSTALL""))
      OR (campaign_goal = ""OPTIMIZE_CPI_FOR_APP_UA""
        AND metric_type IN (""CPD_INSTALL"")) )
  GROUP BY
    1,
    2,
    3,
    4 )
SELECT
  os,
  cr_format,
  campaign_goal,
  metric_type,
  stat.campaign_stat.total_eligible,
  stat.test_statistic.estimate AS point_est,
  ROUND(`explab-298609.udf.get_conf_int`(0.95,
      stat.test_statistic)[SAFE_OFFSET(1)], 4) AS lb,
  ROUND(`explab-298609.udf.get_conf_int`(0.95,
      stat.test_statistic)[SAFE_OFFSET(2)], 4) AS ub,
IF
  ( `explab-298609.udf.get_conf_int`(0.95,
      stat.test_statistic)[SAFE_OFFSET(1)]>1
    OR `explab-298609.udf.get_conf_int`(0.95,
      stat.test_statistic)[SAFE_OFFSET(2)]<1, TRUE, FALSE ) statsig,
  stat.test_statistic.log_transform_std_err AS log_std_err
FROM
  stat_summary
ORDER BY
  3,
  2,
  1,
  4"