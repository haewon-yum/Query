# MA DS: ACS Adoption Meta Analysis — Full Review

**Date:** 2026-03-06
**Document:** [MA DS: ACS adoption meta analysis](https://docs.google.com/document/d/18okXtBAgXh3E3KsMPxHmN1TjgybQDcpLmlx01O4jgdY)
**Notebook:** `~/Documents/Queries/Measurement/acs_adoption/acs_adoption_analysis.ipynb`

---

## Part 1: Logical Soundness Review

### Overall Assessment: Solid foundation with clear narrative; a few areas to tighten

The analysis is well-structured and covers multiple dimensions (genre, target country, creative format, CTR). The core argument — that KOR/JPN lag in ACS Advanced adoption — is convincingly demonstrated. The TR;DL is well-hedged. Below are issues to address, each with a suggested fix.

---

### Issue 1: The TR;DL is well-balanced, but some section-level conclusions could be tightened to match

**Problem:** The TR;DL correctly states: *"office-level context may play a large role in ACS adoption."* This is the right framing. However, the target country section concludes that competitive markets (RUS, ITA, DEU, CAN, FRA) indicate opportunity — then immediately notes *"very few KOR/JPN bundles direct significant spend to these markets"*, which effectively negates that finding as an activation lever. The transition between the two points could be smoother.

**Current text:**
> *"Several markets outside of KOR and JPN show high ACS adoption rates... Those markets are expected to be more competitive than others... However, from an activation perspective, there are very few bundles in KOR and JPN where a significant amount of spend is directed toward these identified competitive markets."*

**Suggested fix:**
> *"Several markets outside of KOR and JPN — notably RUS, ITA, DEU, CAN, and FRA — show high ACS Advanced adoption (>50%), suggesting intense attribution competition. However, few KOR/JPN bundles direct significant spend to these markets, **limiting the direct activation value of this finding. A more actionable follow-up is to examine multi-DSP usage among KOR/JPN advertisers via SensorTower data** — if these advertisers are running multiple DSPs, they face attribution competition regardless of target market, strengthening the case for Advanced adoption."*

---

### Issue 2: The EFS bucket-level analysis supports the correlation well; the office-level scatter plot needs a caveat

**Problem:** The EFS section has two views:

(a) **Bucket-level chart (Section 9-0)** — This clearly supports a positive correlation. Adoption rises from 9.4% (0% EFS) to 38.7% (100% EFS), roughly a 4x increase across the full range. The dip at 51–75% (22.5%) breaks strict monotonicity but does not negate the overall upward trend. **This chart is solid evidence for the "positive correlation" claim.**

| EFS Bucket | Adv Rate |
|---|---|
| 0% | 9.4% |
| 1–25% | 16.7% |
| 26–50% | 26.9% |
| 51–75% | 22.5% |
| 76–99% | 32.0% |
| 100% | 38.7% |

(b) **Office-level scatter plot (Section 9-3)** — This has only ~8 data points, and IND (59.9% EFS, 86% adoption) and SGP (60.1% EFS, 63.8% adoption) are clear outliers that show high adoption is achievable with low EFS. A trend line on 8 points is not statistically robust.

The doc currently frames KOR/JPN as having an *"understandable adoption rate considering their Avg EFS."* While directionally fair, this understates the IND/SGP counterexample.

**Current text:**
> *"IND and SGP show significantly higher adoption rates with relatively low EFS. (Note: their overall adoption rate is higher than other regions across dimensions.)"*
> *"KOR/JPN: understandable adoption rate considering their Avg EFS."*

**Suggested fix:**
> *"IND and SGP show significantly higher adoption rates despite relatively low EFS, demonstrating that **office-level activation practices can override creative format composition as a driver of adoption.** KOR/JPN's low adoption is directionally consistent with their lower EFS, but the IND/SGP examples confirm that low EFS is not an insurmountable barrier — **activation effort matters more than format mix.** This reinforces the opportunity: KOR/JPN bundles can adopt Advanced even without first changing their creative strategy."*

Note: The bucket-level finding ("positive correlation") is well-supported and should stay as-is. The qualification is only needed for the office-level scatter plot interpretation.

---

### Issue 3: CTR section — valuable negative result, but the proxy limitation should be acknowledged

**Problem:** The finding that *"User CTR is NOT correlated with ACS Advanced adoption"* is important. However, the hypothesis was about **advertiser CTR tolerance** (a qualitative/perceptual measure), while the test used **bundle-level true click CTR** (a quantitative proxy). These are different constructs — an advertiser may resist Advanced regardless of their actual CTR if they *perceive* that high MMP-visible CTR is a risk.

**Current text:**
> *"Result: User CTR (true clicks) is NOT correlated with ACS Advanced adoption"*

**Suggested fix:**
> *"Result: Bundle-level User CTR (true clicks) is NOT correlated with ACS Advanced adoption. This suggests that **observed click behavior does not predict adoption decisions.** However, this does not rule out the possibility that **advertiser-stated CTR tolerance** (a qualitative measure, not captured in log data) plays a role in adoption resistance. PSO's initiative to collect CTR expectations via Sales will help clarify whether perceived CTR sensitivity is a barrier in KOR/JPN."*

---

### Issue 4: The "competitive markets" argument — add a follow-up on multi-DSP usage

**Problem:** The analysis identifies RUS/ITA/DEU/CAN/FRA as competitive based on high Advanced adoption, but doesn't examine the competitive landscape for KOR/JPN bundles directly. Rather than speculating about competitor click behavior (which is not directly observable), a stronger approach is to measure **multi-DSP usage** among KOR/JPN advertisers via SensorTower data — if advertisers are actively running multiple DSPs, they are in an attribution-competitive environment where Advanced's measurement parity becomes critical.

**Current text:**
> (No follow-up on multi-DSP usage)

**Suggested fix — add to Open Questions or as a note under the Target Country section:**
> *"Follow-up: Examine multi-DSP usage patterns among KOR/JPN advertisers using SensorTower data (coordinating with Benita's parallel workstream). If KOR/JPN bundles are actively running multiple DSPs, they are in an attribution-competitive environment — making ACS Advanced essential for measurement parity, even in their home markets."*

---

### Issue 5: Correlation vs. suitability framing — one sentence to add

**Problem:** The Hypotheses section now correctly uses suitability framing (*"Bundles with higher EFS have more to gain from ACS Advanced"*). However, the Key Findings section uses pure correlation language (*"There's a positive correlation between EFS and ACS Advanced adoption rate"*) without connecting back to the mechanism.

**Current text (EFS section opening):**
> *"There's a positive correlation between Engaged Format Share and ACS Advance adoption rate."*

**Suggested fix:**
> *"There is a positive correlation between Engaged Format Share and ACS Advanced adoption rate — adoption roughly quadruples from 9.4% (0% EFS) to 38.7% (100% EFS). **This is consistent with the ACS mechanism: Advanced's incremental attribution signals (3s Engaged Views, impression-based clicks) fire exclusively on vi/nv/ri formats, so bundles with higher EFS have more to gain from upgrading.** The correlation reflects both self-selection (bundles that benefit most are more likely to adopt) and suitability (high-EFS bundles are better candidates for activation)."*

---

### Issue 6: Missing dimension — Performance impact (highest priority gap)

**Problem:** The analysis thoroughly maps **where** adoption is low but doesn't address **what happens when bundles switch to Advanced**. Without before/after evidence, the activation narrative lacks its most persuasive argument. The Literature Review references the `[Internal] ACS Adoption and Impact Analysis` and `[CHN NBS + Mid-market] ACS Impact Analysis` — these likely contain uplift data.

**Current text:**
> (No performance impact section)

**Suggested fix — add a paragraph to Key Findings or Recommendations:**
> *"Prior internal analyses ([Internal] ACS Adoption and Impact Analysis; [CHN NBS + Mid-market] ACS Impact Analysis — Recommended to Advanced) have quantified the performance impact of ACS mode migration. [Insert key uplift metrics here, e.g., "Bundles migrating from Recommended to Advanced typically saw X% increase in MMP-attributed installs and Y% reduction in effective CPI."] Incorporating these uplift benchmarks would significantly strengthen the activation pitch for KOR/JPN."*
>
> If the exact numbers aren't yet pulled, flag this as a follow-up action:
> *"Action: Extract performance uplift metrics from existing ACS impact analyses and incorporate into the activation narrative."*

---

## Part 2: Proofreading (Language & Grammar)

### Section-by-section corrections

**Context & Problem Statement:**
- ❌ *"identifying bundles actively using DSP channels but are not in Advanced ACS mode"*
- ✅ *"identifying bundles actively using DSP channels but **that** are not in Advanced ACS mode"*

- ❌ *"implications for KOR/JON"*
- ✅ *"implications for KOR/**JPN**"* (typo: JON → JPN)

**Hypotheses:**
- ❌ *"Bundles with higher engagement for mat share have more to gain"*
- ✅ *"Bundles with higher **engaged format** share have more to gain"* (typo: "for mat" → "format")

- ❌ *"High-EFS(Engagement Format Share)"*
- ✅ *"High-EFS (**Engaged** Format Share)"* — "Engaged" not "Engagement" to match the metric definition

**Methodology:**
- ❌ *"Advertiser-level: tier, agency vs. direct, global vs local, OS mix, CTR sensitivity(?, how to proxy?)"*
- ✅ Clean up or remove the parenthetical internal note *(?, how to proxy?)* — either frame as an open question formally or remove for the final version

**TR;DL:**
- ❌ *"Even though genre, target countries, and engaged format share show to some extent correlation with ACS adoption rate"*
- ✅ *"Although genre, target countries, and engaged format share show **some degree of** correlation with ACS adoption rate"*

- ❌ *"office-level context – customer profiles (CTR sensitiveness, cultural fit, etc.) – may play a large role"*
- ✅ *"office-level context — customer profiles (CTR **sensitivity**, cultural fit, etc.) — **likely plays** a larger role"*

**ACS Advanced Adoption Status:**
- ❌ *"Both KOR and JPN have <9% of ACS Advanced adoption"*
- ✅ *"Both KOR and JPN have **<9%** ACS Advanced adoption" (remove "of")*

- ❌ *"KOR has large portion(78.3%) of Recommended"*
- ✅ *"KOR has **a large portion** (78.3%) **on** Recommended"*

- ❌ *"More conservative than conservative – disabled EV (more aggressive)"*
- ✅ Unclear what this means — should be rephrased: *"Are they more conservative than Conservative (e.g., EV disabled)? Or more aggressive?"*

**ACS Adoption by Genre:**
- ❌ *"Puzzle, Party, Hypercasual, Tabletop, Entertainment are top genres with >50% of ACS advanced adoption"*
- ✅ *"Puzzle, Party, Hypercasual, Tabletop, and Entertainment are the top genres with >50% ACS Advanced adoption"*

**ACS Adoption by Genre × Office:**
- ❌ *"CHN, EMEA < USA show >60% of adoption"*
- ✅ *"CHN, EMEA**,** **and** USA show >60% adoption"* (the `<` appears to be a typo for `,`)

- ❌ *"while there is almost no spend on ACS Advanced in KOR and JPN"*
- ✅ *"while **KOR and JPN show** almost no spend on ACS Advanced"*

**ACS Adoption by Target Country:**
- ❌ *"that attribution competition is more intense in that market"*
- ✅ OK, but consider: *"that **the** attribution **landscape** is more competitive in that market"*

- ❌ *"Any KOR/JPN app bundles with a high spend portion in DEU/CAN/FRA/RUS/ITA ?"*
- ✅ *"**Are there** KOR/JPN app bundles with a high spend **share** in DEU/CAN/FRA/RUS/ITA**?**"*

**ACS Adoption by Creative Format Mix:**
- ❌ *"Looking at correlation between engaged formats spend portion (will be bucketized) and ACS adoption at a bundle level"*
- ✅ *"**This section examines the** correlation between engaged format spend share **(bucketized)** and ACS adoption at **the** bundle level"*

**ACS Adoption by True CTR:**
- ❌ *"Advertisers with lower click tolerance may resist ACS Advanced because it adds incremental attribution clicks (engaged view clicks, engaged clicks), inflating the MMP-visible CTR."*
- ✅ Good sentence, but consider: *"Advertisers with **lower CTR** tolerance may resist ACS Advanced because it adds incremental attribution clicks (Engaged View**s**, Engaged Click**s**), **which inflate** the MMP-visible CTR."*

**Slack comments at bottom:**
- ❌ *"identifying additional opportunities soley based on meta analysis may be somewhat limited"*
- ✅ *"identifying additional opportunities **solely** based on meta analysis may be somewhat limited"*

---

## Part 3: Draft Content for Missing Fields

### TL;DR — Review of Updated Version (Mar 6)

The author updated the TL;DR with actual content (replacing the TBU template). Review below.

#### What works well
- Covers all four dimensions (genre, target country, EFS, CTR) — logical structure
- Hedged framing ("show to some extent correlation", "may play a large role") avoids overclaiming
- User CTR negative result included — important for objection handling

#### Issues to address

**1. Missing bottom line upfront.** The TL;DR starts with a qualifying statement about correlations. Lead with the gap and opportunity, then supporting evidence.

**2. Missing opportunity quantification.** The 412 quick-win bundles ($22.7M) and 715 non-Advanced products ($35.2M) are the most actionable outputs — they're not mentioned at all.

**3. EFS conclusion undermines the activation narrative.**
- ❌ *"From this lens, KOR/JPN's lower ACS Adv adoption is reasonable with relatively lower EFS."*
- This implies the gap is "reasonable" and not a problem. But IND/SGP achieve 60–86% adoption with comparable EFS — so EFS doesn't explain the gap away.
- ✅ Reframe: low EFS is a structural factor, but the 412 high-EFS non-Advanced bundles show activation opportunity still exists.

**4. RPG caveat belongs in the body, not the TL;DR.**
- ❌ *"However, it is difficult to conduct a deeper analysis... as the sub genres under the RPG are highly fragmented."*
- This is a methodological limitation that disrupts TL;DR flow. Move to the Genre section body.

**5. Missing action / "so what".** The TL;DR lists findings but doesn't say what to do about them.

**6. Language fixes.**

| Current | Fix |
|---|---|
| *"show to some extent correlation"* | *"show some degree of correlation"* |
| *"CTR sensitiveness"* | *"CTR sensitivity"* |
| *"ACS Advance adoption"* (missing 'd') | *"ACS Advanced adoption"* |
| *"ACS advanced adoption"* (lowercase) | *"ACS Advanced adoption"* (consistent capitalization) |

#### Suggested rewrite

> **TL;DR**
>
> **KOR and JPN have <9% ACS Advanced adoption** (by spend), compared to 40–86% in other offices. The gap is primarily structural — driven by office-level activation practices and customer profiles (CTR sensitivity, cultural fit) — rather than any single product-level factor. Genre, target country competitiveness, and engaged format share each show some degree of correlation with adoption globally, but none fully explains the KOR/JPN lag.
>
> - **Genre:** Globally high-adoption genres (Puzzle, Party, Hypercasual, Tabletop) account for minimal spend in KOR/JPN. In RPG — the dominant KOR genre — both KOR and JPN lag behind in adoption rates.
> - **Target Countries:** Several markets (RUS, ITA, DEU, CAN, FRA) show high Advanced adoption, suggesting intense attribution competition. However, few KOR/JPN bundles direct significant spend to these markets, limiting this as a direct activation lever.
> - **Engaged Format Share:** Globally, there is a positive correlation between EFS and Advanced adoption (~4x from 9.4% at 0% EFS to 38.7% at 100% EFS). KOR/JPN's relatively lower EFS partly explains their lower adoption, but IND and SGP achieve 60–86% adoption with comparable EFS — confirming that activation effort matters more than format mix alone. **412 high-EFS, non-Advanced bundles in KOR/JPN ($22.7M spend) are natural activation candidates.**
> - **User CTR:** User CTR (true clicks) is NOT correlated with ACS Advanced adoption, suggesting bundle-level click rate does not predict adoption decisions.
>
> **Overall:** 715 non-Advanced products in KOR/JPN ($35.2M spend) represent the total addressable opportunity. The quickest path to activation is the 412 high-EFS bundles, coordinated with the ACS activation 2.0 workstream.

### Previous TL;DR Draft (for reference)

> **Key Findings:**
>
> - **KOR and JPN have <9% ACS Advanced adoption** (by spend), compared to 40–86% in other offices. The gap persists across all dimensions analyzed (genre, target country, creative format mix).
>
> - **The adoption gap is primarily driven by office-level practices**, not by product characteristics. While genre, target country competitiveness, and engaged format share show some correlation with Advanced adoption globally, these factors are secondary to office-level activation norms. IND and SGP achieve 60–86% Advanced adoption despite lower EFS than KOR/JPN.
>
> - **Genre lens:** Globally high-adoption genres (Puzzle, Party, Hypercasual, Tabletop) account for minimal spend in KOR/JPN. The dominant KOR genre — RPG — shows low Advanced adoption across both offices, with highly fragmented sub-genres limiting targeted activation.
>
> - **Target country lens:** Markets like RUS, ITA, DEU, CAN, and FRA show strong Advanced adoption (>50%) globally, suggesting intense attribution competition. However, few KOR/JPN bundles direct significant spend to these markets, limiting this as an activation lever.
>
> - **Engaged format share (EFS) lens:** Higher EFS correlates with higher Advanced adoption globally (mean EFS: 95.4% for Adv vs. 90.4% for Non-Adv). This is mechanistically sound — Advanced's incremental signals (3s EV, impression-based clicks) fire exclusively on vi/nv/ri formats. **412 high-EFS, non-Advanced bundles in KOR/JPN ($22.7M spend)** are natural activation candidates.
>
> - **True CTR is not correlated with Advanced adoption**, suggesting that bundle-level click rate is not a reliable proxy for advertiser CTR tolerance. PSO's initiative to collect CTR expectations via Sales may yield better signal.
>
> - **715 non-Advanced products in KOR/JPN** account for **$35.2M in spend** — this represents the total addressable opportunity.
>
> **Action Plan:**
> - Coordinate with ACS activation 2.0 workstream (Alaric/Benita) to integrate the quick-win lead list (412 bundles, $22.7M) into the global lead refresh.
> - Build KOR/JPN-specific objection handling narratives around high CTR and high VT concerns.
> - Engage PSO to push customer CTR expectation profiling via Sales to supplement the quantitative findings.

### Recommendations and Next Steps (Draft)

> **Immediate Actions:**
>
> 1. **Activate the quick-win lead list.** 412 bundles in KOR/JPN with high Engaged Format Share (≥50%) and non-Advanced ACS represent $22.7M in spend. These bundles already run vi/nv/ri formats and would benefit most from Advanced's incremental attribution signals. Share with regional Sales/GMs as priority migration candidates.
>
> 2. **Build regional objection handling guides.** KOR and JPN advertisers have specific concerns around:
>    - **High CTR visibility:** Advanced adds attribution clicks (EV, EC, impression-based) that inflate MMP-visible CTR. Prepare a narrative explaining that these are measurement-parity signals, not fraudulent clicks, and that competing DSPs fire at 70–90% CTR levels.
>    - **High VT rates:** Prepare a VT landscape narrative showing how VT configuration interacts with ACS settings and SKAN performance (leveraging DraftKings SKAN investigation learnings).
>
> 3. **Coordinate with ACS activation 2.0** (Alaric/Benita, OKR Obj 2 KR4) to integrate findings into the global activation workflow. Target: GM approval >90%, client adoption >50%.
>
> 4. **Investigate JPN's ACS_CUSTOM settings.** JPN has 10.5% of products on ACS_CUSTOM — understanding whether these are more conservative or more aggressive than the standard Conservative mode would clarify the activation opportunity and approach.
>
> **Follow-up Analysis:**
>
> 5. **Add performance impact data.** This analysis maps *where* adoption is low but doesn't quantify *what happens after migration*. Pull before/after metrics from the existing [Internal] ACS Adoption and Impact Analysis and [CHN NBS + Mid-market] ACS Impact Analysis to strengthen the activation pitch with concrete uplift numbers.
>
> 6. **Examine multi-DSP usage via SensorTower.** The current analysis identifies competitive markets (RUS, ITA, etc.) based on global Advanced adoption patterns. A more direct approach: use SensorTower data to measure multi-DSP usage among KOR/JPN advertisers (coordinating with Benita's parallel workstream). If these advertisers actively run multiple DSPs, they face attribution competition regardless of target market — making Advanced essential for measurement parity.
>
> 7. **Supplement with qualitative data.** PSO plans to push "filling customer profile regarding CTR expectation" through Sales. Once collected, overlay CTR tolerance profiles with this analysis to refine the lead list and prioritize advertisers with higher tolerance.
>
> 8. **Develop a lead scoring framework.** Rank the 412 quick-win bundles by: (a) spend volume, (b) EFS level, (c) genre competitive intensity, (d) multi-DSP usage (from Benita's Sensor Tower data). Present the top 20–30 as priority activation targets.
>
> 9. **Cross-regional sharing.** Present findings at the Thursday Cross-Regional Discussion and contribute ACS/SKAN content to the monthly Consumer & Gaming Insights Newsletter (Marvin/Skye).

### Open Questions (Draft)

> - **What do JPN's ACS_CUSTOM settings actually configure?** Are they more conservative (e.g., EV disabled) or more aggressive than the standard Conservative mode? This affects whether JPN's 10.5% ACS_CUSTOM cohort is a migration opportunity or already optimally configured.
>
> - **How many KOR/JPN advertisers are running multiple DSPs?** SensorTower data (coordinating with Benita's workstream) can quantify multi-DSP usage. Advertisers running multiple DSPs face attribution competition regardless of target market — making Advanced essential for measurement parity. This is a more directly observable signal than speculating about competitor click behavior.
>
> - **What specific CTR thresholds trigger advertiser concern in KOR/JPN?** The quantitative analysis shows no correlation between bundle-level User CTR and Advanced adoption. However, advertiser *perceived* CTR tolerance (qualitative) may differ. PSO's Sales-driven customer profiling initiative will help fill this gap.
>
> - **How do lifetime suppression settings interact with ACS mode?** Multiple accounts (Supercell, Playrix, DraftKings) have escalated lifetime suppression concerns. If suppression interacts with Advanced's attribution click behavior, this could affect both the lead list and objection handling.
>
> - **What is the actual performance uplift when migrating from Recommended → Advanced?** The existing [Internal] ACS Adoption and Impact Analysis and CHN NBS analysis likely contain this data but are not yet incorporated. Quantifying the uplift is critical for Sales conversations.

---

## Appendix: Key Data Points from Notebook (for reference)

| Metric | Value |
|---|---|
| Analysis period | 2025-11-01 to 2026-01-31 |
| Total bundles analyzed | 19,957 |
| KOR Advanced adoption (spend-weighted) | 9.2% |
| JPN Advanced adoption (spend-weighted) | 12.1% |
| Global mean EFS | 92.0% (median: 100%) |
| Adv bundles mean EFS | 95.4% |
| Non-Adv bundles mean EFS | 90.4% |
| Non-Advanced products in KOR/JPN | 715 |
| Non-Advanced spend in KOR/JPN | $35.2M |
| Quick-win bundles (EFS ≥50%, non-Adv, KOR/JPN) | 412 bundles, $22.7M spend |
| User CTR: Advanced vs Non-Advanced | 2.39% vs 2.72% (not significant) |
| MMP-visible CTR: Advanced vs Non-Advanced | 8.59% vs 4.74% |
| ACS Click Uplift: Advanced vs Non-Advanced | 6.20% vs 2.02% |
