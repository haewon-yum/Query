-- explab-298609.summary_v2.cmh_aggregation

( 
  WITH campaign_level_summary AS (
    SELECT
      campaign_id,
      IFNULL((test_spent > 0 AND control_spent > 0), FALSE) has_spent,
      IFNULL((test_d > 0 AND control_d > 0), FALSE) has_denominator,
      IFNULL((test_n > 0 AND control_n > 0), FALSE) has_conv,
      IFNULL(test_d, 0) AS test_d,
      IFNULL(test_n, 0) AS test_n,
      IFNULL(control_d, 0) AS control_d,
      IFNULL(control_n, 0) AS control_n,
      SAFE_DIVIDE(test_n*control_d, test_d*control_n) AS ratio
    FROM UNNEST(metric_info)
  ),
  cmh_summary AS (
    SELECT
      COUNT(*) total_eligible_campaign,
      COUNTIF(NOT has_spent) AS zero_spending_campaign,
      IF(metric_type = 'VT_RATIO', 
          COUNTIF(has_spent AND NOT has_denominator), 
          COUNTIF(has_spent AND NOT has_conv)
      ) AS zero_conversion_campaign,
      COUNTIF(has_spent AND has_conv AND ratio >= 1) AS positive_effect_campaign,
      COUNTIF(has_spent AND has_conv AND ratio < 1) AS negative_effect_campaign,
      IF(
        metric_type='VT_RATIO',
        `explab-298609.udf.cmh_risk_ratio`(ARRAY_AGG(STRUCT(CAST(control_d AS INT64), CAST(test_d AS INT64), control_n, test_n))),
        `explab-298609.udf.cmh_rate_ratio`(ARRAY_AGG(STRUCT(control_d, test_d, control_n, test_n)))
        ) AS cmh_ratio
    FROM campaign_level_summary
  )
  SELECT 
    STRUCT(
      STRUCT(
          total_eligible_campaign AS total_eligible, 
          zero_spending_campaign AS zero_spend, 
          zero_conversion_campaign AS zero_conversion,
          positive_effect_campaign AS positive, 
          negative_effect_campaign AS negative
      ) AS campaign_stat,
      STRUCT(
            IF(metric_type='VT_RATIO', 'cmh_risk_ratio', 'cmh_rate_ratio') AS formula, 
            cmh_ratio AS estimate, 
            NULL AS std_err, 
            (
              SELECT
                IF(metric_type='VT_RATIO',
                  `explab-298609.udf.log_cmh_risk_ratio_se`(ARRAY_AGG(STRUCT(CAST(control_d AS INT64), CAST(test_d AS INT64), control_n, test_n, cmh_ratio))),
                  `explab-298609.udf.log_cmh_rate_ratio_se`(ARRAY_AGG(STRUCT(control_d, test_d, control_n, test_n, cmh_ratio)))
                )
              FROM campaign_level_summary
            ) AS log_transform_std_err
      ) AS test_statistic
    )
  FROM cmh_summary
)

/* explab-298609.udf.cmh_rate_ratio */

(SELECT SAFE_DIVIDE(SUM(IF(control_spent*test_spent*control_conv*test_conv > 0,
    test_conv*control_spent/(control_spent+test_spent), 0)),
    SUM(IF(control_spent*test_spent*control_conv*test_conv > 0,
    control_conv*test_spent/(control_spent+test_spent), 0)))
  FROM UNNEST(camp_summary))

-- Arg: camp_summary ARRAY<STRUCT<control_spent FLOAT64, test_spent FLOAT64, control_conv INT64, test_conv INT64>>
