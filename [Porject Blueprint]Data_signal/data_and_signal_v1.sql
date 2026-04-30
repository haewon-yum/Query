-- ============================================
-- RAW DATA
-- ============================================
WITH normalized_pb_data AS (
    SELECT
      timestamp,
      mmp.name AS mmp,
    IF
      (NULLIF(attribution.method, '') IS NOT NULL, attribution.method, "UNKNOWN") AS attribution_method,
      attribution.attributed AS moloco_attributed,
      device.os AS os,
      attribution.view_through AS is_vt,
      NOT `moloco-ods.general_utils.is_userid_truly_available`(device.idfa) AS is_lat,
      app.bundle AS app_bundle,
      device.country AS country,
      mmp.event_source AS event_source,
    IF
      (LOWER(event.name) = 'install', 'install',
      IF
        (event.revenue_raw.amount > 0
          AND (LOWER(event.name) LIKE "%adrevenue%"
            OR LOWER(event.name) LIKE "%ad_revenue%"), 'ad_revenue',
        IF
          (event.revenue_raw.amount > 0, "revenue", "in_app_action"))) AS event_type,
      NULLIF(device.model, '') AS dev_model,
      NULLIF(`moloco-ods.general_utils.normalize_dev_language`(device.language), '') AS dev_lang,
      NULLIF(`moloco-ods.general_utils.normalize_ip`(device.ip), '') AS dev_ip,
      NULLIF(device.ua, '') AS dev_ua,
      NULLIF(`moloco-ods.general_utils.normalize_dev_osv`(device.osv), '') AS dev_osv,
      NULLIF(device.idfv, '') AS dev_idfv,
      NULLIF(device.language, '') AS raw_dev_lang,
      NULLIF(device.ip, '') AS raw_dev_ip,
      NULLIF(device.osv, '') AS raw_dev_osv
    FROM
      `focal-elf-631.df_accesslog.pb`
    WHERE
      DATE(TIMESTAMP) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
),

normalized_pb_data_validation AS (
    SELECT
      *,
      dev_model IS NOT NULL
      AND LOWER(dev_model) NOT IN ('iphone',
        'ipad',
        'ipod') AS valid_dev_model,
      dev_lang IS NOT NULL AS valid_dev_lang,
      dev_ip IS NOT NULL
      AND NOT ENDS_WITH(dev_ip, '.0') AS valid_dev_ip,
      dev_ua IS NOT NULL AS valid_dev_ua,
      dev_osv IS NOT NULL AS valid_dev_osv,
      dev_idfv IS NOT NULL AS valid_dev_idfv,
      dev_model IS NULL AS null_dev_model,
      raw_dev_lang IS NULL AS null_dev_lang,
      raw_dev_osv IS NULL AS null_dev_osv,
      raw_dev_ip IS NULL AS null_dev_ip
    FROM
      normalized_pb_data ),

mmp_identity_signal_availability AS (
  SELECT
      mmp,
      attribution_method,
      moloco_attributed,
      os,
      is_vt,
      is_lat,
      app_bundle,
      country,
      event_source,
      event_type,
      COUNT(
      IF
        (valid_dev_model, 1,NULL)) AS available_dev_model,
      COUNT(
      IF
        (valid_dev_lang, 1,NULL)) AS available_dev_lang,
      COUNT(
      IF
        (valid_dev_ip, 1, NULL)) AS available_dev_ip,
      COUNT(
      IF
        (valid_dev_ua, 1,NULL)) AS available_dev_ua,
      COUNT(
      IF
        (valid_dev_osv, 1,NULL)) AS available_dev_osv,
      COUNT(
      IF
        (valid_dev_idfv, 1,NULL)) AS available_dev_idfv,
      COUNT(
      IF
        (null_dev_model, 1,NULL)) AS null_dev_model_cnt,
      COUNT(
      IF
        (null_dev_lang, 1,NULL)) AS null_dev_lang_cnt,
      COUNT(
      IF
        (null_dev_ip, 1, NULL)) AS null_dev_ip_cnt,
      COUNT(
      IF
        (null_dev_osv, 1,NULL)) AS null_dev_osv_cnt,
      COUNT(*) AS total_pb_cnt,
      COUNT(
      IF
        (valid_dev_lang
          AND valid_dev_osv
          AND valid_dev_model
          AND valid_dev_ip, 1, NULL)) AS exists_full_feature_set,
    FROM
      normalized_pb_data_validation
    WHERE
      DATE(TIMESTAMP) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
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
      10
),

base_metrics AS (
  SELECT
     app_bundle,
     os,
     is_lat,
     COALESCE(SUM(available_dev_osv), 0) AS available_dev_osv,
     COALESCE(SUM(available_dev_idfv), 0) AS available_dev_idfv,
     COALESCE(SUM(available_dev_ip), 0) AS available_dev_ip,
     COALESCE(SUM(available_dev_lang), 0) AS available_dev_lang,
     COALESCE(SUM(available_dev_model), 0) AS available_dev_model,
     COALESCE(SUM(exists_full_feature_set), 0) AS exists_full_feature_set,
     COALESCE(SUM(total_pb_cnt), 0) AS total_pb_cnt
  FROM mmp_identity_signal_availability
  WHERE 
    mmp IN ('ADJUST', 'APPSFLYER', 'BRANCH', 'SINGULAR') 
     AND attribution_method IN ('UNKNOWN', 'fingerprint', 'identifier', 'probabilistic')
     AND event_type IN ('ad_revenue', 'in_app_action', 'install', 'revenue')
  GROUP BY 1, 2, 3
),

-- ============================================
-- BUNDLE-LEVEL METRICS
-- ============================================
signal_quality_tab AS (
  SELECT
    app_bundle,
    os,
    SAFE_DIVIDE(COALESCE(total_pb_cnt_false, 0), COALESCE(total_pb_cnt_false + total_pb_cnt_true, 0)) AS idfa_pb_pct,
    -- Calculate percentages using pivoted columns
    SAFE_DIVIDE(COALESCE(available_dev_osv_true, 0), COALESCE(total_pb_cnt_true, 0)) AS available_dev_osv_pct_lat,
    SAFE_DIVIDE(COALESCE(available_dev_idfv_true, 0), COALESCE(total_pb_cnt_true, 0)) AS available_dev_idfv_pct_lat,
    SAFE_DIVIDE(COALESCE(available_dev_ip_true, 0), COALESCE(total_pb_cnt_true, 0)) AS available_dev_ip_pct_lat,
    SAFE_DIVIDE(COALESCE(available_dev_lang_true, 0), COALESCE(total_pb_cnt_true, 0)) AS available_dev_lang_pct_lat,
    SAFE_DIVIDE(COALESCE(available_dev_model_true, 0), COALESCE(total_pb_cnt_true, 0)) AS available_dev_model_pct_lat,
    SAFE_DIVIDE(COALESCE(exists_full_feature_set_true, 0), COALESCE(total_pb_cnt_true, 0)) AS exists_full_feature_set_pct_lat,
    SAFE_DIVIDE(COALESCE(available_dev_osv_false, 0), COALESCE(total_pb_cnt_false, 0)) AS available_dev_osv_pct_idfa,
    SAFE_DIVIDE(COALESCE(available_dev_idfv_false, 0), COALESCE(total_pb_cnt_false, 0)) AS available_dev_idfv_pct_idfa,
    SAFE_DIVIDE(COALESCE(available_dev_ip_false, 0), COALESCE(total_pb_cnt_false, 0)) AS available_dev_ip_pct_idfa,
    SAFE_DIVIDE(COALESCE(available_dev_lang_false, 0), COALESCE(total_pb_cnt_false, 0)) AS available_dev_lang_pct_idfa,
    SAFE_DIVIDE(COALESCE(available_dev_model_false, 0), COALESCE(total_pb_cnt_false, 0)) AS available_dev_model_pct_idfa,
  FROM base_metrics
  PIVOT(
    SUM(available_dev_osv) AS available_dev_osv,
    SUM(available_dev_idfv) AS available_dev_idfv,
    SUM(available_dev_ip) AS available_dev_ip,
    SUM(available_dev_lang) AS available_dev_lang,
    SUM(available_dev_model) AS available_dev_model,
    SUM(exists_full_feature_set) AS exists_full_feature_set,
    SUM(total_pb_cnt) AS total_pb_cnt
    FOR is_lat IN (TRUE, FALSE)
  )
),

unattributed_tab AS (
  SELECT
    app_bundle AS mmp_bundle_id,
    os,
    COUNTIF(NOT moloco_attributed) AS unattributed_installs_count,
    IF(COUNTIF(NOT moloco_attributed) > 0, TRUE, FALSE) AS unattributed_installs,
  FROM normalized_pb_data
  WHERE event_type = 'install'
  GROUP BY 1, 2
),

pa_tab AS (
  SELECT
    app_bundle AS mmp_bundle_id,
    os,
    IF(SUM(IF(attribution_method IN ('probabilistic', 'fingerprint'), 1, 0)) > 0, TRUE, FALSE) AS pa_enabled
  FROM normalized_pb_data
  WHERE event_type = 'install'
    AND moloco_attributed
    AND os = 'IOS'
  GROUP BY 1, 2
),

-- ============================================
-- CAMPAIGN INFO - Get campaign to bundle mapping
-- ============================================
bundle_info AS (
  SELECT DISTINCT
    campaign_id,
    advertiser.mmp_bundle_id,
    campaign.os
  FROM `ads-bpd-guard-china.athena.fact_dsp_core`
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
),

-- ============================================
-- CALCULATE ALL SCORES
-- ============================================
all_scores AS (
  SELECT
    bi.*,
    
    -- Signal Quality Score Components
    COALESCE(idfa_pb_pct, 0) AS idfa_pct,
    COALESCE(available_dev_osv_pct_lat, 0) AS osv_pct,
    COALESCE(available_dev_idfv_pct_lat, 0) AS idfv_pct,
    COALESCE(available_dev_ip_pct_lat, 0) AS ip_pct,
    COALESCE(available_dev_lang_pct_lat, 0) AS lang_pct,
    COALESCE(available_dev_model_pct_lat, 0) AS model_pct,
    
    -- ScoreLAT calculation: (osv_pct + idfv_pct + ip_pct + lang_pct + model_pct) / 5
    (COALESCE(available_dev_osv_pct_lat, 0) + 
     COALESCE(available_dev_idfv_pct_lat, 0) + 
     COALESCE(available_dev_ip_pct_lat, 0) + 
     COALESCE(available_dev_lang_pct_lat, 0) + 
     COALESCE(available_dev_model_pct_lat, 0)) / 5 AS score_lat,
    
    -- Signal Quality Score: idfa_pct + (1 - idfa_pct) * ScoreLAT
    ROUND(100 * (
      COALESCE(idfa_pb_pct, 0) + 
      (1 - COALESCE(idfa_pb_pct, 0)) * 
      ((COALESCE(available_dev_osv_pct_lat, 0) + 
        COALESCE(available_dev_idfv_pct_lat, 0) + 
        COALESCE(available_dev_ip_pct_lat, 0) + 
        COALESCE(available_dev_lang_pct_lat, 0) + 
        COALESCE(available_dev_model_pct_lat, 0)) / 5)
    ), 2) AS signal_quality_score,
    
    -- Unattributed Score: 0 if FALSE, 100 if TRUE
    IF(COALESCE(ua.unattributed_installs, FALSE), 100, 0) AS unattributed_score,
    
    -- PA Score: Android defaults to 100, iOS evaluated based on data
    IF(bi.os != 'IOS', 100,
      IF(COALESCE(pa.pa_enabled, FALSE), 100, 0)
    ) AS pa_score,
    
    -- Detail fields
    ua.unattributed_installs,
    ua.unattributed_installs_count,
    pa.pa_enabled,
    
    -- Recommendation strings
    CASE
      WHEN ROUND(100 * (
        COALESCE(idfa_pb_pct, 0) + 
        (1 - COALESCE(idfa_pb_pct, 0)) * 
        ((COALESCE(available_dev_osv_pct_lat, 0) + 
          COALESCE(available_dev_idfv_pct_lat, 0) + 
          COALESCE(available_dev_ip_pct_lat, 0) + 
          COALESCE(available_dev_lang_pct_lat, 0) + 
          COALESCE(available_dev_model_pct_lat, 0)) / 5)
      ), 2) >= 80 THEN 'Signal quality is strong. Most postbacks have IDFA, or key LAT features.'
      WHEN ROUND(100 * (
        COALESCE(idfa_pb_pct, 0) + 
        (1 - COALESCE(idfa_pb_pct, 0)) * 
        ((COALESCE(available_dev_osv_pct_lat, 0) + 
          COALESCE(available_dev_idfv_pct_lat, 0) + 
          COALESCE(available_dev_ip_pct_lat, 0) + 
          COALESCE(available_dev_lang_pct_lat, 0) + 
          COALESCE(available_dev_model_pct_lat, 0)) / 5)
      ), 2) >= 50 THEN 'Improve LAT signal quality - check OSV, IDFV, IP, Lang, Model availability'
      ELSE 'Warning: Low LAT signal quality - identity signals are chronically missing'
    END AS signal_quality_recommendations,
    
    CASE
      WHEN COALESCE(ua.unattributed_installs, FALSE) THEN 'Unattributed installs are being received'
      ELSE 'No unattributed installs detected'
    END AS unattributed_recommendations,
    
    CASE
      WHEN bi.os != 'IOS' THEN 'Not applicable for Android'
      WHEN COALESCE(pa.pa_enabled, FALSE) THEN 'Probabilistic attribution is enabled'
      ELSE 'Enable probabilistic attribution for better coverage'
    END AS pa_recommendations
    
  FROM bundle_info bi
  LEFT JOIN signal_quality_tab sq 
    ON bi.mmp_bundle_id = app_bundle 
    AND bi.os = sq.os
  LEFT JOIN unattributed_tab ua 
    ON bi.mmp_bundle_id = ua.mmp_bundle_id
    AND bi.os = ua.os
  LEFT JOIN pa_tab pa 
    ON bi.mmp_bundle_id = pa.mmp_bundle_id
    AND bi.os = pa.os
),

overall_scores AS (
  SELECT
    *,
    -- Overall Bundle Score: average of the three scores
    ROUND((signal_quality_score + unattributed_score + pa_score) / 3, 2) AS overall_campaign_score
  FROM all_scores
)

-- ============================================
-- FINAL OUTPUT - VERTICAL FORMAT
-- ============================================
SELECT * FROM (
  -- Signal Quality
  SELECT
    campaign_id,
    mmp_bundle_id,
    '1_signal_quality' AS blueprint_index,
    signal_quality_score AS score,
    CONCAT(
      'IDFA: ', CAST(ROUND(idfa_pct * 100, 1) AS STRING), '% | ',
      'ScoreOSV: ', CAST(ROUND(osv_pct * 100, 1) AS STRING), '%',
      'ScoreIDFV: ', CAST(ROUND(idfv_pct * 100, 1) AS STRING), '%',
      'ScoreIP: ', CAST(ROUND(ip_pct * 100, 1) AS STRING), '%',
      'ScoreDevLang: ', CAST(ROUND(lang_pct * 100, 1) AS STRING), '%',
      'ScoreDevModel: ', CAST(ROUND(model_pct * 100, 1) AS STRING), '%'
    ) AS detail,
    signal_quality_recommendations AS recommendations,
    overall_campaign_score
  FROM overall_scores
  GROUP BY ALL
  
  UNION ALL
  
  -- Unattributed Installs
  SELECT
    campaign_id,
    mmp_bundle_id,
    '2_unattributed_installs' AS blueprint_index,
    unattributed_score AS score,
    CASE 
      WHEN unattributed_installs THEN CONCAT('Unattributed: ', CAST(unattributed_installs_count AS STRING), ' installs')
      ELSE 'No unattributed installs'
    END AS detail,
    unattributed_recommendations AS recommendations,
    overall_campaign_score
  FROM overall_scores
  GROUP BY ALL
  
  UNION ALL
  
  -- Probabilistic Attribution
  SELECT
    campaign_id,
    mmp_bundle_id,
    '3_probabilistic_attribution' AS blueprint_index,
    pa_score AS score,
    CASE 
      WHEN os != 'IOS' THEN 'Not applicable for Android'
      WHEN pa_enabled THEN 'PA Enabled'
      ELSE 'PA Disabled'
    END AS detail,
    pa_recommendations AS recommendations,
    overall_campaign_score
  FROM overall_scores
  GROUP BY ALL
)
ORDER BY mmp_bundle_id, blueprint_index