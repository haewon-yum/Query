# Netmarble KOR Review — Stonekey + 7DS:Origin Campaign Investigations

**Advertiser:** Netmarble (`yfg0At8VksGnt6EO`)
**Investigation started:** 2026-04-09

---

## Session 2026-04-09 / 2026-04-10

### Context
- **Scope**: Dual parallel campaign performance investigation for two Netmarble KOR titles: (1) StoneAge Pet World ("Stonekey"), (2) The Seven Deadly Sins: Origin ("7DS:Origin"). Both Android + iOS. Detect performance issues, root cause analysis, recommend stabilization and growth actions for GDS x Sales.
- **Searchlight sessions**: Stonekey = `cc7314f`, 7DS:Origin = `27a3360`
- **Reports**: `.investigate_sessions/cc7314f/answers/REPORT.md` (Stonekey), `.investigate_sessions/27a3360/answers/REPORT.md` (7DS:Origin)
- **Tables used**: `moloco-ae-view.athena.fact_dsp_core`, `fact_dsp_creative`, `fact_dsp_all`, `focal-elf-631.entity_history.prod_entity_history`, `focal-elf-631.standard_digest.campaign_digest`, `product_digest`, `ad_group_digest`, `audience_target_digest`, `moloco-data-prod.younghan.campaign_trace_raw_prod`, `prod_stream_view.pb`, `explab-298609.summary_view.experiment_summary`

### Process & Hypotheses — Stonekey (session cc7314f, 3 iterations, 51 questions)

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Discover Stonekey campaigns | campaign_digest + entity_history search | 5 campaigns found (3 active, 2 inactive). Advertiser yfg0At8VksGnt6EO. Apps: com.netmarble.stonkey (AOS), id6737408689 (iOS). |
| 2 | CPI Balancer experiment caused Android tROAS CVR collapse | fact_dsp_core daily trends, experiment_summary, control arm analysis | **I1 REJECTED by judge**: Control arm (2%, n=5 installs) shows same CVR collapse as test arm. Alpha=0.9 produces only ~5% ROAS impact per Glean. |
| 3 | Post-launch audience saturation is primary cause | ADV2: benchmark against 396 KOR gaming launches. A20: CVR recovery when budget cut. | **CONFIRMED**: 87% CVR decline at 0.5 percentile. CVR recovered 0.33%→0.66% when budget cut 84% with CPI Balancer still active. Saturation + 6x budget ramp ($1,393→$8,276) is the primary driver. |
| 4 | iOS quality degraded due to LAT traffic admission | entity_history (filter_expr change), fact_dsp_all is_lat breakdown | **CONFIRMED with nuance**: ad_tracking_allowance changed NON_LAT_ONLY→DO_NOT_CARE on Apr 3 00:43 UTC. LAT users have lower I2A (352.5% vs 412.3%) but HIGHER D1 ROAS (4.88% vs 0.90%) and D7 ROAS (6.60% vs 1.36%). Non-LAT quality also cratered independently. |
| 5 | Spending collapse Apr 5-8 was platform issue | entity_history for budget/enable changes | **RULED OUT**: Deliberate Netmarble budget cuts. nazpxG3J5MareHRz: $8,276→$1,307 by 3 operators. ylgO8XQvDb5nx3k4 disabled Apr 8. |
| 6 | Postback drop (ODSB-17082) causing CVR collapse | fact_dsp_core vs prod_stream_view.pb cross-validation | **RULED OUT**: Attributed installs match exactly across tables. CVR collapse is real, not measurement artifact. |
| 7 | VBT / exchange path throttling affecting campaigns | Code search (marvel2) for VBT and throttling mechanisms | **RULED OUT**: SDK_MAX/SDK_LEVELPLAY bypass VBT (IgnoreVBT: true). Exchange path throttling blocks only non-SDK. |

### Process & Hypotheses — 7DS:Origin (session 27a3360, 3 iterations, 30 questions)

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Discover 7DS:Origin campaigns | campaign_digest + entity_history | 5 campaigns (3 Android, 2 iOS). App: com.netmarble.nanaori (AOS), 6744205088 (iOS). Title ~2 weeks old. CPA migration in progress (login_1st → login_1st_s2s). |
| 2 | Creative fatigue causing CPI surge | fact_dsp_creative CTR trends, cross-campaign creative comparison | **REJECTED**: Same creatives perform WORSE on newer campaigns (iyH1 0.32% CTR vs HTVA 0.92%). Within-format CTR stable/improving on mature campaign (vi: 36.7%→50.8%). |
| 3 | Post-launch audience saturation driving IPM collapse | CPI decomposition (CPM/IPM), benchmark against 540 KOR campaigns | **CONFIRMED**: IPM collapsed -75% (Android), -89% (iOS). 7DS at worst 2-3% of 540 comparable launches (median decay = -13%). Abnormally severe — 5.7x worse than typical. |
| 4 | Kakao bizboard high CVR is genuine | fact_dsp_all CT/VT attribution breakdown for Kakao vs non-Kakao | **ATTRIBUTION ARTIFACT**: 95.6% of Kakao installs are VT (view-through). CT-only CVR = 1.57% (normal). Kakao claims credit for organic installs. Launch-day CVR hit 119.5% (more installs than clicks). |
| 5 | D56 recency creative pick change hurting new title | Code search (marvel2 PR #71341) | **CONFIRMED as compounding factor**: pickByPerformance defaults all creatives to "new" (random selection) when no D56 data exists. No cold-start fallback. But IPM decline predates Apr 6 change by 12 days — not the initial cause. |
| 6 | CPA campaign cannibalization during migration | entity_history enable/disable timestamps | **RULED OUT**: Clean 8-second switchover (HTVA disabled 09:58:52, vHKy activated 09:59:00 on Apr 8). Identical targeting. No overlap. |

### Key Findings

**Stonekey:**

1. **Android tROAS CVR collapse is budget-driven saturation, not CPI Balancer** — CVR declined 87% (1.11%→0.29%) primarily from 6x budget ramp into saturated KOR audience. CPI Balancer control arm shows same collapse (0.355% vs test 0.423%). CVR recovered when budget cut. CPI Balancer at alpha=0.9 only ~5% ROAS impact. [fact_dsp_core, experiment_summary, entity_history]

2. **iOS LAT users outperform non-LAT on revenue metrics** — Against 9% D1 ROAS target: LAT=4.88%, non-LAT=0.90% post-Apr 3. LAT also has higher D7ROAS (6.60% vs 1.36%) and cheaper CPI ($12.38 vs $15.53). Non-LAT quality cratered independently (-72% D1 ROAS). Recommendation: separate LAT/non-LAT ad groups, NOT revert to NON_LAT_ONLY. [fact_dsp_core by is_lat]

3. **Stonekey report updated with D1 ROAS analysis** — User requested D1 ROAS (9% target metric) be included. Added to Finding 2, Bottom Line, and Recommendation 2 in the report.

4. **EQCWerD5mEThZO4P ($3,500/day) paused due to 0.70% ROAS** — KPI action buy_pet_lv3 is too deep-funnel. 8/21 Netmarble campaigns paused for BM oscillation fixes. [Glean search]

**7DS:Origin:**

5. **IPM decay is abnormally severe (worst 2-3%)** — Among 540 comparable KOR gaming campaigns: median W1→W2 IPM decay = -13%. 7DS at -75%. Only 12/540 (2.2%) had worse decay. Suggests compounding factors beyond normal saturation (competitive pressure, D56 recency). [fact_dsp_core benchmark query]

6. **Kakao bizboard is a brand billboard, not performance channel** — 30-44% of spend at 0.045% CTR. 95.6% VT attribution. CT-only CPI = $53.79 vs apparent $2.39. VT users have good quality (D7 ROAS 60.3%) because they're organic users. [fact_dsp_all CT/VT breakdown]

7. **CPI still rising at $14.72 (no stabilization)** — Original-campaigns-only CPI: $5.54→$14.72 (+166%) in 7 days (Apr 3-9). Judge flagged: do NOT frame as "steady state" for Sales. Monitor for stabilization. [fact_dsp_core]

8. **iOS consistently 2-4x better ROAS than Android** — iOS D7ROAS 24-81% vs Android 8-61%. Primary growth lever: shift budget toward iOS. [fact_dsp_core]

### Open Questions

- [ ] **Stonekey**: Monitor D1 ROAS trends as LAT/non-LAT cohorts mature (post-Apr 10). Confirm LAT revenue advantage is sustained, not driven by whale effect.
- [ ] **Stonekey**: Track ODSB-17082 postback resolution and ODSB-16909 fraud investigation for com.netmarble.stonkey.
- [ ] **Stonekey**: Consider disabling CPI Balancer for 48h as low-risk definitive test (only ~5% ROAS impact at alpha=0.9).
- [ ] **Stonekey**: Re-evaluate EQCWerD5mEThZO4P with shallower KPI (e.g., login instead of buy_pet_lv3).
- [ ] **7DS:Origin**: Investigate competitive KOR gaming launches Mar-Apr 2026 (SensorTower) as explanation for abnormal IPM severity.
- [ ] **7DS:Origin**: Review Kakao VT attribution methodology with Sales — 30-44% spend on 0.045% CTR warrants client discussion.
- [ ] **7DS:Origin**: Escalate D56 cold-start concern to creative selection team (pickByPerformance random selection for new titles).
- [ ] **7DS:Origin**: Recheck CPI trajectory after Apr 21 — has it stabilized? Set CPA targets only after stabilization confirmed.
- [ ] **7DS:Origin**: Allow 2-4 weeks for new campaigns (vHKy, iyH1) to exit model learning phase before evaluating.
