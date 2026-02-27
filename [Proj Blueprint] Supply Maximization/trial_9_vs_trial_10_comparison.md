# Trial 9 vs Trial 10: Performance Comparison

Job IDs:
- **Trial 9**: `moloco-ods:US.bquxjob_7e064777_19c48032db4`
- **Trial 10**: `moloco-ods:US.bquxjob_7a5c92b7_19c4868a751`

---

## 1. Top-Level Metrics

| Metric | Trial 9 | Trial 10 | Delta |
|---|---|---|---|
| **Status** | TIMED OUT (6h limit) | **COMPLETED** | -- |
| **Elapsed (wall clock)** | 360.3 min (6h, hit limit) | **311.5 min (5.2h)** | -49 min |
| **Total Slot Ms** | 17,152,067,156 (17.2B) | **576,887,227 (576.9M)** | **29.7x less** |
| **Slot Ms (from plan)** | 10,939,541,945 (10.9B) | **572,905,776 (572.9M)** | **19.1x less** |
| **Bytes Processed** | N/A (timed out) | 205.5 GB | -- |
| **Bytes Billed** | N/A (timed out) | 205.5 GB | -- |
| **Estimated Bytes** | 205.5 GB | 205.5 GB | Same |
| **Total Stages** | 228 | 779 | More parallel |
| **Records Read** | 8.3B | 15.6B | Higher |
| **Records Written** | 3.1B | 480M | **6.4x less** |
| **Shuffle Bytes** | 0 GB (incomplete) | 155.1 GB | -- |
| **Spill to Disk** | 0 GB | 0 GB | Same |
| **Slot Contention** | Yes (Stage 252) | **None** | Resolved |

### Verdict: Trial 10 wins decisively

- Trial 9 **never finished** (6-hour timeout).
- Trial 10 **completed** in 5.2 hours with **29.7x less slot time** and **no slot contention**.

---

## 2. Bottleneck Analysis

### Trial 9: Where it got stuck

The query stalled in two stages that were **still RUNNING** when the 6-hour limit hit:

| Stage | Name | Slot Ms | Records In | Records Out | Status |
|---|---|---|---|---|---|
| **252** | SFC: Output | **10,603,168,905** (10.6B) | 0 (blocked) | 0 | **RUNNING** (slot contention!) |
| **243** | SF3: Join | 308,120,115 (308M) | 6.7M | 1,126,566,254 | **RUNNING** |
| 240 | SF0: Output | 5,772,105 | 1.25B | 5.8M | Complete |
| 225 | SE1: Join+ | 1,294,330 | 160M | 1.23B | Complete |

**What happened:**

1. **Stage 243** = `campaign_rows_with_target` (campaign × bid_dim_targeted join).
   - 44,930 campaigns × 6.6M bid rows → **1.13B intermediate rows** materialized to shuffle.
2. **Stage 252** = `campaign_rows_with_flags` + `campaign_bids_with_target`.
   - Reads 1.13B rows from Stage 243, JOINs with **unscoped `apt_categories`** (all apps), computes targeting_pass, aggregates.
   - This stage was **blocked** waiting for Stage 243 AND suffered **slot contention**.
   - `recordsRead: 0` — it never got enough input to process before timeout.

**Root cause:** Two-stage pipeline with 1.13B intermediate rows materialized between them + massive `apt_categories` hash table (all apps globally).

### Trial 10: How it solved this

| Stage | Name | Slot Ms | Records In | Records Out | Status |
|---|---|---|---|---|---|
| **761** | S2F9: Join+ | **504,029,508** (504M) | 131M | 26,795 | **COMPLETE** |
| **779** | S30B: Join+ | 5,513,900 | 635M | 2.2M | **COMPLETE** |

**What happened:**

1. **Stage 761** fused three operations into **one stage**:
   - Campaign × bid_dim_targeted JOIN
   - LEFT JOIN with **scoped `apt_categories`** (only bidrequest app_bundles)
   - Targeting_pass computation + aggregation to campaign_id
   - **No intermediate materialization** of the 1.13B rows.
2. **Stage 779** = non-targeted path (bid_dim_light + campaign join), completed quickly.

**Why it worked:**
- **Optimization 3 (scoped apt_categories)** dramatically reduced the hash table size for the LEFT JOIN, allowing BigQuery to fuse the join + compute + aggregate into a single stage.
- **Optimization 1 (fact_base consolidation)** freed up resources by eliminating duplicate fact_dsp_core scans.
- BigQuery allocated 779 parallel stages vs 228, distributing work more evenly.

---

## 3. High-Cardinality Join Comparison

Both trials hit the same fundamental row explosion in the campaign × bid join:

| Join | Trial 9 | Trial 10 |
|---|---|---|
| Campaign × bid_dim (targeted) | 44,930 × 6.6M → **1.23B** | 45,859 × 6.9M → **1.23B** |
| Intermediate × apt_categories | 1.23B × 21.4M → **18.15B** | 1.23B × 124.3M → **18.14B** |

The row explosion is nearly identical (~18.1B). The difference is:
- Trial 9: 18.1B rows evaluated across **two separate stages** with materialization between them.
- Trial 10: 18.1B rows evaluated in **one fused stage**, avoiding the shuffle of 1.13B intermediate rows.

---

## 4. What Each Optimization Contributed

| Optimization | Impact |
|---|---|
| **#1: fact_dsp_core consolidation** | Eliminated 2 redundant table scans. Freed slot capacity. |
| **#2: Single bidrequest scan** | BigQuery still created parallel stages for targeted/light paths, but from a single read. |
| **#3: Scoped apt_categories** | **Biggest single contributor.** Reduced the apt hash table from 21.4M to a subset of bidrequest bundles, enabling BigQuery to fuse stages 243+252 into one. |
| **#4: LAT regex fix** | Correctness fix. No performance impact. |
| **#5: Removed SELECT DISTINCT** | Minor — eliminated one unnecessary shuffle. |
| **#6: Deduplicated CASE** | Minor — reduced computation in the light path. |

---

## 5. Remaining Bottleneck & Further Improvement Areas

### 5.1 The 18.1B row explosion is still the dominant cost

Stage 761 (504M slot ms) accounts for **88%** of trial_10's total slot time. It's driven by:

```
campaigns (45K) × countries (~5 per campaign) × bid_dim_targeted rows per (country, os)
= ~1.23B intermediate rows
× apt_categories lookup
= ~18.1B evaluations
```

**Potential fix: Pre-filter bid_dim_targeted before the campaign join.**

Currently, `bid_dim_targeted` contains ALL (country, os, is_lat, app_bundle, exchange, device_type) combinations. Most of these will fail targeting for every campaign. If we pre-filter to eliminate rows that can't pass ANY campaign's targeting:

```sql
bid_dim_targeted_pruned AS (
  SELECT bd.*
  FROM bid_dim_targeted bd
  WHERE
    -- Only keep app_bundles that aren't blocked by ALL campaigns
    NOT EXISTS (
      SELECT 1 FROM campaign_with_target c
      WHERE ARRAY_LENGTH(c.blocked_apps) > 0
        AND bd.app_bundle IN UNNEST(c.blocked_apps)
    )
    -- Only keep exchanges that at least one campaign allows
    OR EXISTS (
      SELECT 1 FROM campaign_with_target c
      WHERE ARRAY_LENGTH(c.allowed_exchanges) = 0
         OR bd.exchange IN UNNEST(c.allowed_exchanges)
    )
)
```

This is complex to generalize, but for campaigns with large blocklists, it could significantly reduce the 1.23B intermediate.

### 5.2 Partition targeted campaigns by targeting type

Not all targeted campaigns need all 6 bid dimensions. For example:
- Campaigns with **only country/LAT targeting** don't need `app_bundle`, `exchange`, `device_type`.
- Campaigns with **only app blocklists** don't need `exchange` or `device_type`.

Splitting into sub-paths (e.g., `app_targeting_only`, `exchange_targeting_only`, `mixed_targeting`) could reduce the GROUP BY cardinality for each sub-path.

### 5.3 Consider pre-aggregated bidrequest tables

If this query runs daily/on-schedule, a **materialized view** or **pre-aggregated table** of bidrequest counts by `(date, country, os, is_lat, app_bundle, exchange, device_type)` would eliminate the expensive bidrequest scan entirely. The 3-day window means only 3 partitions to read from a pre-aggregated source.

### 5.4 Wall clock vs slot time gap

Trial 10 used 572.9M slot-ms but took 311.5 minutes wall clock. That's:
- Slot time: ~9.5 minutes of serial compute
- Wall clock: 311.5 minutes

The 33x gap suggests the query is **waiting for slot scheduling** most of the time (ENTERPRISE edition, shared pool). If this becomes a recurring scheduled job, consider:
- **Reservations**: Dedicated slot pool to avoid scheduling delays.
- **BATCH priority**: If latency isn't critical, BATCH can access more slots.

---

## 6. Decision

- [x] **Keep trial_10 as-is** — single `bid_base` scan performs dramatically better.
  - Trial 9 timed out. Trial 10 completed with 29.7x less slot time.
  - The `bid_base` CTE was NOT harmfully materialized — BigQuery successfully inlined/fused it.
- [ ] ~~Hybrid approach — revert bidrequest to two-scan.~~ Not needed.

### Recommended next steps (priority order)

1. **Pre-aggregated bidrequest table** — highest ROI if this runs regularly.
2. **Sub-path split by targeting type** — reduce GROUP BY cardinality for simple-targeting campaigns.
3. **Slot reservation** — reduce wall-clock time from 5.2h to closer to the ~10min theoretical slot time.
