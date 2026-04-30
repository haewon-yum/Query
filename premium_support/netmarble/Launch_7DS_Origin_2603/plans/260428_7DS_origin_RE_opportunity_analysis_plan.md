# 7DS: Origin — RE Campaign Opportunity Analysis Plan

**Date:** 2026-04-28
**Bundle:** `com.netmarble.nanaori` (Android)
**Ticket context:** [ODSB-17637](https://mlc.atlassian.net/browse/ODSB-17637)
**Goal:** Quantify the potential revenue benefit of Retention & Engagement (RE) campaigns by measuring D7 revenue of lapsed users across inactivity buckets.

---

## 1. Objective

Establish a revenue baseline for lapsed users of 7DS: Origin to:
1. Identify the optimal inactivity window for RE campaign targeting
2. Set a data-grounded ROAS target for RE campaigns
3. Quantify the total addressable revenue opportunity per inactivity bucket

> **Scope note:** This analysis measures *organic return revenue* — what lapsed users earn when they return on their own. It is not incremental RE lift, which would require a holdout experiment.

---

## 2. Analysis Design

### 2.1 Cohort Definition

**Reference date:** `CURRENT_DATE() - 7` (rolling, so D7 revenue is fully observed as of today)

**Prior activity required for all cohorts:** ≥1 non-install event before the lapse window — excludes users whose only prior event was the install itself.

The analysis produces **two complementary views** from the same underlying data:

#### View A — Daily trend (X = 1 to 14)
For each day X, users whose **last non-install event occurred exactly X days before the reference date**. Gives 14 mutually exclusive daily cohorts. Plotting as a line chart reveals the exact decay curve shape and any inflection points.

#### View B — Bucket summary (with D14+ reference group)
Aggregates the daily cohorts into 4 mutually exclusive buckets:

| Bucket | Definition | Purpose |
|--------|-----------|---------|
| 1–3 days | Last event exactly 1, 2, or 3 days before reference | Recently lapsed — high return probability |
| 4–7 days | Last event exactly 4–7 days before reference | Weekly lapse — core RE targeting window |
| 8–14 days | Last event exactly 8–14 days before reference | Extended lapse — marginal RE viability |
| **15+ days** | Last event ≥15 days before reference | **Deep churn reference group** — establishes the revenue floor beyond the targeting window |

> **Why D14+ matters:** If D15+ revenue is near-zero, it confirms the 1–14 day window captures the full RE opportunity. If D15+ users still generate meaningful revenue, it argues for extending the targeting window. Given 7DS: Origin launched ~2026-04-06, the D15+ cohort covers users who have been inactive since near-launch — expect a small but informative group.

### 2.2 Activity Definition

**Active** = any MMP postback event with `event_name` NOT matching install-type events.
Exclude: any event where `LOWER(event_name)` matches `%install%`, `%first_open%`, or platform-specific install events.
Include: login events, session events, purchase events, level-ups, any engagement event.

### 2.3 Revenue Measurement

**D7 revenue** = sum of `revenue` from events fired in the 7-day window after the reference date:
`[reference_date, reference_date + 7 days)`

Segment revenue by:
- All lapsed users (any revenue contributor)
- Paying users only (those with revenue > 0 in the pre-lapse period)

### 2.4 Output Metrics Per Inactivity Day

One row per X (X = 1 to 14):

| Metric | Description |
|--------|-------------|
| `inactivity_days` | X (1–14) |
| `n_users` | Cohort size for that exact inactivity day |
| `n_returning` | Users with ≥1 non-install event in D7 window |
| `return_rate` | `n_returning / n_users` |
| `n_paying_returning` | Users with revenue > 0 in D7 window |
| `d7_revenue_total` | Sum of D7 revenue for this cohort |
| `d7_revenue_per_user` | `d7_revenue_total / n_users` (conservative; includes non-returners) |
| `d7_revenue_per_returning` | `d7_revenue_total / n_returning` (value of re-engaged user) |
| `arpu_pre_lapse` | Avg revenue in 7-day window before lapse (pre-lapse value tier context) |

---

## 3. Data Sources

| Purpose | Table | Notes |
|---------|-------|-------|
| Event activity (all events) | `focal-elf-631.prod_stream_sampled.pb` | Sampled — use for user-level inactivity detection; confirm sampling rate |
| Revenue events | Same pb table, filter `revenue > 0` | Cross-check with `fact_dsp_publisher` if available |
| Event name discovery | `pb` table, `DISTINCT event_name` for this bundle | Run Section 0 first to confirm event coverage |

**Pre-flight check:** Run event discovery query first to confirm:
- `event_name` values present for `com.netmarble.nanaori`
- Revenue field name and non-null rate
- Date range coverage in pb table for this bundle

---

## 4. Hypotheses

| # | Hypothesis | Expected signal |
|---|-----------|----------------|
| H1 | D7 revenue decays as inactivity days grow | Monotonic decline from X=1 to X=14; the curve shape reveals how quickly player value erodes |
| H2 | Revenue is concentrated in paying users, not returning DAU | n_paying_returning << n_returning; most D7 revenue from <20% of returners regardless of inactivity day |
| H3 | Return rate declines with inactivity days | Users inactive 1 day return more readily than users inactive 14 days |
| H4 | A visible "elbow" in the curve marks the churn threshold | Expect a kink where `d7_revenue_per_user` drops sharply — likely around X=7–10 for a new title |

---

## 5. Expected Insights

### 5.1 Targeting Window
If H1 holds: target the X-day bucket with the best `d7_revenue_per_user`. Compare revenue to RE campaign cost to assess viability.

### 5.2 RE ROAS Target
```
max_cpa = d7_revenue_per_returning × (1 - target_margin)
max_roas_target = d7_revenue_per_returning / d7_revenue_per_returning  # = 1.0 at break-even
```
Use `d7_revenue_per_user` (including non-returners) as the conservative ROAS target denominator — this accounts for the fact that a RE campaign impression doesn't guarantee return.

### 5.3 Market Sizing
```
RE opportunity ($) = n_users_per_bucket × d7_revenue_per_user × (RE lift multiplier)
```
RE lift multiplier is unknown without holdout; assume 1.0x (organic baseline) as the floor.

### 5.4 Churn Threshold
The bucket where `d7_revenue_per_user` drops to near-zero indicates the practical churn boundary. For a 22-day-old title, this is likely ≤14 days.

---

## 6. Caveats & Limitations

| Caveat | Implication |
|--------|-------------|
| Organic return ≠ incremental RE benefit | Analysis shows revenue floor, not true lift. Actual RE campaigns should run with holdout. |
| pb table is sampled | User counts and revenue may be underestimates. Note sampling factor and scale if known. |
| 22-day title history | Cohort sizes will be small; treat findings as directional, not statistically definitive. |
| Activity definition | "Any non-install event" — if only install events exist for some users, they won't appear as lapsed; they'll be excluded as cohort candidates. |
| No RE campaign history | Cannot separate users who returned due to push notifications / organic channels. |

---

## 7. Implementation Plan

### Step 0 — Event Discovery
Query `pb` table for `com.netmarble.nanaori`, get `DISTINCT event_name` and row counts over last 30 days. Confirm revenue field availability and value distribution.

### Step 1 — User Activity Timeline
Build a per-user activity table: for each user, the latest event date before the reference date (excluding install events).

### Step 2 — Inactivity Day Assignment
For each user, compute `inactivity_days = DATE_DIFF(reference_date, last_active_date, DAY)`. Keep only users where `inactivity_days BETWEEN 1 AND 14`. Exclude users with no pre-lapse non-install events (new users).

### Step 3 — D7 Revenue Aggregation
For each cohort user, sum revenue in the 7-day post-reference window.

### Step 4 — Output Table
Aggregate to bucket level: n_users, n_returning, return_rate, d7_revenue_total, d7_revenue_per_user, d7_revenue_per_returning.

### Step 5 — Visualization
- **Line chart (primary — View A):** `d7_revenue_per_user` by `inactivity_days` (X=1 to 14) — decay curve
- **Secondary line:** `return_rate` by `inactivity_days` on same or adjacent axis
- **Bar chart (View B):** `d7_revenue_per_user` by bucket [1–3, 4–7, 8–14, 15+], with D15+ visually distinguished as the reference group
- **Cohort size bars:** `n_users` per inactivity day/bucket (flag where n is too small to be reliable)
- **Table:** full 14-row + 4-bucket metrics summary for Netmarble deck/sharing

---

## 8. Output Destination

- **Notebook:** `260428_7DS_origin_RE_opportunity_analysis.ipynb`
- **Results export:** Excel or Google Sheets for sharing with Netmarble team
- **Slide-ready:** Revenue decay chart + market sizing table

---

## 9. Open Questions — Resolved via MOBIUS Table Validation (2026-04-28)

- [x] **Table:** Use `focal-elf-631.prod_stream_view.pb` — NOT `prod_stream_sampled`. The sampled view has no `pb` partition. `prod_stream_view.pb` is 100% unsampled; ~300–400 GB/day, partitioned on `DATE(timestamp)`. No scaling factor needed.
- [x] **Attribution coverage:** Both Moloco-attributed AND organic events are present. `moloco.attributed = TRUE` accounts for ~44.2% of rows; `FALSE` ~55.8%. Segmentation uses `LOGICAL_OR(moloco.attributed)` per user across pre-reference events.
- [x] **Sampling rate:** N/A — `prod_stream_view.pb` is unsampled. No scaling needed.
- [x] **Paying vs non-paying:** Not available as a pre-lapse dimension (no distinct paying-user flag). Segmented instead by `moloco.attributed` (TRUE/FALSE). D7 revenue > 0 is computed as a post-hoc metric.
- [ ] **KOR only or all geos?** Not yet filtered — initial implementation uses all geos. Recommend filtering to KOR for the Netmarble-facing cut if cohort size supports it.
