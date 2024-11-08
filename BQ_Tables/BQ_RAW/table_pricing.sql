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