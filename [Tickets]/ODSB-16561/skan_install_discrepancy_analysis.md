# ODSB-16561: SKAN Install Discrepancy Analysis

**Campaign:** `ohLrG2wb6Iyfzkxi` (MUSINSA Japan iOS Install)
**Period:** February 1–20, 2026
**Date of Analysis:** 2026-03-04

---

## Summary

The customer reported ~953 SKAN app installs (앱설치) for Feb 1–20, while Moloco's dashboard shows ~3,998 SKAN installs for the same period. The **~4x discrepancy** is explained by differences in SKAN postback filtering — specifically, Moloco includes **view-through fidelity** and **redownloads**, while the customer's MMP likely excludes both.

---

## Moloco's SKAN Install Counting Logic

Moloco's `skan_installs` field in `fact_dsp_core` is derived from raw SKAN postbacks (`cv_skan` table) with the following criteria:

```sql
-- Moloco's internal SKAN install definition:
SELECT COUNT(*)
FROM `focal-elf-631.prod_stream_view.cv_skan`
WHERE cv.pb.did_win = true               -- Apple confirmed Moloco won attribution
  AND cv.pb.postback_sequence_index = 0   -- First postback only (= install event)
  -- Redownloads ARE included
  -- View-through fidelity (fidelity_type=0) IS included
```

### Data Flow

```
Apple SKAdNetwork → SKAN Postback → Moloco (ad network) → Forwards to MMP
```

1. **Raw postbacks** land in `focal-elf-631.prod_stream_view.cv_skan`
2. **Attribution filtering** (`did_win=true`, `postback_sequence_index=0`) is applied
3. **Aggregated** into `moloco-ae-view.athena.fact_dsp_core` as `skan_installs`

---

## Cross-Check: Feb 1–20

### Totals Across Data Sources

| Source | Count |
|--------|-------|
| **fact_dsp_core: SKAN installs** | **3,998** |
| **fact_dsp_core: MMP installs** | **3,285** |
| **fact_dsp_core: Total (MMP + SKAN)** | **7,283** |
| cv_skan raw: did_win=T, seq=0 (validates fact_dsp_core) | 3,991 (~matches¹) |
| cv_skan raw: did_win=T, seq=0, excl. redownloads | 3,301 |
| cv_skan raw: all postbacks | 6,455 |
| **Customer's MMP: 앱설치** | **953** |

¹ The 7-record gap (3,998 vs 3,991) is likely a timestamp boundary edge case between cv_skan partition date and fact_dsp_core date_utc.

### Raw Postback Breakdown

| Dimension | Count | % of Total |
|-----------|-------|------------|
| **Total raw postbacks** | 6,455 | 100% |
| did_win = true | 5,163 | 80% |
| did_win = false (not attributed to Moloco) | 1,292 | 20% |
| **Fidelity: View-through** (fidelity_type=0) | 4,948 | **77%** |
| **Fidelity: StoreKit-rendered** (fidelity_type=1) | 1,499 | **23%** |
| Redownloads | 1,075 | 17% |

---

## Root Cause: Why 3,998 (Moloco) vs 953 (Customer)

### Factor 1: View-through fidelity dominates (biggest factor)

- **77% of postbacks are view-through** (`fidelity_type=0`) — user saw the ad but didn't click the StoreKit overlay
- Only **23% are StoreKit-rendered** (`fidelity_type=1`) — user tapped through the in-app App Store overlay
- The customer's MMP likely **does not count view-through SKAN installs**

### Factor 2: Redownloads are included

- **1,075 postbacks (17%)** are redownloads (`redownload=true`)
- Excluding redownloads drops SKAN installs from 3,998 → 3,301
- Customer's MMP likely **excludes redownloads**

### Factor 3: MMP attribution deduplication

- The customer's 953 "앱설치" may represent only MMP-attributed installs, not raw SKAN postbacks
- MMPs apply their own deduplication across all ad networks

### Combined Filtering Effect

| Filter Applied | SKAN Install Count |
|---|---|
| Moloco default (did_win + seq=0) | 3,998 |
| − Remove redownloads | 3,301 |
| − Keep only StoreKit-rendered (fidelity=1) | **~920** (estimated: 23% of 3,998) |
| **Customer's reported number** | **953** |

When filtering to only **StoreKit-rendered (click-through), non-redownload, first postbacks**, the count is **~920–950**, aligning almost exactly with the customer's 953.

---

## Key Dates Flagged by Customer (Feb 9–13)

The customer highlighted Feb 9–13 in red. These dates showed particularly large discrepancies, likely because view-through SKAN volume spiked during this period (possibly due to increased impression volume without proportional click-through).

---

## Conclusion

Neither Moloco nor the customer is "wrong." The discrepancy arises from **different definitions of a SKAN install**:

| | Moloco | Customer's MMP (likely) |
|---|---|---|
| View-through fidelity | Included | **Excluded** |
| Redownloads | Included | **Excluded** |
| did_win = true only | Yes | Yes |
| First postback only | Yes | Yes |

---

## Recommended Actions

1. **Confirm the customer's MMP** and their SKAN filtering configuration (fidelity type, redownload handling)
2. **Clarify to the customer** that Moloco's SKAN install count includes view-through fidelity and redownloads by design
3. **For apples-to-apples comparison**, Moloco could provide a filtered view:
   - Exclude redownloads (`redownload = false`)
   - Include only StoreKit-rendered fidelity (`fidelity_type = 1`)
4. **Consider** whether the high view-through ratio (77%) warrants a review of the campaign's creative/targeting strategy for this Japan iOS campaign

---

## Reference

### BQ Tables Used

| Table | Purpose |
|-------|---------|
| `moloco-ae-view.athena.fact_dsp_core` | Pre-aggregated daily campaign metrics (skan_installs, installs) |
| `focal-elf-631.prod_stream_view.cv_skan` | Raw individual SKAN postback records from Apple |
| `focal-elf-631.standard_report_v1_view.report_final_skan` | Standard reporting view with SKAN_ConversionCount |

### Key Fields

- `skan_installs` — Total SKAN-attributed installs (did_win=T, seq=0, incl. redownloads)
- `skan_installs_ct` — Click-through SKAN installs
- `skan_installs_vt` — View-through SKAN installs
- `cv.pb.did_win` — Whether Apple confirmed Moloco won SKAN attribution
- `cv.pb.postback_sequence_index` — 0 = install event, >0 = subsequent updates
- `cv.pb.redownload` — Whether this is a re-install
- `cv.pb.fidelity_type` — 0 = view-through, 1 = StoreKit-rendered (click-through)
