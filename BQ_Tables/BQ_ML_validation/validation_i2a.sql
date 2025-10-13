-- https://console.cloud.google.com/bigquery?ws=!1m5!1m4!4m3!1smoloco-data-prod!2sml_calibration_check!3svalidation_i2a

-- ml calibration validation ver 2.10 : i2a
-- last modified : 2025/04/21
-- v2.3 : WILDLIFE campaigns are excluded from i2a validation
-- v2.3 : We consider previous 7 days with target date_install to avoid counting mtid in multiple time buckets
-- v2.4 : add campaign_goal_type, os for grouping
-- v2.5 : add type for grouping
-- v2.5 : filter bid.model.prediction_logs[SAFE_OFFSET(1)].type = 'ACTION*' or 'SEC_KPI*'
-- v2.6 : add country for grouping
-- v2.6 : add logloss to summables
-- v2.8 : UNNEST bid.model.prediction_logs not to fix position of install model
-- v2.8 : type for i2a calibration ('ACTION', 'ACTION_GENERAL', 'ACTION_LAT', 'SEC_KPI', 'SEC_KPI_LAT')
-- v2.9 : WILDLIFE campaigns are included
-- v2.10 : add exchange, mmp for grouping

WITH

  ref_campaign_action AS (
    SELECT
      campaign_name AS campaign,
      JSON_VALUE(campaign_goal,'$.type') AS campaign_goal_type,
      kpi_actions,
      LOWER(COALESCE( JSON_EXTRACT_STRING_ARRAY(campaign_goal, "$.optimize_app_roas.revenue_actions"),
        IF(JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action") IS NULL,
        [],
          [JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action")]) )[SAFE_OFFSET(0)]) as kpi_action_1st,
      LOWER(COALESCE( JSON_EXTRACT_STRING_ARRAY(campaign_goal, "$.optimize_app_roas.revenue_actions"),
        IF(JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action") IS NULL,
        [],
          [JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action")]) )[SAFE_OFFSET(1)]) as kpi_action_2nd,
    FROM `focal-elf-631.prod.campaign_digest_merged_20*`
    WHERE _TABLE_SUFFIX = FORMAT_DATE('%y%m%d', DATE('2025-09-09'))
      AND JSON_VALUE(campaign_goal,'$.type') IN ('OPTIMIZE_ROAS_FOR_APP_UA', 'OPTIMIZE_CPA_FOR_APP_UA')
  ),

  table_install_1st_kpi AS (
    SELECT
      bid.mtid AS mtid,
      ANY_VALUE(api.platform.id) AS platform,
      ANY_VALUE(api.product.app.tracking_bundle) AS tracking_bundle,
      ANY_VALUE(api.campaign.id) AS campaign,
      ANY_VALUE(api.product.app.mmp) AS mmp,
      ANY_VALUE(req.exchange) AS exchange,
      ANY_VALUE(req.device.geo.country) AS country,
      ANY_VALUE(req.device.os) AS os,
      ANY_VALUE(plog.type) AS i2a_type,
      ANY_VALUE(plog.prediction_type) AS i2a_prediction_type,
      ANY_VALUE(plog.tf_model_name) AS i2a_tf_model_name,
      ANY_VALUE(plog.context_name) AS i2a_context_name,
      ANY_VALUE(plog.reason) AS i2a_reason,
      ANY_VALUE(plog.pred) AS i2a_pred,
      MIN(timestamp) AS ts_install,
    FROM `focal-elf-631.prod_stream_view.cv` AS t_raw, t_raw.bid.model.prediction_logs AS plog
    WHERE DATE(timestamp) BETWEEN DATE_SUB(DATE('2025-09-09'), INTERVAL 7 DAY) AND DATE('2025-09-09')
      AND cv.event = 'INSTALL'
      AND plog.type IN ('ACTION', 'ACTION_GENERAL', 'ACTION_LAT')
      AND api.campaign.id IN (SELECT campaign FROM ref_campaign_action)
    GROUP BY 1
  ),

  table_install_2nd_kpi AS (
    SELECT
      bid.mtid AS mtid,
      ANY_VALUE(api.platform.id) AS platform,
      ANY_VALUE(api.product.app.tracking_bundle) AS tracking_bundle,
      ANY_VALUE(api.campaign.id) AS campaign,
      ANY_VALUE(api.product.app.mmp) AS mmp,
      ANY_VALUE(req.exchange) AS exchange,
      ANY_VALUE(req.device.geo.country) AS country,
      ANY_VALUE(req.device.os) AS os,
      ANY_VALUE(plog.type) AS i2a_type,
      ANY_VALUE(plog.prediction_type) AS i2a_prediction_type,
      ANY_VALUE(plog.tf_model_name) AS i2a_tf_model_name,
      ANY_VALUE(plog.context_name) AS i2a_context_name,
      ANY_VALUE(plog.reason) AS i2a_reason,
      ANY_VALUE(plog.pred) AS i2a_pred,
      MIN(timestamp) AS ts_install,
    FROM `focal-elf-631.prod_stream_view.cv` AS t_raw, t_raw.bid.model.prediction_logs AS plog
    WHERE DATE(timestamp) BETWEEN DATE_SUB(DATE('2025-09-09'), INTERVAL 7 DAY) AND DATE('2025-09-09')
      AND cv.event = 'INSTALL'
      AND plog.type IN ('SEC_KPI', 'SEC_KPI_LAT')
      AND api.campaign.id IN (SELECT campaign FROM ref_campaign_action)
    GROUP BY 1
  ),

  table_install_before_filtering AS (
    (
      SELECT *,
        IFNULL(SUBSTR(i2a_context_name, STRPOS(i2a_context_name, ':')+1), kpi_action_1st) AS event_pb
      FROM table_install_1st_kpi
        LEFT JOIN ref_campaign_action USING (campaign)
    )
    UNION ALL
    (
      SELECT *,
        IFNULL(SUBSTR(i2a_context_name, STRPOS(i2a_context_name, ':')+1), kpi_action_2nd) AS event_pb
      FROM table_install_2nd_kpi
        LEFT JOIN ref_campaign_action USING (campaign)
    )
  ),
  table_install AS (
    SELECT *,
      (IFNULL(i2a_reason, 'NULL') NOT IN ('tf serving prediction is zero')) AS bool_nontrivial,
    FROM table_install_before_filtering
    WHERE DATE(ts_install) = DATE('2025-09-09')
      AND i2a_pred > 0
      AND i2a_pred < 1
  ),

  table_action AS (
    SELECT
      bid.mtid AS mtid,
      LOWER(cv.event_pb) AS event_pb,
      MIN(timestamp) AS ts_action,
    FROM `focal-elf-631.prod_stream_view.cv`
    WHERE DATE(timestamp) BETWEEN DATE('2025-09-09') AND DATE_ADD(DATE('2025-09-09'), INTERVAL 7 DAY)
      AND cv.event = 'CUSTOM_KPI_ACTION'
      AND api.campaign.id IN (SELECT campaign FROM ref_campaign_action)
    GROUP BY 1, 2
  ),

  table_i2a AS (
    SELECT *,
      (CASE
        WHEN ts_action IS NULL THEN FALSE
        WHEN i2a_prediction_type = 'UNIFIED_D1' THEN (TIMESTAMP_DIFF(ts_action, ts_install, HOUR) < 24)
        WHEN i2a_prediction_type = 'UNIFIED_D3' THEN (TIMESTAMP_DIFF(ts_action, ts_install, HOUR) < 24 * 3)
        ELSE (TIMESTAMP_DIFF(ts_action, ts_install, HOUR) < 24 * 7)
      END) AS bool_conversion_i2a,
    FROM table_install
      LEFT JOIN table_action USING (mtid, event_pb)
  )


SELECT
  DATE(ts_install) AS date_install,
  platform,
  tracking_bundle,
  campaign,
  campaign_goal_type,
  mmp,
  exchange,
  country,
  os,
  event_pb,
  i2a_type AS type,
  i2a_tf_model_name AS tf_model_name,
  bool_nontrivial,
  ROUND(LOG(i2a_pred,10),1) AS pred_bucket_log10,
  COUNT(*) AS cnt_install,
  COUNTIF(bool_conversion_i2a) AS cnt_action,
  SUM(i2a_pred) AS predicted_action,
  (-1) * SUM(IF(bool_conversion_i2a, LOG(i2a_pred), LOG(1 - i2a_pred))) AS logloss,
FROM table_i2a
GROUP BY ALL




#### RETENTION ####
WITH

  ref_campaign_action AS (
    SELECT
      campaign_name AS campaign,
      JSON_VALUE(campaign_goal,'$.type') AS campaign_goal_type,
      kpi_actions,
      LOWER(COALESCE( JSON_EXTRACT_STRING_ARRAY(campaign_goal, "$.optimize_app_roas.revenue_actions"),
        IF(JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action") IS NULL,
        [],
          [JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action")]) )[SAFE_OFFSET(0)]) as kpi_action_1st,
      LOWER(COALESCE( JSON_EXTRACT_STRING_ARRAY(campaign_goal, "$.optimize_app_roas.revenue_actions"),
        IF(JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action") IS NULL,
        [],
          [JSON_VALUE(campaign_goal, "$.optimize_cpa_for_app_ua.action")]) )[SAFE_OFFSET(1)]) as kpi_action_2nd,
    FROM `focal-elf-631.prod.campaign_digest_merged_20*`
    WHERE _TABLE_SUFFIX = FORMAT_DATE('%y%m%d', DATE('2025-09-09'))
      -- AND JSON_VALUE(campaign_goal,'$.type') IN ('OPTIMIZE_ROAS_FOR_APP_UA', 'OPTIMIZE_CPA_FOR_APP_UA')
      AND campaign_name = 'CWejnySh2gCs2WyF'
  ),

  table_install_1st_kpi AS (
    SELECT
      bid.mtid AS mtid,
      ANY_VALUE(api.platform.id) AS platform,
      ANY_VALUE(api.product.app.tracking_bundle) AS tracking_bundle,
      ANY_VALUE(api.campaign.id) AS campaign,
      ANY_VALUE(api.product.app.mmp) AS mmp,
      ANY_VALUE(req.exchange) AS exchange,
      ANY_VALUE(req.device.geo.country) AS country,
      ANY_VALUE(req.device.os) AS os,
      ANY_VALUE(plog.type) AS i2a_type,
      ANY_VALUE(plog.prediction_type) AS i2a_prediction_type,
      ANY_VALUE(plog.tf_model_name) AS i2a_tf_model_name,
      ANY_VALUE(plog.context_name) AS i2a_context_name,
      ANY_VALUE(plog.reason) AS i2a_reason,
      ANY_VALUE(plog.pred) AS i2a_pred,
      MIN(timestamp) AS ts_install,
    FROM `focal-elf-631.prod_stream_view.cv` AS t_raw, t_raw.bid.model.prediction_logs AS plog
    WHERE DATE(timestamp) BETWEEN DATE_SUB(DATE('2025-09-09'), INTERVAL 7 DAY) AND DATE('2025-09-09')
      AND cv.event = 'INSTALL'
      AND plog.type IN ('ACTION', 'ACTION_GENERAL', 'ACTION_LAT')
      AND api.campaign.id IN (SELECT campaign FROM ref_campaign_action)
    GROUP BY 1
  ),

  table_install_2nd_kpi AS (
    SELECT
      bid.mtid AS mtid,
      ANY_VALUE(api.platform.id) AS platform,
      ANY_VALUE(api.product.app.tracking_bundle) AS tracking_bundle,
      ANY_VALUE(api.campaign.id) AS campaign,
      ANY_VALUE(api.product.app.mmp) AS mmp,
      ANY_VALUE(req.exchange) AS exchange,
      ANY_VALUE(req.device.geo.country) AS country,
      ANY_VALUE(req.device.os) AS os,
      ANY_VALUE(plog.type) AS i2a_type,
      ANY_VALUE(plog.prediction_type) AS i2a_prediction_type,
      ANY_VALUE(plog.tf_model_name) AS i2a_tf_model_name,
      ANY_VALUE(plog.context_name) AS i2a_context_name,
      ANY_VALUE(plog.reason) AS i2a_reason,
      ANY_VALUE(plog.pred) AS i2a_pred,
      MIN(timestamp) AS ts_install,
    FROM `focal-elf-631.prod_stream_view.cv` AS t_raw, t_raw.bid.model.prediction_logs AS plog
    WHERE DATE(timestamp) BETWEEN DATE_SUB(DATE('2025-09-09'), INTERVAL 7 DAY) AND DATE('2025-09-09')
      AND cv.event = 'INSTALL'
      AND plog.type IN ('SEC_KPI', 'SEC_KPI_LAT')
      AND api.campaign.id IN (SELECT campaign FROM ref_campaign_action)
    GROUP BY 1
  ),

    table_install_before_filtering AS (
    (
      SELECT *,
        IFNULL(SUBSTR(i2a_context_name, STRPOS(i2a_context_name, ':')+1), kpi_action_1st) AS event_pb
      FROM table_install_1st_kpi
        LEFT JOIN ref_campaign_action USING (campaign)
    )
    UNION ALL
    (
      SELECT *,
        IFNULL(SUBSTR(i2a_context_name, STRPOS(i2a_context_name, ':')+1), kpi_action_2nd) AS event_pb
      FROM table_install_2nd_kpi
        LEFT JOIN ref_campaign_action USING (campaign)
    )
  ),

  table_install AS (
    SELECT *,
      (IFNULL(i2a_reason, 'NULL') NOT IN ('tf serving prediction is zero')) AS bool_nontrivial,
    FROM table_install_before_filtering
    WHERE DATE(ts_install) = DATE('2025-09-09')
      AND i2a_pred > 0
      AND i2a_pred < 1
  ),

  table_action AS (
    SELECT
      bid.mtid AS mtid,
      LOWER(cv.event_pb) AS event_pb_raw,
      '#retention' AS event_pb,
      MIN(timestamp) AS ts_action,
    FROM `focal-elf-631.prod_stream_view.cv`
    WHERE TIMESTAMP_DIFF(timestamp, install.install_at_pb, DAY) = 1
      AND DATE(timestamp) BETWEEN DATE('2025-09-09') AND DATE_ADD(DATE('2025-09-09'), INTERVAL 7 DAY)
      AND LOWER(cv.event) <> 'install'
      AND api.campaign.id IN (SELECT campaign FROM ref_campaign_action)
    GROUP BY 1, 2
  ),

  table_i2a AS (
  SELECT *,
    (CASE
      WHEN ts_action IS NULL THEN FALSE
      WHEN i2a_prediction_type = 'UNIFIED_D1' THEN (TIMESTAMP_DIFF(ts_action, ts_install, HOUR) < 24)
      WHEN i2a_prediction_type = 'UNIFIED_D3' THEN (TIMESTAMP_DIFF(ts_action, ts_install, HOUR) < 24 * 3)
      ELSE (TIMESTAMP_DIFF(ts_action, ts_install, HOUR) < 24 * 7)
    END) AS bool_conversion_i2a,
  FROM table_install
    LEFT JOIN table_action USING (mtid, event_pb)
  )

  SELECT 
  -- *,
  --   event_pb_raw
    COUNT(DISTINCT mtid)
  FROM table_install
    LEFT JOIN table_action USING (mtid, event_pb)
  WHERE ts_action IS NOT NULL

  -- 리텐션 캠페인.. 이벤트가 많다고 무조건 좋은 걸까? 