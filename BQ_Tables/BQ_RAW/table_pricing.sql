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
    CASE WHEN candidates.candidate_result = 'CommitBid' THEN 1 ELSE 0 END AS is_commitbid
  FROM `focal-elf-631.prod_stream_view.pricing`, 
       UNNEST(pricing.candidates) AS candidates
  WHERE candidates.cr_format IN ('vi', 'ri')
    AND DATE(timestamp) BETWEEN start_date AND end_date
    AND candidates.candidate_result IN ('CommitBid', 'InternalAuctionCandidate', 'InternalAuctionWinner')
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
    COUNT(DISTINCT fb.bid_id) AS cnt_internal_auction,
    SUM(fb.is_commitbid) AS cnt_commit_bid
  FROM filtered_bids fb
  JOIN valid_bids vb 
    ON fb.bid_id = vb.bid_id AND fb.campaign_id = vb.campaign_id
  GROUP BY fb.campaign_id, fb.cr_format
)

SELECT * FROM final_summary;
