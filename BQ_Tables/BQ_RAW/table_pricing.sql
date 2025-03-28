/*
    - focal-elf-631.prod_stream_view.pricing
    - Internal bids AKA all the prediction evaluations for the internal auction.
    - Sampled: 1/1000
    - DS team can use this table to identify and debug spending issues in campaigns and debug ML models issues
*/

/* SCHEMA

- timestamp
- country
- os
- req
    - bid_id
    - app
    - device
    - imp
        - bidfloor
        - banner
        - video
        - native
        - inventory_format
        - ...
- pricing
    - maid
    - internal_bid_id
    - candidates 
        - candidate_result (pricing result, such as 'FilterByBidfloor', 'CommitBid', )


*/


-- Check pricing count by candidate_result
SELECT 
  candidates.candidate_result,
  count(1) as cnt
FROM `focal-elf-631.prod_stream_view.pricing` ,
  UNNEST(pricing.candidates) AS candidates
WHERE date(timestamp) = '2024-10-10'
GROUP BY ALL


--- 각 캠페인 앱별 pricing에 고려된 (Internal acution에 참여한) bid request 수
SELECT
  req.app.bundle AS publisher_bundle, 
  count(1) AS pricing_cnt,
  
FROM `focal-elf-631.prod_stream_view.pricing` ,
  UNNEST(pricing.candidates) AS candidates
WHERE 
  pricing.candidates.product_id IN ('q23yekzCBcvizM3g')

-- get pricing result (result and cnt) for specific campaigns and exchange (ADX -- X)
-- https://docs.google.com/document/d/10HmMGNrLTCRBvQu7GA0PPKrcSMsrbLPn73pk6uMq9cY/edit?tab=t.0
SELECT
  candidates.candidate_result,
  count(1) as cnt
FROM `focal-elf-631.prod_stream_view.pricing`,
  UNNEST(pricing.candidates) AS candidates
WHERE DATE(timestamp) BETWEEN '2025-01-27' AND CURRENT_DATE()
  AND candidates.campaign_id IN ("VcuKWhzoARe41XuW", --- T2
                                  "ZhVrXq6afOKwvqiO", --- T3
                                  "EJeygr8V37lRIDIj", --- T4
                                  "s3tza9UyiW6sHiIn"  --- T1
                                  )
  AND req.exchange = "ADX"
GROUP BY ALL


/* 
  pricing count by creative_format for campaign `cFuBq0q4TpYpR1RU`
  - https://moloco.looker.com/explore/athena/fact_dsp_creative?qid=1itfA3kHrKujsJ1WCaRT1o&toggle=dat,fil,vis

  start date = 2024-07-22
  end date = 2024-08-05
  durint the period, ri spend had been increased. 
*/

SELECT
  req.imp.inventory_format, req.imp.inventory_format,
  count(1) AS pricing_cnt,
FROM `focal-elf-631.prod_stream_view.pricing` ,
  UNNEST(pricing.candidates) AS candidates
WHERE 
  candidates.campaign_id IN ('cFuBq0q4TpYpR1RU')
  AND DATE(timestamp) BETWEEN '2024-07-22' AND '2024-08-05'
GROUP BY ALL 


/* 
  - internal auction dynamics between ri and vi
  - for bids where same campaings / different cr_format competed together
*/

DECLARE start_date DATE DEFAULT '2025-03-12';
DECLARE end_date DATE DEFAULT '2025-03-12';

WITH filtered_bids AS (
  SELECT
    req.bid_id,   
    candidates.campaign_id,
    candidates.adgroup_id,
    candidates.cr_format,
    CASE WHEN candidates.candidate_result IN ('InternalAuctionCandidate', 'InternalAuctionWinner', 'CommitBid') THEN 1 ELSE 0 END AS is_candidate,
    CASE WHEN candidates.candidate_result IN ('InternalAuctionWinner', 'CommitBid') THEN 1 ELSE 0 END AS is_winner,
    CASE WHEN candidates.candidate_result IN ('CommitBid') THEN 1 ELSE 0 END AS is_bid,
  FROM `focal-elf-631.prod_stream_view.pricing`, 
       UNNEST(pricing.candidates) AS candidates
  WHERE candidates.cr_format IN ('vi', 'ri')
    AND DATE(timestamp) BETWEEN start_date AND end_date
    -- AND candidates.candidate_result IN ('CommitBid', 'InternalAuctionCandidate', 'InternalAuctionWinner')
),
valid_bids AS (
  -- Select only bid IDs that have BOTH 'vi' and 'ri' cr_format
  SELECT bid_id, campaign_id
  FROM filtered_bids
  GROUP BY bid_id, campaign_id
  HAVING COUNT(DISTINCT cr_format) = 2
),
final_summary AS (
  -- Aggregate valid bids with their associated cr_format
  SELECT
    fb.campaign_id,
    fb.cr_format,
    COUNT(DISTINCT fb.bid_id) AS cnt_pricing,
    SUM(fb.is_candidate) AS cnt_is_candidate,
    SUM(fb.is_winner) AS cnt_is_winner,
    SUM(fb.is_bid) AS cnt_is_bid
  FROM filtered_bids fb
    JOIN valid_bids vb USING(bid_id, campaign_id)
  GROUP BY fb.campaign_id, fb.cr_format
)

SELECT * FROM final_summary;


/* 
  Expand the previous query into multiple days, model prediction values
*/ 

DECLARE start_date DATE DEFAULT '2025-03-01';
DECLARE end_date DATE DEFAULT '2025-03-12';

WITH filtered_bids AS (
  SELECT
    DATE(timestamp) AS dt,
    req.bid_id,   
    candidates.campaign_id,
    candidates.adgroup_id,
    candidates.cr_format,
    CASE WHEN candidates.candidate_result IN ('InternalAuctionCandidate', 'InternalAuctionWinner', 'CommitBid') THEN 1 ELSE 0 END AS is_candidate,
    CASE WHEN candidates.candidate_result IN ('InternalAuctionWinner', 'CommitBid') THEN 1 ELSE 0 END AS is_winner,
    CASE WHEN candidates.candidate_result IN ('CommitBid') THEN 1 ELSE 0 END AS is_bid,
    prediction_logs[SAFE_OFFSET(0)].pred AS i2i_pred,
    prediction_logs[SAFE_OFFSET(1)].pred AS i2a_pred,
    prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer AS normalizer,
    safe_divide(prediction_logs[SAFE_OFFSET(1)].pred, prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) as i2a_norm,
    prediction_logs[SAFE_OFFSET(2)].pred / prediction_logs[SAFE_OFFSET(2)].wrapper.normalizer as rev_mult,
    candidates.bid_price AS bid_price
  FROM `focal-elf-631.prod_stream_view.pricing`, 
       UNNEST(pricing.candidates) AS candidates
  WHERE candidates.cr_format IN ('vi', 'ri')
    AND DATE(timestamp) BETWEEN start_date AND end_date
    -- AND candidates.candidate_result IN ('CommitBid', 'InternalAuctionCandidate', 'InternalAuctionWinner')
),
valid_bids AS (
  -- Select only bid IDs that have BOTH 'vi' and 'ri' cr_format
  SELECT dt, bid_id, campaign_id
  FROM filtered_bids
  GROUP BY ALL
  HAVING COUNT(DISTINCT cr_format) = 2
),
valid_campaigns AS ( -- only include campaigns run every days between start_date and end_date
  SELECT campaign_id
  FROM filtered_bids
  GROUP BY ALL
  HAVING COUNT(DISTINCT dt) = 12
),
internal_auction AS (
  -- Aggregate valid bids with their associated cr_format
  SELECT
    fb.dt,
    fb.campaign_id,
    fb.cr_format,
    COUNT(DISTINCT fb.bid_id) AS cnt_pricing,
    SUM(fb.is_candidate) AS cnt_is_candidate,
    SUM(fb.is_winner) AS cnt_is_winner,
    SUM(fb.is_bid) AS cnt_is_bid,
    SUM(fb.is_winner) / COUNT(DISTINCT fb.bid_id) AS internal_win_rate,
    AVG(i2i_pred) AS i2i_pred,
    AVG(i2a_pred) AS i2a_pred,
    AVG(normalizer) AS normalizer,
    AVG(i2a_norm) AS i2a_norm,
    AVG(rev_mult) AS rev_mult,
    AVG(bid_price) AS bid_price
  FROM filtered_bids fb
    JOIN valid_bids vb USING(dt, bid_id, campaign_id)
    JOIN valid_campaigns vc USING(campaign_id)
  GROUP BY 1,2,3
),
summary_1 AS (
  SELECT 
    dt,
    campaign_id, 
    CASE WHEN cr_format = 'vi' THEN internal_win_rate ELSE NULL END AS win_rate_vi,
    CASE WHEN cr_format = 'ri' THEN internal_win_rate ELSE NULL END AS win_rate_ri,
    CASE WHEN cr_format = 'vi' THEN i2i_pred ELSE NULL END AS i2i_pred_vi,
    CASE WHEN cr_format = 'ri' THEN i2i_pred ELSE NULL END AS i2i_pred_ri,
    CASE WHEN cr_format = 'vi' THEN i2a_pred ELSE NULL END AS i2a_pred_vi,
    CASE WHEN cr_format = 'ri' THEN i2a_pred ELSE NULL END AS i2a_pred_ri,
    CASE WHEN cr_format = 'vi' THEN normalizer ELSE NULL END AS normalizer_vi,
    CASE WHEN cr_format = 'ri' THEN normalizer ELSE NULL END AS normalizer_ri,
    CASE WHEN cr_format = 'vi' THEN i2a_norm ELSE NULL END AS i2a_norm_vi,
    CASE WHEN cr_format = 'ri' THEN i2a_norm ELSE NULL END AS i2a_norm_ri,
    CASE WHEN cr_format = 'vi' THEN rev_mult ELSE NULL END AS rev_mult_vi,
    CASE WHEN cr_format = 'ri' THEN rev_mult ELSE NULL END AS rev_mult_ri,
    CASE WHEN cr_format = 'vi' THEN bid_price ELSE NULL END AS bid_price_vi,
    CASE WHEN cr_format = 'ri' THEN bid_price ELSE NULL END AS bid_price_ri
  FROM internal_auction
)

SELECT
  dt,
  campaign_id,
  MAX(win_rate_vi) AS win_rate_vi,
  MAX(win_rate_ri) AS win_rate_ri,
  MAX(i2i_pred_vi) AS i2i_pred_vi,
  MAX(i2i_pred_ri) AS i2i_pred_ri,
  MAX(i2a_pred_vi) AS i2a_pred_vi,
  MAX(i2a_pred_ri) AS i2a_pred_ri,
  MAX(normalizer_vi) AS normalizer_vi,
  MAX(normalizer_ri) AS normalizer_ri,
  MAX(i2a_norm_vi) AS i2a_norm_vi,
  MAX(i2a_norm_ri) AS i2a_norm_ri,
  MAX(rev_mult_vi) AS rev_mult_vi,
  MAX(rev_mult_ri) AS rev_mult_ri,
  MAX(bid_price_vi) AS bid_price_vi,
  MAX(bid_price_ri) AS bid_price_ri
FROM summary_1
GROUP BY 1, 2

