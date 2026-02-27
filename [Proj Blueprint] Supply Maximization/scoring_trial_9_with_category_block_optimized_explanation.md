# Scoring Query Walkthrough (Optimized Version)

This document explains the logic of:

- `[Proj Blueprint] Supply Maximization/scoring_trial_9_with_category_block_optimized.sql` (scheduled-query style with `@run_time`)
- `[Proj Blueprint] Supply Maximization/scoring_trial_9_with_category_block_optimized_portable.sql` (manual/scheduled compatible with `CURRENT_DATE()`)

Both files use the same business logic and performance optimizations.  
Only the date-parameter handling is different.

---

## 1) Date Window Setup (`params`)

### What it does
Defines the analysis window used by all spend and bidrequest reads.

### Why
Keeps date filtering consistent across all CTEs and avoids hardcoded dates.

### Difference between two files
- `optimized.sql`: uses `DATE(@run_time)` for scheduled queries.
- `optimized_portable.sql`: uses `CURRENT_DATE()` for ad-hoc and scheduled usage.

---

## 2) Active Campaign Scope (`campaigns_with_spend`)

### What it does
From `athena.fact_dsp_core`, selects campaigns with positive spend in the date window (`IOS`, `ANDROID` only).

### Why
This is the primary scope reduction so later heavy steps only process relevant campaigns.

---

## 3) Campaign Metadata (`campaign_tab`)

### What it does
Builds campaign-level metadata:
- `campaign_id`
- `advertiser_id`
- normalized `os`
- `target_countries` array (uppercased)

### Why
Provides consistent campaign attributes and country targeting list used in later joins.

---

## 4) Ad Group -> Target Mapping (`adgroup_raw`, `distinct_target_ids`, `target_raw`)

### What it does
1. Extracts `user_targets` from active ad groups.
2. Deduplicates target IDs.
3. Pulls targeting condition JSON from `audience_target_digest`.

### Why
Creates the minimum target dataset required for campaign-level targeting masks.

---

## 5) Campaign Target Masks (`target_masks_raw`, `target_masks`, `target_key_counts`)

### What it does
- Reads arrays directly from JSON paths (`allowed_*`, `blocked_*`) using `JSON_VALUE_ARRAY`.
- Aggregates arrays to campaign level.
- De-duplicates values into clean campaign masks.
- Computes per-key counts for reporting details.

### Why
This replaces the expensive regex-based key extraction in the original query and avoids row explosion.

---

## 6) LAT Policy + Campaign Join (`campaign_digest`)

### What it does
Joins campaign metadata with `standard_digest.campaign_digest` to get normalized `ad_tracking_allowance`:
- `DO_NOT_CARE`
- `NON_LAT_ONLY`
- `LAT_ONLY`

### Why
Needed to compute tracking-eligible and fully accessible bid supply.

---

## 7) Effective Targeting Split (`campaign_target_profile`, `campaign_with_target`, `campaign_without_target`)

### What it does
Builds campaign profile with all targeting masks and a boolean:
- `has_effective_targeting` = any targeting array has at least one value.

Then splits campaigns into:
- `campaign_with_target`
- `campaign_without_target`

### Why
This is a key optimization: non-targeted campaigns do not need app/exchange/device/category-level bid dimensions.

---

## 8) Country/OS Pruning (`campaign_country_os_target`, `campaign_country_os_no_target`)

### What it does
Precomputes distinct `(country, os)` pairs needed for each path.

### Why
Prunes bidrequest table scans and keeps both targeted and non-targeted aggregations scoped.

---

## 9) Publisher Categories Lookup (`apt_categories`)

### What it does
Loads app categories from APT table:
- key: `app_bundle`
- value: normalized `pub_categories` array

### Why
Required to enforce category allow/block rules.

---

## 10) Bidrequest Aggregation (Split Strategy)

### 10.1 `bid_dim_targeted` (detailed)
Aggregates bidrequests by:
- `country`, `os`, `is_lat`, `app_bundle`, `exchange`, `device_type`

Used only for campaigns with effective targeting.

### 10.2 `bid_dim_light` (lightweight)
Aggregates bidrequests by:
- `country`, `os`, `is_lat`

Used only for campaigns without targeting.

### Why
This reduces global runtime significantly by avoiding unnecessary high-cardinality group-bys for non-targeted campaigns.

---

## 11) Targeted Path Evaluation (`campaign_rows_with_target`, `campaign_rows_with_flags`)

### What it does
For targeted campaigns:
1. Joins campaign rows to detailed bid dim and APT categories.
2. Computes two booleans once per row:
   - `tracking_pass`
   - `targeting_pass` (apps/exchanges/countries/device/category checks)

Category logic:
- Allowlist: if set, app must have at least one matching category.
- Blocklist: if set, app passes only if no blocked category is present.
- If app has no APT category, blocklist check passes (current conservative behavior).

### Why
Computing pass/fail flags once avoids repeating identical complex conditions in multiple SUM expressions.

---

## 12) Bid Metrics by Campaign

### 12.1 `campaign_bids_with_target`
Computes:
- `total_bids`
- `tracking_eligible_bids`
- `tgt_eligible_bids`
- `accessible_bids` (`tracking_pass AND targeting_pass`)

### 12.2 `campaign_bids_without_target`
Computes same metric schema, but:
- target eligibility is full (`SUM(total_bids)`)
- accessibility equals tracking eligibility

### 12.3 `bid_agg`
`UNION ALL` of both paths.

---

## 13) Summary Table (`summary`)

### What it does
Joins bid metrics with:
- campaign metadata (`os`, `target_countries`, `ad_tracking_allowance`)
- targeting key counts

Then computes ratios:
- `bid_accessible_ratio_tracking`
- `bid_accessible_ratio_targeting`
- `bid_accessible_ratio_total`

### Why
Central normalized table for downstream score generation.

---

## 14) Blueprint Scores

### 14.1 `target_accessible_supply_bids_score`
- Score: `bid_accessible_ratio_targeting * 100`
- Adds details + recommendations based on targeting key counts.

### 14.2 `traffic_accessible_supply_bids_score`
- Score: `bid_accessible_ratio_tracking * 100`
- Adds recommendation based on LAT policy and OS.

### 14.3 OS Coverage Score (`advertisers_with_spend` -> `os_scoring_agg_camp`)
- Calculates advertiser-level OS mix quality by country vs market ratio.
- Emits campaign-level score row (`3_os_coverage_supply_score`) via advertiser join.

---

## 15) Final Merge and Overall Index (`merged`, `overall_index`)

### What it does
Combines all blueprint rows per campaign and computes:

`overall_optimization_bidreq_score = (target_score * traffic_score) / 100`

using:
- `'1_target_accessible_supply_bidreq_score'`
- `'2_traffic_accessible_supply_bidreq_score'`

### Why
Produces a consolidated supply optimization index while retaining per-blueprint diagnostics.

---

## 16) Practical Notes

- The optimized query is expected to scale better globally due to:
  - elimination of regex-based target flattening
  - targeted/non-targeted bid aggregation split
  - single-pass predicate flags
- Result differences vs previous versions may appear in text fields ordering (`STRING_AGG`) even when scores match.
- If deterministic recommendation ordering is required, add `ORDER BY` inside `STRING_AGG`.

---

## 17) Which File to Use

- Use `..._optimized.sql` when you want scheduler-driven dates via `@run_time`.
- Use `..._optimized_portable.sql` when you want one query that runs manually and in scheduler without parameters.

