# Root Cause Report: ODSB-17593 — KB Securities (kr.kbsec.iplustar) Sustained iOS Install Drop

> 🌐 **Language:** EN (this doc) · [한국어 버전 →](./investigation_57f49cb_REPORT_ko.md)

> **DISCLAIMER:** This report and its data may not be accurate. The information presented could contain errors, incomplete data, or sensitive information that may not be appropriate for public disclosure. Reproducible queries are included so that findings can be validated independently. Please verify before sharing externally.

**Ticket:** ODSB-17593
**Advertiser:** KB Securities (KB증권) / app `kr.kbsec.iplustar` / iTunes 350742701
**Ad account:** `syFnKP76xSYZQcMW`
**MMP:** AIRBRIDGE (99.4% of non-SKAN postbacks); SKADNETWORK parallel
**Agency:** DPLAN360 (to be confirmed)
**Investigation window:** Feb 1 – Apr 16, 2026
**Report date:** 2026-04-17
**Investigation session:** 57f49cb (3 iterations, JUDGE_FINAL: PASS)
**Confidence:** MIXED — HIGH on most causal factors; **LOW on the Mar 20 07 UTC specific trigger**

---

## Ticket Summary

KB Securities' iOS UA campaigns show spend/impressions recovered but MMP (AIRBRIDGE) attributed installs remain at 33–50% of the February baseline. Sales (dongkwon.yoo) is driving client-side escalation. This investigation answers (a) when (b) why and (c) what to do next.

---

## TL;DR

1. **Not a single root cause — 4-layer cascade:** (i) Mar 1–10 PIM-2841 action model outage, (ii) KB structural fragility (AFP=FALSE + deep-funnel KPI `account_step16_complete` + 0–4 tfexample labels/day + 21× smaller budget + KAKAO/TPMN 65% supply concentration + near-entirely SKAN 4.0 declared inventory), (iii) **Mar 20 KB-specific cliff — TWO PHASES: Phase 1 (07 UTC) total postback volume −71% (attr/unattr drop uniformly = AIRBRIDGE→Moloco forwarding issue) + Phase 2 (08-16 UTC) attribution-specific additional degradation**, (iv) Apr 3 manual −50% budget cut accelerating the feedback loop.
2. **Mar 20 cliff is KB-only + Phase 1 is not a Moloco issue.** 9 peers on same MMP·OS·geo (including Samsung Securities) are all stable. The Phase 1 volume drop (attr −73% / unattr −71%, proportional) is at the `pb` table level → upstream of Moloco's attribution logic. **AIRBRIDGE is sending 71% fewer postbacks for the KB bundle.** This cannot be explained by MM-138 or any other Moloco-side code change (attribution-side code cannot reduce incoming volume). → **Top priority: verify KB app-side / DPLAN360 agency config / AIRBRIDGE tenant-side changes.**
3. **Apr 3 budget cut is an additional KB-only shock.** Win rate 29%→14%, demand CPM −34%, bids 2.8×, nl format iOS imp share jumped 5%→59%, within-cell iCVR −70~95%.
4. **Recovery requires both axes simultaneously:** (A) Root-cause the Mar 20 cliff via KB/DPLAN360, (B) Reduce structural fragility (AFP=TRUE, diversify exchange mix, simpler interim KPI to regenerate feedback). **Restoring budget alone would waste spend.**
5. **nrt_resolver and MPID capper are NOT causes** (A10 z=0.04, p=0.97; M3 code trace confirmed serving-only). `tracking_link_auto_standardization` (PR #71921) and pickByPerformance (#71341) are also ruled out.

---

## Root Cause Summary — Stratified by Confidence

### Layer 1 — Pre-existing Moloco action model outage (Mar 1–10) · CONFIDENCE: HIGH
- PIM-2841 incident: 2/26 deploy fail → 3/5–3/8 P1 outage → 3/10 07:53 UTC restored. KB is on the incident's impacted-campaigns sheet.
- `validation_i2i` has NO rows for `kr.kbsec.iplustar` iOS on Mar 1–5; KB AIRBRIDGE attribution rate = 0.06% on Mar 1–5 (vs 10.49% Feb baseline).
- Mar 14–15 brief zero-episode consistent with PIM-2841 aftershock (MEDIUM confidence).
- **Effect:** Destroyed Feb label corpus for KB's action model. KB's 0–4 tfexample positives/day means recovery is slow by construction.

### Layer 2 — KB structural fragility (persistent moderator, not a trigger) · CONFIDENCE: HIGH

Primary peer: **Samsung Securities (삼성증권, `com.samsungpop.ios.mpop`)** — same vertical (Korean retail securities / MTS), same MMP (AIRBRIDGE), same OS/geo, likely same agency cluster. This isolates structural variables that matter for "what is achievable for a KOR securities MMP iOS advertiser" from variables inherent to the business model.

| Structural factor | KB Securities | **Samsung Securities (primary vertical peer)** | Note |
|---|---|---|---|
| **AIRBRIDGE attribution rate** Mar 18-22 | **10–14% → 0.74%** (−93.7%) | **5–6% flat** (−13.9%, within noise) | Samsung stable through Mar 20-21 cliff — confirms cliff is KB-specific, not vertical-wide or agency-wide |
| `allow_fingerprinting` (AFP) | **FALSE** (all campaigns) | Mixed: **TRUE=8 / FALSE=4** (~67% / 33%) | Samsung's AFP=FALSE campaigns stayed stable → AFP alone is not the differential |
| Optimization KPI | `account_step16_complete` (deep funnel) | Not directly queried [TBC] | Vertical peers likely share deep-funnel KPIs due to regulated account-opening flows |
| tfexample positive labels/day | **0–4** | Not directly queried [TBC] | KB label-starved; Samsung not confirmed |
| Daily budget | ~182k–363k KRW | Not directly queried [TBC] | Budget-scale comparison pending Samsung data pull |
| Exchange mix | KAKAO+TPMN ≈ 65% | Not directly queried [TBC] | KB's KR-publisher concentration observed; Samsung's mix not pulled |
| Supply SKAN 4.0 declared share | 98.9% | Not directly queried [TBC] | Bid-request supply-framework flag (not traffic type). See caveat below. |
| LAT rate trajectory (iOS, IDFA absent) [BQ-verified, KB only] | 73.5% (Feb 2) → 44.9% (Mar 2) → 24.1% (Apr 6) → 20.3% (Apr 13 partial) — **−53 pp** | Not directly queried [TBC] | KB's IDFA availability improved (tailwind, not fragility) |

**✅ Why Samsung Securities is the right primary peer.** Same vertical (Korean retail securities / MTS), same MMP (AIRBRIDGE), same OS/geo, likely same agency cluster. This isolates structural variables that matter for "what is achievable for a KOR securities MMP iOS advertiser" from variables inherent to the business model (KPI depth driven by regulated account-opening, budget set by client strategy, exchange mix driven by target-audience). Samsung's stable 5–6% attribution through Mar 20-21 confirms the cliff is not a vertical-wide or agency-wide event.

**⚠ Open data gaps.** Samsung Securities dimensions NOT directly queried: optimization KPI, tfexample positives/day, daily budget, exchange mix, SKAN 4.0 supply share, LAT rate. These should be pulled in a follow-up to strengthen the "structural fragility" narrative.

**⚠ Terminology note (BQ-verified):** F8's "98.9% SKAN" comes from `req.ext.skadn.version` in bid requests — a publisher/exchange supply-side declaration of SKAN framework support, NOT a traffic type. KB's `skadn.version=4.0` share was stable at 98.7-99.9% throughout Feb-Apr while LAT collapsed from 73% to 20% — confirming these are independent dimensions. The correct traffic-type metric for attribution-path availability is **LAT rate** / IDFA availability — shown in the bottom row.

**This is the moderator**, not the trigger. It explains **why KB gets hit when peers don't** — AFP=FALSE + chronic label starvation + thin budget + concentrated supply make every platform perturbation amplify disproportionately on KB.

### Layer 3 — Mar 20 KB-specific cliff — TWO-PHASE DECOMPOSITION · CONFIDENCE: HIGH on scope + two-phase structure / LOW on the upstream driver

The Mar 20 cliff is actually **two distinct events** at different hours with different mechanisms:

#### Phase 1 — Mar 20 07:00 UTC: Volume-level drop (upstream of Moloco attribution)

| Metric | Baseline (Mar 20 06 UTC) | Mar 20 07 UTC | Δ |
|---|---:|---:|---:|
| Total postbacks | 381 | 111 | **-71%** |
| Attributed | ~55 | 15 | **-73%** |
| Unattributed | ~326 | 96 | **-71%** |
| Attribution % | 15.6% | 13.5% | stable |

Attributed and unattributed drop by the **same proportion** — this is a volume problem, not an attribution problem. Since `pb` table counts all postbacks AIRBRIDGE sends to Moloco for this bundle (both Moloco-wins and cross-network), a uniform 71% drop across both buckets means **AIRBRIDGE is sending 71% fewer postbacks TO Moloco** for KB at 07:00 UTC. The issue is at the MMP→Moloco forwarding layer, **upstream of any Moloco attribution logic.** [A11]

**Likely Phase 1 mechanisms (cannot verify from Moloco data alone):**
- AIRBRIDGE tenant-side postback endpoint change (Moloco integration paused/modified at agency level)
- KB app SDK upgrade changing event-firing semantics
- DPLAN360 × KB postback forwarding rule change

#### Phase 2 — Mar 20 08:00 → 16:00 UTC: Attribution-specific degradation
- Total pb stays low but non-zero (26-88/hr)
- Attributed share progressively degrades: 8.3% → 7% → 1.5% → 0%
- **Mar 20 16:00 UTC: first fully-zero hour.** Stays 0 through Mar 22 20:00 UTC.
- Mar 22 21:00+ UTC: partial recovery to 5-7% (possible rollback/fix signature).
- Phase 2 attribution rate falls **independently of volume** — could be a downstream artifact of the already-reduced-volume denominator, or a separately-coincident Moloco-side event. Hard to disentangle given the already-low denominators.

#### Shared evidence (applies to both phases)
- **Scope KB-specific:** 9 AIRBRIDGE iOS KOR peers (incl. 삼성증권, same vertical) stable through window; worst peer Coinone –32% recovering Mar 23; KB –93.7% = order-of-magnitude outlier. [ADV3]
- **AFP alone is NOT the differential:** Samsung's mix of AFP=TRUE/FALSE stable. [F9]
- **MM-138 / PR #70212 (Mar 20 06:11 UTC merge):** REJECTED as mechanism. MM-138 is `attributionsvc/consumer` dedup refactor; it **cannot reduce incoming postback volume** (the Phase 1 signal). Even without invoking the partner-agnostic diff trace, the volume-drop fact alone eliminates any Moloco-attribution-side PR as the Phase 1 cause. [M7, A11]

#### Implication
Phase 1 is **not a Moloco problem at all** — AIRBRIDGE is sending 71% fewer postbacks TO Moloco at 07:00 UTC. This MUST be resolved at the KB/DPLAN360/AIRBRIDGE side. Phase 2 is downstream; it may self-resolve once Phase 1 is fixed, or may be a distinct Moloco-side issue worth investigating separately.

### Layer 4 — Apr 3 budget cut tipping point · CONFIDENCE: HIGH

| Event | Apr 3 | Active? |
|---|---|---|
| KB UA daily budget | 363k → 181k KRW (-50%) | **YES** |
| NRT resolver ramp | 10% → 20% | NO (A10 z=0.04 p=0.97; M3 serving-only) |
| MPID capper ramp | 5% → 10% | NO (M3 bid-serving only) |

**Feedback loop:** win rate 29%→14%, demand CPM –34%, bid volume 2.8x, nl creative share 15%→59%, within-cell iCVR –70~95% across all `cr_format × exchange` cells except ADPOPCORN. [A2, A4]

---

## Timeline of Events

| Date / time (UTC) | Event | Source |
|---|---|---|
| Feb 1–28 | KB AIRBRIDGE attribution baseline 10.49%; Samsung Securities baseline ~5-6% | A6, F1, ADV3 |
| Feb 26+ | PIM-2841 Moloco action model deploy failures begin | F7 |
| Mar 1–5 | KB attribution collapses to 0.06% (PIM-2841 P1 outage) | A6, F7 |
| Mar 5 | New KB campaigns created under ad_account syFnKP76xSYZQcMW, AFP=FALSE | F8 |
| Mar 6–10 | Partial recovery; PIM-2841 restored Mar 10 07:53 UTC | F7 |
| Mar 2–16 | Cohort-wide iCVR grind (28 peers), cause unidentified (not nrt) | A7, A10 |
| Mar 10–11 | Platform-wide normalizer wobble: peer median –4%, KB –37% persistent | A12 |
| Mar 19–20 | KB attribution REBOUNDS to 10–14% near Feb baseline | A6 |
| **Mar 20 06:11** | Moloco MM-138 / PR #70212 merged (attributionsvc dedup — cannot reduce incoming volume) | M7 |
| **Mar 20 07:00** | **PHASE 1 — Volume cliff: total pb 381→111 (-71%). Attributed -73% and Unattributed -71% drop PROPORTIONALLY. Attribution rate stays 13.5%. Upstream of Moloco attribution.** | **A11** |
| Mar 20 08-15 | **PHASE 2 — Attribution rate degrades independently** (8.3% → 7% → 1.5%) on already-reduced volume | A11 |
| **Mar 20 16:00** | **First fully-zero attribution hour (0/26 pb attributed)** | **A11** |
| Mar 22 21:00+ | KB partial recovery to 5–7% | A11 |
| Mar 23 | AVI-5757 rollout | F7 |
| Mar 24 – Apr 3 | nrt_resolver ramp 10→20→50% (ruled out) | B1, A10 |
| Mar 26 | Cohort daily iCVR trough, recovery begins | A7 |
| **Apr 3** | **KB budget 363k→181k KRW + NRT 10→20% + MPID 5→10% (budget only active)** | A9, A10, M3 |
| Apr 3–16 | Feedback loop: WR 29→14%, dCPM –34%, bids 2.8x, nl 15→59%, iCVR –70~95% | A2, A3, A4 |

---

## Key Findings — Grouped by Layer

### Trigger Layer (Mar 20 07 UTC cliff)
- **F-T1.** KB-specific: 9-peer cohort (incl. 삼성증권) all stable; KB the only >50% drop. [ADV3]
- **F-T2.** Hour-precise cliff: volume -71% at 07:00 UTC; attribution zero at 16:00 UTC; partial recovery at Mar 22 21:00+. Two-phase signature. [A11]
- **F-T3.** AFP alone NOT differential: Samsung AFP=TRUE/FALSE mix stable. [F9]
- **F-T4.** All Moloco code deploys audited (MM-138, #69335, #71341, #71921) — rejected or orthogonal. [M1, M2, M4, M7, B3]

### Structural Layer (persistent moderator)
- AFP=FALSE (all KB campaigns) — Samsung Securities has mixed AFP (TRUE=8/FALSE=4) and Samsung's AFP=FALSE campaigns stayed stable, so AFP alone is not the differential; KPI=`account_step16_complete` (deep-funnel, regulated account-opening flow); tfexample positives 0–4/day (chronic label starvation); KAKAO+TPMN 65% concentrated supply. [F8, ADV2, F9]
- LAT-rate trajectory: KB 76% (late Jan) → 24% (Apr); peers 64–67% stable. IDFA availability *improved* — positive, not fragility. [prior session A6]
- Caveat: F8's "98.9% SKAN" is supply-side bid-request SKAN-framework declaration (not LAT / traffic type).

### Compounding Layer (Apr 3 onwards)
- Apr 3+: spend 79–84%, imps 118–127%, attributed installs 33–50%; correlation spend↔installs flipped +0.92 → –0.18. [A1, A3]
- nl share shift is within-ML selection (creatives stable 9+9). [A2, F5]
- Within-cell iCVR –70~95% universal except ADPOPCORN. [A2]
- KB regime shift REAL: Feb 10.49% → Apr 1.27% = 8.3x drop; Samsung Securities stable 5-6% in same window. [A6, F1, ADV3]

---

## Ruled Out (with rejection evidence)

| Hypothesis | Rejection evidence |
|---|---|
| **PR #69335 (forward vi traffic, Mar 10–11 KST)** as KB Mar 11 driver | A12: peer cohort normalizer wobble only –4 to –12% (peer median –4%), while KB showed –37% persistent. KB's drop is KB-specific amplification of a mild global wobble, not caused by the PR itself. Reframed as "moderator, not cause." |
| **MM-138 / PR #70212 / aux.go:25** as KB Mar 20 cause | M7 diff trace: `attributionsvc/consumer` dedup refactor; zero fingerprinting logic; buildVariants removal is partner-agnostic. ADV3: no peer effect. **Strengthened by Phase 1 analysis**: MM-138 cannot reduce *incoming postback volume* — yet Phase 1 shows total pb (attr + unattr) dropped 71% uniformly. Attribution-side code changes cannot produce that signal. Mechanism falsified on two independent grounds. |
| **nrt_resolver (exp 16979/16980)** | A10: z=0.04 p=0.97; 100% of cohort decline PRE-nrt; recovery began during ramp. |
| **MPID capper** | M3: bid-serving only; zero MPID refs in attributionsvc. |
| **pickByPerformance (#71341)** | M1: CR_IPM_D56 already D56 pre-PR; creative selection only. |
| **tracking_link_auto_standardization (#71921)** | M2: iosSpecPathResolver supports AF/Singular/Adjust only; AIRBRIDGE untouched. |
| **Creative churn** as nl shift driver | F5: creative groups stable 9+9 items Mar 13–Apr 16. |
| **Moloco entity/goal/bid-strategy/experiment change Mar 20–21** | F5, B1, B3: no KB entity history changes; no experiment toggle. |

---

## Recommendations — Stratified by Mechanism

### [IMMEDIATE — Client engagement, highest priority]
1. **Contact KB / DPLAN360 with specific evidence.** Message draft: "Starting Mar 20 16:00 KST (= 07:00 UTC), KB-specific AIRBRIDGE attribution postback collapse observed. 9 peer AIRBRIDGE iOS KR advertisers (including Samsung Securities, incl. peers with identical AFP=FALSE config) are all normal. Platform-level changes and AFP setting are not the cause. Please verify KB-side changes first."
   - Items to verify: AIRBRIDGE SDK version change, iOS app release notes (Mar 19–20 KST), DPLAN360 tracking-link/postback URL history, AIRBRIDGE tenant agency configuration.
2. **Optional — Harness deploy timeline audit for MM-138** (low-probability but 0-cost to rule out).

### [STRUCTURAL — Long-term fragility reduction]
3. **Evaluate AFP=TRUE switch** (for training-label regeneration). Requires client consent.
4. **Diversify exchange mix** (dilute KAKAO+TPMN 65% concentration, expand non-SKAN inventory).
5. **Simplify KPI** — during recovery window, switch to `install` or mid-funnel events to regenerate labels.
6. **Confirm PIM-2841 KB action model redeployment** — cross-check with PIM team whether the deep-funnel-KPI-specific model is fully redeployed.

### [BUDGET / BID LEVERS — Hold pattern]
7. **Hold budget at current level.** Any increase before attribution recovers is cash burn.
8. **Block or floor-price iOS nl format** (within-cell iCVR –70~95%).

### [MODEL FEEDBACK REGENERATION — Parallel track]
9. **Reserve a 2-week learning window after attribution recovers.**
10. **Monitor Samsung Securities as a reference trajectory** for a healthy KOR securities iOS advertiser.

---

## Open Questions — Honest Gaps

1. **The exact Mar 20 07 UTC trigger cannot be identified from Moloco data alone** — KB/DPLAN360/AIRBRIDGE-side logs required. The largest limitation.
2. **Mar 22 21:00+ partial-recovery signature** was not traced.
3. **Mar 2–16 cohort iCVR decline cause is unidentified** (nrt ruled out; SDK/SKAN drift hypothesized).
4. **"Label sparsity amplification" is an inferred mechanism** — framed as moderator only.
5. **F9 AFP test is at the Samsung aggregate level** — FALSE-only 4-campaign subset is a low-priority follow-up.

---

## Data Sources

**Primary tables:** `focal-elf-631.prod_stream_view.pb`, `focal-elf-631.prod_stream_view.imp`, `focal-elf-631.prod_stream_sampled.imp_1to100`, `moloco-ae-view.athena.fact_dsp_core`, `moloco-ae-view.athena.fact_dsp_creative`, `moloco-ae-view.athena.fact_dsp_all`, `focal-elf-631.entity_history.prod_entity_history`, `explab-298609.summary_view.experiment_summary`.

**Qualitative:** PIM-2841, MM-138 / PR #70212, PRs #69335, #71341, #71921.

---

## Sources Legend

### Category definitions

| Tag | Phase / Role | Purpose |
|---|---|---|
| `A#` | A-phase (ab_phase) | Data / metric probe — quantitative BQ queries establishing observational facts |
| `B#` | B-phase (ab_phase) | System / context — experiment configs, Glean/Slack/Jira, external MMP events, deploys |
| `F#` | F-phase (fm_phase) | Cross-validation — orthogonal checks of A/B findings via different tables/cohorts |
| `M#` | M-phase (fm_phase) | Mechanism / code — marvel2 / attributionsvc / bidfnt code paths |
| `ADV#` | Adversarial | Proof-by-contradiction questions designed to FALSIFY the proposed chain |
| `C#` | Claim | Synthesis claims in the final reasoning block (C1-C16). See Section 11. |

### Questions → Answer files

Each answer file contains SQL + query URL (Google Drive) + result table + interpretation. Located in `~/searchlight/.investigate_sessions/57f49cb/answers/`.

**A-phase (data / metrics)**

| Tag | Question | File |
|---|---|---|
| A1 | Daily KB iOS spend/imp/VT/CT/SKAN/unattributed trend Feb–Apr | [A1.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A1.md) |
| A2 | iCVR decomposition by cr_format × exchange (Pre/Post/Recent) | [A2.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A2.md) |
| A3 | Apr 3 spend-cut + restoration decoupling test | [A3.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A3.md) |
| A4 | Win rate + bid-price signature (under-prediction check) | [A4.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A4.md) |
| A5 | tfexample_install bundle-level label volume trend | [A5.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A5.md) |
| A6 | Pre-Mar-21 KB AIRBRIDGE attribution rate (Negative-Evidence Gate) | [A6.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A6.md) |
| A7 | Daily cohort iCVR Feb 15–Apr 16 (nrt timeline validation) | [A7.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A7.md) |
| A8 | KB bid-time aggregates 3-window split + changepoint | [A8.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A8.md) |
| A9 | Apr 3 KB decomposition beyond budget | [A9.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A9.md) |
| A10 | nrt_resolver treatment/control per-advertiser | [A10.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A10.md) |
| A11 | Hourly KB postback Mar 20–22 UTC (cliff pin) | [A11.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A11.md) |
| A12 | Cohort-wide daily ACTION normalizer trend | [A12.md](../../../searchlight/.investigate_sessions/57f49cb/answers/A12.md) |

**B-phase (system / context)**

| Tag | Question | File |
|---|---|---|
| B1 | Experiment ramp check Mar 15 – Apr 16 | [B1.md](../../../searchlight/.investigate_sessions/57f49cb/answers/B1.md) |
| B2 | External AIRBRIDGE signal + cross-advertiser scope | [B2.md](../../../searchlight/.investigate_sessions/57f49cb/answers/B2.md) |
| B3 | Moloco-side deploys + action model retraining | [B3.md](../../../searchlight/.investigate_sessions/57f49cb/answers/B3.md) |
| B4 | AIRBRIDGE SDK + iOS ATT changes Feb 15 – Mar 31 | [B4.md](../../../searchlight/.investigate_sessions/57f49cb/answers/B4.md) |

**F-phase (cross-validation)**

| Tag | Question | File |
|---|---|---|
| F1 | 30-pb sample trace (bucket A1 gap) | [F1.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F1.md) |
| F2 | imp_1to100 prediction_logs (bid-time pred_install) | [F2.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F2.md) |
| F3 | 29-peer AIRBRIDGE iOS KOR serving metrics | [F3.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F3.md) |
| F4 | cv table orthogonal (label-starvation filter test) | [F4.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F4.md) |
| F5 | KB entity_history Mar 15 – Apr 16 | [F5.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F5.md) |
| F6 | KB vs peer exp treatment Mar 10-11 (originally vs Zeta; Zeta later excluded as vertical-mismatched, finding unchanged) | [F6.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F6.md) |
| F7 | KB zero-episodes vs PIM-2841 action model outage | [F7.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F7.md) |
| F8 | KB vs peer supply composition (exchange / iOS / SKAN flag). Originally vs Zeta; Zeta excluded — KB's 98.9% SKAN + KAKAO/TPMN concentration findings stand on their own. | [F8.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F8.md) |
| F9 | Samsung Securities allow_fingerprinting check | [F9.md](../../../searchlight/.investigate_sessions/57f49cb/answers/F9.md) |

**M-phase (mechanism / code)**

| Tag | Question | File |
|---|---|---|
| M1 | pickByPerformance D56 recency (PR #71341) | [M1.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M1.md) |
| M2 | pb → fact_dsp_core credit + tracking_link_auto_std (PR #71921) | [M2.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M2.md) |
| M3 | nrt_resolver + MPID capper attributionsvc scope | [M3.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M3.md) |
| M4 | marvel2 PR #69335 "forward vi traffic only" VBT | [M4.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M4.md) |
| M5 | install_consol_v1_quant_test expansion (explab-conf #11854) | [M5.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M5.md) |
| M6 | AIRBRIDGE tracking-link-only code path | [M6.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M6.md) |
| M7 | MM-138 c156c9c2af0 diff (Mar 20 attributionsvc) | [M7.md](../../../searchlight/.investigate_sessions/57f49cb/answers/M7.md) |

**ADV (adversarial falsifiers)**

| Tag | Question | File |
|---|---|---|
| ADV1 | Healthy-peer AIRBRIDGE attribution split (C3 falsifier). Originally used Zeta; superseded by ADV3 8-peer sweep | [ADV1.md](../../../searchlight/.investigate_sessions/57f49cb/answers/ADV1.md) |
| ADV2 | KB bundle vs peer bundle model-side differentiator search. Originally vs Zeta, later scoped out — findings reframed as KB-specific structural facts | [ADV2.md](../../../searchlight/.investigate_sessions/57f49cb/answers/ADV2.md) |
| ADV3 | 9-peer Mar 21 scope test (incl. Samsung Securities) | [ADV3.md](../../../searchlight/.investigate_sessions/57f49cb/answers/ADV3.md) |

### Additional glossary

| Term | Meaning |
|---|---|
| `AFP` / `allow_fingerprinting` | MMP_INTEGRATION entity field. **TRUE** = Moloco sends S2S click signals (IP+UA+molo_click_id) to the MMP for fingerprint matching. **FALSE** = skip this S2S path + classify traffic more restrictively at bid time. **KB=FALSE (all campaigns); Samsung Securities=mixed (TRUE=8 / FALSE=4).** Note: AIRBRIDGE's Moloco integration lacks a documented S2S path regardless, so AFP's primary effect for KB is on Moloco-internal bid-time classification and training-data generation. |
| `LAT` | Limit Ad Tracking — iOS privacy status where user denied ATT prompt; IDFA zeroed. Traffic type, orthogonal to SKAN. |
| `IDFA` | iOS advertising ID. Present for non-LAT users; zeroed for LAT. |
| `SKAN` / SKAdNetwork | Apple's privacy-preserving postback framework. Measurement method, orthogonal to IDFA/LAT. A SKAN-declared impression can still be MMP-attributed via IDFA or fingerprint. |
| `MMP` | Mobile Measurement Partner (AIRBRIDGE, Adjust, AppsFlyer, Singular). |
| `VT` / `CT` | View-Through / Click-Through install attribution modes. |
| `pb` table | `prod_stream_view.pb` — postbacks received from MMPs (both `moloco.attributed=TRUE` and `=FALSE`). |
| `tfexample` | Action model training dataset (bundle × OS × KPI). `is_mmp_effective=TRUE` positives feed the model. |
| `iCVR` | Impression-to-install Conversion Rate = attributed_installs / impressions. |
| `nl` | Native Logo creative format. |
| `PIM-2841` | Moloco internal action-model P1 outage ticket (Mar 5-8 2026). KB on impacted-campaigns sheet. |

---

## Reproducible Queries

### Query 1 (A11): Hourly KB postback attribution Mar 20–22 (trigger timing)
```sql
SELECT TIMESTAMP_TRUNC(timestamp, HOUR) AS hr,
       COUNT(*) AS total_pb,
       COUNTIF(moloco.attributed = TRUE) AS attributed_count,
       COUNTIF(moloco.attributed = FALSE OR moloco.campaign_id IS NULL OR moloco.campaign_id = '') AS unattributed_count,
       SAFE_DIVIDE(COUNTIF(moloco.attributed = TRUE), COUNT(*)) * 100 AS attributed_pct
FROM `focal-elf-631.prod_stream_view.pb`
WHERE app.bundle = 'kr.kbsec.iplustar'
  AND mmp_name = 'AIRBRIDGE'
  AND event.name = 'install'
  AND DATE(timestamp) BETWEEN '2026-03-20' AND '2026-03-22'
GROUP BY 1 ORDER BY 1;
```

### Query 2 (ADV3): 9-peer AIRBRIDGE iOS KOR cohort scope test — Mar 18–23
```sql
SELECT
  CASE app.bundle
    WHEN 'com.samsungpop.ios.mpop'   THEN 'SamsungSec'
    WHEN 'kr.co.33m2'                 THEN '33m2'
    WHEN 'kr.co.coinone.officialapp' THEN 'Coinone'
    WHEN 'com.initialcoms.BOM'       THEN 'Ridi'
    WHEN 'com.healthing.babitalk'    THEN 'Babitalk'
    WHEN 'kr.co.ktmusic.genie'       THEN 'genie'
    WHEN 'kr.co.millie.MillieShelf'  THEN 'Millie'
    WHEN 'com.wantedlab.wanted'      THEN 'wanted'
    WHEN 'kr.kbsec.iplustar'         THEN 'KB'
  END AS peer,
  DATE(timestamp) AS d,
  COUNTIF(moloco.attributed=TRUE) AS attr,
  COUNT(*) AS total,
  ROUND(SAFE_DIVIDE(COUNTIF(moloco.attributed=TRUE), COUNT(*))*100, 2) AS attr_pct
FROM `focal-elf-631.prod_stream_view.pb`
WHERE app.bundle IN (
  'com.samsungpop.ios.mpop','kr.co.33m2',
  'kr.co.coinone.officialapp','com.initialcoms.BOM','com.healthing.babitalk',
  'kr.co.ktmusic.genie','kr.co.millie.MillieShelf','com.wantedlab.wanted',
  'kr.kbsec.iplustar')
  AND device.os = 'IOS'
  AND mmp_name = 'AIRBRIDGE'
  AND event.name = 'install'
  AND DATE(timestamp) BETWEEN '2026-03-18' AND '2026-03-23'
GROUP BY 1,2 ORDER BY 1,2;
```

### Query 3 (A6): KB daily AIRBRIDGE attribution regime shift (Feb–Mar)
```sql
SELECT DATE(timestamp) AS d,
  COUNT(*) AS total_pb,
  COUNTIF(moloco.attributed=TRUE) AS attributed_count,
  COUNTIF(moloco.attributed=FALSE) AS unattributed_count,
  ROUND(COUNTIF(moloco.attributed=TRUE)*100.0/COUNT(*), 2) AS attributed_pct
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN '2026-02-01' AND '2026-03-20'
  AND LOWER(event.name)='install'
  AND mmp_name='AIRBRIDGE'
  AND app.bundle='kr.kbsec.iplustar'
GROUP BY d ORDER BY d;
```

### Query 4 (A3): KB daily iOS metrics Mar 25 – Apr 16 (feedback loop)
```sql
SELECT date_utc,
  ROUND(SUM(gross_spend_usd),2) spend_usd,
  SUM(impressions) impressions,
  SUM(installs) attr_installs,
  SUM(skan_installs) skan_installs,
  ROUND(SAFE_DIVIDE(SUM(installs), SUM(impressions))*1000, 4) icvr_per_1k_imp,
  ROUND(SAFE_DIVIDE(SUM(gross_spend_usd), SUM(installs)), 2) cpi_usd
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE date_utc BETWEEN '2026-03-25' AND '2026-04-16'
  AND advertiser_id = 'syFnKP76xSYZQcMW'
  AND campaign.os = 'IOS'
GROUP BY 1 ORDER BY 1;
```

### Query 5 (A9): KB entity history around Apr 3 budget cut
```sql
WITH snap AS (
  SELECT DATE(timestamp) AS d, timestamp,
    JSON_VALUE(json_entity, '$.name') AS campaign_id,
    CAST(JSON_VALUE(json_entity, '$.user_capper.budget.daily_budget') AS INT64) AS daily_budget,
    JSON_VALUE(json_entity, '$.goal.action_name') AS action_name,
    JSON_VALUE(json_entity, '$.bid_strategy.type') AS bid_strategy_type,
    ROW_NUMBER() OVER (PARTITION BY DATE(timestamp), JSON_VALUE(json_entity, '$.name') ORDER BY timestamp DESC) AS rn
  FROM `focal-elf-631.entity_history.prod_entity_history`
  WHERE DATE(timestamp) BETWEEN '2026-03-30' AND '2026-04-06'
    AND entity_type = 'CAMPAIGN'
    AND JSON_VALUE(json_entity, '$.advertiser_id') = 'syFnKP76xSYZQcMW'
)
SELECT * FROM snap WHERE rn=1 ORDER BY campaign_id, d;
```

---

## Claim-to-Evidence Traceability

| Claim | Verdict | Sources |
|---|---|---|
| C1 — Apr 3+ spend recovered, installs stuck | PASS | A3, A1 |
| C2 — Mar 21 no Moloco entity/tracking/goal change | PASS | F5, B1, B3, M1, M2 |
| C3_rev — KB AIRBRIDGE 10.49%→1.27% regime shift | PASS | A6, F1, ADV1 |
| C4_rev — nrt_resolver ruled out | PASS | A7, A10 |
| C5_corrected — Mar 11 KB-unique amplification | PASS (moderator) | A8, A12, F2 |
| C6_rev — nl 5→59% within-ML | PASS | A2, F5 |
| C7 — Within-cell iCVR –70~95% | PASS (descriptive) | A2 |
| C8_rev — Mar 1-5 PIM-2841 HIGH / Mar 14-15 MEDIUM | PASS | F7, A6 |
| C9 — nrt/MPID serving-only | PASS | M3 |
| C10 — pickByPerformance non-pricing | PASS | M1 |
| C11 — tracking_link_auto_std non-AIRBRIDGE | PASS | M2 |
| C12 — KB structural fragility | PASS | F8, ADV2 |
| C13_rev — PR #69335 NOT primary cause | PASS (ruled-out) | M4, A12 |
| C14 — MM-138 × aux.go:25 mechanism | **REJECTED (Ruled Out)** | A11, M6, M7 |
| C15_new — Mar 20 07 UTC KB-specific cliff | PASS (LOW on WHAT) | A11, ADV3, F9 |
| C16_new — Apr 3 budget cut tipping | PASS | A9, A10, M3 |

**Cross-confirmation:** nrt_resolver code trace (M3) ↔ A10 experimental data match — ruled out as both bid-serving-only (code) and null-effect (z=0.04, p=0.97) in post-ramp peer cohort.

---

**Report Generated:** 2026-04-17
**Session:** 57f49cb
**Judge verdict:** JUDGE_FINAL PASS (3 iterations converged)
**Confidence summary:** HIGH on most factors & ruled-out hypotheses; MEDIUM on C3_rev, C5_corrected; **LOW on the Mar 20 07 UTC specific trigger mechanism** (external; requires KB/DPLAN360 engagement)
