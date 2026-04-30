# ACS Advanced Adoption × Engaged Creative Format Hypothesis

**Date:** 2026-03-05
**Context:** ACS adoption meta analysis for KOR/JPN growth opportunity

---

## Original Hypothesis

> "Bundles with higher portions of engaged creative format, such as vi/ri/nv would be more likely to adopt ACS Advanced, as signals from engaged format would be beneficial for models to be trained with more accurate data."

---

## Assessment

### What is ACS?

**ACS = Attribution Click Signaling** — Moloco's system for sending engagement-based attribution clicks to MMPs to recover signal loss and achieve measurement parity with competing DSPs.

ACS modes (Conservative → Recommended → Advanced) control how aggressively Moloco fires attribution clicks:

| Mode | Engaged View (EV) | Engaged Click (EC) | StoreKit/Inline Click | Impression-based Click |
|---|---|---|---|---|
| **Conservative** | vi/nv @ 10s threshold | ri @ first interaction | Rendered, **no click sent** | No |
| **Recommended** | vi/nv @ 10s threshold | ri @ first interaction | Click sent | No |
| **Advanced** | vi/nv @ **3s threshold** | ri @ first interaction | Click sent | **Yes (ri/vi/nv only)** |

Key: All of Advanced's incremental signals (3s EV, impression-based clicks, Smart Click Throttler) **fire exclusively on vi/nv/ri formats**.

---

### First Half: Mechanistically Sound

ACS Advanced's additional click signals exclusively target vi/nv/ri (engaged) formats:

- A **high-EFS bundle** (heavy vi/nv/ri usage) has much more to gain from Advanced — more attribution clicks recovered → better measurement parity with competing DSPs (which fire clicks at 70–90% CTR)
- A **banner-only bundle** gets almost zero incremental benefit from switching to Advanced
- Therefore, **high-EFS bundles are natural candidates for ACS Advanced adoption** — the product's value proposition is strongest for them

### Second Half: Needs Reframing

The phrase *"signals from engaged format would be beneficial for models to be trained with more accurate data"* conflates the mechanism:

- ACS Advanced sends more **attribution clicks to the MMP** for engaged formats → MMP attributes more installs to Moloco → **reduces signal loss**
- This recovered attribution data does feed back into Moloco's ML models (more attributed conversions = better training signal), but the **primary value proposition is measurement parity**, not model training per se
- Competing DSPs fire clicks at 70–90% CTR; without Advanced, Moloco loses attribution to them

### Empirical Evidence: Weak but Directionally Correct

From the notebook analysis (Section 9):

**Global EFS vs. Advanced adoption:**

| EFS Bucket | Bundles | Spend ($M) | Adv Rate |
|---|---|---|---|
| 0% | — | — | — |
| 26–50% | 442 | $49.5 | 26.9% |
| 51–75% | 730 | $84.8 | **22.5%** (dip) |
| 76–99% | 15,473 | $452.8 | 32.0% |
| 100% | 2,465 | $23.3 | 38.7% |

- **Adv bundles mean EFS: 95.4%** vs **Non-Adv: 90.4%** — only 5pp difference
- The distribution is ceiling-compressed (mean 92%, median 100%) — almost all bundles already use engaged formats heavily
- Non-monotonic pattern (dip at 51–75%) weakens a simple "more EFS → more Advanced" narrative

**Office-level data contradicts a simple EFS→adoption story:**

| Office | Avg EFS | Adv Rate |
|---|---|---|
| IND | **59.9%** | **86.0%** |
| SGP | **60.1%** | **63.8%** |
| CHN | 86.7% | 55.0% |
| EMEA | 87.1% | 39.6% |
| USA | 73.6% | 23.6% |
| JPN | 62.9% | 12.1% |
| KOR | 56.0% | 9.2% |

IND and SGP have the **lowest EFS but highest Advanced adoption**, proving that EFS is a **necessary but not sufficient** condition. Adoption is primarily driven by **office-level activation practices and AM recommendations**.

---

## Recommended Framing

> Bundles with higher EFS have more to gain from ACS Advanced, because Advanced's incremental click signals (3s EV, impression-based clicks) fire exclusively on vi/nv/ri formats. **High-EFS, non-Advanced bundles in KOR/JPN represent the strongest quick-win opportunity** — they already run the formats that benefit most from Advanced, but haven't been activated. The 412 such bundles ($22.7M spend) are natural migration candidates for measurement parity.

This framing:
1. Correctly identifies EFS as a **suitability indicator** (not a causal driver of adoption)
2. Grounds the argument in ACS's actual mechanism (attribution click recovery, not model training)
3. Positions the growth opportunity around **activation gap** (office-level practices), not format readiness
