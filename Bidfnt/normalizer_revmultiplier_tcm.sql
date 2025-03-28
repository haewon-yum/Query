/* 
    https://www.notion.so/moloco/Pull-Normalizer-Revenue-Multiplier-and-Target-Cost-Multiplier-14bcdb35133681579f67fa69493f9249
*/

SELECT
    DATE_TRUNC(timestamp, DAY) AS date,
    bid.model.pricing_function as pricing_name,
    bid.model.prediction_logs[safe_offset(1)].tf_model_name as action_model_name,
    bid.model.prediction_logs[SAFE_OFFSET(0)].pred AS i2i,
    bid.model.prediction_logs[SAFE_OFFSET(1)].pred AS i2a,
    bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer AS normalizer,
    safe_divide(bid.model.prediction_logs[SAFE_OFFSET(1)].pred, bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) as i2a_norm,
    bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.multiplier AS revenue_multiplier,
    bid.model.multipliers.budget AS budget_tcm
  FROM
    `focal-elf-631.prod_stream_view.imp`
  where DATE(timestamp) = '2022-10-03'
  AND
    api.campaign.id = 'ccss_video_a_ua_usa'
  limit 100