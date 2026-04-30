# Review: MA DS ACS Adoption Meta Analysis

**Date:** 2026-03-05
**Document reviewed:** [MA DS: ACS adoption meta analysis](https://docs.google.com/document/d/18okXtBAgXh3E3KsMPxHmN1TjgybQDcpLmlx01O4jgdY)

---

## What Works Well

1. **Clear problem framing** — KOR/JPN lag at <9% Advanced adoption is well-established upfront with multi-dimensional evidence
2. **Multi-axis approach** — Genre, target country, office, creative format, sub-genre — gives a comprehensive view rather than a single-lens story
3. **Practical orientation** — Lead lists (e.g., KOR bundles in competitive markets, high-EFS non-Advanced bundles) are directly actionable
4. **Honest about limitations** — The caveat that "ACS level should align with CTR tolerance, which isn't observable in logs" is an important and often-skipped qualifier

---

## Areas to Improve

### 1. The TL;DR and Recommendations are still TBU — this is the most critical gap

The doc has rich analysis but **no synthesized narrative**. Readers (especially Sales/PSO/leadership) will likely skip to TL;DR and find nothing. Suggestion:

- **Lead with the bottom line**: "KOR/JPN Advanced adoption is <9% vs 40–86% in other offices. The gap is structural (genre mix, office practices) not just awareness. Here are the 3 highest-leverage activation paths."
- **Quantify the opportunity**: Total spend on non-Advanced bundles in KOR/JPN ($35.2M from notebook Section 5-1). What's the estimated incremental spend/attribution recovery if even 30% migrated?

### 2. The EFS hypothesis needs more rigorous framing

The doc states there is a "clear positive correlation" between EFS and Advanced adoption. But:

- The **5pp difference** (Adv 95.4% vs Non-Adv 90.4%) is small, and the distribution is ceiling-compressed (92% mean, 100% median)
- The non-monotonic dip at 51–75% EFS (22.5% adoption vs 26.9% at 26–50%) weakens the "clear" correlation claim
- **IND (EFS 59.9%, 86% Advanced) and SGP (60.1%, 63.8%)** directly contradict a simple EFS→adoption story

**Suggestion**: Reframe EFS not as a *predictor of adoption* but as a **suitability indicator** — "high-EFS bundles have the most to gain from Advanced because its incremental signals fire exclusively on vi/nv/ri." This is mechanistically correct and doesn't overstate the empirical pattern.

### 3. Causal language should be tightened

The doc implies engaged formats drive adoption ("signals from engaged format would be beneficial for models"). The actual mechanism is:

- ACS Advanced sends **attribution clicks to the MMP** (not model training signals directly)
- The primary value prop is **measurement parity** with competing DSPs, not model accuracy
- Adoption is a **human decision** (AM/advertiser), not an automatic outcome of signal quality

**Suggestion**: Replace "signals beneficial for models" with "Advanced's incremental click signals (3s EV, impression-based clicks) fire exclusively on vi/nv/ri — bundles without these formats gain minimal benefit from upgrading to Advanced."

### 4. Missing analysis: What's actually blocking KOR/JPN?

The doc thoroughly maps *where* the gap exists but doesn't deeply investigate *why*. The JPN observation (more ACS_CUSTOM and Conservative) is flagged as an open question but not investigated. Consider adding:

- **What do JPN's ACS_CUSTOM settings actually look like?** Are they more or less aggressive than Conservative?
- **Are there specific customer objections in KOR/JPN?** (e.g., MMP rejected install rate sensitivity — the Notion comm doc mentions this as a disqualifier for Advanced)
- **AM survey data or qualitative input** — even 5 data points on why KOR/JPN AMs don't push Advanced would be valuable

### 5. The competitive market angle is underdeveloped

The finding that "RUS, ITA, DEU, CAN, FRA show strong Advanced adoption" but "few KOR/JPN bundles spend there" effectively closes off that avenue. But the doc doesn't pivot to ask: **what are the competitive conditions in KOR/JPN's primary target markets (KOR, JPN, TWN, SEA)?** Are competing DSPs also firing aggressive clicks in those markets? If so, KOR/JPN bundles are losing attribution even in their home markets.

### 6. Statistical rigor gaps

- No **confidence intervals** or **statistical significance tests** on the EFS correlation
- The scatter plot (Avg EFS vs Adv Rate by office) has only ~8 data points — a trend line here is not statistically meaningful
- No control for **confounders**: genre, spend tier, OS mix, advertiser maturity all correlate with both EFS and Advanced adoption
- A simple logistic regression (`is_advanced ~ EFS + office + genre + spend_tier`) would clarify whether EFS has independent predictive power

### 7. Missing dimension: Performance impact

The doc focuses on adoption patterns but doesn't show **what happens after migration**. Adding a "before/after" or "Advanced vs Recommended performance comparison" (even from the existing internal ACS impact analyses) would strengthen the activation narrative. Sales teams need ammunition: "Bundles that switched to Advanced saw X% more attributed installs / Y% lower effective CPI."

### 8. Lead list prioritization needs a scoring framework

The notebook identifies 412 quick-win bundles (high EFS, non-Advanced, KOR/JPN). But not all are equal. A simple scoring framework would help:

- **Spend volume** (bigger = higher impact)
- **EFS level** (higher = more to gain from Advanced)
- **Genre competitive intensity** (from the global heatmap)
- **Multi-DSP usage** (Benita's parallel workstream)

Rank the 412 by composite score and present the top 20–30 as the priority activation list.

---

## Summary of Recommendations


| Priority | Action                                                                                                              |
| -------- | ------------------------------------------------------------------------------------------------------------------- |
| **P0**   | Write the TL;DR and Recommendations — the analysis is rich enough to synthesize now                                 |
| **P1**   | Reframe EFS as a suitability indicator, not a causal driver; correct the ACS mechanism description                  |
| **P1**   | Add performance impact data (before/after Advanced migration) from existing internal analyses                       |
| **P2**   | Investigate JPN's ACS_CUSTOM settings — are they more or less aggressive?                                           |
| **P2**   | Add competitive landscape for KOR/JPN home markets (are competing DSPs aggressive there too?)                       |
| **P3**   | Run a simple logistic regression to test if EFS has independent predictive power after controlling for office/genre |
| **P3**   | Build a lead scoring framework for the 412 quick-win bundles                                                        |


