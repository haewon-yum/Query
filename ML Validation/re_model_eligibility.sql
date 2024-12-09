-- Checking the current models
select
  bid.model.prediction_logs[SAFE_OFFSET(0)].type AS model_type,
  bid.MODEL.pricing_function,
  bid.model.prediction_logs[SAFE_OFFSET(0)].tf_model_name AS model_name
from `focal-elf-631.prod_stream_view.imp`
where date(timestamp) = CURRENT_DATE()
and api.campaign.id IN ('VBnWxKikoKxWVkVa')


      SELECT
        *
      FROM (
        SELECT
          key AS campaign,
          AVG(label * weight) mean_label,
          AVG(prediction * weight) mean_pred,
          SUM(label * weight) sum_label,
          SUM(prediction * weight) sum_pred,
          IFNULL(SAFE_DIVIDE(SUM(prediction * weight), SUM(label * weight)), 0.0) calibration
        FROM
          `moloco-ml.monitoring_model.re_revenue_v10_cont_predictions`
        GROUP BY
          campaign)
      JOIN (
        SELECT
          api.campaign.id AS campaign,
          COUNT(bid.mtid) AS cnt
        FROM
          `focal-elf-631.prod_stream_view.imp`
        WHERE
          date(timestamp) = '2024-12-04'
          and api.campaign.id = 'VBnWxKikoKxWVkVa'
        GROUP BY
          campaign)
      USING
        (campaign)
      ORDER BY
        calibration


      -- SELECT
      --   *
      -- FROM (
      --   SELECT
      --     key AS campaign,
      --     AVG(label * weight) mean_label,
      --     AVG(prediction * weight) mean_pred,
      --     SUM(label * weight) sum_label,
      --     SUM(prediction * weight) sum_pred,
      --     IFNULL(SAFE_DIVIDE(SUM(prediction * weight), SUM(label * weight)), 0.0) calibration
      --   FROM
      --     `moloco-ml.monitoring_model.re_action_v7_1_cont_predictions`
      --   GROUP BY
      --     campaign)
      -- JOIN (
      --   SELECT
      --     api.campaign.id AS campaign,
      --     COUNT(bid.mtid) AS cnt
      --   FROM
      --     `focal-elf-631.prod_stream_view.imp`
      --   WHERE
      --     -- date(timestamp) BETWEEN '2024-11-25' AND CURRENT_DATE()
      --     date(timestamp) = '2024-12-04'
      --     and api.campaign.id = 'VBnWxKikoKxWVkVa'
      --   GROUP BY
      --     campaign)
      -- USING
      --   (campaign)
      -- ORDER BY
      --   calibration