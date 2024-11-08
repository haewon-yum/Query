/* 

- moloco-ae-view.looker.campaign_summary_all_view
- A precursor to campaign_summary_metrics_view, it has data at hourly level, ad group level, and creative id
- Notes
    - To be replaced with fact_dsp_creative by AE “soon”

** CAVEAT **
- `moloco-ae-view.looker.campaign_summary_all_view`
    - This view contains many of the fields from `all_events_extended_utc` table and other helpful fields for Looker reporting such as `advertiser_title`, `campaign_title`, `product_title`, `product_category`, `tracking_bundle`, `app_store_bundle`, `genre`, `sub_genre`, `sales_person`, `account_manager`, `operations_manager`, etc.
    - This table contains `local_date`, `utc_date`, and `utc_hour` for time-based fields
- `moloco-ae-view.looker.campaign_summary_metrics_view`
    - This is a subset of `campaign_summary_all_view` table that is much more cost efficient and faster to query on.
    - Please use this table at first-hand whenever possible for campaign-level data and if fields in this table are insufficient, then consider using `campaign_summary_all_view`.

*/