# Fraud Investigation Checklist

## Overview
This checklist guides the investigation of suspected fraudulent traffic, publishers, or user behavior in DSP campaigns.

## When to Use This Checklist
- Advertiser reports suspicious install patterns
- Abnormal retention/revenue metrics detected
- MMP flags rejected installs
- Unusually high CTR/IR from specific publishers
- Sudden CPI changes without market explanation

---

## Prerequisites / Data Sources

### BigQuery Tables
| Table | Purpose |
|-------|---------|
| `focal-elf-631.prod_stream_view.cv` | Conversion events (installs, purchases, retention) |
| `moloco-ae-view.looker.campaign_raw_metrics_view` | Aggregated campaign metrics |
| `moloco-ae-view.looker.campaign_raw_all_view` | Detailed campaign metrics by dimensions |
| `focal-elf-631.df_app_profile.lifetime_app_latest` | Publisher app profile info |
| `moloco-ae-view.athena.dim1_app` | App metadata (publisher name, genre) |
| `moloco-ae-view.athena.fact_dsp_all` | Daily aggregated DSP metrics |

### Required Information
- [ ] Campaign ID(s)
- [ ] Advertiser ID
- [ ] Date range of suspicious activity
- [ ] Specific publisher bundle(s) if known
- [ ] MMP rejection reasons if available

---

## Step-by-Step Investigation Process

### Step 1: Identify Scope and Baseline
1. Pull overall campaign metrics for the period
2. Compare against historical averages (prior 30 days)
3. Note any significant deviations in:
   - Install volume
   - CPI
   - Retention rates (D1, D3, D7)
   - Revenue per install

### Step 2: Publisher-Level Analysis
Run retention and revenue analysis by publisher (app_bundle):

```sql
-- Key metrics by publisher
DECLARE start_date DATE DEFAULT 'YYYY-MM-DD';
DECLARE end_date DATE DEFAULT 'YYYY-MM-DD';

WITH installs AS (
  SELECT
    bid.mtid,
    cv.happened_at AS install_at,
    req.app.bundle
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE timestamp BETWEEN start_date AND end_date
    AND cv.event = "INSTALL"
    AND api.campaign.id = 'YOUR_CAMPAIGN_ID'
), 
events AS (
  SELECT
    bid.mtid,
    cv.event_pb,
    cv.revenue_usd.amount AS postback_revenue,
    cv.happened_at AS event_at,
    LOWER(cv.event_pb) LIKE "%purchase%" OR LOWER(cv.event_pb) LIKE "%iap%" AS is_purchase
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE timestamp >= start_date
    AND cv.event <> "INSTALL"
    AND api.campaign.id = 'YOUR_CAMPAIGN_ID'
)
SELECT
  bundle,
  COUNT(DISTINCT installs.mtid) AS installs,
  SUM(IF(TIMESTAMP_DIFF(event_at, install_at, DAY) < 7, postback_revenue, 0)) AS d7_revenue,
  COUNT(DISTINCT CASE WHEN is_purchase AND TIMESTAMP_DIFF(event_at, install_at, DAY) < 7 THEN events.mtid END) AS unique_payer_d7,
  COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 1 THEN events.mtid END) AS d1_retention,
  COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 3 THEN events.mtid END) AS d3_retention,
  COUNT(DISTINCT CASE WHEN TIMESTAMP_DIFF(event_at, install_at, DAY) = 7 THEN events.mtid END) AS d7_retention
FROM installs
LEFT JOIN events ON events.mtid = installs.mtid
GROUP BY 1
ORDER BY installs DESC
```

### Step 3: Check MMP Rejection Flags
Look for rejected installs and their reasons:

```sql
SELECT
  req.app.bundle AS bundle,
  COUNT(*) AS rejected_installs,
  STRING_AGG(DISTINCT cv.mmp, ", " ORDER BY cv.mmp ASC) AS mmp_flag,
  cv.pb.attribution.rejection_reason
FROM `focal-elf-631.prod_stream_view.cv`
WHERE timestamp BETWEEN start_date AND end_date
  AND cv.event_pb LIKE "%rejected%"
  AND api.campaign.id = 'YOUR_CAMPAIGN_ID'
GROUP BY 1, 4
ORDER BY rejected_installs DESC
```

**Common rejection reasons to flag:**
- `bots()` - Bot traffic
- `Engagement injection` - Click injection
- `Anonymous traffic` - Invalid user data

### Step 4: Retention Rate Comparison
Compare retention rates across publishers:

| Metric | Healthy Range | Red Flag |
|--------|---------------|----------|
| D1 Retention | 30-50% | < 10% or > 80% |
| D3 Retention | 15-30% | < 5% or > 60% |
| D7 Retention | 10-20% | < 3% or > 50% |
| D7 ARPPU | Varies by app | Near zero or abnormally high |

### Step 5: User-Level Deep Dive (if needed)
For specific suspicious publishers, analyze individual user patterns:
- Time between click and install (CTIT)
- Device characteristics (model distribution, OS version)
- Geographic distribution vs. targeting
- Event timing patterns

---

## Key Metrics to Check

### Volume Metrics
- [ ] Install count by publisher
- [ ] Impression-to-install rate (IR)
- [ ] Click-to-install rate

### Quality Metrics
- [ ] D1, D3, D7 retention rates by publisher
- [ ] Revenue per install (D7)
- [ ] Payer rate
- [ ] KPI event completion rate

### Fraud Indicators
- [ ] MMP rejection rate
- [ ] CTIT distribution (click-to-install time)
- [ ] Device ID diversity
- [ ] Geographic anomalies

---

## Common Patterns / Red Flags

### High Fraud Risk Indicators
1. **Zero/Near-zero retention** - Installs that never return
2. **Perfect metrics** - Suspiciously consistent patterns
3. **Burst traffic** - Sudden volume spikes from unknown publishers
4. **Geographic mismatch** - Traffic from non-targeted regions
5. **Device anomalies** - Unusual device model distribution
6. **CTIT clustering** - Installs happening in suspicious time patterns

### Publisher-Specific Red Flags
- New publisher with sudden high volume
- Publisher with retention significantly below campaign average
- Publisher with high rejected install rate
- Publisher showing abnormal CTR (> 5% often suspicious)

---

## Example Cases with Findings

### Case Pattern 1: Bot Traffic
**Symptoms:**
- D1 retention < 5%
- No post-install events
- MMP rejection reason: "bots()"

**Action:** Block publisher, request refund from advertiser MMP data

### Case Pattern 2: Click Injection
**Symptoms:**
- Normal retention but abnormal CTIT (< 10 seconds)
- High install volume from Android apps
- MMP rejection: "Engagement injection"

**Action:** Investigate CTIT distribution, consider publisher blocklist

### Case Pattern 3: Install Farming
**Symptoms:**
- High install volume
- Moderate D1 retention but sharp D3/D7 drop
- Low revenue metrics
- Limited device diversity

**Action:** Deep dive on user-level data, check device ID patterns

---

## Escalation Criteria

Escalate to Fraud Team when:
- [ ] Suspected fraud volume > $1,000 spend
- [ ] Multiple campaigns affected
- [ ] Pattern suggests sophisticated fraud scheme
- [ ] Advertiser requesting formal investigation
- [ ] MMP data required for verification

---

## Related Resources

### Local SQL Files
- `Fraud/publisher_performance_data.sql` - Publisher metrics with retention
- `Fraud/publisher_analysis.sql` - Detailed publisher breakdown
- `Fraud/Retention_revenue_by_perblisher.sql` - Retention by publisher

### Internal Docs
*To be populated from Glean search*

---

*Last updated: Feb 3, 2026*
*Version: Draft 1.0*
