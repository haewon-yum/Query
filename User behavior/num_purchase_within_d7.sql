DECLARE start_date TIMESTAMP DEFAULT '2024-04-02';
DECLARE end_date TIMESTAMP DEFAULT  '2024-07-31';
DECLARE store_bundle STRING DEFAULT 'com.percent.aos.luckydefense';

WITH user_raw AS(
    SELECT
        bid.maid AS user_id,
        DATE(cv.install_at_pb) AS install_dt,
        cv.happened_at,
        cv.event,
        cv.event_pb,
        TIMESTAMP_DIFF(cv.happened_at, cv.install_at_pb, DAY) + 1 AS diff_day,
        cv.revenue_usd.amount AS revenue
    FROM
        `focal-elf-631.prod_stream_view.cv`
    WHERE
        timestamp >= start_date
        AND cv.install_at_pb BETWEEN start_date AND end_date
        AND cv.revenue_usd.amount > 0  
        AND api.product.app.store_id = store_bundle
)

SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY happened_at) AS purchase_seq
FROM user_raw
ORDER BY user_id, install_dt, happened_at
LIMIT 100
