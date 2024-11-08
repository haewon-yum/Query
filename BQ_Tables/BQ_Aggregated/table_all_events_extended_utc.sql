/* 
- focal-elf-631.standard_cs_v5_view.all_events_extended_utc
- This table is one of the precursor tables to fact_dsp_daily, 
    it contains very granular data at event level and creative id level. 
    Also contains metrics: impressions, installs, spend… and cohorted metrics: D7 actions, D7 revenue…
- Notes
    + Note that the standalone counts like count_cv, count_installs etc columns are using the arrival time of the event and not the impression time.
    + Note that timestamp is the postback time, and not install time.
    + Contains publisher data in a field called “app_bundle”.
    + spend is “total_revenue” field
    + cr_id is a concatenation of advertiser_id and OS and cr_id

*/