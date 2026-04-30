/* Reference: https://moloco.slack.com/archives/C044XS0DWJK/p1732760786297039?thread_ts=1732760367.592349&cid=C044XS0DWJK */

DECLARE camp_id STRING DEFAULT 'vjAfWY1eV0lkLxpj';
DECLARE START_DATE STRING default '2023-01-06';
DECLARE END_DATE STRING default '2023-01-12';
  
SELECT
  DATE_TRUNC(timestamp, DAY) AS date,
  cand.cr_format,
  pricing_function as pricing_name,
  req.exchange,
  count(*) cnt,
  avg(prediction_logs[SAFE_OFFSET(0)].pred) AS i2i,
  avg(prediction_logs[SAFE_OFFSET(1)].pred) AS i2a,
  avg(prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) AS normalizer,
  avg(safe_divide(prediction_logs[SAFE_OFFSET(1)].pred, prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer)) as i2a_norm,
  avg(prediction_logs[SAFE_OFFSET(1)].wrapper.multiplier) AS revenue_multiplier,
  avg(pricing.market_model.mu) market_model_mu, -- based on mbtw
  avg(cand.multipliers.budget) AS budget_tcm, -- ignore
  avg(cand.multipliers.converted_target) AS tcm,
  avg(cand.bid_price) AS bid_price
FROM
  `focal-elf-631.prod_stream_sampled.pricing_1to100` AS p
CROSS JOIN
  UNNEST(p.pricing.candidates) AS cand
WHERE
  DATE(timestamp) between DATE(START_DATE) and DATE(END_DATE)
  AND cand.campaign_id = camp_id
GROUP BY
  1, 2, 3, 4
order by 4, 2, 1