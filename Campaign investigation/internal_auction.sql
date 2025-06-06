### playable investigation ###
## ri vs. vi investigation ##
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
),
valid_bids AS (
 -- Select only bid IDs that have BOTH 'vi' and 'ri' cr_format
 SELECT bid_id, campaign_id
 FROM filtered_bids
 GROUP BY bid_id, campaign_id
 HAVING COUNT(DISTINCT cr_format) = 2
),
internal_auction AS (
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
),
summary AS (
 SELECT
   campaign_id,
   CASE WHEN cr_format = 'vi' THEN internal_win_rate ELSE NULL END AS win_rate_vi,
   CASE WHEN cr_format = 'ri' THEN internal_win_rate ELSE NULL END AS win_rate_ri,
 FROM(
   SELECT
     *,
     cnt_is_winner / cnt_pricing AS internal_win_rate
   FROM internal_auction
 )
)
SELECT
 campaign_id,
 MAX(win_rate_vi) AS win_rate_vi,
 MAX(win_rate_ri) AS win_rate_ri
FROM summary
GROUP BY 1



### Shared by Tolga ###

WITH crformat_cnt AS (
      SELECT
        req.bid_id,
        COUNT(DISTINCT cand.cr_format) as crformat_cnt
  FROM `focal-elf-631.prod_stream_view.pricing` as p CROSS JOIN UNNEST(p.pricing.candidates) AS cand
  CROSS JOIN UNNEST(cand.bid_former.generic) as bid_price
  WHERE
    DATE(timestamp) >= '2024-07-01' AND DATE(timestamp) <= '2024-09-01'
    AND cand.campaign_id = 'cFuBq0q4TpYpR1RU'
    and cand.cr_format in ('vi', 'ri')
    GROUP BY 1
    ORDER BY 1
  )

  SELECT
    date(TIMESTAMP_TRUNC(timestamp, DAY)) AS date,
    req.bid_id,
    cand.adgroup_id,
    cand.cr_format,
    req.exchange,
    prediction_logs[SAFE_OFFSET(0)].pred AS i2i_pred,
    cand.bid_price AS bid_price,
    crformat_cnt,
    candidate_result
    --COUNTIF(candidate_result IN ('CommitBid', 'InternalAuctionWinner')) AS win_cnt,
    --COUNTIF(candidate_result IN ('CommitBid', 'InternalAuctionWinner')) / count(*) AS win_rate
  FROM `focal-elf-631.prod_stream_view.pricing` as p CROSS JOIN UNNEST(p.pricing.candidates) AS cand
  LEFT JOIN crformat_cnt ON p.req.bid_id = crformat_cnt.bid_id
  CROSS JOIN UNNEST(cand.bid_former.generic) as bid_price
  WHERE
    DATE(timestamp) >= '2024-07-01' AND DATE(timestamp) <= '2024-09-01'
    AND cand.campaign_id = 'cFuBq0q4TpYpR1RU'
    and prediction_logs[safe_offset(1)].tf_model_name is not null
    and cand.cr_format in ('vi', 'ri')
    --GROUP BY 1,2,3,4
    ORDER BY 1,2,3,4