# Context of VT analysis

* doc: https://docs.google.com/document/d/17P3y6WdYpJpnLf-lxCnIXZTbyNamFSXojmmop6ULz3I/edit?tab=t.e46cdhj7zi3s
* Picked up as a priority task during GDS x Sales workshop in JAN 2026

---

## Notebooks

All notebooks are under `Measurement/VT/notebook/`:

| Notebook | Status | Description |
|----------|--------|-------------|
| `vt_landscape.ipynb` | Done | Global VT landscape — baseline for all follow-up work |
| `kr_vt_deepdive.ipynb` | In progress | KOR VT deep-dive (Sections 1–4 per plan doc) |
| `kor_kakao_native_bizboard_skew.ipynb` | In progress | Section 5 — KakaoTalk Bizboard vs Native impression skew |
| `ib_format_deepdive.ipynb` | Done (queries + charts) | IB format deepdive — why KOR has high IB share (supply vs bidding hypothesis) |

Charts → `Measurement/VT/charts/`, CSVs → `Measurement/VT/data/`

---

## kor_kakao_native_bizboard_skew.ipynb — Current State

### Completed cells

| Cell | Section | Status |
|------|---------|--------|
| 0 | Header | Done |
| 1–2 | Imports + BQ setup | Done |
| 3–5 | **Step 1** — fact_supply funnel (ib / ni / nl + Native total) | Done & executed |
| 6–7 | **Step 2** — Funnel viz (bid_requests → bids → bids_won → impressions) | Done & executed |
| 8–10 | **Step 3** — prod.trace bid_result breakdown (VBT throttle rates) | Done & executed |
| 11–13 | **Step 3b** — Bid floor comparison (bidrequest* sampled table) | Done & executed |
| 14 | Step 4 header | Done |
| 15 | **Step 4-A** — Bid price query (prod_stream_view.pricing) | **Code fixed, NOT yet executed** |
| 16 | **Step 4-B** — Bid price chart (P25/P50/P75/P90) | Not yet executed (depends on 15) |
| 17–19 | **Appendix** — inventory_format × cr_format cross-tab | Done & executed |
| 20–21 | Export to CSV | Not yet executed |

### Key findings so far

- **Bid request ratio**: KakaoTalk sends ib:native roughly 1:1 (slight ib skew in raw volume)
- **343x impression gap**: Bizboard vs Native — compounds across three funnel stages:
  - bid rate gap: ~5.4x (Bizboard bids on a higher fraction of requests)
  - win rate gap: ~3.8x (Bizboard wins more auctions per bid)
  - serve rate gap: ~5.2x (Bizboard impressions per win)
- **VBT throttle rate nearly equal**: ib ≈ 36%, native ≈ 33% — VBT does NOT preferentially throttle native. The skew is NOT a VBT issue.
- **Root cause hypothesis remaining**: Moloco underbids on native relative to the bid floor → confirmed by Step 3b (bid floor comparison). Step 4 (bid price) is next to confirm.

### Pending: Step 4-A fix (Cell 15)

Schema corrections required (confirmed via BQ agent):
- `candidates.bid_price` = **INT64 (micro-CPM)** — use `/ 1e6` directly
- `req.imp.bidfloor` = **STRUCT<currency STRING, amount_micro INT64>** — access as `req.imp.bidfloor.amount_micro / 1e6`

Current Cell 15 uses a CTE to extract both scalars before aggregating. This pattern is needed because BQ cannot access STRUCT sub-fields inside aggregate functions directly. The fix was applied but the cell has NOT been re-executed yet.

**Next action when resuming**: Run Cell 15 → should succeed → then run Cell 16 (chart), Cell 21 (export).

---

## Schema Gotchas (prod_stream_view.pricing)

| Field | Type | Usage |
|-------|------|-------|
| `candidates.bid_price` | INT64 (micro-CPM) | `candidates.bid_price / 1e6` for CPM |
| `req.imp.bidfloor` | STRUCT<currency STRING, amount_micro INT64> | `req.imp.bidfloor.amount_micro / 1e6` for floor CPM |
| `candidates.candidate_result` | STRING | Filter: `= 'CommitBid'` for actual bids submitted |
| `pricing.candidates` | REPEATED RECORD | Must `UNNEST(pricing.candidates) AS candidates` |

**BQ gotcha**: STRUCT sub-field access inside aggregate functions (e.g. `AVG(struct.field)`) fails with "Unable to coerce type STRUCT to INTERVAL". Always extract scalars in a CTE first, then aggregate in the outer query.

---

## kr_vt_deepdive.ipynb — Current State

**Analysis window:** `DATE_START = 2026-01-01`, `DATE_END = 2026-01-31`, `TARGET_COUNTRY = KOR`, `OS = ANDROID`

### Notebook structure

| Cell | Section | Status |
|------|---------|--------|
| 0–2 | Imports + params | Done |
| 3–6 | Section 1 — VT Ratio by Creative Format | Done |
| 7–17 | Section 2 — Kakao vs Non-Kakao (IB, by format, by exchange) | Done |
| 18–26 | Section 3 — Kakao impact on VT ratio | Done |
| 27–34 | Section 4 — Publisher-level analysis within IB | Done |
| 35–38 | **5-A** — Bundle selection (top 10 per vertical by KakaoTalk spend) | Done |
| 39–41 | **5-B** — ITIT CDF | Done |
| 42–43 | **5-C** — Retention query + heatmap | Fixed & ready to run |
| 44–47 | **5-D** — ARPPU query + viz | Fixed & ready to run |
| 48–49 | **5-E** — Vertical summary | Not yet run |

### Key variables

| Variable | Cell | Value |
|----------|------|-------|
| `RETENTION_DATE_END` | 42 | `DATE_END - 7d = '2026-01-24'` |
| `gaming_bundles`, `nongaming_bundles`, `all_bundles_sql` | 38 | Top 10 per vertical |
| `VERTICAL_MAP` | 43 | `{bundle → 'Gaming'/'Non-Gaming'}` |
| `SEG_ORDER`, `SEG_COLORS` | 43 | VT/CT × KakaoTalk/NonKakaoTalk |
| `df_retention` | 42 | Retention counts + rates by bundle × segment |
| `df_arppu` | 45 | D7 ARPPU + paying rate by bundle × segment |

### Fixes applied this session

**5-C Retention query (cell 42)**
- `SELECT DISTINCT` added to `post_events` CTE — was causing M×N join explosion
- Removed redundant `DATE(cv.happened_at)` filter — `timestamp` alone for partition pruning
- `TEST_MODE = True` block added — use 1 bundle × 3-day window to validate first; flip to `False` for full run

**5-C Retention heatmap (cell 43)**
- `pd.NA → float` crash fixed: use `pivot.to_numpy(dtype=float, na_value=float('nan'))` not `.values.astype(float)`
- `thin_pivot` bool+NaN crash fixed: `thin_arr = thin_pivot.to_numpy(dtype=object, na_value=False)`
- Per-row (per-bundle) color normalization: each bundle scaled 0→its own max so colors compare segments within a bundle
- NaN cells now rendered grey `#cccccc` with `"N/A"` label (not white, which looked like low retention)
- Source was accidentally stored as character list — fixed to proper line list

**5-D ARPPU (cells 45–46)**
- Query: removed redundant `DATE(cv.happened_at)` filters; added `df_arppu['vertical']` mapping
- Viz: now loops over Gaming / Non-Gaming — one chart + paying rate table per vertical
- Saved files: `s4d_arppu_gaming_...png` and `s4d_arppu_non_gaming_...png`

### Next actions when resuming

1. Run cell 42 with `TEST_MODE = True` → verify sanity checks pass → set `TEST_MODE = False` → re-run
2. Run cell 43 (retention heatmap)
3. Run cell 45 (ARPPU query) → cell 46 (ARPPU viz)
4. Run cell 49 (5-E vertical summary — aggregates retention + ARPPU)
5. Check `SEG_COLORS` is defined before cells 43/46 (search in notebook; may need to be added to params cell if missing)

### Known gotchas

- `VERTICAL_MAP` first defined in cell 43 — run cell 38 first if starting mid-notebook
- `cv.view_through` (BOOL) = canonical VT flag; `engaged_view_through` is separate, not a subset
- `timestamp` in `prod_stream_view.cv` = processing time (partition key); `happened_at` = actual event time
- BQ nullable types (`Int64`, `Float64`) → always use `.to_numpy(dtype=float, na_value=float('nan'))` for matplotlib

---

## Plan docs

`Measurement/VT/plans/kor_vt_deepdive_plan.md` — full analysis plan with Sections 1–5. Covers Bizboard vs Native skew.
`Measurement/VT/plans/kakao_deepdive_plan.md` — Kakao deepdive (exclusive reach + assisted installs).
`Measurement/VT/plans/ib_format_deepdive_plan.md` — IB format deepdive (supply vs bidding hypothesis).

---

## ib_format_deepdive.ipynb — Current State

**Analysis window:** L30D, `req.country = 'KOR'` (Sections 3–4), top 5 countries by spend for Sections 1–2

### Notebook structure

| Cell | Section | Status |
|------|---------|--------|
| 0–2 | Header + imports + BQ setup | Done |
| 3–5 | **Section 1** — IB install share benchmark by country × OS (`fact_dsp_creative`) | ✅ Executed |
| 6–8 | **Section 2** — Supply format mix B/N/I by country × OS (`bidrequest2026*`) | ✅ Executed |
| 9–11 | **Section 3** — Bidding strategy: bid_rate, win_rate, imp_to_bid by `inventory_format` × country (`fact_supply`) | ✅ Executed |
| 12–14 | **Section 4-A** — IB deep dive: gaming vs non-gaming publisher (`fact_supply`, `req.app_is_gaming`, KOR) | ✅ Executed |
| 15–17 | **Section 4-B** — IB deep dive: Kakao vs Non-Kakao (`fact_supply`, `exchange = 'KAKAO'`, KOR) | ✅ Executed |

### Key design decisions

- **Country grouping:** top 5 by Moloco L30D spend (USA $118M, JPN $16M, KOR $14M, GBR $14M, DEU $11M) + Others
- **Section 3 uses `inventory_format`** (not `cr_format`) to preserve zero-bid rows for accurate bid_rate
- **Section 4 gaming proxy:** `req.app_is_gaming` = publisher app genre (supply side), not advertiser vertical — noted in chart headers
- **No office filter** — supply depends on campaign market (`req.country`), not advertiser office
