# VT Analysis — Project Tracker

**Context:** Priority task from GDS × Sales workshop (Jan 2026)
**Doc:** https://docs.google.com/document/d/17P3y6WdYpJpnLf-lxCnIXZTbyNamFSXojmmop6ULz3I/edit?tab=t.e46cdhj7zi3s

---

## 1. VT Landscape (`notebook/vt_landscape.ipynb`)

**Goal:** Global view of VT ratio across offices, countries, OS, and creative formats

| Section | Description | Status |
|---------|-------------|--------|
| Step 1-1 | VT ratio heatmap by office × target country | ✅ Done |
| Step 1-2 | VT ratio heatmap by OS (iOS / Android) | ✅ Done |
| Step 1-3 | VT ratio by target country × OS — bar chart | ✅ Done |
| Step 2-1 | VT ratio by advertiser office — box plots | ✅ Done |
| Step 2-2 | VT ratio by target country — box plots | ✅ Done |
| Step 2-3 | VT ratio at campaign level by OS — box plots per OS × target country | ✅ Done |
| Step 2-4 | Spend by VT bucket — KOR targeting, horizontal stacked bar + %>60% annotation | ✅ Done |
| Step 2-4-2 | Same as 2-4 but KOR targeting + KOR office | ✅ Done |
| Step 3-1 | CR format mix + median VT ratio by format (global, all offices) | ✅ Done |
| Step 3-2 | Same as 3-1 but per OS loop; IB install share (all offices + KOR office); VT by country (all offices + KOR office); global IB benchmark | ✅ Done |

---

## 2. KOR VT Deepdive (`notebook/kr_vt_deepdive.ipynb`)

**Goal:** Deep dive into KOR office VT drivers — Kakao impact, bundle-level analysis

| Section | Description | Status |
|---------|-------------|--------|
| Section 1 | VT ratio trend over time (KOR office) | ✅ Done |
| Section 2 | VT ratio by OS × target country (KOR office) | ✅ Done |
| Section 3 | KOR office × KOR targeting: All / KakaoTalk Only / Excl. KakaoTalk — vertical bar | ✅ Done |
| Section 3b | Same as Section 3 but IB format only (`fact_dsp_all`) | ✅ Done |
| Section 3c | Top 10 KakaoTalk spend bundles per vertical × OS; VT ratio (All vs Excl.KT) + IB share line; flagged bundles (Excl.KT VT>70% & IB<40%) with format + publisher breakdown | ✅ Done |
| Section 4 | RTB funnel analysis (bid rate, win rate, serve rate) — KOR KakaoTalk | ✅ Done |
| Section 5 | Bid floor, bid price distribution — KOR KakaoTalk | ✅ Done |

**Pending / Open:**
- Section 3c: `campaign.type = 'APP_USER_ACQUISITION'` filter confirmed via Glean — applied ✅
- Section 3c publisher breakdown: publisher name lookup via `product_dimensions_SoT` — applied ✅

---

## 3. Kakao Deepdive (`notebook/kakao_deepdive.ipynb`)

**Goal:** Quantify KakaoTalk's exclusive reach and assisted install contribution

### Section 1 — Exclusive IDFA/GAID Reach

| Section | Description | Status |
|---------|-------------|--------|
| 1-A | Unique device ID volume: KakaoTalk vs. all publishers by OS (`codered_bid`) | ✅ Done |
| 1-B | Exclusive reach rate computation from 1-A | ✅ Done |
| 1-C | Venn diagram: KakaoTalk-only / Both / Non-Kakao by OS | ✅ Done |
| 1-D | (Optional) Exclusive reach by publisher sub-bundle within KakaoTalk | ⬜ Not started |

### Section 2 — Assisted Installs

| Section | Description | Status |
|---------|-------------|--------|
| 2-0 | Top 5 KakaoTalk spend bundles per vertical × OS (queried fresh from `fact_dsp_publisher`) | ✅ Done |
| 2-A | KakaoTalk impression summary by bundle × OS × cr_format (`prod_stream_view.imp`) | ✅ Done |
| 2-B | Install coverage check by bundle × OS (`prod_stream_view.pb`, aggregated) | ✅ Done |
| 2-C | Range join: installs ← KakaoTalk impressions within Xh; output: total_installs, had_kakao_imp, last_touch, assisted per bundle×OS | ✅ Done (windows: 1h, 3h) |
| 2-D | Conversion rate charts: stacked bar (last-touch / assisted / no Kakao) overall + per bundle | ✅ Done (charts generated) |
| 2-E | Assist rate by OS × cr_format × last-touch attribution | ⬜ Not started |

**Open decisions:**
- 2-D denominator: currently **KakaoTalk impression base** (exposed devices). User proposed alternative: flip to total installs as base, then show dark funnel (of globally unattributed installs, what % had KakaoTalk imp in prior Xh). **Decision pending.**
- 2-E: skip or implement after 2-D framing is settled

---

## 4. IB Format Deepdive (`notebook/ib_format_deepdive.ipynb`)

**Goal:** Understand why KOR has disproportionately high IB format share (iOS: 42%, Android: 27%) — supply-side composition vs bidding strategy

| Section | Description | Status |
|---------|-------------|--------|
| Section 1 | IB install share benchmark — top 5 countries + Others, by OS (`fact_dsp_creative`) | ✅ Done |
| Section 2 | Supply-side format mix — B/N/I bid request share by country × OS (`bidrequest2026*`) | ✅ Done |
| Section 3 | Bidding strategy — bid_rate, win_rate, imp_to_bid by `inventory_format` × country (`fact_supply`) | ✅ Done |
| Section 4-A | IB deep dive — gaming vs non-gaming publisher inventory (`fact_supply`, `req.app_is_gaming`, KOR) | ✅ Done |
| Section 4-B | IB deep dive — Kakao vs Non-Kakao (`fact_supply`, `exchange = 'KAKAO'`, KOR) | ✅ Done |

**Plan doc:** `plans/ib_format_deepdive_plan.md`

---

## 5. Supporting Files

| File | Purpose |
|------|---------|
| `plans/kor_vt_deepdive_plan.md` | Original plan for KOR deepdive |
| `plans/kakao_deepdive_plan.md` | Plan for Kakao deepdive (Section 1 + 2 methodology) |
| `plans/ib_format_deepdive_plan.md` | Plan for IB format deepdive (supply vs bidding hypothesis) |
| `context_vt_analysis.md` | Project context and doc link |
| `charts/` | Output charts from `kr_vt_deepdive.ipynb` |
| `notebook/*.png` | Output charts from `kakao_deepdive.ipynb` |
| `data/` | Cached CSV outputs from KOR deepdive queries |

---

## Key BQ Tables Used

| Table | Used for |
|-------|---------|
| `moloco-ae-view.athena.fact_dsp_publisher` | VT ratio by publisher, Kakao vs non-Kakao, top bundle ranking |
| `moloco-ae-view.athena.fact_dsp_creative` | VT ratio by cr_format, IB share |
| `moloco-ae-view.athena.fact_dsp_all` | IB format + publisher combined (Section 3b) |
| `moloco-dsp-profile-prod.bidlog.codered_bid_YYYYMMDD` | Unsampled device ID reach (Section 1) |
| `focal-elf-631.prod_stream_view.imp` | Impression events with device IFA (Section 2) |
| `focal-elf-631.prod_stream_view.pb` | Postback install events (Section 2) |
| `focal-elf-631.prod.trace{YYYYMMDD}*` | VBT throttle analysis (KOR deepdive Sec 4) |
| `focal-elf-631.prod.bidrequest{YYYY}*` | Supply-side bid floor (KOR deepdive Sec 5); supply format mix (IB deepdive Sec 2) |
| `moloco-ae-view.athena.fact_supply` | RTB funnel by format/country/exchange (IB deepdive Sec 3, 4-A, 4-B) |
| `moloco-ods.business_intelligence.product_dimensions_SoT` | App name lookup |
