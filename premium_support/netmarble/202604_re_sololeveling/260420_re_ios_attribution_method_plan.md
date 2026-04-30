# iOS RE LAT Attribution Method — Benchmark Analysis for Netmarble Pitch

| Field | Value |
|-------|-------|
| **Author** | Haewon Yum |
| **Date** | 2026-04-20 |
| **Client** | Netmarble (target audience) |
| **Purpose** | Internal benchmark data to support iOS RE LAT pitch |

---

## Objective

Using RE LAT campaigns active across any advertiser in the last 7 days, quantify what proportion of iOS RE LAT attributed postbacks is **deterministic** (deeplink-based) vs probabilistic (fingerprint), as a benchmark data point to address Netmarble's concern that RE LAT attribution is unreliable.

---

## Background & Client Context

**Netmarble's stance on probabilistic attribution (confirmed from internal docs):**
- Netmarble has historically treated SKAN as the sole source of truth for iOS measurement and explicitly characterizes probabilistic attribution as "데이터 정합성을 해침 (harms data integrity)" — confirmed in Slack `#ads-netmarble`
- PA was enabled for Netmarble only on **April 2, 2026**, after years of persuasion
- No iOS probabilistic RE campaign has been run for any Netmarble title to date
- Solo Leveling is running iOS RE IDFA campaigns only — the client has not agreed to RE LAT

**Why this benchmark matters:**
- Netmarble's core concern is that RE LAT = probabilistic = unreliable attribution signal
- However, deeplink-based RE LAT attribution is deterministic — MMP observes a direct click → app-open chain without needing IDFA
- We need a data point showing that a meaningful share of RE LAT attribution across the industry IS deterministic, to counter this objection
- Precedent: GTM previously requested this same benchmark internally via Slack ("iOS LAT RE Data for NETMARBLE") but no analysis was completed

**Confirmed deeplink mechanism (from internal product docs):**
> "Deep linking enables MMPs to provide deterministic attribution for iOS LAT users, with probabilistic attribution as the fallback when deep links aren't being used."
— iOS LAT RE Beta deck; iOS RE Closed Alpha Test spec (Design Partner Program)

**Confirmed attribution method values (from Looker dashboard spec DDPTICKET-355):**

| `attribution.method` | Classification | Description |
|---------------------|---------------|-------------|
| `DEEPLINK` | **Deterministic** | Deeplink click → app open; MMP SDK direct match |
| `REFERRER` | **Deterministic** | Adjust-specific; treated equivalently to `DEEPLINK` internally |
| `PROBABILISTIC` | Probabilistic | Fingerprint fallback |
| `FINGERPRINT` | Probabilistic | Fingerprint variant |
| `NULL` | Unknown | MMP did not populate method macro |

Internal deterministic filter definition (DDPTICKET-355):
```
attribution.method = 'DEEPLINK'
OR (mmp = 'ADJUST' AND attribution.method = 'REFERRER')
```

**Key constraint (confirmed):** VT attribution on LAT traffic is always probabilistic — excluded from scope.

---

## Scope

### Sections 1–3 (Industry benchmark)
- **Platform:** iOS only
- **Campaigns:** Any RE LAT iOS campaigns active in the last 7 days, across all advertisers
- **Attribution type:** Click-through RE postbacks only — `attribution.reengagement = TRUE`, `attribution.viewthrough = FALSE`, `attribution.attributed = TRUE`; IDFA (`identifier`) excluded — proportions computed within LAT traffic only
- **Period:** Last 7 days from analysis date

### Sections 4+ (KOR office deep-dive)
- **Platform:** iOS only
- **Campaigns:** RE LAT iOS campaigns run by KOR office advertisers in the last 6 months
- **Attribution type:** Same as above — click-through, LAT traffic only, IDFA excluded
- **Period:** Last 3 months from analysis date (6-month scan ~1.6 PB on an unpartitioned 7.7T-row table; 3 months ~800 GB — sufficient for trend)
- **Office filter:** `advertiser.office = 'KOR'` (confirmed live against `fact_dsp_core`)

---

## Out of Scope

- Netmarble-specific campaigns (none exist for iOS RE LAT)
- IDFA campaigns
- Android RE
- UA postbacks
- VT attributed postbacks

---

## Key Tables

| Table | Purpose |
|-------|---------|
| `moloco-dsp-data-view.postback.pb` | RE postback records with `attribution.method` — canonical source (post-2025-04-09 migration) |
| `moloco-ae-view.athena.fact_dsp_core` | Campaign-level metadata to identify RE LAT iOS campaigns |

---

## Analysis Sections

### Section 1 — RE LAT iOS Campaign Inventory (Last 7 Days)
**Goal:** Identify all RE LAT iOS campaigns with spend in the last 7 days, across all advertisers.

Query `fact_dsp_core` for RE goal, iOS platform, LAT campaign type, last 7 days, spend > 0. Output: campaign count, advertiser count, total spend, total reattributions.

Used to scope the postback pull in Section 2.

---

### Section 2 — Attribution Method Distribution (All RE LAT iOS Postbacks)
**Goal:** Count and share (%) of RE LAT click-through postbacks by attribution method.

From `moloco-dsp-data-view.postback.pb`:
- Filter: RE LAT campaign IDs (from Section 1), `attribution.reengagement = TRUE`, `attribution.viewthrough = FALSE`, `attribution.attributed = TRUE`, last 7 days, iOS
- Group by `attribution.method`
- Compute: count and share (%)
- Roll up into: Deterministic (`DEEPLINK` + `REFERRER`) / Probabilistic (`PROBABILISTIC` + `FINGERPRINT`) / Unknown (`NULL`)

**Key output number:** Deterministic % — the headline figure for the Netmarble pitch.

Visualization: bar chart, attribution method × count, with share % labels.

---

### Section 3 — Daily Trend: Deterministic vs Probabilistic Share (Past 7 Days)
**Goal:** Confirm the deterministic share is consistent day-over-day (not a spike artifact).

Group RE LAT postbacks by date × classification. Plot stacked bar chart.

---

### Section 4 — KOR Office RE LAT iOS Campaign Inventory (Last 6 Months)
**Goal:** Identify all RE LAT iOS campaigns run by KOR office advertisers in the last 6 months.

Query `fact_dsp_core` with KOR office filter + RE LAT iOS criteria, 6-month lookback, spend > 0. Output: campaign IDs, advertiser names, bundle IDs, MMP, spend, reattributions. Campaign IDs scope Sections 5–6.

---

### Section 5 — Attribution Method Distribution (KOR Office, 6 Months)
**Goal:** Same analysis as Section 2 but scoped to KOR office advertisers over 6 months.

From `moloco-dsp-data-view.postback.pb`:
- Filter: KOR office campaign IDs (from Section 4), same postback filters as Section 2, IDFA excluded
- Group by `attribution.method` → roll up to Deterministic / Probabilistic
- Output: count, share (%)

Visualization: bar chart. Compare headline % to Sections 1–3 benchmark.

---

### Section 6 — Bundle-level Breakdown (KOR Office, 6 Months)
**Goal:** Deterministic share per app bundle for KOR office advertisers — show the range.

Same approach as Section 2b: group by `app.bundle × classification`, compute share per bundle. Order by deterministic share descending. Flag bundles with ~0% deterministic (deeplink not configured).

---

### Section 7 — Monthly Trend: Deterministic vs Probabilistic Share (KOR Office, 6 Months)
**Goal:** Confirm deterministic share is stable or improving over the 6-month window (not a spike artifact).

Group postbacks by month × classification. Plot stacked bar chart.

---

## Output & Use

| Artifact | Audience |
|----------|----------|
| Headline stat: "X% of RE LAT postbacks are deterministic" (industry, 7d) | Netmarble pitch, AM/PSO talking points |
| Daily trend chart | Supporting evidence for consistency (industry) |
| KOR office attribution breakdown + bundle-level range (6mo) | Deeper context for KOR-specific pitch |
| Monthly trend chart (KOR office) | Stability of deterministic share over time |

**Related internal references:**
- Prior benchmark data request: [iOS LAT RE Data for NETMARBLE](https://moloco.slack.com/archives/C08LE62T267/p1764763335103269)
- Client-facing iOS PA deck: [[NETMARBLE] iOS Discussion](https://docs.google.com/presentation/d/1vqFoImm0DMZmHFmnz_ndOaHEHPdZVY_EilJtQ3xT8dw)
- 2026 Q1/Q2 Netmarble support doc: [link](https://docs.google.com/document/d/1Q-VumukbGJPa64mcuYbyhNhZCI6R27fdbjyd4no9KTA) — post-PA data (CPI lift) already shared
- RE test proposals for Netmarble: [link](https://docs.google.com/spreadsheets/d/16ADbbCDTTCx8PGy67GCwczWM2hMk7m13VxDTxP2dYX4)
- Netmarble iOS PA explainer doc: [link](https://docs.google.com/document/d/1xlcEz_O3zLU47YIRRIHI84J2cfyH0aHhkUhhYkDf_k4)
