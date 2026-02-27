/* 
    focal-elf-631.prod_stream_view.click_surplus

    (by Glean)
    The click_surplus table (focal-elf-631.prod_stream_view.click_surplus) logs click events that were filtered out of the normal click table because they failed quality/attribution rules. In other words:

    “Surplus” = rejected clicks, not “extra” clicks.
    These clicks are not billable and not used for attribution; they exist so we can debug and monitor click quality and fraud.  
    Typical reasons a click goes to click_surplus instead of click:

    Duplicate of a prior click for the same impression/mtid
    No matching impression found (NO_IMP_CLICK)
    Arrived too late (EXPIRED_CLICK)
    Policy-based suppression (e.g., IGNORE_REPORT_TO_MMP)  

*/

