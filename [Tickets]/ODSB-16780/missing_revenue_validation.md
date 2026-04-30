# ODSB-16780: Missing Revenue Alert Validation

**Date analyzed**: 2026-03-09

## Campaign Overview

| Field | Value |
|-------|-------|
| Campaign ID | `Jl5NUKiajhIyKXQK` |
| Campaign Title | `WISEBIRDS_[XRTX]sololv_update_moloco_WW_And_tROAS_260301` |
| Goal | RE_ROAS |
| App | Solo Leveling ARISE_AOS (`com.netmarble.sololv`) |
| OS | Android |
| Geo | WW |
| MMP | AppsFlyer |
| Start Date | 2026-02-28 |
| Workspace | NETMARBLE |
| Ad Account | tGYMnmOyEZqjEIND / Wisebirds |

## Alert Details

- **Alert type**: Missing Revenue — daily revenue sum = 0 despite KPI event count >= 1
- **Triggered on**: 2026-03-05 (data timestamp 2026-03-06) and 2026-03-06 (data timestamp 2026-03-07)
- **KPI event**: `revenue` (event type: `CUSTOM_KPI_ACTION`)

---

## Validation: Alert Confirmed — Intermittent Revenue Gaps

Revenue postbacks are arriving intermittently:

| Date | Spend | Impressions | Installs | KPI Actions | KPI Revenue | Status |
|------|-------|-------------|----------|-------------|-------------|--------|
| Feb 28 | $161 | 335K | 1 | 0 | $0 | No actions |
| Mar 01 | $1,137 | 1,779K | 2 | 0 | $0 | No actions |
| Mar 02 | $898 | 1,443K | 7 | 2 | $44.44 | OK |
| Mar 03 | $971 | 1,407K | 4 | 4 | $48.44 | OK |
| Mar 04 | $999 | 1,561K | 9 | 0 | $0 | No actions |
| **Mar 05** | **$1,026** | **1,580K** | **11** | **5** | **$0** | **Alert — actions but $0 revenue** |
| **Mar 06** | **$1,088** | **1,653K** | **6** | **1** | **$0** | **Alert — actions but $0 revenue** |
| Mar 07 | $1,136 | 1,646K | 10 | 7 | $14.15 | OK (resumed) |
| Mar 08 | $1,085 | 1,700K | 9 | 9 | $8.83 | OK |
| Mar 09 | $84 | 151K | 1 | 2 | $3.89 | OK (partial day) |

---

## Event-Level Detail (Mar 4–8)

All revenue events arrive as `CUSTOM_KPI_ACTION` with `event.name = 'revenue'`:

| Date | Event Type | Event Name | is_kpi | KPI Actions | KPI Revenue | PB Revenue |
|------|-----------|------------|--------|-------------|-------------|------------|
| Mar 02 | CUSTOM_KPI_ACTION | revenue | true | 2 | $44.44 | $44.44 |
| Mar 03 | CUSTOM_KPI_ACTION | revenue | true | 4 | $48.44 | $48.44 |
| Mar 05 | CUSTOM_KPI_ACTION | revenue | true | 5 | $0 | $0 |
| Mar 06 | CUSTOM_KPI_ACTION | revenue | true | 1 | $0 | $0 |
| Mar 07 | CUSTOM_KPI_ACTION | revenue | true | 7 | $14.15 | $14.15 |
| Mar 08 | CUSTOM_KPI_ACTION | revenue | true | 9 | $8.83 | $8.83 |

When revenue is present, `kpi_pb_revenue = pb_revenue` — the revenue source is consistent.

---

## Cohorted Revenue

| Date | PB Revenue | Revenue D1 | Capped Revenue D1 | Revenue D7 |
|------|-----------|-----------|-------------------|-----------|
| Feb 28 | $0 | $0 | $0 | $0 |
| Mar 01 | $0 | $0 | $0 | $4.00 |
| Mar 02 | $44.44 | $0 | $0 | $0 |
| Mar 03 | $48.44 | $0 | $0 | $0 |
| Mar 04 | $0 | $0 | $0 | $0 |
| Mar 05 | $0 | $0 | $0 | $0 |
| Mar 06 | $0 | $0 | $0 | $0 |
| Mar 07 | $14.15 | $0 | $0 | $0 |
| Mar 08 | $8.83 | $0 | $0 | $0 |

Cohorted revenue (D1, D7) is essentially **zero across all days**. Only $4 D7 revenue on Mar 1.

---

## Key Observations

1. **Intermittent, not persistent**: Revenue was $0 on Mar 5-6 despite KPI actions firing, but resumed on Mar 7-8. Suggests a temporary MMP-side reporting gap rather than a permanent config issue.

2. **Revenue values are low overall**: Even on "good" days, revenue is $8-48 against ~$1K daily spend. Total revenue over 10 days: ~$115 vs $8.5K total spend.

3. **Cohorted revenue (D1/D7) is essentially zero**: `revenue_d1 = 0` across all days. This is concerning for a tROAS campaign — the model has almost no revenue signal to optimize against.

4. **Event type is CUSTOM_KPI_ACTION**: Revenue events come as custom KPI actions, not standard REVENUE or PURCHASE event types.

---

## Assessment

- **Alert validity**: **Valid**. Mar 5-6 had KPI action events with $0 revenue — the MMP sent the event but with no revenue value attached.
- **Root cause hypothesis**: AppsFlyer is intermittently failing to include revenue values in the `revenue` event postback. The event fires (kpi_actions > 0) but the revenue field is empty/zero on some days.
- **Concern**: Even ignoring the alert days, the revenue signal is very sparse and low ($115 total over 10 days vs $8.5K spend). This RE_ROAS campaign lacks sufficient revenue data for the model to optimize effectively.

---

## Recommended Actions

1. **Check with GM/client**: Is AppsFlyer correctly configured to send revenue values with the `revenue` event? The intermittent nature suggests a partial integration issue.
2. **Check AppsFlyer postback settings**: Verify that revenue parameter is mapped and consistently populated in the S2S postback to Moloco.
3. **Flag ROAS optimization risk**: With near-zero cohorted revenue, the tROAS model is effectively flying blind. Consider whether this campaign should remain on ROAS goal or switch to CPA until revenue reporting stabilizes.

---

## Queries Used

### Daily performance since campaign start (fact_dsp_core)

```sql
SELECT
  date_utc,
  ROUND(SUM(gross_spend_usd), 2) AS spend,
  SUM(impressions) AS impressions,
  SUM(installs) AS installs,
  SUM(kpi_actions) AS kpi_actions,
  ROUND(SUM(kpi_pb_revenue_usd), 2) AS kpi_revenue,
  ROUND(SUM(capped_revenue_d7), 2) AS revenue_d7,
  ROUND(SUM(revenue_d1), 2) AS revenue_d1
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE campaign_id = 'Jl5NUKiajhIyKXQK'
  AND date_utc BETWEEN '2026-02-28' AND '2026-03-09'
GROUP BY 1
ORDER BY 1
```

### Event-level detail for KPI events (fact_dsp_all)

```sql
SELECT
  DATE(timestamp_utc) AS date,
  event.type AS event_type,
  event.name AS event_name,
  event.is_kpi,
  SUM(kpi_actions) AS kpi_actions,
  ROUND(SUM(kpi_pb_revenue_usd), 4) AS kpi_revenue,
  ROUND(SUM(revenue_d1), 4) AS revenue_d1,
  SUM(impressions) AS impressions
FROM `moloco-ae-view.athena.fact_dsp_all`
WHERE campaign_id = 'Jl5NUKiajhIyKXQK'
  AND DATE(timestamp_utc) BETWEEN '2026-03-04' AND '2026-03-08'
GROUP BY 1, 2, 3, 4
HAVING kpi_actions > 0 OR kpi_revenue > 0 OR revenue_d1 > 0
ORDER BY 1, event_type
```

### Revenue postback history (fact_dsp_all)

```sql
SELECT
  DATE(timestamp_utc) AS date,
  event.type AS event_type,
  event.name AS event_name,
  SUM(kpi_actions) AS kpi_actions,
  ROUND(SUM(kpi_pb_revenue_usd), 4) AS kpi_pb_revenue,
  ROUND(SUM(pb_revenue_usd), 4) AS pb_revenue
FROM `moloco-ae-view.athena.fact_dsp_all`
WHERE campaign_id = 'Jl5NUKiajhIyKXQK'
  AND DATE(timestamp_utc) BETWEEN '2026-02-28' AND '2026-03-08'
  AND event.name = 'revenue'
GROUP BY 1, 2, 3
ORDER BY 1
```

### All revenue fields by date (fact_dsp_all)

```sql
SELECT
  DATE(timestamp_utc) AS date,
  ROUND(SUM(pb_revenue_usd), 4) AS total_pb_revenue,
  ROUND(SUM(kpi_pb_revenue_usd), 4) AS total_kpi_pb_revenue,
  ROUND(SUM(revenue_d1), 4) AS total_revenue_d1,
  ROUND(SUM(capped_revenue_d1), 4) AS total_capped_rev_d1,
  ROUND(SUM(revenue_d7), 4) AS total_revenue_d7
FROM `moloco-ae-view.athena.fact_dsp_all`
WHERE campaign_id = 'Jl5NUKiajhIyKXQK'
  AND DATE(timestamp_utc) BETWEEN '2026-02-28' AND '2026-03-08'
GROUP BY 1
ORDER BY 1
```
