/*
- focal-elf-631.prod_stream_view.bid / MOLOCO가 비딩한 bid만 포함!!!
- This table only contains those bid requests in which MOLOCO has bid on. 
  Also contains in .bid.MODEL all the data on our ML predictions + normalisers + adjustments.

*/

/* SCHEMA 
- timestamp
- platform_id
- advertiser_id
- req
    - bid_id
    - app
        - bundle
        - publisher
            - id
            - name
    - device
        - ifa
        - os
        - osv
        - carrier
        - language
        - ip
        - geo
            - region
            - country
            - city
            - zip
            - lat
            - lon
    - imp
        - bidfloor
        - adunitname
        - banner
        - video
        - native
        - inventory_format
        - pmp
        - video_type
    - ...
- bid
    - timestamp
    - mtid 
    - maid
    - bid_price
    - ext
        - skadn
        - inventory_feature
    - aux
        - ignore_mmp_feedback
        - header_bidding_multiplier
    - MODEL
        - pricing_function
        - pricing_name
        - core
- api
- compliance

*/


SELECT
FROM `focal-elf-631.prod_stream_view.bid`
WHERE 