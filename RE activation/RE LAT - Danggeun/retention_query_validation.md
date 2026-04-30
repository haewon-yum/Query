# Retention Query Validation: RE LAT - Danggeun (Step 2b)

**Query:** Pull full daily retention curve (D0-D7)
**Date:** 2026-03-03

## Field Paths: All Correct

| Reference | Path | Status |
|---|---|---|
| `cv.bid.mtid` | `bid.mtid` (STRING) | OK |
| `cv.timestamp` | `timestamp` (TIMESTAMP) | OK |
| `cv.imp.happened_at` | `imp.happened_at` (TIMESTAMP) | OK |
| `cv.cv.pb.attribution.reengagement` | `cv.pb.attribution.reengagement` (BOOL) | OK |
| `cv.api.campaign.id` | `api.campaign.id` (STRING) | OK |
| `cd.campaign_id` | `campaign_id` (STRING) | OK |
| `cd.campaign_os` | `campaign_os` (STRING) | OK |

## Issues Found

### 1. Title vs code mismatch (bug)

Title says **D0-D7** but `GENERATE_ARRAY(0, 30)` generates **D0-D30**. The 37-day extension on the timestamp filter is consistent with D30, so the title is wrong. Fix either:
- Change title to "D0-D30", or
- Change `GENERATE_ARRAY(0, 30)` to `GENERATE_ARRAY(0, 7)` and `INTERVAL 37 DAY` to `INTERVAL 14 DAY`

### 2. Retention measured via `cv` events, not app sessions (conceptual)

The `cv` table tracks **conversion postbacks** from MMPs (installs, in-app events, purchases). This is **not the same as app opens/sessions**. A user could open the app daily but only appear "retained" on days they trigger a tracked conversion event. This likely **undercounts true retention** unless the MMP sends app-open postbacks.

If you want session-based retention, you'd need an app-event or session table instead.

### 3. `daily_activity` includes non-reengagement events (intentional?)

The cohort is filtered to `is_reengagement = TRUE`, but `daily_activity` pulls **all** events from `re_events` (including `is_reengagement = FALSE`). This means any cv event counts as "retained", not just reengagement-attributed ones. This is likely correct (any activity = retained), but worth confirming it's intentional.

## Minor Suggestions

- **Explicit DATE cast**: `DATE_ADD('{END_DATE}', INTERVAL 37 DAY)` relies on implicit string-to-DATE casting. Safer to use `DATE_ADD(DATE '{END_DATE}', INTERVAL 37 DAY)`.
- **`campaign_digest` has no version/timestamp filter**: If the digest has multiple versions per campaign, you may get duplicate rows. Consider adding `QUALIFY ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY version DESC) = 1`.

## Overall Verdict

The query is **structurally sound** - joins, grouping, and retention logic are correct. The main concern is **issue #1** (D7 vs D30 mismatch) which should be fixed, and **issue #2** (whether cv events are the right signal for retention) which is a design decision.
