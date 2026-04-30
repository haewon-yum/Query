# Blueprint Seller Insight Dashboard — Plan

## Objective

Build a comparative dashboard that shows how a given advertiser/campaign/bundle scores on the Blueprint framework relative to a peer group. The dashboard surfaces actionable gaps and benchmarks, helping sellers prioritize conversations and set realistic improvement targets.

**Deployment target:** Google Cloud Run (Python + Plotly Dash)

---

## Data Sources

| Table | Role |
|-------|------|
| `moloco-ods.alaricjames.project_blueprint_combined_data` | Blueprint scores per campaign × pillar + campaign metadata (**to be replaced with updated table**) |
| `moloco-dsp-data-view.athena.dim1_app_v3_rmg_vertical` | Moloco-curated app taxonomy — source of truth for all category filters |

### Join Coverage (validated 2026-04-07)

| Metric | Value |
|--------|-------|
| Distinct bundles in blueprint table | 6,290 |
| Matched to dim1_app | 5,627 (89.5%) |
| Has `moloco_vertical` | 84.5% |
| Has `moloco_sub_vertical` | 81.2% |
| Has `moloco_genre` | 76.1% |

- Join on `app_market_bundle` alone is sufficient — nested struct `d.moloco.vertical` accessor confirmed working.
- ~663 bundles (10.5%) have no dim1_app match → NULL taxonomy → excluded from peer group assignment.

### Key Fields — Blueprint Table

| Field | Notes |
|-------|-------|
| `campaign_id`, `advertiser_id`, `platform_id` | Primary identifiers |
| `app_market_bundle`, `mmp_bundle_id` | Bundle-level join key to dim1_app |
| `pillar`, `blueprint_index` | Pillar and sub-score check identifier |
| `score`, `overall_campaign_score`, `overall_blueprint_score` | Score at check / campaign / advertiser level |
| `detail`, `recommendations` | Human-readable diagnosis per check |
| `os`, `mmp_name`, `campaign_goal`, `spend_L7` | Campaign attributes |
| `office_region`, `office`, `growth_pod` | Sales org metadata |

> Note: existing `vertical`, `sub_vertical`, `genre` columns in the blueprint table are **not used** — all taxonomy is sourced from `dim1_app` via LEFT JOIN.

### Key Fields — dim1_app_v3_rmg_vertical (moloco struct)

| Field | Sample Values | Notes |
|-------|---------------|-------|
| `app_market_bundle` | `com.example.app` | Join key |
| `moloco.vertical` | `Gaming`, `Consumer` | Primary category |
| `moloco.sub_vertical` | `Action`, `Commerce` | Secondary category |
| `moloco.genre` | `arcade`, `food services` | Most granular |

---

## Input & Filter Design

### Required Input
| Filter | Source | Notes |
|--------|---------|-------|
| `platform_id` | blueprint table | Always required |

### Focal Entity Selectors (cascading — select from top down)
| Filter | Source | Notes |
|--------|---------|-------|
| `advertiser_id` / `advertiser_title` | blueprint table | Optional — narrows to one advertiser |
| `app_market_bundle` | blueprint table | Optional — narrows to one bundle |
| `campaign_id` / `campaign_title` | blueprint table | Optional — narrows to one campaign |

**Behavior by selection depth:**
- **Advertiser only (no bundle)**: plot one focal dot per bundle for that advertiser
- **Bundle selected (no campaign)**: single focal dot = bundle-level weighted avg score
- **Campaign selected**: bundle-level weighted avg shown in View 1; campaign score shown as additional marker in View 2 drill-down

### Optional Peer Group Filters
| Filter | Source | Notes |
|--------|---------|-------|
| `moloco.vertical` | dim1_app | e.g., `Gaming` |
| `moloco.sub_vertical` | dim1_app | e.g., `Action` |
| `moloco.genre` | dim1_app | e.g., `arcade` |
| `campaign_goal` | blueprint table | e.g., `CPI`, `ROAS` |
| `office_region` / `office` | blueprint table | Regional drill-down |

---

## Peer Group Definition

### Taxonomy Hierarchy (3-level fallback)

Peer group resolves at the most granular level with N ≥ 10 bundles, falling back if below threshold:

```
moloco.genre  →  (< 10 peers?)
  moloco.sub_vertical  →  (< 10 peers?)
    moloco.vertical  →  (< 10 peers?)
      [no valid peer group — show warning]
```

- `is_gaming` dropped as a fallback tier (63.8% fill rate — too sparse).
- Bundles with NULL taxonomy on all three levels are **excluded** from peer group assignment.
- Dashboard always displays the resolved level and peer N (e.g., "Peers: 42 bundles in `arcade` genre").

### Minimum Peer Count
- **N ≥ 10 bundles** required for a valid peer group
- Below threshold at all levels: show a warning, do not render box plot

---

## Score Aggregation

### Unit of Analysis

Both **campaign-level** and **bundle-level** views are provided — users toggle between them on the same box plot.

| View | Peer group data point | Focal entity data point |
|------|-----------------------|-------------------------|
| Campaign-level | Each individual campaign in the peer group | Selected campaign score (or all campaigns for the bundle/advertiser) |
| Bundle-level | One weighted-avg score per bundle | Weighted-avg score for the focal bundle(s) |

### Weighted Average Method

- **Weight**: `spend_L7`
- **Exclusion**: campaigns with `spend_L7 = 0` are excluded before aggregation
- Applied at: overall score, per-pillar score, per-`blueprint_index` sub-score

**Bundle-level aggregation formula (per metric):**
```
bundle_score = SUM(campaign_score × spend_L7) / SUM(spend_L7)
```
where the sum is over all non-zero-spend campaigns for that `(platform_id, app_market_bundle)`.

### Score Levels

| Level | Field | Use case |
|-------|-------|----------|
| Sub-score (check) | `score` per `blueprint_index` | Diagnosing a specific check within a pillar |
| Pillar | weighted avg of `score` per `pillar` | Pillar-level comparison |
| Overall | `overall_blueprint_score` | Top-level benchmarking |

---

## Dashboard Views

All views include a **Campaign / Bundle toggle** that switches the peer group distribution and focal entity between campaign-level and bundle-level data.

### View 1 — Overall & Pillar Score Benchmarking (Box Plot)
- One box plot per pillar (X-axis: pillar, Y-axis: score 0–100)
- Box = peer group distribution (p25 / median / p75 / whiskers)
- Overlay: focal entity score as a dot (one dot per bundle if advertiser-only input)
- Header: resolved peer level + N (e.g., "Peers: 42 bundles · arcade genre")
- Toggle: Campaign view / Bundle view

### View 2 — Pillar Drill-Down (Sub-score Box Plots)
- Triggered by clicking a pillar in View 1
- One box plot per `blueprint_index` within the selected pillar
- Same campaign/bundle toggle as View 1
- If a campaign is selected: campaign score shown as a distinct marker (e.g., diamond) in addition to the bundle dot
- Below each box plot: focal entity's `detail` and `recommendations` text for that check
- Optional: table of top-5 peer bundles for that check

### View 3 — Bundle Leaderboard
- Within peer group: rank all bundles by bundle-level weighted-avg `overall_blueprint_score`
- Color-coded: ≥80 green / 50–79 yellow / <50 red
- Filterable by pillar
- Shows `spend_L7`, `app_name`, resolved taxonomy level

### View 4 — Spend-Weighted Priority View
- Scatter: X = bundle-level overall score, Y = `spend_L7`
- Bubble size = optional (e.g., number of campaigns)
- Focal entity highlighted
- Quadrant labels: high-spend + low-score = priority outreach
- Filterable by pillar

---

## Query Design

### Step 1 — Enrich Blueprint Data with dim1_app Taxonomy

```sql
WITH enriched AS (
  SELECT
    b.platform_id,
    b.advertiser_id,
    b.advertiser_title,
    b.campaign_id,
    b.campaign_title,
    b.campaign_goal,
    b.app_market_bundle,
    b.app_name,
    b.os,
    b.mmp_name,
    b.pillar,
    b.blueprint_index,
    b.score,
    b.overall_campaign_score,
    b.overall_blueprint_score,
    b.detail,
    b.recommendations,
    b.spend_L7,
    b.office_region,
    b.office,
    -- Taxonomy from dim1_app (source of truth)
    d.moloco.vertical     AS moloco_vertical,
    d.moloco.sub_vertical AS moloco_sub_vertical,
    d.moloco.genre        AS moloco_genre
  FROM `moloco-ods.alaricjames.project_blueprint_combined_data` b
  LEFT JOIN `moloco-dsp-data-view.athena.dim1_app_v3_rmg_vertical` d
    ON b.app_market_bundle = d.app_market_bundle
  WHERE b.spend_L7 > 0  -- exclude zero-spend campaigns globally
),
```

### Step 2 — Bundle-Level Score Aggregation (Weighted Average)

```sql
bundle_scores AS (
  SELECT
    platform_id,
    advertiser_id,
    app_market_bundle,
    app_name,
    moloco_vertical,
    moloco_sub_vertical,
    moloco_genre,
    pillar,
    blueprint_index,
    -- Campaign-level scores kept for campaign view
    campaign_id,
    campaign_title,
    score                   AS campaign_check_score,
    overall_campaign_score,
    overall_blueprint_score AS campaign_overall_score,
    spend_L7,
    detail,
    recommendations,
    office_region,
    office,
    -- Bundle-level weighted averages
    SAFE_DIVIDE(
      SUM(score * spend_L7) OVER (PARTITION BY platform_id, app_market_bundle, pillar, blueprint_index),
      SUM(spend_L7)         OVER (PARTITION BY platform_id, app_market_bundle, pillar, blueprint_index)
    ) AS bundle_check_score,
    SAFE_DIVIDE(
      SUM(overall_blueprint_score * spend_L7) OVER (PARTITION BY platform_id, app_market_bundle),
      SUM(spend_L7)                           OVER (PARTITION BY platform_id, app_market_bundle)
    ) AS bundle_overall_score,
    SUM(spend_L7) OVER (PARTITION BY platform_id, app_market_bundle) AS bundle_spend_L7
  FROM enriched
  WHERE platform_id = @platform_id
),
```

### Step 3 — Peer Group with 3-Level Fallback

```sql
-- Compute bundle-distinct counts at each taxonomy level
peer_counts AS (
  SELECT
    platform_id,
    moloco_genre,
    moloco_sub_vertical,
    moloco_vertical,
    COUNT(DISTINCT app_market_bundle) OVER (PARTITION BY platform_id, moloco_genre)         AS n_genre,
    COUNT(DISTINCT app_market_bundle) OVER (PARTITION BY platform_id, moloco_sub_vertical)  AS n_sub_vertical,
    COUNT(DISTINCT app_market_bundle) OVER (PARTITION BY platform_id, moloco_vertical)      AS n_vertical
  FROM bundle_scores
  WHERE moloco_vertical IS NOT NULL
),
-- Resolve peer level per bundle
peer_resolved AS (
  SELECT *,
    CASE
      WHEN moloco_genre IS NOT NULL AND n_genre >= 10         THEN 'genre'
      WHEN moloco_sub_vertical IS NOT NULL AND n_sub_vertical >= 10 THEN 'sub_vertical'
      WHEN moloco_vertical IS NOT NULL AND n_vertical >= 10   THEN 'vertical'
      ELSE 'insufficient'
    END AS peer_level,
    CASE
      WHEN moloco_genre IS NOT NULL AND n_genre >= 10         THEN moloco_genre
      WHEN moloco_sub_vertical IS NOT NULL AND n_sub_vertical >= 10 THEN moloco_sub_vertical
      WHEN moloco_vertical IS NOT NULL AND n_vertical >= 10   THEN moloco_vertical
      ELSE NULL
    END AS peer_key
  FROM peer_counts
)
```

---

## Deployment: Google Cloud Run

### Architecture

```
┌─────────────────────────────────────────┐
│            Google Cloud Run             │
│                                         │
│  ┌─────────────┐    ┌────────────────┐  │
│  │  Plotly     │    │  FastAPI /     │  │
│  │  Dash UI    │◄──►│  BQ Backend    │  │
│  └─────────────┘    └───────┬────────┘  │
│                             │           │
└─────────────────────────────┼───────────┘
                              │
                    ┌─────────▼──────────┐
                    │  BigQuery          │
                    │  (moloco-ods /     │
                    │  dsp-data-view)    │
                    └────────────────────┘
```

### Tech Stack

| Component | Choice | Notes |
|-----------|--------|-------|
| UI framework | Plotly Dash | Native Plotly box plots, filter widgets built-in |
| Backend | Dash + `google-cloud-bigquery` | Single-service deployment |
| Auth | Google IAP (Identity-Aware Proxy) | Restrict to Moloco org |
| Container | Python 3.11 slim | `Dockerfile` + `requirements.txt` |
| BQ auth | Workload Identity / service account | No key files in container |
| Config | Environment variables | `PLATFORM_ID_DEFAULT`, `BQ_PROJECT`, etc. |

### Service Layout

```
seller_insight/
├── app.py              # Dash app entrypoint
├── layout.py           # UI layout (filters, tabs, views)
├── callbacks.py        # Interactivity (filter → query → plot)
├── queries.py          # BQ query builders (parameterized)
├── Dockerfile
├── requirements.txt
└── seller_insight_plan.md
```

### Query Strategy

- **On filter change**: re-run parameterized BQ query → cache result in Dash `dcc.Store`
- **Peer group fallback**: resolved server-side in SQL, returned with `peer_level` and `peer_n` columns
- **Campaign/Bundle toggle**: single query returns both levels; client-side toggle switches which columns to plot (no re-query needed)

---

## Implementation Steps

- [x] **Step 0** — Validate dim1_app join coverage (done: 89.5% match, nested struct accessor confirmed)
- [ ] **Step 1** — Scaffold Cloud Run project: `Dockerfile`, `requirements.txt`, `app.py` skeleton
- [ ] **Step 2** — Build and validate enriched base query (blueprint + dim1_app LEFT JOIN, spend_L7 > 0 filter)
- [ ] **Step 3** — Build bundle-level weighted-avg aggregation; validate against known campaigns
- [ ] **Step 4** — Build peer group query with 3-level fallback; test edge cases (N < 10 at all levels)
- [ ] **Step 5** — Build Dash layout: filter panel + View 1 box plot with Campaign/Bundle toggle
- [ ] **Step 6** — Add View 2 drill-down (sub-score box plots per `blueprint_index`, campaign marker, detail text)
- [ ] **Step 7** — Add View 3 (leaderboard table) and View 4 (spend-priority scatter)
- [ ] **Step 8** — Deploy to Cloud Run; configure IAP

---

## Open Questions

1. **Blueprint table replacement**: Confirm updated table name when available — query design is schema-compatible.
2. **Peer group fallback UX**: Silent fallback (current plan) or show a banner "Peer level widened to sub_vertical (genre had only 6 bundles)"? Recommend banner — sellers need to know the comparison basis.
3. **IAP setup**: Is there an existing Cloud Run service / project in `moloco-ods` to deploy under, or should this be a new GCP project?
