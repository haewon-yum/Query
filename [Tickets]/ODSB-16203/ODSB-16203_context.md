# ODSB-16203: Postback Event Volume Check

**Jira:** https://mlc.atlassian.net/browse/ODSB-16203

**Date:** 2026-02-05

---

## Objective

Check if we have enough postback volume for specific events in the app `com.towneers.www` before setting up RE campaigns or changing KPI events.

## Target Events
- `click_pay_payment`
- `click_pay_payment_ad`

## Lookback Period
- Last 7 days

---

## Volume Guidelines (for RE Campaigns)

| Daily Volume | Status | Recommendation |
|--------------|--------|----------------|
| ≥30 events/day | ✅ Sufficient | Stable model training |
| 10-30 events/day | ⚠️ Low but usable | May need longer learning period |
| <10 events/day | ❌ Insufficient | Consider using upper-funnel event |

---

## Files

| File | Description |
|------|-------------|
| `ODSB-16203_pb_event_volume_check.ipynb` | Jupyter notebook for running the analysis |
| `ODSB-16203_pb_event_volume_check.sql` | Raw SQL queries |

---

## SQL Query

```sql
DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
DECLARE end_date DATE DEFAULT CURRENT_DATE();

-- Daily breakdown by event and attribution status
SELECT
    DATE(timestamp) AS date_utc,
    event.name AS event_name,
    moloco.attributed,
    COUNT(*) AS event_count,
    COUNT(DISTINCT device.ifa) AS unique_devices
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN start_date AND end_date
    AND app.bundle = 'com.towneers.www'
    AND LOWER(event.name) IN ('click_pay_payment', 'click_pay_payment_ad')
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;

-- Grand total with volume status
SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT device.ifa) AS unique_devices,
    ROUND(COUNT(*) / 7.0, 1) AS avg_daily_events,
    CASE 
        WHEN COUNT(*) / 7.0 >= 30 THEN '✅ Sufficient (>=30/day)'
        WHEN COUNT(*) / 7.0 >= 10 THEN '⚠️ Low but usable (10-30/day)'
        ELSE '❌ Insufficient (<10/day)'
    END AS volume_status
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN start_date AND end_date
    AND app.bundle = 'com.towneers.www'
    AND LOWER(event.name) IN ('click_pay_payment', 'click_pay_payment_ad');
```

---

## Related Knowledge (from Glean)

### RE KPI Event Change - Key Risks

1. **Model Reset** - New KPI = new model, needs 7-14 days to stabilize
2. **Data Volume** - Deeper funnel events = fewer events = slower learning
3. **Audience Cannibalization** - RE & UA targeting same users/events
4. **Attribution Issues** - MMP config changes needed when KPI changes
5. **Invalid Events** - `app_open` not supported for RE optimization

### Best Practices Checklist

- [ ] Pre-train via shell campaign (7+ days before launch)
- [ ] Run as A/B test, don't switch KPI "in place"
- [ ] Check event volume (~30 attributed actions/day)
- [ ] Verify audience size (RE audience ≥ 100k recommended)
- [ ] Wait 10-14 days before evaluating performance

### Reference Docs
- [Comm Doc] Re-Engagement: https://www.notion.so/b6ceb371a5704e469fc22b79e064c270
- RE-marketing for GDS: https://www.notion.so/1afcdb35133680dfa32ee502a3beefaa

---

## Notes

- Notebook may have loading issues in Cursor - use BigQuery console with the SQL file as fallback
- For KR gaming specifically, systematic RE KPI best practices are still being developed as a 2026 workstream
