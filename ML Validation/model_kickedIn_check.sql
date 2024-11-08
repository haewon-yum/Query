-- Reference: https://docs.google.com/document/d/1A6IA38wOHl1ATelo2Ykf6rdQ0oOO_Qw_3a6lvXoQ2jc/edit
SELECT
*
FROM
    (select 
    date(timestamp) as date, 
    --IF(STARTS_WITH(bid.maid, ""k:""), ""LAT"", ""IDFA"") as traffic_type,
    api.campaign.id,
    bid.model.pricing_function AS pricing_function,
    avg(bid.model.prediction_logs[SAFE_OFFSET(1)].pred) AS i2a_pred_avg,
    avg(bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) as i2a_norm_avg,
    avg(bid.bid_price.amount_micro)/1e6 as bid_price,
    avg(bid.model.multipliers.converted_target) as tcm,
    avg(bid.model.prediction_logs[safe_OFFSET(1)].pred) as i2a_pred,
    avg(bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer) AS normalizer,
    avg(safe_divide(bid.model.prediction_logs[SAFE_OFFSET(1)].pred, bid.model.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer)) as i2a_norm,
    avg(bid.model.prediction_logs[SAFE_OFFSET(2)].pred / bid.model.prediction_logs[SAFE_OFFSET(2)].wrapper.normalizer) as rev_mult,
    count(*) as imp_cnt
    from `focal-elf-631.prod_stream_sampled.imp_1to1000` 
    where date(timestamp) >= '2024-09-01'
    and api.product.app.tracking_bundle IN  ('com.nexon.maplem.global')
    group by 1,2,3
    ) t1
LEFT JOIN 
    (SELECT
    date(cv.happened_at) as date,
    api.campaign.id,
    count(distinct bid.mtid) as payer_cnt
    FROM `focal-elf-631.prod_stream_view.cv`
        WHERE date(timestamp) >= '2024-09-01'
        and api.product.app.tracking_bundle IN  ('com.nexon.maplem.global')
        and cv.event = 'CUSTOM_KPI_ACTION'
        and TIMESTAMP_DIFF(cv.happened_at, install.happened_at, DAY) < 7 
        group by 1,2) t2
on t1.id = t2.id
and t1.date = t2.date
ORDER BY 1,2,3,4,5