/* 
    - table for S2S ingestion data
    - focal-elf-631.ingest_prod.app_event_view
    - SCHEMA
        - timestamp
        - app_id
        - event_type
        - app
            - name
            - bundle
            - store
            - version
            - sdk_version
        - event
            - name
            - envet_at
            - click_at
            - download_at
            - install_at
            - revenue_raw
            - revenue_usd
            - page_uri
            - custom_json
        - device
            - ifa
            - user_bucket
            - ifv
            - os
            - osv
            - language
            - model
            - ip
            - iptype
            - ua
            - country
            - session_count
            - auxid
        - raw

*/


SELECT 
    event.name, 
    COUNT(1) as cnt_event
FROM `focal-elf-631.ingest_prod.app_event_view`
WHERE 
    app.bundle = 'com.percent.aos.luckydefense'
    AND event.name IN ('af_level_9__AND__af_purchase', 'purchase_value_d7_10')
    AND timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) AND CURRENT_TIMESTAMP()
GROUP BY 1



### checking attributed KPI event ###
https://moloco.slack.com/archives/C083RRM7VQR/p1741145863192909?thread_ts=1741142440.523339&cid=C083RRM7VQR

with s2s_data as (
SELECT
  True as s2s_source,
  timestamp as s2s_timestamp,
  event.name,
  COALESCE(device.ifa, device.ifv) as idfa,
  sum(event.revenue_raw.amount) as rev_raw
 FROM `focal-elf-631.ingest_prod.app_event_view` 
 WHERE DATE(timestamp) >= "2025-04-01"
 and regexp_contains(app.bundle, 'com.percent.aos.luckydefense')
 and `moloco-ods.general_utils.is_idfa_truly_available`(COALESCE(device.ifa, device.ifv))
 group by 1, 2, 3, 4
),
cv_data as (
  select 
    True as mmp_source,
    timestamp as install_timestamp,
    COALESCE(req.device.ifa, req.device.ifv) as idfa,
    req.device.geo.country
from
    `focal-elf-631.prod_stream_view.cv`
  where DATE(timestamp) >= "2025-04-01"
  and api.campaign.id IN ("Rz6UMY3CAziN9Yf8", "oVj8Mm8Tr1hZoFVx")
  and lower(cv.event) = 'install'
  and `moloco-ods.general_utils.is_idfa_truly_available`(COALESCE(req.device.ifa, req.device.ifv))
  group by 1, 2, 3, 4
)
# only matches on idfa data
select
  date(install_timestamp) as install_date,
  idfa,
  country,
  count(*) actions,
  count(idfa) as purchaser,
  SUM(rev_raw) as rev_raw
from 
  s2s_data
inner join
cv_data
  using(idfa)
where TIMESTAMP_DIFF(s2s_timestamp, install_timestamp, DAY) < 7
group by all
order by 1