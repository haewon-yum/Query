/*

- focal-elf-631.prod_stream_view.pb
- All postbacks including attributed, unattributed (which likely include organic).
- Some MMPs can pass is_organic flag, but it’s not reliable yet.
- Sampled: 1/100 in general, except some cases
    + Non-sampled cases: 
    (1) attributed events 
    (2) all the installs (attributed + unattributed) 
    (3) all the revenue events (attributed + unattributed)

SCHEMA
- timestamp
- mmp_name
- event_name
- mmp
    - ...
- attribution
    - method
    - raw_method
    - viewthrough
    - reengagement
    - organic
    - reject_reason
- moloco
    - attributed
    - mtid
    - is_test
    - compaign_id
    - creative_id
    - ...
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
        -...
    - revenue_usd
        - currency
        - amount
- device
    - ifa
    - ...
    - user_bucket (?) -- maybe used in experimentation
    - os
    - osv
    - model
    - model_norm - normalized format of model (e.g. model: SM-S918U1 => model_norm: sms918u)
    - session_count ?? 
    -...
    - country
- publisher
- payload
*/

SELECT *
FROM `focal-elf-631.prod_stream_view.pb`
WHERE date(timestamp) = current_date()
LIMIT 10