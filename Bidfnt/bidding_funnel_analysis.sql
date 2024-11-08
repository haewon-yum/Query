-- raw sql results do not include filled-in values for 'bidding_funnel.bid_result_sort'


WITH bidding_funnel AS 
(SELECT 
    utc_date, 
    country, 
    exchange, 
    inventory_format, 
    bid_result, 
    os, 
    traffic, 
    ROUND(eval_cnt/rate) AS eval_cnt, 
    ROUND(pricing_cnt/rate) AS pricing_cnt, 
    ROUND(cnt/rate) AS cnt
         FROM(
          SELECT
            DATE(TIMESTAMP) AS utc_date,
            country,
            exchange,
            inventory_format,
            bid_result,
            rate,
            IF(SUBSTR(maid, 0, 2) in ('a:','j:'), 'ANDROID', IF(SUBSTR(maid, 0, 2) in ('i:','k:'), 'IOS', 'OTHER')) AS os,
            IF(SUBSTR(maid, 0, 2) in ('a:','i:'), 'IDFA', IF(SUBSTR(maid, 0, 2) in ('j:','k:'), 'LAT', 'OTHER')) AS traffic,
            SUM(array_length(limiter_passed_campaigns)) AS eval_cnt,
            SUM(pricing_count) AS pricing_cnt,
            count(*) AS cnt
          FROM `focal-elf-631.prod.trace*`
          WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', CAST(TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY, 'UTC'), INTERVAL -2 DAY) AS date))
            AND FORMAT_DATE('%Y%m%d', CAST(TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY, 'UTC'), INTERVAL -2 DAY), INTERVAL 3 DAY) AS date))
            AND ((( timestamp ) >= ((TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY, 'UTC'), INTERVAL -2 DAY))) AND ( timestamp ) < ((TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY, 'UTC'), INTERVAL -2 DAY), INTERVAL 3 DAY)))))
            AND exchange != 'MOLOCO'
          GROUP BY 1,2,3,4,5,6,7,8)
          WHERE os != 'OTHER' AND traffic != 'OTHER'
      )
SELECT
    (CASE
WHEN bidding_funnel.bid_result = 'FILTER_BY_BIDFNT'  THEN '00'
WHEN bidding_funnel.bid_result = 'BIDBND_ERROR'  THEN '01'
WHEN bidding_funnel.bid_result = 'THROTTLED_EVENTFNT_DOWN'  THEN '02'
WHEN bidding_funnel.bid_result = 'THROTTLED_HIGH_SPEND_AVOIDANCE'  THEN '03'
WHEN bidding_funnel.bid_result = 'THROTTLED_HIGH_BID_AVOIDANCE'  THEN '04'
WHEN bidding_funnel.bid_result = 'THROTTLED_BOOTUP'  THEN '05'
WHEN bidding_funnel.bid_result = 'THROTTLED_EXPERIMENT_TAG'  THEN '06'
WHEN bidding_funnel.bid_result = 'THROTTLED_BIDFLOOR_THROTTLER'  THEN '07'
WHEN bidding_funnel.bid_result = 'THROTTLED_NONREWARDED_VIDEO'  THEN '08'
WHEN bidding_funnel.bid_result = 'THROTTLED_RANDOM_THROTTLER'  THEN '09'
WHEN bidding_funnel.bid_result = 'THROTTLED_ABUSIVE'  THEN '10'
WHEN bidding_funnel.bid_result = 'THROTTLED_CONFIG_SERVER_REGION'  THEN '11'
WHEN bidding_funnel.bid_result = 'THROTTLED_NOT_ALLOWED_COUNTRY'  THEN '12'
WHEN bidding_funnel.bid_result = 'THROTTLED_EXCHANGE'  THEN '13'
WHEN bidding_funnel.bid_result = 'THROTTLED_CONFIG_BLOCKLIST'  THEN '14'
WHEN bidding_funnel.bid_result = 'THROTTLED_ANONYMOUS_IP'  THEN '15'
WHEN bidding_funnel.bid_result = 'THROTTLED_OUTSTANDING_REQUESTS'  THEN '16'
WHEN bidding_funnel.bid_result = 'INVALID_BID_REQUEST'  THEN '17'
WHEN bidding_funnel.bid_result = 'FILTERED_APT_READ'  THEN '18'
WHEN bidding_funnel.bid_result = 'FILTERED_UNPUBLISHED_APP'  THEN '19'
WHEN bidding_funnel.bid_result = 'FILTERED_PUBLISHER'  THEN '20'
WHEN bidding_funnel.bid_result = 'THROTTLED_SHORT_TERM_USER_PROFILE'  THEN '21'
WHEN bidding_funnel.bid_result = 'THROTTLED_UPT'  THEN '22'
WHEN bidding_funnel.bid_result = 'NO_CAMPAIGN_AFTER_REQ_FILTER'  THEN '23'
WHEN bidding_funnel.bid_result = 'UPT_READ_ERROR'  THEN '24'
WHEN bidding_funnel.bid_result = 'NO_CAMPAIGN_AFTER_CTX_FILTER'  THEN '25'
WHEN bidding_funnel.bid_result = 'NO_ADGROUP_AFTER_CTX_FILTER'  THEN '26'
WHEN bidding_funnel.bid_result = 'NO_FINALIST'  THEN '27'
WHEN bidding_funnel.bid_result = 'NO_WINNER'  THEN '28'
WHEN bidding_funnel.bid_result = 'THROTTLED_POSTPRICING_WIN_PRED'  THEN '29'
WHEN bidding_funnel.bid_result = 'INTERNAL_ERROR'  THEN '30'
WHEN bidding_funnel.bid_result = 'UPT_WRITE_ERROR'  THEN '31'
WHEN bidding_funnel.bid_result = 'BID'  THEN '32'
WHEN bidding_funnel.bid_result = 'TIME_OUT'  THEN '33'
WHEN bidding_funnel.bid_result = 'FILTERED_INCOMPATIBLE_TARGET_INVENTORY'  THEN '34'

END) AS bidding_funnel_bid_result_sort__sort_,
    (CASE
WHEN bidding_funnel.bid_result = 'FILTER_BY_BIDFNT'  THEN 'FILTER_BY_BIDFNT'
WHEN bidding_funnel.bid_result = 'BIDBND_ERROR'  THEN 'BIDBND_ERROR'
WHEN bidding_funnel.bid_result = 'THROTTLED_EVENTFNT_DOWN'  THEN 'THROTTLED_EVENTFNT_DOWN'
WHEN bidding_funnel.bid_result = 'THROTTLED_HIGH_SPEND_AVOIDANCE'  THEN 'HIGH_SPEND_AVOIDANCE'
WHEN bidding_funnel.bid_result = 'THROTTLED_HIGH_BID_AVOIDANCE'  THEN 'HIGH_BID_AVOIDANCE'
WHEN bidding_funnel.bid_result = 'THROTTLED_BOOTUP'  THEN 'BOOTUP'
WHEN bidding_funnel.bid_result = 'THROTTLED_EXPERIMENT_TAG'  THEN 'EXPERIMENT_TAG'
WHEN bidding_funnel.bid_result = 'THROTTLED_BIDFLOOR_THROTTLER'  THEN 'BIDFLOOR_THROTTLER'
WHEN bidding_funnel.bid_result = 'THROTTLED_NONREWARDED_VIDEO'  THEN 'NONREWARDED_VIDEO'
WHEN bidding_funnel.bid_result = 'THROTTLED_RANDOM_THROTTLER'  THEN 'RANDOM_THROTTLER'
WHEN bidding_funnel.bid_result = 'THROTTLED_ABUSIVE'  THEN 'ABUSIVE'
WHEN bidding_funnel.bid_result = 'THROTTLED_CONFIG_SERVER_REGION'  THEN 'CONFIG_SERVER_REGION'
WHEN bidding_funnel.bid_result = 'THROTTLED_NOT_ALLOWED_COUNTRY'  THEN 'NOT_ALLOWED_COUNTRY'
WHEN bidding_funnel.bid_result = 'THROTTLED_EXCHANGE'  THEN 'EXCHANGE'
WHEN bidding_funnel.bid_result = 'THROTTLED_CONFIG_BLOCKLIST'  THEN 'CONFIG_BLOCKLIST'
WHEN bidding_funnel.bid_result = 'THROTTLED_ANONYMOUS_IP'  THEN 'ANONYMOUS_IP'
WHEN bidding_funnel.bid_result = 'THROTTLED_OUTSTANDING_REQUESTS'  THEN 'OUTSTANDING_REQUESTS'
WHEN bidding_funnel.bid_result = 'INVALID_BID_REQUEST'  THEN 'INVALID_BID_REQUEST'
WHEN bidding_funnel.bid_result = 'FILTERED_APT_READ'  THEN 'FILTERED_APT_READ'
WHEN bidding_funnel.bid_result = 'FILTERED_UNPUBLISHED_APP'  THEN 'FILTERED_UNPUBLISHED_APP'
WHEN bidding_funnel.bid_result = 'FILTERED_PUBLISHER'  THEN 'FILTERED_PUBLISHER'
WHEN bidding_funnel.bid_result = 'THROTTLED_SHORT_TERM_USER_PROFILE'  THEN 'SHORT_TERM_USER_PROFILE'
WHEN bidding_funnel.bid_result = 'THROTTLED_UPT'  THEN 'UPT_PRESSURE'
WHEN bidding_funnel.bid_result = 'NO_CAMPAIGN_AFTER_REQ_FILTER'  THEN 'NO_CAMPAIGN_AFTER_REQ_FILTER'
WHEN bidding_funnel.bid_result = 'UPT_READ_ERROR'  THEN 'UPT_READ_ERR'
WHEN bidding_funnel.bid_result = 'NO_CAMPAIGN_AFTER_CTX_FILTER'  THEN 'NO_CAMPAIGN_AFTER_CTX_FILTER'
WHEN bidding_funnel.bid_result = 'NO_ADGROUP_AFTER_CTX_FILTER'  THEN 'NO_ADGROUP_AFTER_CTX_FILTER'
WHEN bidding_funnel.bid_result = 'NO_FINALIST'  THEN 'NO_FINALIST'
WHEN bidding_funnel.bid_result = 'NO_WINNER'  THEN 'NO_WINNER'
WHEN bidding_funnel.bid_result = 'THROTTLED_POSTPRICING_WIN_PRED'  THEN 'POSTPRICING_WIN_PRED'
WHEN bidding_funnel.bid_result = 'INTERNAL_ERROR'  THEN 'INTERNAL_ERROR'
WHEN bidding_funnel.bid_result = 'UPT_WRITE_ERROR'  THEN 'UPT_WRITE_ERROR'
WHEN bidding_funnel.bid_result = 'BID'  THEN 'BID'
WHEN bidding_funnel.bid_result = 'TIME_OUT'  THEN 'TIME_OUT'
WHEN bidding_funnel.bid_result = 'FILTERED_INCOMPATIBLE_TARGET_INVENTORY'  THEN 'FILTERED_TARGET_BID'

END) AS bidding_funnel_bid_result_sort,
    COALESCE(SUM(bidding_funnel.cnt ), 0) AS bidding_funnel_cnt
FROM bidding_funnel
WHERE (bidding_funnel.os ) = 'ANDROID'
GROUP BY
    1,
    2
ORDER BY
    1
LIMIT 500