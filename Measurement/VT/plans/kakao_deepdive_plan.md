# Kakao Deepdive — Analysis Plan

**Scope:** KOR office × KOR targeting campaigns
**Period:** TBD (suggest last 30–90d for supply; last 30d for postback)
**Notebook:** `kakao_deepdive.ipynb`

---

## Motivation

From `kr_vt_deepdive.ipynb` Section 3:
- Excluding KakaoTalk lowers aggregate VT ratio for KOR campaigns significantly
- Some bundles show high VT even after KakaoTalk exclusion (Excl.KT VT > 70%)
- Unknown: how much of KakaoTalk's install volume is truly additive (exclusive reach) vs. overlapping with other publishers

Two open questions to answer:

| # | Question | Why it matters |
|---|----------|---------------|
| 1 | What fraction of reachable IDFAs/GAIDs are exclusively reachable via KakaoTalk? | If KakaoTalk has high exclusive reach, excluding it means losing real users — not just VT inflation |
| 2 | Among converters, how many were exposed to a KakaoTalk ad shortly before install? | Separates "KakaoTalk as last-touch" from "KakaoTalk as assist" — important for attribution and VT interpretation |

---

## Section 1 — Exclusive IDFA/GAID Reach via KakaoTalk

### Hypothesis
KakaoTalk has a significant fraction of IDFAs/GAIDs that are not reachable through any other publisher on Moloco, particularly on Android (where KakaoTalk dominates native/banner inventory). Excluding KakaoTalk therefore trades off VT accuracy against real reach loss.

### Device ID Coverage Caveat (important)

| OS | ID type | Coverage | Reliability |
|----|---------|----------|-------------|
| Android | GAID | High — most Android devices share GAID | **Primary analysis** — numbers are representative |
| iOS | IDFA | Low — post-ATT (iOS 14.5+), most users do not consent to tracking | **Directional only** — opted-in users are a self-selected minority; exclusive reach likely understated |

All iOS reach numbers must be reported with the caveat: *"Based on IDFA-consented traffic only; true iOS exclusive reach is likely higher due to LAT/non-consenting users not appearing in bid requests."*

### Method

1. Pull bid-request level data (sampled) grouped by IDFA/GAID + publisher app bundle
2. Classify each device ID:
   - **KakaoTalk-exclusive** — appeared only on KakaoTalk inventory, never on any other publisher
   - **Overlap** — appeared on KakaoTalk AND other publishers
   - **Non-Kakao** — appeared only on non-Kakao publishers
3. Report exclusive reach % = `KakaoTalk-exclusive / total KakaoTalk device IDs`
4. Break down by OS — Android is the meaningful signal; iOS is supplementary

### Key Metrics
- `exclusive_reach_rate` = device IDs only on KakaoTalk / total KakaoTalk device IDs
- `kakao_id_share` = total KakaoTalk device IDs / all reachable device IDs
- Same metrics split by OS (Android primary, iOS directional)
- Distribution by `inventory_format` (B/N) — does exclusivity skew toward banner vs. native?

### Candidate Data Sources
| Source | Notes |
|--------|-------|
| `focal-elf-631.prod.trace{YYYYMMDD}*` | Sampled bid requests; has `exchange`, `app_bundle`, device IDs — **verify IDFA/GAID field name before querying** |
| `focal-elf-631.prod.bidrequest{YYYY}*` | 1/10000 supply-side sample; has device ID, exchange, publisher bundle |

> **Gotcha:** Use `inventory_format IN ('B','N')` (not `cr_format`) for unbiased reach counts — `cr_format` is NULL for throttled rows in the trace table.

> **Gotcha:** Device IDs absent from bid requests ≠ unreachable — they may be LAT/non-consenting users. The "non-Kakao" pool excludes these silently.

### Expected Output
- Venn-style summary table: KakaoTalk-only / Both / Non-KakaoTalk device ID counts and % — Android and iOS separately
- Bar chart: exclusive reach rate by OS with iOS caveat annotation
- Optional: exclusive reach by publisher sub-bundle within Kakao (KakaoTalk app vs. KakaoStory etc.)

---

## Section 2 — Assisted Installs via KakaoTalk

### Hypothesis
A non-trivial share of Moloco-attributed installs had a KakaoTalk ad exposure within a short window (e.g., 6–24h) before conversion. These "KakaoTalk-assisted" installs are currently last-touch attributed to a different publisher, yet KakaoTalk contributed to the user's path. This would partially explain high VT ratios on KakaoTalk (view-through = user saw KakaoTalk ad, then installed via another touch).

### Method

1. Pull KakaoTalk **impression events** with device ID + timestamp (publisher = KakaoTalk, KOR targeting, KOR office)
2. Pull Moloco-attributed **install events** (postback) with device ID + install timestamp, for the same apps/campaigns
3. Join on device ID: for each install, check if there is a KakaoTalk impression within `[install_time - X hours, install_time]`
4. Vary X = 6h, 24h, 48h — report assist rate at each window
5. Break down by:
   - OS (Android vs. iOS)
   - Attributed publisher (was the converting touch also KakaoTalk, or a different publisher?)
   - `cr_format` of the KakaoTalk impression (ib vs. nl/ni — relates to VT)

### Key Metrics
- `assist_rate(X)` = installs with ≥1 KakaoTalk impression in prior X hours / total installs
- `last_touch_kakao_rate` = installs attributed to KakaoTalk / total installs (baseline comparison)
- `pure_assist_rate` = installs where KakaoTalk assisted but was NOT the last touch
- VT rate of the KakaoTalk impression involved in the assist — was it a view-through or click-through?

### Candidate Data Sources
| Source | Notes |
|--------|-------|
| Impression log | Need to confirm table — likely `focal-elf-631.prod_stream_view.*` or a win/impression table; **must verify schema** |
| Postback / MMP install table | `focal-elf-631.mmp_pb_summary.app_status` or `focal-elf-631.prod.*pb*` — **verify exact table and device ID field** |

> **Gotcha:** VT impression (view-through) vs. click impression distinction is critical here. If KakaoTalk impressions are predominantly view-through, assist rate could be inflated by passive exposures. Segment by impression type.

> **Gotcha:** Postback data may only cover IFA-enabled devices (`opt_with_ifa`). LAT devices will be missing from the join. Report coverage rate upfront.

### Expected Output
- Summary table: assist rate at 6h / 24h / 48h windows
- Bar chart: assist rate by OS × window
- Stacked bar: for KakaoTalk-assisted installs — last-touch was KakaoTalk (view-through) vs. other publisher
- Optional: funnel — impression → assist → install, by cr_format

---

## Open Questions Before Starting

1. **Impression log table** — which table stores win/impression events with device ID + publisher bundle? Needs `exchange`, `publisher.app_bundle`, `device_id`/`maid`, `timestamp`, `is_click`
2. **Postback device ID field** — confirm field name and IFA opt-in coverage for KOR Android/iOS
3. **Sampling rates** — trace is sampled; confirm extrapolation multiplier for reach numbers
4. **Lookback window for reach** — 30d or 90d? Longer = more stable but more stale MAIDs

---

## Notebook Structure

```
Section 0: Setup & Parameters
  - DATE_START / DATE_END
  - TARGET_COUNTRY = 'KOR'
  - OFFICE = 'KOR'
  - KAKAO_PUBLISHER_FILTER
  - Assist windows: [6, 24, 48]  # hours

Section 1: Exclusive IDFA/GAID Reach (Android primary; iOS directional)
  1-A: Total device ID volume on KakaoTalk vs. all publishers, by OS
  1-B: Exclusive reach classification (KakaoTalk-only / Both / Non-Kakao)
  1-C: Exclusive reach rate by OS — annotate iOS ATT caveat
  1-D: (Optional) Exclusive reach by publisher sub-bundle within Kakao

Section 2: Assisted Installs
  2-A: KakaoTalk impression volume (impression log)
  2-B: Install events from postback (IFA coverage check)
  2-C: Join — KakaoTalk impression → install within X hours
  2-D: Assist rate by window (6h / 24h / 48h)
  2-E: Assist rate by OS × cr_format × last-touch attribution
```

---

## Dependencies / Pre-checks

- [ ] Confirm impression log table name + device ID field name
- [ ] Confirm postback table name + IFA opt-in filter
- [ ] Confirm `pub_bundle` field name in trace table for KakaoTalk filter
- [ ] Decide date range (suggest 30d for postback join; 90d for reach analysis)
- [ ] Decide assist window candidates (default: 6h, 24h, 48h)
