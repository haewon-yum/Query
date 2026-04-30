# Session Log: KB Securities VT/CT Attribution Collapse — Follow-Up Analysis

**Date:** 2026-04-14 — 2026-04-15
**Ticket:** ODSB-17593
**Original Investigation:** Searchlight session eccbf2d (2026-04-13)
**Duration:** ~5 hours (2 sessions)
**Analyst:** Haewon Yum

---

## What We Did

Follow-up deep dive on the KB Securities iOS MMP attribution collapse (Mar 21) identified in the original Searchlight investigation. Tested specific hypotheses, corrected T1-T4 definitions, verified PA status, and analyzed raw postback/cv data.

### Investigation Structure

| Phase | Questions | Key Discoveries |
|-------|-----------|-----------------|
| H1-H4: Hypothesis testing | 4 parallel BQ queries | VT+CT both collapsed; SKAN surged 3-6x; IDFA improved not worsened; exchange-level universality confirmed |
| Postback deep dive | Raw `postback.pb` by iOS vs Android | iOS VT collapsed at raw postback level; Android recovered; fact_dsp_core matches postback ~100% |
| PA enablement check (1-A) | `app_status` table | `fp_status=ENABLED` at app level throughout |
| PA enablement check (1-B) | `cv` table attribution method | `attribution.method=UNKNOWN` — AIRBRIDGE sends no method metadata |
| PA campaign-level check | `campaign_digest` daily snapshots | `allow_fingerprinting=false` since campaign creation (Mar 5). **PA was never enabled.** |
| Predecessor PA check | `campaign_digest` Feb snapshots | Predecessor also `allow_fingerprinting=false`. PA was never enabled for any KB Securities campaign. |
| T1-T4 correction | Internal traffic type doc | Corrected definitions; `is_mmp_effective` depends on PA, not raw IDFA presence |
| Raw cv deep dive | `prod_stream_view.cv` | **65-71% of MMP installs had NO IDFA** — AIRBRIDGE was doing its own probabilistic matching independently of Moloco's PA |
| Model calibration | `imp_1to100` prediction_logs | Model under-predicted pre-collapse (pred/actual=0.24-0.46); recalibrated post-collapse; install prediction rate halved by Apr 7 |
| Traffic type distribution (campaign) | `fact_dsp_core` by attribution | T4 = 99%+ throughout — no shift |
| Traffic type distribution (market) | `fact_dsp_core` iOS KR total | Market is 80-88% T2 (Bi-attributable) — Moloco reclassifies as T4 when PA is off |
| Bid request supply | `bidrequest*` sampled | T2=25.3%, T4=64.6% at supply level |

### Root Cause (Corrected from Original)

**Original hypothesis (Searchlight):** AIRBRIDGE VT attribution window disabled. Confidence: MEDIUM.

**Corrected root cause (follow-up):** AIRBRIDGE's MMP attribution matching broke for KB Securities around Mar 21 — **both VT (-98%) and CT (-70-90%)**. Not VT-only. PA was never enabled (`allow_fingerprinting=false` since creation). All pre-collapse MMP installs relied on **AIRBRIDGE's own probabilistic matching** (65-71% of installs had no IDFA in postback). That matching capability was disrupted. **Confidence: HIGH.**

### Key Corrections Made

1. **T1-T4 definitions:** Corrected per internal traffic type doc. With PA disabled, Moloco classifies 99.9% of traffic as T3+T4, not T1+T2.
2. **"VT collapse" → "MMP attribution collapse (VT+CT)":** CT also dropped 70-90%, ruling out VT-window-only change.
3. **PA was never the cause:** `allow_fingerprinting=false` for all KB Securities campaigns (predecessor and current) since creation. PA auto-disable hypothesis ruled out.
4. **AIRBRIDGE's own probabilistic matching was the engine:** 65-71% of MMP installs had no IDFA. The predecessor's $5.72 CPU was built on AIRBRIDGE's matching, not Moloco's PA.
5. **Moloco's PA ≠ MMP's attribution:** Two independent systems. AIRBRIDGE does its own fingerprint matching regardless of Moloco's `allow_fingerprinting` setting.

### Key Evidence Chain

```
Feb: Predecessor campaigns running (PA=off, LAT=76%)
  → AIRBRIDGE's own probabilistic matching attributes 65-71% of installs (no IDFA)
  → CPU $5.72 — excellent performance built on AIRBRIDGE's matching

Mar 5: New campaigns created (PA=off, still)
  → Action model outage Mar 5-10 (CPU inflated 2-5x)
  → Recovery Mar 11-20 (iOS CPU reached $2.73 on Mar 20)
  → Same AIRBRIDGE matching mechanism working: 66% of installs had no IDFA

~Mar 21: AIRBRIDGE attribution breaks for KB Securities
  → VT w/o IDFA: 277 → 0 (overnight — AIRBRIDGE's probabilistic matching stopped)
  → VT w/ IDFA: 152 → 5 (deterministic matching also degraded)
  → CT: 34 → 2 (both VT and CT affected)
  → SKAN surges 3-6x (installs shift to SKAN attribution)
  → All exchanges affected uniformly
  → KB Securities-specific (34 other advertisers unaffected)

Mar 21+: Feedback loop
  → Fewer MMP conversions → model recalibrates downward
  → Install prediction rate halved by Apr 7
  → Lower predictions → lower bids → worse inventory → fewer installs
  → Budget cuts Apr 3 amplify decline
```

---

## Data Files Produced

### Queries (SQL)
| File | Description |
|------|-------------|
| `claude-bq-agent/tmp/queries/20260414_142117_3b8f.sql` | Daily VT/CT/SKAN breakdown for iOS |
| `claude-bq-agent/tmp/queries/20260414_142127_1522.sql` | Daily LAT rate trend for iOS |
| `claude-bq-agent/tmp/queries/20260414_142138_d8aa.sql` | Attribution type breakdown by date |
| `claude-bq-agent/tmp/queries/20260414_142149_601f.sql` | Cross-advertiser LAT rate comparison |
| `claude-bq-agent/tmp/queries/20260414_142315_cbbf.sql` | Exchange-level VT shift pre/post collapse |
| `claude-bq-agent/tmp/queries/20260414_143935_007c.sql` | Postback VT by iOS vs Android |
| `claude-bq-agent/tmp/queries/20260414_144245_5bf5.sql` | PA check: attribution method in cv table |
| `claude-bq-agent/tmp/queries/20260414_144417_631c.sql` | Postback vs fact_dsp_core match rate |
| `claude-bq-agent/tmp/queries/20260414_144920_96e2.sql` | Full daily T1-T4 x VT/CT pivot |
| `claude-bq-agent/tmp/queries/20260414_145728_6562.sql` | app_status PA check |
| `claude-bq-agent/tmp/queries/20260414_151618_5e1d.sql` | campaign_digest PA history |
| `claude-bq-agent/tmp/queries/20260414_152634_c374.sql` | Predecessor campaign PA status |
| `claude-bq-agent/tmp/queries/20260414_153829_93f8.sql` | Daily impressions by T1-T4 (campaign) |
| `claude-bq-agent/tmp/queries/20260414_155143_99e4.sql` | Raw cv: VT/CT x IDFA presence |
| `claude-bq-agent/tmp/queries/20260414_155852_0689.sql` | Daily spend around collapse |
| `claude-bq-agent/tmp/queries/20260414_163004_6a8b.sql` | Predecessor cv: VT/CT x IDFA |
| `claude-bq-agent/tmp/queries/20260414_164039_f5ad.sql` | Model calibration (prediction_logs) |
| `claude-bq-agent/tmp/queries/20260414_164225_6848.sql` | KB impression market share by traffic type |
| `claude-bq-agent/tmp/queries/20260414_164600_5403.sql` | iOS KR market traffic type distribution |

### Data (CSV)
| File | Description |
|------|-------------|
| `claude-bq-agent/tmp/data/20260414_153829_bca2.csv` | Daily T1-T4 impressions for KB Securities iOS |
| `claude-bq-agent/tmp/data/20260414_155143_7a60.csv` | Raw cv VT/CT x IDFA breakdown |
| `claude-bq-agent/tmp/data/20260414_163004_66c6.csv` | Predecessor VT/CT x IDFA |
| `claude-bq-agent/tmp/data/20260414_164039_073f.csv` | Model calibration trend |
| `claude-bq-agent/tmp/data/20260414_164225_913e.csv` | KB impression market share |
| `claude-bq-agent/tmp/data/20260414_164600_a913.csv` | iOS KR market traffic type daily |

### Charts
| File | Description |
|------|-------------|
| `~/Downloads/kb-securities-cpu-degradation-2026-04/charts/07_traffic_type_daily.png` | 3-panel chart: T1-T4 impressions, T1+T3 zoomed, T4 share % |

### Reports
| File | Description |
|------|-------------|
| `~/Downloads/kb-securities-cpu-degradation-2026-04/report.html` | Updated with corrected follow-up analysis |
| `~/Documents/Queries/[Tickets]/ODSB-17593/kb_securities_vt_attribution_collapse_followup.md` | Markdown follow-up report (title/bottom line corrected) |

---

## Recommendations

### Immediate
1. **Contact KB Securities/DPLAN360:** Ask specifically whether AIRBRIDGE attribution settings for Moloco channel were changed around Mar 20-21. Present the evidence: both VT and CT collapsed overnight, SKAN surged, 65% of prior installs had no IDFA (AIRBRIDGE's probabilistic matching was the engine).

### After AIRBRIDGE Fix
2. **Enable PA (`allow_fingerprinting=true`):** Aligns Moloco's bidder classification with market reality (80-88% T2 vs current 0% T2). Model can properly value impressions and optimize on full MMP feedback signal.
3. **Restore iOS budget to $300-400/day.**
4. **Set realistic CPU targets:** $4-6 iOS (potentially better than predecessor's $5.72 given improved IDFA availability 76% vs 24%).

### Do NOT Do
- Enable PA while AIRBRIDGE attribution is still broken (model would over-predict → overbid → waste spend)
- Reduce budget further (amplifies negative feedback loop)

---

## Session 2 Additions (2026-04-15)

### Glean Codebase Trace: PA Data Flow
- **MCP UI source**: MEMS `MmpIntegration.FingerprintingSetting.allow_fingerprinting` → Product API → MCP UI
- **Daily update**: `app_status.verdict.fp_status` → Tascone `reflect_fingerprint_status` Airflow DAG (04:00 UTC) → MEMS
- **campaign_digest**: downstream mirror, NOT the source

### Glean Codebase Trace: AIRBRIDGE Tracking Mechanism
- AIRBRIDGE uses `DefaultForwardRequestFinalizer` → returns `(nil, false)` → **no S2S imp/click forwarding**
- AIRBRIDGE receives signal via **tracking link URL macro resolution**: `{{device.ip}}`, `{{device.user_agent}}`, `%{idfa}`, `%{bid_id}}`
- `allow_fingerprinting` does NOT affect tracking link resolution → **PA is irrelevant to AIRBRIDGE attribution**
- Key sources: `marvel2/go/src/eventtracker/service/fwdreqbldr/imp.go`, `marvel2/go/base/measurement/pkg/mmp/partners/` default finalizers

### Simon Phua Report Review (GDS APAC)
- **New finding**: Native Logo (nl) lock-in — 37% iOS spend on nl format (worst-performing), vs Samsung Securities 0.4-1.8%
- **Agreed**: Attribution gap, PA enablement recommendation
- **Disagreed**: "Jan baseline was broken" — predecessor sustained $0.30-$0.53 CPI for 8 weeks AND current campaign recovered to $0.45 by Mar 20
- **Missing**: No mention of Mar 21 overnight collapse; frames problem as structural rather than acute event

### Daily IDFA Presence in Attributed Installs
- Query: `focal-elf-631.prod_stream_view.cv`, `cv.pb.device.ifa` presence check
- Pre-collapse: ~30% IDFA, ~70% non-IDFA (consistent across predecessor and current)
- Post-collapse: IDFA share rose to ~48-70% — non-IDFA (probabilistic) matching broke more severely
- CSV: `claude-bq-agent/tmp/data/20260415_171622_2411.csv`

---

## Open Questions (Updated)

1. ~~Why was PA never enabled for KB Securities?~~ → **Resolved: PA is irrelevant to AIRBRIDGE attribution (no S2S path). PA only affects Moloco bid-time classification.**
2. What specific AIRBRIDGE-side change happened on Mar 21? **Tracking link template? AIRBRIDGE config? Redirect URL?**
3. Can AIRBRIDGE's attribution be restored? → **Ask DPLAN360 with evidence: 70% of installs had no IDFA (AIRBRIDGE's own probabilistic matching was the engine)**
4. Should nl (Native Logo) be blocked on iOS? → **Yes, per Simon's analysis. 37% spend on worst format.**
5. PA enable: useful for **model optimization** (bid valuation alignment with market T2 = 80-88%), but **will NOT fix AIRBRIDGE attribution**

---

## Session 2026-04-19 → 2026-04-20

### Context
- **Scope:** Full `/investigate` root-cause session for the Mar 20 attribution non-recovery + Apr 3 regime change, then multiple rounds of methodological refinement, report v2 restructuring, stress-testing critiques, and Apps Script deployment.
- **Tables used:** `focal-elf-631.prod_stream_view.pb`, `focal-elf-631.df_accesslog.integration_summary`, `moloco-ae-view.athena.fact_dsp_core`, `moloco-ae-view.athena.fact_dsp_creative`, `moloco-ae-view.athena.fact_dsp_all`, `focal-elf-631.entity_history.prod_entity_history`.
- **Investigation session:** `57f49cb` — 3 iterations, 35 questions, JUDGE_FINAL: PASS.

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|---|---|---|---|
| 1 | Root-cause the sustained non-recovery | `/investigate` 3-iter with A/B/ADV/F/M agents | 4-layer cascade: PIM-2841 baseline + structural fragility + Mar 20 07 UTC cliff + Apr 3 budget cut |
| 2 | Is SKAN a traffic-type fragility factor? | BQ check of `req.ext.skadn.version` vs LAT rate | SKAN is a supply-side framework flag independent of LAT — corrected from earlier framing |
| 3 | Is SoI decoupled from spend? | Daily spend × SoI Pearson correlation, Feb 1–Apr 18 | Decoupled post-Mar 20. Mar 23–27: spend +161% vs Feb baseline ($338/$129.5), SoI at 61% of baseline |
| 4 | Was Apr 3 nl explosion a model reweight or new asset? | creative_id-level KAKAO imp share Feb 1–Apr 18 | NEW creative `IhrxSOh9QzmyZyzv` (group `EVX0myMHmYIGMRgQ`) activated Apr 3 from zero → 60% of KAKAO imp in one day |
| 5 | IPM comparison: new nl vs incumbent ib | Creative-level IPM gap-fill on KAKAO, pre/post Apr 3 | New nl = 0.0121, incumbent ib post-Apr 3 = 0.0196 (nl is 38% worse). Incumbent ib OWN IPM collapsed 82% (0.1096 → 0.0196) on same date |
| 6 | Mar 2 → 3 pb volume 3.5× spike cause | Hourly pb Feb 28–Mar 5 + Moloco spend | External KB install surge (likely marketing push). 79% unattributed on Mar 3 vs 62% on Feb 28. Persists Mar 4–5. Moloco was blacked out — not a backfill dump |
| 7 | Is LAT rate reliable (denominator check)? | Impression-side vs attributed-install-side LAT comparison | Impression-side (n=1.93M): 81% → 24%. Attributed-side (n=35 on Apr 13): 82% → 11%. Directional claim robust; install-side magnitude is noisy |
| 8 | Weekly seasonality contribution to chart volatility | Additive TS decomposition (7-day period, pre-cliff n=48) | Weekly seasonal = 43% of non-trend variance; residual = 57%. Mar 3 residual +1,619 (7× seasonal). Mar 20→21 cliff: 28% explained by Fri→Sat pattern, 72% residual anomaly |
| 9 | Is Mar 20 07 UTC truly unique? | Hourly pb z-score scan across 1,840 transitions | Rank #1 at −4.89σ vs same-hour-of-day baseline — only >60% drop with before-volume >300 in 77-day window |

### Key Findings

1. **Mar 20 07 UTC cliff is upstream of Moloco attribution logic** — the `pb` table row count itself drops −71% (attr −73%, unattr −71%, proportional). AIRBRIDGE is sending 71% fewer postbacks for the KB bundle. Moloco-side code (MM-138, PR #70212) cannot produce this signal. → Client/agency/AIRBRIDGE-side investigation is the only viable path.

2. **Apr 3 is a compound regime change, not a pure model reweight** — budget cut (−50%) + new creative `IhrxSOh9QzmyZyzv` (nl, 1200×600 JPEG) activated same day + incumbent ib `ogMJ5cQEBJ4fNbOw` (1029×258 PNG) displaced from 94% → 25% of KAKAO imp. The new nl creative captured 60% of KAKAO imp in 24h.

3. **Two IPM mechanisms compound post-Apr 3** — new nl is structurally 38% worse than incumbent ib (0.0121 vs 0.0196/1k imp on same post-Apr 3 KAKAO inventory), AND the incumbent ib's own IPM collapsed 82% on the same date. Dropping the new nl creative alone fixes creative-quality gap only — the concurrent KAKAO audience/attribution degradation persists.

4. **Spend-mechanical critique does NOT survive** — Mar 23–27 spend averaged $338/day (+161% vs Feb baseline $129.5) while SoI stayed at 61% of baseline. Spend and SoI visibly decouple at Mar 21 and never re-couple. Apr 3–16 SoI at ~12% of baseline is the compound effect of upstream forwarding break + Apr 3 regime change.

5. **Weekly seasonality accounts for only 43% of chart volatility** — via additive TS decomposition. Mar 3 spike residual = +1,619 (7× Tuesday seasonal effect). Mar 20→21 cliff residual drop = −1,728 of the −2,372 observed drop (72% genuine anomaly, 28% weekly pattern). Chart should be read on 7-day moving averages.

6. **Mar 31 – Apr 1 KST midnight spike is volume-only** — AIRBRIDGE briefly resumed forwarding more postbacks (onset hour 707 pb, 7× normal), but attribution rate stayed at 0.4–3.9%. Onset aligned exactly with KST 00:00 = scheduled/batch signature on MMP/publisher side, not a fix.

7. **Ruled out (code-trace + data-cross-validated):** nrt_resolver, MPID capper, pickByPerformance, tracking_link_auto_standardization, MM-138/PR #70212, vertical-wide AIRBRIDGE outage, AFP-only differential, PIM-2841 as a direct trigger (timing-only).

### Deliverables

- **v2 reports (4 files)** at `~/Documents/Queries/[Tickets]/ODSB-17593/`:
  - `investigation_57f49cb_REPORT_v2.html` (EN, 5-part narrative + TS decomp + spend overlay + creative previews + 121 clickable inline refs)
  - `investigation_57f49cb_REPORT_v2_ko.html` (KO mirror, 123 clickable inline refs)
  - `investigation_57f49cb_REPORT_v2.md` / `_v2_ko.md` (Markdown companions)
- **TS analysis workspace** at `~/Documents/Queries/[Tickets]/ODSB-17593/ts_analysis/`:
  - `daily_pb_spend.csv` — 77-day joined daily series (attr, unattr, total, pct, spend)
  - `decomp_components.csv` — trend / seasonal / residual per day
  - `decompose_simple.py` — additive decomposition reproducer (pandas + numpy)
- **Creative CDN URLs (KAKAO iOS):**
  - New nl `IhrxSOh9QzmyZyzv`: `https://cdn-f.adsmoloco.com/syFnKP76xSYZQcMW/creative/mni9bepx_sqo7bc1_mvvysv3x1erkepfc.jpg`
  - Incumbent ib `ogMJ5cQEBJ4fNbOw`: `https://cdn-f.adsmoloco.com/syFnKP76xSYZQcMW/creative/mmo956nt_l0sktqz_cneoggnewfdr2rja.png`
- **Apps Script web-app**:
  - `apps_script/Code.gs` — Drive-backed router (EN default, `?lang=ko` for KO)
  - `apps_script/appsscript.json` — manifest with Drive readonly scope
  - Drive file IDs: EN `128pd5zS9K7OOSNZcpICpIfJj62UqjVkX`, KO `1yVIdoqmlVNx4q5kguL-ect3kcO0xWF-R`
  - Uses `ScriptApp.getService().getUrl()` to inject absolute switcher URLs so `target="_top"` navigates parent correctly

### Methodology Refinements (applied to v2)

- **iCVR → IPM** — relabeled across all files; IPM is the canonical Moloco metric (installs/imp × 1000).
- **Samsung Securities as primary peer** — Zeta removed from peer set (entertainment vertical, not comparable).
- **Unattributed-only framing** — isolates from spend-driven SoI artifacts.
- **Standalone reporting principle** — no "previous analysis" cross-refs; every section digestible by cold GM reader (saved to memory).
- **Headline metrics reframed around pb volume** — primary trigger location now leads, not SoI %.
- **Recommendations trimmed** — dropped exchange mix (ML-controlled), PIM-2841 confirmation (resolved), Harness audit (low-value); modified budget hold to be conditional on MMP resolution.

### Open Questions

- [ ] Exact Mar 20 07 UTC trigger cannot be identified from Moloco data alone — requires KB/DPLAN360/AIRBRIDGE-side logs. **Top-priority escalation.**
- [ ] What was the client intent behind the new creative group `EVX0myMHmYIGMRgQ`? (open question to Dongkwon)
- [ ] Phase 2 attribution-rate degradation (08–16 UTC Mar 20) — downstream artifact of Phase 1's low denominators, or coincident Moloco-side event? Hard to disentangle at n=26–88/hr.
- [ ] Mar 22 21:00+ partial-recovery signature (rollback/fix?) was not traced.
- [ ] Concurrent external factor degrading incumbent ib IPM −82% on Apr 3 (KAKAO audience shift? budget reallocation to poorer inventory? continued attribution-path degradation?) — not pinned.
- [ ] Samsung Securities TBC dimensions (KPI, tfexample labels, budget, exchange mix, SKAN supply share, LAT rate) — low-priority follow-up for structural fragility benchmarking.

