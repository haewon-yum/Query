# VT Analysis — Session Insights

**Initiative:** KOR VT (View-Through) landscape and incrementality narrative
**Origin:** GDS × Sales workshop (Jan 2026) — "We don't have structural evidence on incrementality, particularly on image banners (e.g. Kakao Bizboard)"
**Owner:** haewon.yum@moloco.com
**Contributor:** donggyeong.kim@moloco.com
**Stakeholders (workshop inputs):** Kuyoung Chung, Hankhil Lee, Daniel Jeon
**Source doc:** [WIP] MA DS: VT landscape and potential objection handling narratives in KOR — https://docs.google.com/document/d/17P3y6WdYpJpnLf-lxCnIXZTbyNamFSXojmmop6ULz3I
**Notebooks:** `vt_landscape.ipynb`, `kr_vt_deepdive.ipynb`, `ib_format_deepdive.ipynb`, `kakao_deepdive.ipynb` (plus retired `kor_kakao_native_bizboard_skew.ipynb` — side analysis, excluded from main narrative)
**Investigation started:** 2026-04-21

---

## Session 2026-04-21 → 2026-04-23

### Context
- **Scope:** Synthesise findings across all four VT notebooks + Google Doc into a single self-contained interactive report; validate key numbers; separate observation from interpretation; produce discussion agenda for Sales sync.
- **Tables used:** `moloco-ae-view.athena.fact_dsp_publisher`, `fact_dsp_creative`, `fact_dsp_all`, `fact_supply`; `moloco-dsp-profile-prod.bidlog.codered_bid_YYYYMMDD`; `focal-elf-631.prod_stream_view.imp`, `prod_stream_view.pb`, `prod_stream_view.cv`; `moloco-ods.business_intelligence.product_dimensions_SoT`; `focal-elf-631.prod.bidrequest2026*`.
- **Output:** `vt_synthesis_report.html` (~85 KB, 18 interactive Plotly charts + 5 static PNGs, self-contained) + validation CSV `data/s3a_validation_vt_by_format_kor.csv`.

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Can we digest + synthesise the current VT analysis into one report? | Read Google Doc via Glean MCP (docs read failed on scope); parse all notebook cells; extract key metrics; write HTML synthesis | Full synthesis produced covering landscape → IB over-index → Kakao role → user quality → objection-handling crib sheet → gaps → next steps. |
| 2 | Is the report logic defensible against adversarial review? | Three rounds of skeptical-judge agent review (PASS_WITH_FLAGS each) | R1 fixed bid-rate-compounds logic error in Bizboard-vs-Native section; R2 removed that section entirely (side analysis, not mainstream); R3 found critical chart-data mismatch in Kakao reach donut (slice percentages were wrong). |
| 3 | Is the §3a "uniform 85-99% VT across IB publishers" finding a data error? | Re-query `fact_dsp_all` directly via Jupyter MCP kernel to validate + pull VT ratio cross-format | Data replicates exactly (com.kakao.talk 122,954 installs / 94.07% VT). Uniformity is format-structural: IB 89.4% Android / 97.6% iOS; NL 80.1% / 96.7%; NI 61.1% / 91.1%; video/rewarded formats 3-7%. Banner CTR sub-1% means most installs route through 24h VT window. |
| 4 | Missing USA data in §2d bidding rate charts | Connected to Jupyter MCP, re-ran `fact_supply` query for all countries | USA Banner bid rate 14.3% iOS / 6.2% Android; USA Banner win rate 15.1% iOS / 10.7% Android — KOR Banner win rate (41.2% iOS / 28.5% Android) is the highest of all 6 markets. |
| 5 | Add IB × publisher-genre breakdown (was in open questions) | BQ query on `fact_supply` with `cr_format='ib'` × `req.app_is_gaming` × `req.country='KOR'` | Non-gaming publishers supply 70% of KOR Android IB bid requests and win at 2× the rate of gaming publishers (Android 33.2% vs 16.4%; iOS 48.2% vs 28.2%). |
| 6 | Is "top-10 bundles" definition in §4 clear enough? | Reviewed notebook cell 37 source; added explicit callout | Top-10 per vertical = top 10 advertisers by gross spend **on KakaoTalk inventory** in KOR-office × KOR-target Android campaigns Jan 2026, split by `product.is_gaming`. Not top-10 by overall Moloco spend. |

### Key Findings

1. **KOR VT ratio is highest among top-10 spend markets.** iOS 63% / Android 37% (KOR-target × all offices, Jan 2026). KOR-office × KOR-target is even higher: iOS 78.8% / Android 50.4%. Source: `fact_dsp_publisher`. Implication: the headline "KOR has high VT" is not a measurement artifact; it's the floor for any narrative.

2. **KOR over-indexes on IB format ~2×.** KOR IB install share is iOS 42% / Android 27% vs global benchmark 19.9% / 11.3% (`fact_dsp_creative`, L30D). Supply side confirms this — KOR iOS bid-request Banner share 46.5%, Android 36.7% (`bidrequest2026*`). Implication: the VT level is anchored in format composition, not attribution weirdness.

3. **KakaoTalk is the largest IB publisher but only on Android.** `com.kakao.talk` is 42.3% of KOR Android IB installs vs only 26.3% on iOS (where Block Blast is co-top at 27.5%). Kakao-IB VT vs Non-Kakao IB VT shows a +10.5pp gap on Android (94.0% vs 83.5%) but essentially zero on iOS (97.7% vs 97.6%). Implication: Android has a genuine Kakao-specific signal, iOS does not. This is the single most important asymmetry for the sales narrative.

4. **KakaoTalk exclusion drops aggregate VT by 8.3pp on Android, 4.1pp on iOS** (KOR office × KOR target baseline). Android delta is twice iOS in absolute terms — again confirms Android is Kakao-centric; iOS VT survives Kakao removal largely intact.

5. **KakaoTalk exclusive device-ID reach: Android 8.8%, iOS 11.6%** (unsampled 2-day snapshot via `codered_bid`, Mar 28-29 2026). 2,508,836 Android device IDs appear only on KakaoTalk (not seen on any other Moloco-served publisher). iOS figure is directional only — measured on IDFA-consented pool. Implication: strongest "don't exclude Kakao" evidence.

6. **Section 3a high-VT-across-publishers is format-structural, not suspicious.** Direct validation: IB (banner), NL (native list) and NI (native image) are uniformly VT-heavy across all KOR publishers (89-98%). Video and rewarded formats are CT-heavy (3-7% VT). Banner CTR is sub-1%, so most banner-attributed installs route through the 24h view-through window. Two Android outliers — HanaMembers (11.8% VT) and CashMyCharge (29.7% VT) — are CT-dominated exceptions and flagged in §3a.

7. **KOR Banner win rate is 2-3× other markets.** iOS 41.2% / Android 28.5% — highest of all 6 top-spend markets (USA, JPN, KOR, GBR, DEU, Others). Mechanism not decomposed: could be lower competition, higher Moloco bids, lower floors, or KAKAO-exchange-specific auction dynamics. Surfaced as Q3 in discussion agenda; filed as P2 investigation.

8. **Non-gaming IB out-performs gaming IB on both OS.** Android win rate 33.2% (non-gaming) vs 16.4% (gaming) — 2×; iOS 48.2% vs 28.2% — 1.7×. Non-gaming publishers supply 70% of KOR Android IB bid requests and 56% of iOS. The KOR IB over-index is concentrated in non-gaming publisher inventory (KakaoTalk, tmobi, Daum, kakaobank, KakaoPage, etc.).

9. **ITIT signature does not distinguish organic poaching from real VT.** VT segments cluster at median 154-169 min; CT segments at 0.5-3 min. VT × KakaoTalk and VT × Non-KakaoTalk have nearly identical ITIT shapes — the signature reflects format/attribution mechanics, not publisher-specific user behaviour. Implication: ITIT is a sanity check against late-window gaming, not evidence of incrementality.

10. **Retention heatmap supports "real users" on gaming bundles but cannot prove incrementality.** On several (not all) top-10 gaming bundles, VT × KakaoTalk D1/D3/D7 retention is at or above CT × Non-KakaoTalk baselines. Many non-gaming cells fall below the 50-install threshold and are N/A. This observation is consistent with both "VT users are real" and "Moloco is being credited for organic installs" — observationally indistinguishable. Only a holdout experiment resolves it. (Hankhil's organic-poaching caution.)

11. **Assist window signal is small.** At 3h window, 0.78% of target-bundle installs had prior KakaoTalk impression; 0.22pp assisted to a different publisher. Coincidence only, not causation. Two denominator framings (exposed-device base vs total-installs base) still unreconciled.

### Judge audit trail (3 rounds)

- **R1 — PASS_WITH_FLAGS.** Fixed bid-rate compounding logic error in Native-skew section, reconciled scope of 63%/37% vs 78.8%/50.4%, softened over-reaching rebuttals in crib sheet, added iOS reach confidence row.
- **R2 — PASS_WITH_FLAGS.** Removed Kakao Bizboard-vs-Native analysis entirely (re-classified as side analysis); separated observation from interpretation with per-section insight + open-questions blocks; stripped "mechanistically drives" / "incremental reach" phrasings.
- **R3 — PASS_WITH_FLAGS (chart-data audit).** Critical: Kakao reach donut Android slices were wrong (had 54.4/36.8; correct values are 43.6/47.6 from `kakao_deepdive` cell 8). iOS similarly corrected 18.7/69.7 → 26.6/61.9. Plus 5 medium observation/interpretation slips.

### Final deliverables

- **`vt_synthesis_report.html`** (~85 KB) — self-contained interactive report with:
  - Discussion agenda for Sales sync (inserted after exec summary)
  - 18 interactive Plotly charts (VT by country, IB share KOR vs global, IB share by country, supply format mix, bid rate / win rate × format × country × OS for all 6 markets, IB × genre volume + funnel rates, KOR VT by format, publisher top-20 Android/iOS with VT overlay, excl-KT VT impact, Kakao reach donut, assist window, ITIT summary, retention sample scatter, D7 paying rate gaming/non-gaming)
  - 5 static PNGs preserved (ITIT full CDF shape, 2× retention heatmaps, 2× ARPPU dollar charts — pending CSV export to convert)
  - Per-section insight (observation-only) + open-questions blocks
  - Incrementality narrative crib sheet (§5, 4 objections)
  - 3-round judge review trail in appendix
- **`data/s3a_validation_vt_by_format_kor.csv`** — cross-format VT ratio validation

### Open Questions

- [ ] **No structural incrementality evidence** (the workshop's parent question). Only a holdout experiment resolves it. Android bulk test is P2 item — advertiser pilots not yet named.
- [ ] **iOS incrementality proxy design (workshop track 2-1)** — unscoped. Candidates: SKAN postback-pattern analysis on opted-out traffic, geo-holdout at DMA level, IDFA-consented subset as observational instrument with selection-bias modelling.
- [ ] **Android-vs-iOS performance asymmetry** (Hankhil's challenge) — unanswered. Resolution is downstream of the Android holdout test.
- [ ] **Why is KOR IB Banner win rate 2-3× other markets?** (Discussion Q3) Supply/pricing/DS joint investigation. Candidates: lower competition, higher Moloco bids, lower floors, KAKAO-exchange-specific dynamics. Not a P1 gate.
- [ ] **Retention + ARPPU CSV export** — `df_retention` and `df_arppu` truncated in notebook preview (only 10 of 73 rows visible). Blocks converting retention/ARPPU heatmaps from static PNG to fully-interactive Plotly heatmaps. Fix: add `df_retention.to_csv()` and `df_arppu.to_csv()` lines to `kr_vt_deepdive.ipynb` cells 42 and 46, re-run.
- [ ] **Assist denominator framing** — exposed-device base vs total-installs base produce different headline numbers. Both frames valid; not reconciled.
- [ ] **Stability of 8.8% / 11.6% Kakao exclusive reach** — current snapshot is 2 days. Extend to 30-day window to verify.
- [ ] **Decomposition of KOR IB over-index** — supply-side and bidding-side charts both exist; the 42% vs 19.9% gap has not been decomposed into supply-driven vs bidding-driven components.
- [ ] **§5-E vertical summary** (aggregate retention + ARPPU uplift per vertical over Segment D baseline) not yet produced. Needed for a single-sentence per-vertical quality claim.
- [ ] **Block Blast (1617391485) on KOR iOS** — 27.5% of iOS IB installs, co-top with KakaoTalk. Not investigated separately — do we need a "Block Blast story" for iOS, analogous to the KakaoTalk story on Android?
- [ ] **Discussion agenda decisions pending** — narrative posture (defense vs offense, hedging level), one narrative or two by OS, Android holdout pilot advertiser names, iOS track 2-1 owner + deadline, KOR win-rate investigation ticket owner.
