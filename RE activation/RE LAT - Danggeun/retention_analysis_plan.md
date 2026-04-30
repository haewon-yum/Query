# RE LAT - Danggeun: D1/D3/D7 Retention Analysis by OS

## Objective

Compare post-re-engagement retention (D1, D3, D7) across **iOS vs Android** for Danggeun (Karrot) RE campaigns, using **MTID** as the user identifier.

MTID is preferred over MAID/IDFA because iOS LAT (Limited Ad Tracking / ATT opt-out) users lack IDFA — MTID still provides coverage for these users.

---

## Data Sources


| Table                                           | Purpose                                             |
| ----------------------------------------------- | --------------------------------------------------- |
| `focal-elf-631.standard_digest.campaign_digest` | Identify Danggeun RE campaigns and their OS         |
| `focal-elf-631.prod_stream_view.cv`             | Raw conversion/postback events with `bid.mtid`      |
| `focal-elf-631.standard_digest.product_digest`  | Map product_id → bundle for Danggeun filtering      |
| `moloco-ae-view.athena.fact_dsp_core`           | (Validation) Aggregated spend/installs per campaign |


---

## Key Fields

- `**bid.mtid`** — Moloco Tracking ID (user identifier; works even for LAT/ATT-opted-out users)
- `**bid.maid**` — Mobile Ad ID (`i:` prefix = IDFA, `f:` = IDFV); may be null for LAT users
- `**api.campaign.id**` — Campaign identifier
- `**cv.event_pb**` — Event name from MMP postback (e.g., `#open`, `#retention`, `purchase`, etc.)
- `**cv.pb.attribution.reengagement**` — Boolean; TRUE for re-engagement attributed events
- `**timestamp**` — Event timestamp

---

## Analysis Logic

### Step 1: Identify Danggeun RE campaigns

```sql
SELECT
  cd.campaign_id,
  cd.campaign_title,
  cd.campaign_os,
  cd.product_id,
  pd.tracking_bundle
FROM `focal-elf-631.standard_digest.campaign_digest` cd
JOIN `focal-elf-631.standard_digest.product_digest` pd
  ON cd.product_id = pd.product_id
    WHERE cd.campaign_type = 'APP_REENGAGEMENT'
      AND cd.advertiser_id = 'Voql38wJkmDNzXbW'
      AND cd.is_archived = FALSE
      AND JSON_VALUE(cd.original_json, '$.disabled') = 'false'
  AND cd.is_archived = FALSE
  AND JSON_VALUE(cd.original_json, '$.disabled') = 'false'
```

Output: list of **active** campaign IDs with their OS — to be used as filter in subsequent queries.

### Step 2: Extract all RE-attributed events with MTID

From the `cv` table, pull all events attributed to the identified RE campaigns. **Filter by `imp.happened_at`** (impression time) rather than `cv.timestamp` — this ensures users whose impression falls within the analysis window are captured even if their re-engagement fires slightly later (e.g., impression on 12/30, re-engagement on 12/31). The activity window is extended by +7 days to capture D7 retention events for late cohorts.

```sql
SELECT
  bid.mtid,
  DATE(timestamp) AS event_date,
  DATE(imp.happened_at) AS imp_date,
  cv.event_pb,
  cv.pb.attribution.reengagement AS is_reengagement,
  api.campaign.id AS campaign_id
FROM `focal-elf-631.prod_stream_view.cv`
WHERE api.campaign.id IN UNNEST(@campaign_ids)
  AND DATE(imp.happened_at) BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 7 DAY)
  AND bid.mtid IS NOT NULL
  AND bid.mtid != ''
```

### Step 3: Define cohort (D0)

For each MTID, D0 = the **first date** on which a re-engagement event was attributed:

```sql
cohort AS (
  SELECT
    mtid,
    os,  -- joined from campaign_digest
    MIN(event_date) AS reengage_date
  FROM re_events
  WHERE is_reengagement = TRUE
    AND imp_date BETWEEN @start_date AND @end_date  -- cohort from impressions in the window
  GROUP BY 1, 2
)
```

### Step 4: Track daily activity post-D0

Get all distinct (MTID, event_date) pairs from the same cv data — any event counts as "active":

```sql
daily_activity AS (
  SELECT DISTINCT mtid, event_date
  FROM re_events
)
```

### Step 5: Compute retention

For each cohort member, check if they had any activity on D0+1, D0+3, D0+7:

```sql
SELECT
  c.os,
  COUNT(DISTINCT c.mtid) AS cohort_size,
  COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 1 DAY) THEN c.mtid END) AS ret_d1,
  COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 3 DAY) THEN c.mtid END) AS ret_d3,
  COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 7 DAY) THEN c.mtid END) AS ret_d7,
FROM cohort c
LEFT JOIN daily_activity da ON c.mtid = da.mtid
GROUP BY 1
```

Retention rate = `ret_dN / cohort_size`

---

## Full Combined Query

```sql
DECLARE start_date DATE DEFAULT DATE('2025-01-01');
DECLARE end_date DATE DEFAULT CURRENT_DATE();

WITH
  -- 1. Danggeun RE campaigns
  campaigns AS (
    SELECT
      cd.campaign_id,
      cd.campaign_title,
      cd.campaign_os AS os,
      pd.tracking_bundle
    FROM `focal-elf-631.standard_digest.campaign_digest` cd
    JOIN `focal-elf-631.standard_digest.product_digest` pd
      ON cd.product_id = pd.product_id
    WHERE cd.campaign_type = 'APP_REENGAGEMENT'
      AND (
        LOWER(pd.tracking_bundle) LIKE '%danggeun%'
        OR LOWER(pd.tracking_bundle) LIKE '%karrot%'
        OR LOWER(pd.tracking_bundle) LIKE '%towneers%'
        OR LOWER(cd.campaign_title) LIKE '%danggeun%'
        OR LOWER(cd.campaign_title) LIKE '%karrot%'
      )
  ),

  -- 2. All events for those campaigns (filtered by impression time)
  re_events AS (
    SELECT
      cv.bid.mtid AS mtid,
      DATE(cv.timestamp) AS event_date,
      DATE(cv.imp.happened_at) AS imp_date,
      cv.cv.event_pb AS event_pb,
      cv.cv.pb.attribution.reengagement AS is_reengagement,
      cv.api.campaign.id AS campaign_id,
      c.os
    FROM `focal-elf-631.prod_stream_view.cv` cv
    JOIN campaigns c ON cv.api.campaign.id = c.campaign_id
    WHERE DATE(cv.imp.happened_at) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 7 DAY)
      AND cv.bid.mtid IS NOT NULL
      AND cv.bid.mtid != ''
  ),

  -- 3. Cohort: first RE event per MTID (impression within analysis window)
  cohort AS (
    SELECT
      mtid,
      os,
      MIN(event_date) AS reengage_date
    FROM re_events
    WHERE is_reengagement = TRUE
      AND imp_date BETWEEN start_date AND end_date
    GROUP BY 1, 2
  ),

  -- 4. All daily activity per MTID
  daily_activity AS (
    SELECT DISTINCT mtid, event_date
    FROM re_events
  )

-- 5. Retention by OS
SELECT
  c.os,
  COUNT(DISTINCT c.mtid) AS cohort_size,
  COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 1 DAY) THEN c.mtid END) AS ret_d1,
  COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 3 DAY) THEN c.mtid END) AS ret_d3,
  COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 7 DAY) THEN c.mtid END) AS ret_d7,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 1 DAY) THEN c.mtid END),
    COUNT(DISTINCT c.mtid)
  ) AS retention_d1,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 3 DAY) THEN c.mtid END),
    COUNT(DISTINCT c.mtid)
  ) AS retention_d3,
  SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN da.event_date = DATE_ADD(c.reengage_date, INTERVAL 7 DAY) THEN c.mtid END),
    COUNT(DISTINCT c.mtid)
  ) AS retention_d7
FROM cohort c
LEFT JOIN daily_activity da ON c.mtid = da.mtid
GROUP BY 1
ORDER BY 1
```

---

## Additional Analyses (in notebook)

### 5a. Retention by cohort week

Group `reengage_date` into weekly cohorts to see if retention trends change over time.

### 5b. Daily retention curve (D0–D7)

Compute retention for every day D0 through D7 to visualize the full decay curve, not just the 3 checkpoints.

### 5c. Event breakdown

Examine which `event_pb` types drive retention (e.g., `#open`, `purchase`, custom events) to understand the quality of re-engaged users.

---

## Assumptions & Caveats

1. **Attributed events only** — Retention is measured using events in `cv` (attributed to Moloco). Organic returns without Moloco attribution are not captured.
2. **MTID deduplication** — One MTID = one user. If MTID is reassigned or missing, those users are excluded.
3. **D0 definition** — First RE-attributed event date per MTID. Users re-engaged on multiple days are counted in their earliest cohort only.
4. **Activity = any event** — Any postback event on D+N counts as retained, regardless of event type. Can be refined to specific events if needed.
5. **Date range** — Ensure `end_date` is at least D7 after the last cohort date to allow full D7 retention measurement.

---

## Notebook Structure


| Section                        | Description                            |
| ------------------------------ | -------------------------------------- |
| **0. Config**                  | Date range, advertiser ID, BQ project  |
| **1. Campaign Discovery**      | Identify Danggeun RE campaigns by OS   |
| **2. Data Pull**               | Execute retention query via BQ         |
| **3. Overall Retention by OS** | Summary table + grouped bar chart      |
| **4. Retention Curve (D0–D7)** | Line chart per OS                      |
| **5. Cohort Trend**            | Weekly cohort heatmap                  |
| **6. Event Breakdown**         | Top events driving D1/D3/D7 by OS      |
| **7. Summary & Insights**      | Key findings                           |


