/*
    -  focal-elf-631.prod_stream_view.cv
    - Attributed postbacks from a Moloco campaign.
        - Key: campaign_id, product_id, advertiser_id
    - Sampling: 1/1
*/

/*

SCHEMA
- timestamp: The moment when the conversion event is received
- platform_id: Moloco-specific platform ID
- advertiser_id: Moloco-specific advertiser ID
- req
    - timestamp
    - exchange
    - bid_region
    - bid_id
    - app
        - bundle
        - encoded_bundle
        - id
        - publisher
            - id
            - name
    - site
    - device
        - ifa
        - anonymized_ifa
        - os
        - osv
        - carrier
        - connectiontype
        - hwv
        - make
        - model
        - model_norm
        - devicetype
        - language
        - ip
        - iptype
        - geo
            - utcoffset
            - region
            - country
            - city
            - zip
            - metro
            - lat
            - lon
            
        - lmt
        - atts
        - ua
        - aux
    - imp
    - ext
    - at
    - misc_json
    - tmax
    - internal_bid_id

- bid
    - timestamp
    - mtid
    - maid
    - anonymized_maid
    - bid_price
        - currency
        - amount_micro
    - IsTest
    - ext
    - aux
    - MODEL
        - pricing_function
        - pricing_name
        - core
            - pred
            - threshold
            - prediction_type
            - ref_campaign
            - context_name
            - tf_model_name
            - reason
            - ...
        - wrapper
            - pred
            - threshold
            - prediction_type
        - multipliers
            - converted_target
            - budget
            - calibration
            - exp
        - bid_former
            - fpa
                - name
                - in_cpm
                - out_cpm
            - generic
                - name
                - in_cpm
                - out_cpm
        - value_price
        - bid_price
        - prediction_logs
            - type
            - pred
            - threshold
            - prediction_type
            - prediction_type_mix_rate
            - ref_campaign
            - context_name
            - tf_model_name
            - reason
            - context_revision
            - latency_ns
            - wrapper
                - ...
            - base_model_prediction
    - experiment
    - cr_pick_log
    - market_model
    - seatbid
    - rendezvous_bid
- api
    - platform
    - advertiser
    - product
    - campaign
        - id
        - title
        - skadn_id
        - skadn_tr_suffix
    - trgroup
    - adgroup
    - crgroup
    - creative
    - tracking_links
- imp
    
- imp_extra
- ev
- click
- install
- cv
    - received_at
    - handled_at
    - happend_at
    - client_ip
    - event: This field represents the type of event that occured. For example, it could be an event like 'INSTALL' or 'CUSTOM_KPI_ACTION'. it is used to identify the nature of the event in the conversion data. 
    - event_pb: This field represents the postback event name. It is used to match the event with the specific postback data. For instance, in the context of ROAS (Return on Ad Spend) campaigns, cv.event_pb is used to aggregate daily KPI event counts and the sum of revenue from postbacks.
- compliance

*/


-- Check PB event kinds and counts for given app bundles
SELECT
    cv.event,
    cv.event_pb,
    count(1) as count
FROM focal-elf-631.prod_stream_view.cv
WHERE 
    DATE(C.timestamp) BETWEEN run_from_date AND run_to_date
    AND api.product.app.store_id IN UNNEST(app_bundle)
GROUP BY ALL


