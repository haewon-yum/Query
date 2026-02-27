# Campaign Diagnostic Queries

A set of BigQuery queries to check key health indicators for a given bundle or campaign.

> **Usage**: Replace `{BUNDLE_ID}` with the actual tracking bundle (e.g., `com.krafton.pubgm`) and `{CAMPAIGN_ID}` with the actual campaign ID.

---

## 1. PA Enabled Postback 수신 여부

### Option A: `mmp_pb_summary.app_status` (Recommended — iOS)

Pre-aggregated PA status table with daily verdict. Covers postback attribution breakdown, ATT opt-in/out, and fingerprint (PA) status. **iOS only.**

- **Orchestration:** Airflow DAG `tascone_mmp_pb_summary.py` → stored procedure `merge_app_status()`
- **Upstream:** `mmp_pb_summary.summary` (postback counts) + `standard_digest.mmp_integration_reference_digest` + `standard_digest.campaign_digest` + `standard_cs_v5_view.all_events_extended_utc` (spend)

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
WHERE tracking_bundle = '{BUNDLE_ID}'
  AND utc_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
ORDER BY utc_date DESC
```

**`fp_status` verdict logic:**

| Status | Condition |
|--------|-----------|
| `ENABLED` | AppsFlyer AP off, or attributed opt-out postbacks have MTID (Adjust EPM off) |
| `DISABLED` | AppsFlyer AP on, or all postbacks miss MTID, or Adjust EPM on |
| `PARTIAL` | Mixed MTID presence in postbacks |
| `UNKNOWN_MISSING_ATTR` | No attributed postbacks at all (`attr.total = 0`) |
| `UNKNOWN_MISSING_ATTR_OPTOUT` | Has attributed postbacks but none from ATT opt-out devices |
| `UNKNOWN_NEGLIGIBLE_ATTR_OPTOUT` | ATT opt-out < 1% of total attributed |

**Check**: `pa_status = 'ENABLED'` means PA postbacks are being received. `DISABLED` means PA is off (AppsFlyer AP on or no fingerprint signals). `UNKNOWN_*` means insufficient data to determine — investigate further.

### Option B: `prod_stream_view.cv` — attribution method from structured fields (iOS + Android)

Use when `app_status` doesn't cover the case (e.g., Android, or need campaign-level granularity).
Uses `cv.pb.attribution.method` / `cv.pb.attribution.raw_method` (structured fields, more reliable than regex-parsing the postback URL).

```sql
SELECT
  DATE(timestamp) AS date,
  cv.mmp,
  cv.pb.attribution.method AS attribution_method,
  cv.pb.attribution.raw_method AS raw_method,
  COUNT(*) AS install_count
FROM `focal-elf-631.prod_stream_view.cv`
WHERE
  DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND UPPER(cv.event) = 'INSTALL'
  AND api.product.app.tracking_bundle = '{BUNDLE_ID}'
  -- AND api.campaign.id = '{CAMPAIGN_ID}'  -- optional: filter by campaign
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 5 DESC
```

**Check**: `attribution_method` containing `probabilistic`, `modeled`, or `fingerprint` indicates PA is enabled and being received. If only `id_matching` or `deterministic` appears, PA may not be turned on.

---

## 2. VT Install 수신 여부

Check if View-Through (VT) installs are being received.

```sql
SELECT
  DATE(timestamp) AS date,
  cv.view_through AS is_view_through,
  cv.pb.attribution.method AS attribution_method,
  cv.pb.attribution.viewthrough AS pb_viewthrough,
  COUNT(*) AS install_count
FROM `focal-elf-631.prod_stream_view.cv`
WHERE
  DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND UPPER(cv.event) = 'INSTALL'
  AND api.product.app.tracking_bundle = '{BUNDLE_ID}'
  -- AND api.campaign.id = '{CAMPAIGN_ID}'
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 5 DESC
```

**Check**: If `is_view_through = true` or `pb_viewthrough = true` rows exist, VT installs are being received. `attribution_method` shows how the install was attributed (e.g., `deterministic`, `probabilistic`). If all rows show `false` for both VT fields, VT attribution may be disabled on the MMP side.

---

## 3. Revenue 포스트백 수신 여부

Check if revenue postbacks are being received.

```sql
SELECT
  DATE(timestamp) AS date,
  cv.event_pb AS event_name,
  COUNT(*) AS event_count,
  COUNTIF(cv.revenue_usd.amount > 0) AS events_with_revenue,
  ROUND(SUM(cv.revenue_usd.amount), 2) AS total_revenue_usd
FROM `focal-elf-631.prod_stream_view.cv`
WHERE
  DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND api.product.app.tracking_bundle = '{BUNDLE_ID}'
  -- AND api.campaign.id = '{CAMPAIGN_ID}'
  AND cv.revenue_usd.amount IS NOT NULL
GROUP BY 1, 2
ORDER BY 1 DESC, 5 DESC
```

**Check**: If `events_with_revenue > 0`, revenue postbacks are coming through. Compare event names to ensure expected revenue events (e.g., `purchase`, `subscribe`) are present.

---

## 4. 주요 소재 포맷 Impression 여부

Two-step check: first confirm what creative formats are uploaded/configured, then verify they are actually receiving impressions.

### Step A: 현재 등록된 소재 포맷 확인 (What creatives are configured?)

Query the creative digest to see all creatives uploaded for the product, regardless of whether they are serving.

```sql
WITH product AS (
  SELECT product_id, platform
  FROM `focal-elf-631.standard_digest.product_digest`
  WHERE app_store_bundle = '{BUNDLE_ID}'
    AND NOT is_archived
)
SELECT
  cd.product_id,
  cd.creative_id,
  cd.creative_title,
  cd.creative_type,
  cd.is_archived,
  cd.timestamp AS last_updated
FROM `focal-elf-631.standard_digest.creative_digest` cd
INNER JOIN product p
  ON cd.product_id = p.product_id
  AND cd.platform = p.platform
ORDER BY cd.is_archived, cd.creative_type, cd.timestamp DESC
```

**Check**: Confirm key creative types are present and not archived. Common types: `IMAGE_BANNER`, `NATIVE`, `VIDEO`, `PLAYABLE`, `HTML`. If expected formats are missing or all archived, creatives need to be uploaded before impressions can occur.

### Step B: 소재 포맷별 Impression 확인 (Are those formats getting impressions?)

```sql
SELECT
  date_utc,
  creative.format AS cr_format,
  COUNT(DISTINCT creative.id) AS n_creatives,
  SUM(impressions) AS impressions,
  ROUND(SUM(gross_spend_usd), 2) AS gross_spend_usd,
  SUM(installs) AS installs
FROM `moloco-ae-view.athena.fact_dsp_creative`
WHERE
  date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND advertiser.mmp_bundle_id = '{BUNDLE_ID}'
  -- AND campaign_id = '{CAMPAIGN_ID}'
GROUP BY 1, 2
ORDER BY 1 DESC, 4 DESC
```

**Check**: Compare Step A (configured) vs Step B (serving). If a format exists in Step A but is missing from Step B, that format is not getting impressions — possible causes:
- Creative under review or rejected by exchange
- Ad group targeting excludes the format
- No bid requests matching the format (e.g., PLAYABLE not supported by available exchanges)
- Creative archived or disabled at the creative group level

---

## 5. (국내) Kakao Bizboard (1029x258) 소재 스펜딩/리뷰 여부

Check Kakao Bizboard (1029x258) creative spending status for Korean campaigns.

```sql
SELECT
  date_utc,
  creative.format AS cr_format,
  creative.size,
  creative.title AS cr_title,
  creative.id AS cr_id,
  SUM(impressions) AS impressions,
  ROUND(SUM(gross_spend_usd), 2) AS gross_spend_usd
FROM `moloco-ae-view.athena.fact_dsp_creative`
WHERE
  date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND advertiser.mmp_bundle_id = '{BUNDLE_ID}'
  -- AND campaign_id = '{CAMPAIGN_ID}'
  AND campaign.country = 'KOR'
  AND LOWER(exchange) LIKE '%kakao%'
  AND creative.size = '1029x258'  -- Bizboard exact size
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC, 7 DESC
```

**Check**: If no rows appear, Bizboard (1029x258) creatives are not serving on Kakao. Possible causes:
- No 1029x258 creative uploaded — check creative digest (Section 4 Step A)
- Creative under review or rejected — check Staff Room → Creative Review Status
- Creative uploaded but with wrong dimensions — remove the size filter above and re-run to see what sizes are actually serving on Kakao

---

## 6. 높은 Bid Filter Rate (Campaign / Ad Group Level)

### Option A: Pricing table

Check campaign/ad group level bid filter rate. Note: pricing table is sampled (1/1000), so multiply counts accordingly.

```sql
SELECT
  DATE(timestamp) AS date,
  cand.campaign_id,
  cand.adgroup_id,
  cand.cr_format,
  cand.candidate_result,
  cand.core.reason AS core_reason,
  COUNT(*) AS cnt
FROM `focal-elf-631.prod_stream_view.pricing`,
  UNNEST(pricing.candidates) AS cand
WHERE
  DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND cand.campaign_id = '{CAMPAIGN_ID}'
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1 DESC, 7 DESC
```

### Option B: Campaign trace table (more detailed filter reasons)

```sql
SELECT
  date,
  campaign,
  reason_block,
  reason,
  reason_raw,
  ROUND(SUM(1 / rate) / 1e6, 2) AS estimated_req_millions
FROM `moloco-data-prod.younghan.campaign_trace_raw_prod`
WHERE
  date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND campaign = '{CAMPAIGN_ID}'
  AND reason_block IN ('Get candidate campaigns', 'Evaluate candidate campaigns', 'get candidate ad_groups')
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC, 6 DESC
```

**Check**: High volume of `(ad_group) Ctx` or `(campaign) Ctx` filter reasons indicates targeting/context mismatch. For UA campaigns, overly narrow ad group targeting is a common cause of high filter rates.

---

## 7. Install Leakage / Rejected Install Rate

### Option A: Real-time leakage — `fact_dsp_core` vs `prod_stream_view.cv`

Compare Moloco-reported installs with MMP install postbacks actually received. No dependency on pre-computed pipelines.

```sql
WITH moloco_installs AS (
  SELECT
    date_utc AS date,
    campaign_id,
    campaign.country,
    SUM(installs) AS moloco_installs
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    AND advertiser.mmp_bundle_id = '{BUNDLE_ID}'
    -- AND campaign_id = '{CAMPAIGN_ID}'
  GROUP BY 1, 2, 3
),
mmp_postbacks AS (
  SELECT
    DATE(timestamp) AS date,
    api.campaign.id AS campaign_id,
    COUNT(*) AS mmp_installs
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    AND UPPER(cv.event) = 'INSTALL'
    AND api.product.app.tracking_bundle = '{BUNDLE_ID}'
    -- AND api.campaign.id = '{CAMPAIGN_ID}'
  GROUP BY 1, 2
)
SELECT
  m.date,
  m.campaign_id,
  m.country,
  m.moloco_installs,
  COALESCE(p.mmp_installs, 0) AS mmp_installs,
  m.moloco_installs - COALESCE(p.mmp_installs, 0) AS discrepancy,
  ROUND(SAFE_DIVIDE(m.moloco_installs - COALESCE(p.mmp_installs, 0), m.moloco_installs) * 100, 2) AS leakage_rate_pct
FROM moloco_installs m
LEFT JOIN mmp_postbacks p
  ON m.date = p.date AND m.campaign_id = p.campaign_id
ORDER BY m.date DESC, leakage_rate_pct DESC
```

**Check**: If `leakage_rate_pct` is consistently >10%, investigate: MMP attribution window mismatch, competing networks, low SOI, or budget changes.

### Option B: Rejected install rate — `critical_alert.daily_rejected_install_rate` (daily pipeline)

Pre-computed campaign-level rejected install data with publisher-level breakdown. Updated daily.

```sql
SELECT
  DATE(timestamp) AS date,
  campaign_id,
  ROUND(campaign_spend, 2) AS campaign_spend,
  campaign_valid_installs,
  campaign_rejected_installs,
  ROUND(campaign_rejection_rate * 100, 2) AS rejection_rate_pct,
  is_alert,
  alert_publishers_default,
  alert_publishers_global
FROM `moloco-ods.critical_alert.daily_rejected_install_rate`
WHERE product_id IN (
  SELECT product_id FROM `focal-elf-631.standard_digest.product_digest`
  WHERE app_store_bundle = '{BUNDLE_ID}' AND NOT is_archived
)
  AND DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  -- AND campaign_id = '{CAMPAIGN_ID}'
ORDER BY timestamp DESC, rejection_rate_pct DESC
```

**Check**: If `is_alert = true`, check `alert_publishers_default` / `alert_publishers_global` for publishers with abnormally high rejection rates. High rejection rate may indicate fraud or integration issues on specific publisher apps.

---

## Reference: Key Tables

| Table | Description | Sampling |
|---|---|---|
| `focal-elf-631.mmp_pb_summary.app_status` | PA status verdict, ATT breakdown, spend (iOS only) | Unsampled (daily agg) |
| `focal-elf-631.prod_stream_view.cv` | Event-level conversion data | Unsampled |
| `moloco-ae-view.athena.fact_dsp_creative` | Creative-level aggregated metrics | Unsampled |
| `focal-elf-631.prod_stream_view.pricing` | Internal auction pricing & filter reasons | 1/1000 sampled |
| `moloco-data-prod.younghan.campaign_trace_raw_prod` | Detailed bid funnel trace | Varies |
| `moloco-ods.critical_alert.daily_install_leakage_advertiser_level` | Install leakage alerts | Unsampled |
