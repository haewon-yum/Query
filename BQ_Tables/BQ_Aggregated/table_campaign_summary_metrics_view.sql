/* 

- moloco-ae-view.looker.campaign_summary_metrics_view
- This table is used in Looker reporting, it has similar data to fact_dsp_daily, but also creative format
- Notes
    + utc_date is the install date
    + “revenue” column here = gross_spend_usd in fact_dsp_daily. It means “revenue” for Moloco.


** CAVEAT **
- `moloco-ae-view.looker.campaign_summary_all_view`
    - This view contains many of the fields from `all_events_extended_utc` table and other helpful fields for Looker reporting such as `advertiser_title`, `campaign_title`, `product_title`, `product_category`, `tracking_bundle`, `app_store_bundle`, `genre`, `sub_genre`, `sales_person`, `account_manager`, `operations_manager`, etc.
    - This table contains `local_date`, `utc_date`, and `utc_hour` for time-based fields
- `moloco-ae-view.looker.campaign_summary_metrics_view`
    - This is a subset of `campaign_summary_all_view` table that is much more cost efficient and faster to query on.
    - Please use this table at first-hand whenever possible for campaign-level data and if fields in this table are insufficient, then consider using `campaign_summary_all_view`.

*/
