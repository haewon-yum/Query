/*
- moloco-ae-view.athena.fact_dsp_daily
- This is the authoritative table on high level metrics for Moloco attributed data at campaign level and ad group level, 
    used in operational and financial reports.

- Key: campaign_id, product_id, advertiser_id
- Notes
    + kpi* metrics are the metrics to use, containing the KPI event the campaign is set up to target. 
        Whereas the other metrics (such as revenue_d7) might contain other events, such as pLTV event.
    + contains genre and subgenre from dataai.
    + no creative level data here.
    + date_utc is the install date.

SCHEMA
- date_utc
- date_local
- platform
- advertiser_id
- product_id
- campaign_id
- exchange
- moloco_product : Moloco's product (e.g., DSP, RMP, AVOD)
- advertiser
    - title
    - ...
    - account_age_group
    - agency_id
    - agency_title
    - first_launch_date
    - ...
    - office
    - office_region
    - office_pod
    - ...
    - tier
    - timezone
    - mmp_bundle_id
    - currency
- product
    - title
    - iab_category
    - iab_category_desc
    - app_market_bundle
    - app_name
    - is_gaming
    - genre : app genre from data.ia
    - sub_genre
    - has_ads
    - parent_company_name
    - company_name
    - mmp_name
- campaign
    - title
    - title_id
    - country
    - goal
    - target_action
    - kpi_actions
    - is_lat
    - os
    - type
    - payout_event : (glean) specific action or event that the campaign is aiming to achieve, such as a purchase or an install.
                        ㄴ is different from target_action?
- ad_group  
    - id
    - title
- skan_conversion_value
- bids: Bids Moloco has won
- bid_price_usd: The amount of money Moloco paid for an impression
- clicks
- clickthrough_install (is going to renamed with install_ct)
- conversions: Moloco's attributed events
- gross_spend_usd
- gross_spend_local
- impressions
- installs
- kpi_actions
- media_cost_usd: impression win price in USD
- pb_revenue_usd
- pb_revenue_local
- revenue_before_discounts_usd: Advertiser spend less Moloco's cost in USD
- revenue_before_discounts_local
- skan_conversions
- kpi_actions_dx: Moloco-attributed KPI actions (purchase, etc.) within X days from attribution
- kpi_users_dx: Users that performed at least one Moloco-attributed KPI action within X day from attribution
- kpi_purchases_dx: Moloco-attributed KPI actions with revenue within X day from attribution
- purchases_dx: Moloco-attributed actions with revenue within X day from attribution
- kpi_payers_dx: Users that performed at least one Moloco-attributed KPI action with revenue within X day from attribution
- payers_dx: Users that performed at least one Moloco-attributed KPI action with revenue within X day from attribution
- kpi_pb_revenue_dx: Postback revenue for a Moloco-attributed KPI action within X day from attribution
- revenue_dx: Moloco's attributed postback revenue within X day of install
- capped_kpi_revenue_dx: Capped postback revenue for a Moloco-attributed KPI action within X day from attribution
- capped_revenue_dx: Capped postback revenue within X days of install

*/