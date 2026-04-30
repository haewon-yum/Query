# 7DS: Origin — KOR Performance Investigation Insights

**Ticket:** [ODSB-17637](https://mlc.atlassian.net/browse/ODSB-17637)
**Advertiser:** Netmarble
**App:** The Seven Deadly Sins: Origin (`일곱 개의 대죄: 오리진`)
**Bundles:** Android `com.netmarble.nanaori` · iOS `6744205088`
**Investigation started:** 2026-04-14
**Report:** `260414_7DS_origin_investigation_report.html`
**Notebook:** `260409_7DS_origin_performance_investigation.ipynb`

---

## Session 2026-04-16 (previous session — reconstructed from context)

### Context
- **Scope:** Full KOR performance investigation — CPA vs ROAS campaign structure, ROAS campaign cold-start diagnosis, ML model metrics, creative/exchange performance
- **Tables used:** `moloco-data-prod.younghan.spending_summary`, `fact_dsp_creative`, `fact_dsp_publisher`, `moloco-dsp-data-view.postback.pb`, `focal-elf-631.prod_stream_sampled.pricing_1to100`

### Process & Hypotheses
| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Why is ROAS campaign (iyH1) cold-starting? | Query `spending_summary` for daily normalizer/pred trend | A2R normalizer frozen at 15.243, a2r_pred $12.61–12.89/install vs actual $0.58 → 21× overestimate |
| 2 | Is the pred calibrator active? | Code review of `closure.go` + `ml_pred_calibrator_generation/query.py` | HISTORY_AOP_CALIBRATOR_ACTIVATION_WINDOW=15 is gated on `tKpi > 0` — does NOT apply to OPTIMIZE_ROAS campaigns. Calibrator is irrelevant. |
| 3 | Is the revenue model being adapted? | Checked `revenue_a2r_consol_v1` deployment, context_revision=1775710817 | No redeployment Apr 6–13. Weekly retrain cycle → D7 labels for Apr 6 cohort available ~Apr 13–15; target retrain window ~Apr 14–21 |
| 4 | What is TCM doing? | Daily TCM from `spending_summary` | TCM rose 1.34→8.58 (Apr 6→12) — budget pacing distress signal, not a quality signal. Cannot close calibration gap. |
| 5 | Action model degradation? | core_pred trend from `spending_summary` | core_pred declined 9.21e-5→5.16e-5 (Apr 6→13) — model becoming more selective. pred/normalizer ratio halved 0.295→0.137. |
| 6 | validation_a2r_online accessible? | Attempted BQ query on `moloco-data-prod.younghan` | Not in dataset — not accessible from current credentials. Used `spending_summary` instead. |

### Key Findings
1. **A2R model 21× cold-start overestimate** — `a2r_pred` ranged $12.61–12.89/install (Apr 6–13) vs actual D7 revenue/install $0.58 ($65.02 total / 113 installs). Source: `spending_summary`. Implication: Model is bidding at portfolio-average revenue assumptions with no 7DS-specific calibration.
2. **A2R normalizer frozen at 15.243** — Zero variance across all 8 days (p1=p99=AVG=15.2429). Static training-time anchor baked into TFServing StaticHashTable. Implication: No runtime adaptation possible — only full retrain updates this.
3. **TCM inflation (1.34→8.58×) is a symptom, not a cause** — TCM escalated because model cannot generate competitive bids naturally. The wrapper_normalizer (0.012–0.034) incorporates TCM but cannot close the 21× fundamental calibration gap.
4. **Pred calibrator is NOT applicable** — HISTORY_AOP_CALIBRATOR_ACTIVATION_WINDOW=15 is gated on `tKpi > 0` in `closure.go`. 7DS iyH1 is `OPTIMIZE_ROAS_FOR_APP_UA` with no tKPI. All earlier analysis referencing "Apr 21 pred calibrator activation" was incorrect.
5. **Weekly retrain window ~Apr 14–21** — D7 labels for the Apr 6 install cohort became available ~Apr 13–15. First campaign-adapted retrain incorporating 7DS data expected this window.
6. **login_1st (SDK) vs login_1st_s2s gap** — ~50× volume gap: SDK ~260K/day vs S2S ~5–6K/day. Source: postback table. S2S is the KPI event for tROAS campaign; SDK installs not being attributed back to Moloco.
7. **NHN exchange issue** — 31% of ROAS spend, $217 CPI, zero D7 revenue. Identified as priority action item.

### Open Questions
- [ ] Has the weekly retrain (~Apr 14–21) completed? Did a2r_pred shift after retrain?
- [ ] Did wrapper_normalizer stabilize post-retrain (TCM should drop if calibration improves)?
- [ ] Is login_1st_s2s volume growing — are more S2S events being attributed?
- [ ] NHN blacklist action taken?
- [ ] iOS campaign (IZwbLesdV2Nj4YEy) — why paused? Budget decision or performance?

---

## Session 2026-04-22

### Context
- **Scope:** HTML report finalization (framework tree update, nav fix), model concept clarification, Stonekey iOS campaign status check
- **Tables used:** None (HTML editing + Speedboat MCP + conceptual Q&A)
- **Report file:** `260414_7DS_origin_investigation_report.html` (2.30 MB)

### Process & Hypotheses
| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Nav sidebar "0. Analysis Framework" out of order | Read nav HTML, reorder the anchor tag | Fixed — moved to immediately after Executive Summary in nav |
| 2 | User wanted KOR Performance restructured per handwritten diagram | Misread intent — restructured actual HTML sections | Rolled back from bak2 backup; user clarified: update only the `s-framework` visualization, not content sections |
| 3 | Update framework tree under KOR Performance node | Replace subtree below `② KOR Performance` node only | New tree: Moloco (Overall → Android/iOS/Format×Exchange; Campaign-level → CPA Sec3 / ROAS Sec4) + Comparative (User Quality 2c·2d). Kept root, Account Context, Other Geo, GM Questions, Action Items nodes intact |
| 4 | A2R normalizer vs Wrapper normalizer — what's the difference? | Conceptual explanation from model architecture | See Key Findings below |
| 5 | Stonekey iOS campaign status | Speedboat MCP `resolve_moloco_entity` + `get_campaign_setting` | Found 2 iOS campaigns; 1 active (PAUSED), 1 archived |

### Key Findings
1. **HTML framework tree updated** — `s-framework` section now shows the Moloco/Comparative branching structure per the handwritten diagram. Each node links to correct section anchor. Content sections (2, 3, 4, 5, 6) untouched. File: `260414_7DS_origin_investigation_report.html`.

2. **A2R normalizer vs Wrapper normalizer distinction** (conceptual):
   - `a2r_normalizer` (15.243): **Static training-time anchor** baked into TFServing model. Represents portfolio-average expected revenue per payer. Only changes on full model retrain. Zero runtime variability.
   - `wrapper_normalizer` (0.012–0.034): **Runtime bid multiplier**. Formula: `bid = core_pred × wrapper_normalizer`. Incorporates a2r_pred/a2r_normalizer ratio × TCM × bid scaling. Dynamic — changes daily as TCM changes. Low values (0.012–0.034) reflect both the calibration gap and TCM adjustment.
   - Key: a2r_normalizer is the "world view anchor"; wrapper_normalizer is what actually drives bids in the auction.

3. **Stonekey iOS campaign status** (via Speedboat MCP):
   - `IZwbLesdV2Nj4YEy` — KOR iOS tROAS (`login_1st`), $690/day budget, launched 2026-04-13, currently **PAUSED**. Target ROAS = 0 (may need verification). 2 creative groups active.
   - `NfJv2tV88zR9CJdJ` — HK iOS AEO (`login`), $730/day, launched 2025-07-21, **ARCHIVED**.
   - Only the KOR tROAS campaign is non-archived. Its PAUSED state warrants investigation — launched Apr 13, only 1 week old.

### Open Questions
- [ ] Why is Stonekey KOR iOS tROAS campaign (`IZwbLesdV2Nj4YEy`) PAUSED? Budget decision by Netmarble or Moloco action?
- [ ] Target ROAS = 0 for Stonekey iOS — is this correct config or a missing setup?
- [ ] 7DS Origin ROAS campaign iyH1 — has the Apr 14–21 retrain window resolved the calibration gap? Need post-retrain spending_summary data.
- [ ] NHN exchange action from 7DS Origin report — was it acted on?
