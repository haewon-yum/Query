# ML Validation: Netmarble RE ROAS — `com.netmarble.kofafk`

**Campaign ID:** `y0C1VwL3aBWibp7O`  
**App Bundle:** `com.netmarble.kofafk` (King of Fighters AFK, Android)  
**MMP:** AppsFlyer  
**Investigation Date:** 2026-02-11  
**Google Spreadsheet:** https://docs.google.com/spreadsheets/d/13lGuup0_BN5h3l5_M7a2pHqA-k3VWuMVW0micst8aV0

---

## 1. MMP Postback Events Configured

18 events configured for `com.netmarble.kofafk`:

| # | Event Name |
|---|------------|
| 1 | `af_app_opened` |
| 2 | `buy_adblock` |
| 3 | `create_nickname` |
| 4 | `funnel_first` |
| 5 | `funnel_second` |
| 6 | `funnel_third` |
| 7 | `install` |
| 8 | `join_clan` |
| 9 | `level_achieved_10` |
| 10 | `level_achieved_30` |
| 11 | `login` |
| 12 | `login_complete` |
| 13 | `reengagement` |
| 14 | `revenue` |
| 15 | `summon_fighter_level_5` |
| 16 | `visit_shop` |
| 17 | `rejected_install` |
| 18 | `reattribution` |

**Notes:**
- `revenue` is used for ROAS optimization
- `login` / `af_app_opened` used for CPA campaigns
- `visit_shop` tested as CPA event but did not optimize well toward revenue

---

## 2. ML Model Calibration (RE Revenue)

### Query

```sql
SELECT
  b_campaign AS campaign,
  model_timestamp,
  data_timestamp,
  mean_label * num_examples AS sum_label,
  mean_prediction * num_examples AS sum_prediction,
  SAFE_DIVIDE(mean_prediction, mean_label) AS calibration,
  num_examples
FROM
  `moloco-dsp-ml-prod.training_log_exporter_evaluation_prod.re_revenue`
WHERE
  data_timestamp >= '2026-02-01'
  AND model_version = 'v11'
  AND b_campaign = 'y0C1VwL3aBWibp7O'
ORDER BY data_timestamp DESC
```

### Results (all days >= 2026-02-01)

| data_timestamp | model_timestamp | num_examples | sum_label | sum_prediction | calibration |
|---|---|---:|---:|---:|---|
| 2026-02-09 | 2026-02-08 | 353,905 | **0.0** | 8.13 | null |
| 2026-02-08 | 2026-02-08 | 386,341 | **0.0** | 5.29 | null |
| 2026-02-08 | 2026-02-07 | 386,341 | **0.0** | 4.60 | null |
| 2026-02-07 | 2026-02-07 | 451,278 | **0.0** | 7.02 | null |
| 2026-02-07 | 2026-02-06 | 451,278 | **0.0** | 6.73 | null |
| 2026-02-06 | 2026-02-06 | 807,360 | **0.0** | 12.43 | null |
| 2026-02-06 | 2026-02-05 | 403,680 | **0.0** | 10.95 | null |
| 2026-02-05 | 2026-02-05 | 365,524 | **0.0** | 10.12 | null |
| 2026-02-05 | 2026-02-04 | 365,524 | **0.0** | 14.38 | null |

**Finding:** Every day has `sum_label = 0` and `calibration = null`. Model predicts $5-14 daily revenue but actual is always 0. Campaign serving 353K-807K impressions daily with zero revenue labels.

---

## 3. Unattributed vs Attributed Revenue (Bundle Level)

### Query

```sql
SELECT
  DATE(timestamp) AS date,
  moloco.attributed AS is_attributed,
  COUNT(*) AS event_count,
  SUM(event.revenue_usd.amount) AS total_revenue_usd
FROM `focal-elf-631.prod_stream_view.pb`
WHERE app.bundle = 'com.netmarble.kofafk'
  AND event.name = 'revenue'
  AND timestamp >= '2026-02-01'
  AND device.country = 'KOR'
GROUP BY 1, 2
ORDER BY date DESC, is_attributed
```

### Results

| Date | Attributed Revenue (USD) | Attributed Events | Unattributed Revenue (USD) | Unattributed Events | Unattr % |
|------|---:|---:|---:|---:|---:|
| 2026-02-11 | $62.94 | 30 | $4,137.57 | 1,043 | 98.5% |
| 2026-02-10 | $79.20 | 32 | $3,139.37 | 821 | 97.5% |
| 2026-02-09 | $108.49 | 32 | $2,425.25 | 633 | 95.7% |
| 2026-02-08 | $116.67 | 36 | $2,660.80 | 665 | 95.8% |
| 2026-02-07 | $151.20 | 60 | $2,971.48 | 746 | 95.2% |
| 2026-02-06 | $204.14 | 54 | $3,318.64 | 768 | 94.2% |
| 2026-02-05 | $295.44 | 70 | $5,666.87 | 1,171 | 95.0% |
| 2026-02-04 | $85.89 | 31 | $2,288.48 | 617 | 96.4% |
| 2026-02-03 | $97.09 | 31 | $2,664.92 | 687 | 96.5% |
| 2026-02-02 | $177.82 | 42 | $3,758.17 | 964 | 95.5% |
| 2026-02-01 | $109.43 | 42 | $3,415.76 | 825 | 96.9% |

**Finding:** ~95-98% of revenue is unattributed. Bundle receives $2.3K-$5.7K/day unattributed revenue vs $63-$295/day attributed.

---

## 4. Attributed Revenue by Campaign ID

### Query

```sql
SELECT
  DATE(timestamp) AS date,
  moloco.campaign_id,
  moloco.attributed AS is_attributed,
  COUNT(*) AS event_count,
  SUM(event.revenue_usd.amount) AS total_revenue_usd
FROM `focal-elf-631.prod_stream_view.pb`
WHERE app.bundle = 'com.netmarble.kofafk'
  AND event.name = 'revenue'
  AND timestamp >= '2026-02-05'
  AND device.country = 'KOR'
  AND moloco.attributed = true
GROUP BY 1, 2, 3
ORDER BY date DESC, campaign_id
```

### Results (Feb 8 example)

| Campaign ID | Revenue (USD) | Events |
|---|---:|---:|
| `byJy685EjCDQ8Mri` (CPA visit_shop) | $89.47 | 24 |
| `MWJToYzorEMWkrUj` | $24.58 | 11 |
| `A2e3gzvtXMgX1O6Y` (tROAS launch KR) | $2.62 | 1 |
| **`y0C1VwL3aBWibp7O`** | **$0** | **0** |

**Finding:** Campaign `y0C1VwL3aBWibp7O` receives ZERO attributed revenue events. All attributed revenue goes to other campaigns under the same bundle.

---

## 5. Attributed Conversion Events (Non-Revenue) for `y0C1VwL3aBWibp7O`

### Query (prod_stream_view.pb — sampled)

```sql
SELECT
  DATE(timestamp) AS date,
  event.name AS event_name,
  COUNT(*) AS event_count,
  SUM(IFNULL(event.revenue_usd.amount, 0)) AS total_revenue_usd
FROM `focal-elf-631.prod_stream_view.pb`
WHERE app.bundle = 'com.netmarble.kofafk'
  AND moloco.attributed = true
  AND moloco.campaign_id = 'y0C1VwL3aBWibp7O'
  AND timestamp >= '2026-02-01'
GROUP BY 1, 2
ORDER BY date DESC, event_count DESC
```

### Query (df_accesslog.pb — unsampled)

```sql
SELECT
  DATE(timestamp) AS date,
  event.name AS event_name,
  COUNT(*) AS event_count,
  SUM(IFNULL(event.revenue_usd.amount, 0)) AS total_revenue_usd
FROM `focal-elf-631.df_accesslog.pb`
WHERE app.bundle = 'com.netmarble.kofafk'
  AND attribution.attributed = true
  AND moloco.campaign_id = 'y0C1VwL3aBWibp7O'
  AND timestamp >= '2026-02-01'
GROUP BY 1, 2
ORDER BY date DESC, event_count DESC
```

> **Note:** `prod_stream_view.pb` uses `moloco.attributed`, while `df_accesslog.pb` uses `attribution.attributed`.

### Summary (event counts from sampled table — confirmed identical with unsampled)

| Date | af_app_opened | login_complete | visit_shop | reengagement | reattribution | join_clan | lvl_10 | lvl_30 | login | funnels | other | **revenue** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 02-05 | 412 | 160 | 40 | 259 | 30 | 2 | 6 | 5 | 13 | 1 | 0 | **0** |
| 02-06 | 1,276 | 443 | 126 | 334 | 40 | 9 | 39 | 28 | 12 | 16 | 1 | **0** |
| 02-07 | 1,234 | 345 | 334 | 300 | 47 | 72 | 45 | 30 | 16 | 40 | 3 | **0** |
| 02-08 | 1,010 | 324 | 281 | 270 | 58 | 87 | 40 | 27 | 20 | 36 | 9 | **0** |
| 02-09 | 529 | 222 | 187 | 172 | 32 | 54 | 43 | 27 | 7 | 18 | 3 | **0** |
| 02-10 | 395 | 179 | 188 | 132 | 41 | 23 | 36 | 26 | 18 | 27 | 1 | **0** |
| 02-11 | 67 | 54 | 111 | 14 | 9 | 11 | 12 | 9 | 5 | 13 | 1 | **0** |

---

## 6. Distinct Users (IFA / MTID) per Event

### Query

```sql
SELECT
  DATE(timestamp) AS date,
  event.name AS event_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT device.ifa) AS distinct_ifa,
  COUNT(DISTINCT moloco.mtid) AS distinct_mtid
FROM `focal-elf-631.prod_stream_view.pb`
WHERE app.bundle = 'com.netmarble.kofafk'
  AND moloco.attributed = true
  AND moloco.campaign_id = 'y0C1VwL3aBWibp7O'
  AND timestamp >= '2026-02-01'
GROUP BY 1, 2
ORDER BY date DESC, distinct_mtid DESC
```

### Results

| Date | Event | Events | # Users (MTID) |
|------|-------|-------:|---------------:|
| **2026-02-11** | af_app_opened | 67 | 31 |
| | login_complete | 54 | 30 |
| | visit_shop | 111 | 16 |
| | reengagement | 14 | 14 |
| | level_achieved_10 | 12 | 12 |
| | reattribution | 9 | 9 |
| | level_achieved_30 | 9 | 9 |
| | login | 5 | 5 |
| **2026-02-10** | af_app_opened | 395 | 183 |
| | reengagement | 132 | 132 |
| | login_complete | 179 | 109 |
| | reattribution | 41 | 41 |
| | visit_shop | 188 | 26 |
| | level_achieved_10 | 36 | 25 |
| | level_achieved_30 | 26 | 19 |
| | login | 18 | 18 |
| **2026-02-09** | af_app_opened | 529 | 240 |
| | reengagement | 172 | 172 |
| | login_complete | 222 | 114 |
| | reattribution | 32 | 32 |
| | level_achieved_10 | 43 | 21 |
| | visit_shop | 187 | 19 |
| | level_achieved_30 | 27 | 12 |
| **2026-02-08** | af_app_opened | 1,010 | 358 |
| | reengagement | 270 | 270 |
| | login_complete | 324 | 163 |
| | reattribution | 58 | 58 |
| | visit_shop | 281 | 27 |
| | level_achieved_10 | 40 | 24 |
| | login | 20 | 20 |
| | level_achieved_30 | 27 | 15 |
| **2026-02-07** | af_app_opened | 1,234 | 400 |
| | reengagement | 300 | 300 |
| | login_complete | 345 | 159 |
| | reattribution | 47 | 47 |
| | visit_shop | 334 | 34 |
| | level_achieved_10 | 45 | 26 |
| | level_achieved_30 | 30 | 22 |
| | login | 16 | 16 |
| **2026-02-06** | af_app_opened | 1,276 | 422 |
| | reengagement | 334 | 334 |
| | login_complete | 443 | 154 |
| | reattribution | 40 | 40 |
| | visit_shop | 126 | 22 |
| | level_achieved_10 | 39 | 20 |
| | level_achieved_30 | 28 | 14 |
| | login | 12 | 12 |
| **2026-02-05** | reengagement | 259 | 259 |
| | af_app_opened | 412 | 169 |
| | login_complete | 160 | 67 |
| | reattribution | 30 | 30 |
| | login | 13 | 13 |
| | visit_shop | 40 | 7 |

**Note:** IFA = MTID almost everywhere (1:1 mapping). Only 1 discrepancy on Feb 7 `af_app_opened` (401 IFA vs 400 MTID).

---

## 7. Conclusion

**Root Cause:** Campaign `y0C1VwL3aBWibp7O` has **zero attributed `revenue` postbacks** from AppsFlyer across all dates, despite receiving hundreds to thousands of attributed engagement events daily (app opens, logins, shop visits, reengagement, level achievements, etc.).

The bundle `com.netmarble.kofafk` does receive attributed revenue, but it is attributed to other campaigns (`byJy685EjCDQ8Mri`, `MWJToYzorEMWkrUj`, `A2e3gzvtXMgX1O6Y`) — never to `y0C1VwL3aBWibp7O`.

**Possible causes:**
1. **MMP Attribution Window:** Revenue events may fall outside the attribution window for this campaign, with last-touch attribution going to a different campaign that had a more recent click/impression.
2. **Campaign Link Configuration:** The AppsFlyer attribution link for this campaign may not be properly configured to receive revenue postbacks.
3. **Attribution Priority:** Other campaigns under the same bundle may have higher attribution priority (e.g., more recent user interaction).

**Impact:** The RE revenue ML model trains on all-zero labels for this campaign (sum_label = 0 every day), meaning it cannot learn a meaningful revenue signal. Calibration is undefined (null) across all days.

**Recommendation:** Investigate MMP postback configuration and attribution setup for campaign `y0C1VwL3aBWibp7O`. Check if the campaign's attribution links are correctly configured in AppsFlyer, and whether the attribution window settings match the expected user journey.

---

## 8. PA Status Check — `focal-elf-631.mmp_pb_summary.app_status`

Use this table to check whether PA (Probabilistic Attribution) enabled postbacks are being received for an app bundle.

### Table Overview

- **Partitioned by:** `utc_date` (90-day expiration)
- **Clustered by:** `utc_date`, `mmp`, `tracking_bundle`
- **Scope:** iOS only (the merge procedure filters `device.os = 'IOS'`)
- **Orchestration:** Airflow DAG `tascone_mmp_pb_summary.py` → calls stored procedure `focal-elf-631.mmp_pb_summary.merge_app_status(date_start, date_end)`

### Upstream Dependencies

| Source Table | Role |
|---|---|
| `focal-elf-631.mmp_pb_summary.summary` | Primary source — daily postback counts by attributed/non-attributed, ATT opt-in/opt-out, device signals (IFA, IFV, IP, MTID) |
| `focal-elf-631.standard_digest.mmp_integration_reference_digest` | MMP integration reference — maps `mmp` + `mmp_bundle` to `platform`, `advertiser_id`, `product_id` |
| `focal-elf-631.standard_digest.campaign_digest` | Campaign metadata — maps to `campaign_id` (iOS campaigns) |
| `focal-elf-631.standard_cs_v5_view.all_events_extended_utc` | Spending data — `total_revenue` (spend) per campaign per day |

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `verdict.fp_status` | STRING | PA status: `ENABLED`, `DISABLED`, `PARTIAL`, `UNKNOWN_MISSING_ATTR`, `UNKNOWN_MISSING_ATTR_OPTOUT`, `UNKNOWN_NEGLIGIBLE_ATTR_OPTOUT` |
| `verdict.opt_with_ifa` | BOOL | Feasible to optimize with IFA (has both ATT opt-in and opt-out attributed postbacks) |
| `verdict.opt_with_mas` | BOOL | Feasible to optimize with MAS (no missing IFV+IP in opt-out postbacks) |
| `warning.appsflyer_ap_on` | BOOL | AppsFlyer Advanced Privacy is ON (privacy postbacks detected) |
| `warning.appsflyer_aap_enabled` | BOOL | AppsFlyer AAP enabled |
| `warning.appsflyer_vt_pa_enabled` | BOOL | AppsFlyer VT PA enabled |
| `attr.no_att.privacy` | INT | Count of privacy postbacks (ATT opt-out, attributed) |
| `attr.att.total` | INT | Attributed + ATT opt-in postback count |
| `attr.no_att.total` | INT | Attributed + ATT opt-out postback count |
| `no_attr.att.total` | INT | Non-attributed + ATT opt-in postback count |
| `no_attr.no_att.total` | INT | Non-attributed + ATT opt-out postback count |
| `spend.total` | FLOAT | Total spend (USD) for this mmp + tracking_bundle |

### `fp_status` Verdict Logic

```
APPSFLYER + AP OFF                              → ENABLED
APPSFLYER + AP ON                               → DISABLED
No attributed postbacks (attr.total = 0)        → UNKNOWN_MISSING_ATTR
Attributed but no opt-out (attr.no_att.total=0) → UNKNOWN_MISSING_ATTR_OPTOUT
Opt-out < 1% of total attributed                → UNKNOWN_NEGLIGIBLE_ATTR_OPTOUT
All postbacks have MTID + no Adjust EPM         → ENABLED
All postbacks miss MTID or Adjust EPM on        → DISABLED
Mixed MTID presence                             → PARTIAL
```

### Example Query — PA Status for an iOS Bundle

```sql
SELECT
  utc_date,
  mmp,
  tracking_bundle,
  verdict.fp_status AS pa_status,
  verdict.opt_with_ifa,
  verdict.opt_with_mas,
  warning.appsflyer_ap_on,
  warning.appsflyer_aap_enabled,
  warning.appsflyer_vt_pa_enabled,
  attr.att.total AS attr_att_optin,
  attr.no_att.total AS attr_att_optout,
  attr.no_att.privacy AS attr_privacy_count,
  no_attr.att.total AS noattr_att_optin,
  no_attr.no_att.total AS noattr_att_optout,
  ROUND(spend.total, 2) AS spend_usd
FROM `focal-elf-631.mmp_pb_summary.app_status`
WHERE tracking_bundle = '<iOS_BUNDLE_ID>'
  AND utc_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
ORDER BY utc_date DESC
```

> **Note:** This table is **iOS only**. For Android bundles (e.g., `com.netmarble.kofafk`), PA is generally not relevant as GAID is available. Use `prod_stream_view.pb` or `df_accesslog.pb` directly for Android postback checks.
