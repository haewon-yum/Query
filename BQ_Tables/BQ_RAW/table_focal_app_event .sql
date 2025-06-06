/* 
    S2S injected data
    `focal-elf-631.ingest_prod.app_event`


    SCHEMA
    - timstamp
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
        - event_at
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


## 111Percent customer event check

SELECT *
FROM `focal-elf-631.ingest_prod.app_event_view` 
WHERE app.bundle IN ("com.percent.aos.luckydefense", "id6482291732")
    AND DATE(timestamp) >= '2025-03-01'