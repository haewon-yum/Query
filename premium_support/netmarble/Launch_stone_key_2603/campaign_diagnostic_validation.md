# Campaign Diagnostic Notebook — Query Validation

**Notebook**: `campaign_diagnostic.ipynb`
**Validated**: 2026-02-26
**Tables inspected**: 9

---

## Query-by-Query Validation

### Cell 3 — Bundle Resolution
**Tables**: `focal-elf-631.standard_digest.product_digest`, `moloco-ae-view.athena.fact_dsp_core`
**Fields**: All valid (`app_store_bundle`, `app_tracking_bundle`, `tracking_bundle`, `title`, `os`, `is_archived`, `advertiser.mmp_bundle_id`, `product.app_market_bundle`)
**Logic**: LEFT JOIN on `app_store_bundle = app_market_bundle` is correct.
**Verdict**: OK

### Cell 5 — 1-A PA Status
**Table**: `focal-elf-631.mmp_pb_summary.app_status`
**Fields**: All valid (`utc_date`, `tracking_bundle`, `mmp`, `verdict.fp_status`, `verdict.opt_with_ifa`, `verdict.opt_with_mas`, `warning.*`, `attr.*`, `no_attr.*`, `spend.total`)
**Verdict**: OK

### Cell 6 — 1-B PA Attribution Method
**Table**: `focal-elf-631.prod_stream_view.cv`
**Fields**: All valid (`cv.mmp`, `cv.pb.attribution.method`, `cv.pb.attribution.raw_method`, `cv.event`, `api.product.app.tracking_bundle`, `api.campaign.id`) — confirmed via sample query.
**Verdict**: OK

### Cell 8 — 2. VT Install
**Table**: `focal-elf-631.prod_stream_view.cv`
**Fields**: All valid (`cv.view_through`, `cv.pb.attribution.viewthrough`)
**Verdict**: OK

### Cell 10 — 3. Revenue Postback
**Table**: `focal-elf-631.prod_stream_view.cv`
**Fields**: All valid (`cv.event_pb`, `cv.revenue_usd.amount`)
**Verdict**: OK

### Cell 12 — 4-A Creatives Configured
**Tables**: `focal-elf-631.standard_digest.product_digest`, `focal-elf-631.standard_digest.creative_digest`
**Fields**: All valid (`product_id`, `platform`, `creative_id`, `creative_title`, `creative_type`, `is_archived`, `timestamp`)
**Verdict**: OK

### Cell 13 — 4-B Impressions by Format
**Table**: `moloco-ae-view.athena.fact_dsp_creative`
**Fields**: All valid (`creative.format`, `creative.id`, `impressions`, `gross_spend_usd`, `installs`, `advertiser.mmp_bundle_id`)
**Verdict**: OK

### Cell 15 — 5. Kakao Bizboard
**Table**: `moloco-ae-view.athena.fact_dsp_creative`
**Fields**: All valid (`creative.size`, `creative.title`, `campaign.country`, `exchange`)
**Verdict**: OK

### Cell 17 — 6-A Bid Filter (pricing)
**Table**: `focal-elf-631.prod_stream_view.pricing`
**Fields**: All valid (`pricing.candidates`, `cand.candidate_result`, `cand.core.reason`, `cand.campaign_id`)
**Note**: Title correctly notes this is 1/1000 sampled data. Percentages are valid since they're relative.
**Verdict**: OK

### Cell 18 — 6-B Bid Filter (trace)
**Table**: `moloco-data-prod.younghan.campaign_trace_raw_prod`
**Fields**: All valid (`date`, `campaign`, `reason_block`, `reason`, `reason_raw`, `rate`)
**Logic**: `SUM(1 / rate)` is the correct pattern for this sampled table.
**Minor note**: This is a personal-namespace table (`younghan.`). Consider if there's a production equivalent.
**Verdict**: OK (with caveat above)

### Cell 20 — 7-A Install Leakage
**Tables**: `moloco-ae-view.athena.fact_dsp_core`, `focal-elf-631.prod_stream_view.cv`
**Fields**: All valid.
**Verdict**: **BUG** — see details below.

### Cell 21 — 7-B Rejected Install Rate
**Table**: `moloco-ods.critical_alert.daily_rejected_install_rate`
**Fields**: All valid (`timestamp`, `campaign_id`, `campaign_spend`, `campaign_valid_installs`, `campaign_rejected_installs`, `campaign_rejection_rate`, `is_alert`, `alert_publishers_default`, `alert_publishers_global`, `product_id`)
**Verdict**: OK

---

## Bug: Cell 20 — 7-A Install Leakage (JOIN fan-out)

**Severity**: High — produces incorrect results.
**Symptom**: Output shows **-100% leakage every day**, which is clearly wrong.

**Root cause**: `moloco_installs` CTE groups by `campaign.country`, producing 2 rows per date (e.g., `KOR` and `None`). But `mmp_postbacks` CTE has only 1 row per `(date, campaign_id)` — no country dimension. The LEFT JOIN on `(date, campaign_id)` duplicates MMP installs to **both** country rows:

```
date=2026-02-11, country=KOR:   moloco=485, mmp=485  <- correct
date=2026-02-11, country=None:  moloco=0,   mmp=485  <- fan-out duplicate!
```

The Python summary then sums: `moloco=485, mmp=970 -> leakage=-100%`

### Fix options

**Option A** — Remove country from the CTE (simplest, if country breakdown isn't needed):

```sql
moloco_installs AS (
  SELECT
    date_utc AS date,
    campaign_id,
    SUM(installs) AS moloco_installs
  FROM `moloco-ae-view.athena.fact_dsp_core`
  ...
  GROUP BY 1, 2
)
```

**Option B** — Keep country but fix the summary aggregation to only sum the non-null country rows:

```python
daily = df_7a[df_7a['country'].notna()].groupby('date').agg(...)
```

---

## Issue: Cell 25 — Summary Shows Stale Results

The summary shows `No data` for checks that clearly had data in earlier cells:
- `1. PA match_type: No data` — but `df_1b` had 12 rows with `PROBABILISTIC` attribution
- `2. VT Install: No data` — but `df_2` had 20 rows with VT installs

This is likely a stale execution issue — the summary cell was run in a session where those DataFrames were different (possibly empty from a prior run). Re-running all cells top-to-bottom should fix this.

---

## Summary Table

| Cell | Check | Status |
|------|-------|--------|
| 3 | Bundle Resolution | OK |
| 5 | 1-A PA Status | OK |
| 6 | 1-B PA Attribution | OK |
| 8 | 2. VT Install | OK |
| 10 | 3. Revenue Postback | OK |
| 12 | 4-A Creatives Configured | OK |
| 13 | 4-B Impressions by Format | OK |
| 15 | 5. Kakao Bizboard | OK |
| 17 | 6-A Bid Filter (pricing) | OK |
| 18 | 6-B Bid Filter (trace) | OK (personal-namespace table caveat) |
| 20 | 7-A Install Leakage | **BUG** — JOIN fan-out doubles MMP installs |
| 21 | 7-B Rejected Install Rate | OK |
| 25 | Summary | Stale execution — needs re-run |
