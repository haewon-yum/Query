# View-Through (VT) & SKAN Analysis Checklist

## Overview
This checklist guides the investigation and analysis of View-Through (VT) attribution performance on iOS, including Probabilistic Attribution (PA) status checks and VT vs SKAN comparisons.

## When to Use This Checklist
- Advertiser questions about iOS attribution coverage
- VT install discrepancy investigations
- PA (Probabilistic Attribution) status verification
- SKAN vs VT performance comparison requests
- iOS 14.5+ traffic analysis
- CPI/ROAS discrepancy on iOS campaigns

---

## Prerequisites / Data Sources

### BigQuery Tables
| Table | Purpose |
|-------|---------|
| `focal-elf-631.prod_stream_view.cv` | Conversion events with attribution method |
| `focal-elf-631.mmp_pb_summary.app_status` | PA/fingerprint status by app (last 90 days) |
| `focal-elf-631.prod.campaign_digest_merged_latest` | Campaign configuration |
| `focal-elf-631.prod.campaign_digest_merged_20*` | Historical campaign config |
| `focal-elf-631.standard_report_v1_view.report_final_skan` | SKAN aggregated metrics |
| `moloco-ae-view.athena.fact_dsp_all` | DSP metrics including VT installs |
| `moloco-ae-view.athena.fact_dsp_core` | Core DSP metrics |
| `moloco-ae-view.athena.dim1_app` | App metadata |

### Required Information
- [ ] Campaign ID(s) or Advertiser ID
- [ ] Tracking bundle / Store bundle
- [ ] Date range for analysis
- [ ] MMP name (affects attribution method parsing)

---

## Step-by-Step Investigation Process

### Step 1: Check PA (Probabilistic Attribution) Status

First, verify if PA is enabled for the app:

```sql
-- Check current PA status for an app
SELECT 
  tracking_bundle,
  utc_date,
  verdict.fp_status AS pa_status,
  verdict.vt_fp_status AS vt_pa_status
FROM `focal-elf-631.mmp_pb_summary.app_status`
WHERE tracking_bundle = 'YOUR_TRACKING_BUNDLE'
  AND utc_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND CURRENT_DATE()
ORDER BY utc_date DESC
```

**PA Status Values:**
- `ENABLED` - Probabilistic Attribution is active
- `DISABLED` - Only deterministic attribution

### Step 2: Verify Attribution Method Distribution

Check how installs are being attributed:

```sql
WITH raw AS (
  SELECT
    api.product.app.tracking_bundle,
    CASE
      WHEN req.device.osv = "" THEN "unknown"
      WHEN cv.pb.mmp.name = "SINGULAR" AND req.device.osv BETWEEN "14.0" AND "18.0" THEN "ios14.5+"
      WHEN cv.pb.mmp.name <> "SINGULAR" AND req.device.osv BETWEEN "14.5" AND "18.0" THEN "ios14.5+"
      ELSE "ios14.4-"
    END AS osv_group,
    cv.view_through,
    CASE
      WHEN cv.mmp = "KOCHAVA" THEN REGEXP_EXTRACT(cv.postback, r'&matched_by=([a-zA-Z_]*)')
      WHEN cv.mmp = "ADBRIX_V2" THEN REGEXP_EXTRACT(cv.postback, r'&measurement_type=([a-zA-Z_]*)')
      WHEN cv.mmp <> "BRANCH" THEN REGEXP_EXTRACT(cv.postback, r'&match_type=([a-zA-Z_]*)')
      ELSE "unknown"
    END AS method,
    COUNT(*) AS cnt
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE()
    AND UPPER(cv.event) = "INSTALL"
    AND req.device.os = "IOS"
    AND api.campaign.id = 'YOUR_CAMPAIGN_ID'
  GROUP BY ALL
)
SELECT 
  tracking_bundle,
  osv_group,
  view_through,
  method,
  SUM(cnt) AS installs,
  CASE 
    WHEN method LIKE "%device%" OR method LIKE "%id%" OR method LIKE "%determi%" THEN "deterministic"
    ELSE "probabilistic"
  END AS attribution_type
FROM raw
GROUP BY ALL
ORDER BY installs DESC
```

### Step 3: VT Install Analysis from fact_dsp_all

Check VT vs CT install breakdown:

```sql
SELECT 
  campaign_id,
  DATE(timestamp_utc) AS dt,
  SUM(skan_installs) AS skan_installs,
  SUM(skan_installs_ct) AS skan_installs_ct,
  SUM(skan_installs_vt) AS skan_installs_vt,
  SAFE_DIVIDE(SUM(skan_installs_vt), SUM(skan_installs)) AS vt_ratio
FROM `moloco-ae-view.athena.fact_dsp_all` 
WHERE campaign_id = 'YOUR_CAMPAIGN_ID'
  AND DATE(timestamp_utc) BETWEEN 'START_DATE' AND 'END_DATE'
GROUP BY ALL
ORDER BY dt
```

### Step 4: SKAN Performance Comparison (PA Enabled vs Disabled)

Compare performance between PA-enabled and disabled apps:

```sql
SELECT
  FORMAT_DATE('%Y-%m', time_bucket) AS month,
  platform,
  product_id,
  campaign_id,
  CASE WHEN verdict.fp_status = 'ENABLED' THEN 'pa_enabled' ELSE 'pa_disabled' END AS pa_status,
  SUM(Spend) AS spend,
  SUM(SKAN_ConversionCount) AS conversion_count,
  SUM(SKAN_ConversionEventRevenueMinSum) AS skan_revenue_min,
  SUM(SKAN_ConversionEventRevenueMaxSum) AS skan_revenue_max
FROM `focal-elf-631.standard_report_v1_view.report_final_skan` s
LEFT JOIN `focal-elf-631.mmp_pb_summary.app_status` pa 
  ON s.tracking_bundle = pa.tracking_bundle
WHERE DATE(time_bucket) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND CURRENT_DATE()
GROUP BY ALL
ORDER BY month, platform
```

### Step 5: Campaign-Level PA Configuration Check

Verify campaign settings for allow_fingerprinting:

```sql
SELECT 
  timestamp, 
  campaign_name,
  allow_fingerprinting, 
  sk_ad_network_input
FROM `focal-elf-631.prod.campaign_digest_merged_latest`
WHERE campaign_name = 'YOUR_CAMPAIGN_ID'
ORDER BY timestamp DESC
LIMIT 10
```

---

## Key Metrics to Check

### VT Coverage Metrics
- [ ] VT install ratio (VT installs / Total SKAN installs)
- [ ] PA-attributed install ratio among iOS 14.5+ traffic
- [ ] Deterministic vs Probabilistic attribution split

### Performance Metrics
- [ ] ROAS by attribution type (VT vs CT)
- [ ] CPI by attribution type
- [ ] Install volume trends (pre/post PA change)

### Configuration Checks
- [ ] PA status (ENABLED/DISABLED)
- [ ] VT PA status (separate from CT PA)
- [ ] allow_fingerprinting campaign setting
- [ ] ignore_mmp_feedback setting

---

## Common Patterns / Red Flags

### Low VT Coverage Indicators
1. **PA Disabled** - Check `fp_status` in app_status table
2. **MMP Configuration** - Some MMPs don't support PA
3. **Recent iOS Version** - iOS 17+ has stricter privacy
4. **Campaign Setting Mismatch** - `allow_fingerprinting` = false

### Attribution Discrepancy Indicators
1. **MMP vs MOLOCO count mismatch** - Check attribution window differences
2. **Sudden VT drop** - Check PA status change history
3. **High probabilistic ratio** - May indicate fingerprinting reliance

### Performance Impact Patterns
| Scenario | Expected Impact |
|----------|-----------------|
| PA Disabled → Enabled | +10-30% VT installs |
| PA Enabled → Disabled | Significant VT drop |
| VT ratio too high (>60%) | May indicate attribution leakage |
| VT ratio near zero | Check PA configuration |

---

## PA Status Interpretation

### Combined Status Analysis
```sql
SELECT
  tracking_bundle,
  CASE
    WHEN postback_pa = 'enabled' THEN 
      CASE
        WHEN moloco_pa = 'disabled' THEN "Warning: Attribution status not aligned with postback"
        WHEN viewthrough = 'disabled' THEN "Warning: PA not enabled for VT installs"
        ELSE 'Probabilistic Attribution Enabled'
      END
    ELSE "Warning: PA not enabled for 14.5+ traffic"
  END AS status_summary
FROM (
  SELECT 
    tracking_bundle,
    MAX(CASE WHEN is_fp_attributed THEN 'enabled' ELSE 'disabled' END) AS postback_pa,
    MAX(CASE WHEN ignore_mmp_feedback = FALSE THEN 'enabled' ELSE 'disabled' END) AS moloco_pa,
    MAX(CASE WHEN is_fp_attributed AND view_through THEN 'enabled' ELSE 'disabled' END) AS viewthrough
  FROM attribution_analysis
  GROUP BY tracking_bundle
)
```

---

## Example Cases

### Case 1: Advertiser Reports Low iOS Install Volume
**Investigation Steps:**
1. Check PA status → Found: DISABLED
2. Verify campaign settings → `allow_fingerprinting` was FALSE
3. Compare with PA-enabled peers → 25% lower VT coverage

**Resolution:** Enable PA in campaign settings

### Case 2: VT vs SKAN Discrepancy
**Investigation Steps:**
1. Pull VT ratio from fact_dsp_all → 45% VT
2. Compare with MMP dashboard → MMP shows lower VT
3. Check attribution window settings → Different windows

**Resolution:** Align attribution windows between MOLOCO and MMP

### Case 3: Sudden Drop in iOS Performance
**Investigation Steps:**
1. Check PA status history → Changed from ENABLED to DISABLED on date X
2. Compare metrics pre/post → 30% install drop post-change
3. Verify MMP configuration → MMP updated their SDK

**Resolution:** Coordinate with MMP to re-enable PA

---

## Escalation Criteria

Escalate when:
- [ ] PA status conflicts between MOLOCO and MMP
- [ ] Significant unexplained performance drop (>20%)
- [ ] Attribution method distribution anomalies
- [ ] Advertiser requesting formal VT impact analysis
- [ ] Multiple campaigns affected by same issue

---

## Related Resources

### Local SQL Files
- `iOS Measurement/PA_status_check.sql` - PA status verification
- `iOS Measurement/PA_app_status.sql` - App-level PA status
- `iOS Measurement/SKAN_performance_vt_install.sql` - VT install analysis
- `iOS Measurement/SKAN_performance_comparison.sql` - PA enabled vs disabled comparison
- `iOS Measurement/PA_ratio_among_skan_kpi_apps.sql` - PA ratio analysis

### Reference Links
- Jira: ODSB-11116 (allow_fingerprinting reference)

### Internal Docs
*To be populated from Glean search*

---

*Last updated: Feb 3, 2026*
*Version: Draft 1.0*
