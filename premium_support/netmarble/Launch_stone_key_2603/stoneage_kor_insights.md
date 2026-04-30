# StoneAge: Pet World (KOR) — Performance Investigation Insights

**Client:** Netmarble
**Title:** StoneAge: Pet World (com.netmarble.stonkey / id6737408689)
**Investigation started:** 2026-04-10

---

## Session 2026-04-10 — Initial Attributed vs Unattributed Research

### Context
- **Scope**: Compare Moloco attributed vs unattributed D1/D7 IDP and ARPPU for both Android and iOS bundles
- **Tables used**: `focal-elf-631.prod_stream_view.pb`

### Process & Hypotheses
| Step | Hypothesis / Question | Approach | Finding |
|------|----------------------|----------|---------|
| 1 | Moloco-attributed users should show higher purchase rates than unattributed | MOBIUS agent query on pb table, 3-day install cohort (Mar 28–30), device.ifa as user key, moloco.attributed for split | Android: Moloco IDP 22.26% vs unattributed 1.65% (13.5x). iOS: Moloco IDP 7.52% vs unattributed 10.78% (inverted) |
| 2 | ARPPU should be comparable between attributed and unattributed | Same query, revenue within D1/D7 of install | Android: Moloco ARPPU $19.28 vs unattributed $23.91. iOS: Moloco $7.60 vs unattributed $7.08 |

### Key Findings
1. **Android Moloco IDP is 13.5x higher than unattributed** — D1 IDP 22.26% vs 1.65% (prod_stream_view.pb, Mar 28-30 cohort, n=265 Moloco, n=51,292 unattributed). Moloco ARPPU is 19% lower ($19.28 vs $23.91). Implication: Moloco finds more payers at slightly lower ticket sizes — healthy signal for incremental payer acquisition.
2. **iOS pattern is inverted** — Moloco IDP 7.52% vs unattributed 10.78%; ARPPU similar ($7.60 vs $7.08). Small samples (n=133 Moloco, n=696 unattributed). Implication: iOS attribution is limited to IDFA-available users (~32% match rate), making the comparison unreliable. iOS needs deeper analysis.
3. **Statistical caution on small Moloco cohorts** — Android n=265, iOS n=133 over only 3 install days. D1 IDP 95% CI for iOS: approximately 3.7%–13.5%. Conclusions directional only.

### Open Questions
- [ ] Reconcile these numbers with the notebook's attributed vs unattributed analysis (different table: `moloco-dsp-data-view.postback.pb`, different fields, different date range)
- [ ] Extend cohort to 14 days for more statistical power
- [ ] Investigate iOS IDFA bias — is the 32% match rate skewing results?

---

## Session 2026-04-10 to 2026-04-12 — Notebook Review, Diagnosis & Strategy Doc

### Context
- **Scope**: Comprehensive review of `260409_stoneage_performance_investigation.ipynb` (52 cells), cross-referenced with Searchlight investigation report (cc7314f), MOBIUS research, and Netmarble Q2 strategy context. Produce a diagnosis & recommendations strategy doc.
- **Tables used**: `moloco-ae-view.athena.fact_dsp_core`, `moloco-ae-view.athena.fact_dsp_all`, `moloco-ae-view.athena.fact_supply`, `focal-elf-631.standard_report_v1_view.report_final_skan`, `moloco-dsp-data-view.postback.pb`, `focal-elf-631.entity_history.prod_entity_history`

### Process & Hypotheses
| Step | Hypothesis / Question | Approach | Finding |
|------|----------------------|----------|---------|
| 1 | What is the primary ROAS bottleneck for each campaign type? | Notebook Section 2: ROAS decomposition D1 ROAS = D1 I2P x D1 ARPPU / CPI, KOR L7D data from fact_dsp_core | Android tROAS: CPI problem ($75.08). Android CPA: user quality problem (D7 ARPU $0.11). iOS: middle ground (CPI $14, ARPU $0.48). |
| 2 | Is CPI driven by CPM inflation or IPM collapse? | Notebook Section 2b: CPI = CPM / IPM x 1000, weekly decomposition | IPM collapsed 75% (W1-W4), CPM rose only 37%. Demand-side issue, not supply cost. |
| 3 | The "10x ARPPU gap" (Moloco $11.75 vs organic $116) — is this real? | Examined median vs mean ARPPU from notebook Cell 31 (pb table, L7D) | Mean is distorted by whale outliers. Median comparison: $4.04 vs $14.70 = 3.6x gap. Also corrected "organic" to "unattributed" — those users may include other paid channels. |
| 4 | Did PA enablement (Apr 3) improve iOS performance as hypothesized? | Notebook Section 5: SKAN pre/post PA, MMP pre/post PA, LAT vs non-LAT split from fact_dsp_core | Blended D1 ROAS dropped 3.9% → 2.5% (appears to reject hypothesis). But LAT/non-LAT split reveals LAT at 4.5% D1 ROAS outperforms pre-PA baseline (3.9%). Non-LAT collapsed independently (3.9% → 0.8%) from budget doubling. PA was net positive. |
| 5 | Are CPA campaigns cannibalizing tROAS? | Notebook Section 3c: audience overlap analysis | Cell 39 is a TODO stub — never executed. Remains a hypothesis. Evidence is circumstantial: CPA campaigns win cheap users at $5-13 CPI, possibly leaving only expensive users for tROAS. |
| 6 | What is the current campaign status? | BQ Agent query: fact_dsp_core L7D (Apr 4-10), daily spend Apr 7-10 | tROAS stabilized ~$1.2K/day (CPI $68.63), iOS stable ~$1.1K/day, yFGQ effectively paused, ylgO sporadic. Total ~$2.5K/day vs $18.8K approved (87% below ceiling). |
| 7 | Is KOR audience saturated at current spend levels? | Notebook Section 4: fact_supply win rate, clear rate, CPM daily | Android: win rate improving (29→46%), CPM declining ($1.10→$0.59). Not saturated at ~$1.2K/day. iOS CPM recovered from $2.80 spike to $0.65. |
| 8 | SKAN ROAS pre-PA 9.6% — is this reliable? | Notebook Section 5a: report_final_skan, pre-PA 7d window | Pre-PA SKAN ROAS mid 9.6% is above 9% target. Post-PA 2.1% but immature (SKAN 4.0 second postback at day 3-7 may not have arrived for latest cohorts). Fair comparison requires ~Apr 16 maturity. |
| 9 | "CV pipeline has no install events for iOS" — is this true? | Checked notebook Cell 8 (event validation) and Cell 13 (iOS KOR data) | Incorrect — cv table shows iOS KOR with 946 installs and 94.6% I2L rate. Cell 29 comment is outdated. |

### Key Findings
1. **Android tROAS CPI ($68.63) is the #1 blocker** — IPM collapse (75% decline W1→W4) from audience saturation + 6x budget ramp ($1.4K→$8.3K). CVR doubled on budget cut, confirming budget as primary lever. CPI Balancer is ~5% contributor, not root cause. (fact_dsp_core, L7D)
2. **CPA campaigns are structural ROAS destroyers** — ylgO8XQvDb5nx3k4: $1 D1 revenue on $5.2K spend (0.02% D1 ROAS, 0.34% I2P). yFGQdt2EPPm0NU97: $52 on $10.2K (0.5%). Combined CPA spend ($15.3K) exceeds tROAS D1 revenue ($1,260). (fact_dsp_core, L7D)
3. **iOS PA was a net positive — masked by blended metrics** — LAT traffic (unlocked by PA): 4.5% D1 ROAS at $12.66 CPI. Non-LAT collapsed independently 3.9%→0.8% from budget doubling. Blended 2.5% misleadingly averages the best and worst segments. (fact_dsp_core, post-Apr 3)
4. **Pre-PA SKAN ROAS 9.6% is the strongest signal** — Only segment that hit the 9% D1 ROAS target. Post-PA SKAN is 2.1% but immature (SKAN 4.0 second postback timing). Re-validation needed ~Apr 16. (report_final_skan)
5. **The "10x ARPPU gap" is actually 3.6x** — Mean ARPPU distorted by whales (unattributed mean $116.18, median $14.70). tROAS median $4.04 vs unattributed median $14.70 = 3.6x. Also: tROAS I2P (20.09%) is 6x higher than unattributed (3.30%). Moloco finds payers but at lower ticket size. (postback.pb, L7D)
6. **Not saturated at current spend** — Android win rate improving (29%→46%), CPM declining ($1.10→$0.59) post-budget-cut. iOS CPM recovered from $2.80 to $0.65. Room to operate at current ~$1.2K/day levels. (fact_supply, L14D)
7. **Audience overlap analysis is the biggest analytical gap** — Cell 39 (impression-level device overlap between CPA and ROAS campaigns) was never executed. Cannibalization hypothesis remains unproven.

### Deliverables Produced
- `260410_notebook_review_revised_section6.md` — Section-by-section review with rewritten Section 6
- `260411_stoneage_diagnosis_and_recommendations.html` — Final strategy doc (132KB self-contained HTML with 7 embedded Plotly charts, dark theme, interactive)
- Framed as "Diagnosis & Recommendations" (not notebook review)
- Apps Script deployment attempted but blocked by expired clasp OAuth token

### Open Questions
- [ ] iOS SKAN ROAS post-PA maturation — re-pull after ~Apr 16
- [ ] Audience overlap analysis (Cell 39) — quantify CPA-tROAS device overlap
- [ ] Reconcile attributed vs unattributed ARPPU between two tables (prod_stream_view.pb vs moloco-dsp-data-view.postback.pb)
- [ ] Confirm AppsFlyer SKAN conversion value lock window for this title
- [ ] Deploy HTML strategy doc to Apps Script (clasp token needs re-authentication)
- [ ] KPI event change proposal for Android tROAS (visit_shop as secondary signal)
- [ ] iOS WW ROAS test decision — pending SKAN maturation and Netmarble biweekly alignment
