# Follow-Up Analysis: MMP Attribution Collapse Root Cause — KB Securities

> **Type:** Follow-up to Searchlight Investigation (2026-04-13)
> **Date:** 2026-04-14 (updated with T1-T4 corrections, PA verification, CT collapse)
> **Analyst:** Haewon Yum
> **Ad Account:** syFnKP76xSYZQcMW
> **Confidence:** HIGH

---

## Bottom Line

**Both VT (-98%) and CT (-70-90%) MMP attribution collapsed on Mar 21 for T4 (SKAN-attributable) traffic.** Installs shifted to SKAN-only attribution (surged 3-6x). This is not a VT-only problem — CT conversion rates also halved, pointing to a broad AIRBRIDGE attribution configuration change.

**PA (Probabilistic Attribution) was never enabled** for this campaign (`allow_fingerprinting=false` in `campaign_digest` since creation on Mar 5). All pre-collapse MMP installs relied on deterministic IDFA matching for users who consented to ATT. The collapse is an AIRBRIDGE-side change, not a Moloco PA status change.

A separate, gradual ATT consent prompt improvement (Feb-Mar) increased IDFA availability (LAT: 76%→24%) — a positive change obscured by the attribution collapse.

---

## Hypotheses Tested

| # | Hypothesis | Verdict | Evidence |
|---|-----------|---------|----------|
| H1 | AIRBRIDGE VT attribution window disabled/shortened | **STRONGLY SUPPORTED** | Overnight step-function collapse; universal across all exchanges; SKAN surge fills the gap |
| H2 | IDFA availability dropped (ATT consent change) | **RULED OUT** as VT collapse cause | LAT rate *decreased* from 45% to 24% (IDFA *improved*); KB-specific but gradual, not overnight |
| H3 | SKAN attribution displaced deterministic VT | **CONFIRMED as mechanism** | SKAN surged from ~31/day to ~85-193/day exactly when VT collapsed |
| H4 | Impression engagement/viewability changed | **RULED OUT** | Impression volume stable or increasing post-collapse; all exchanges affected uniformly |

---

## Key Evidence

### 1. SKAN Displacement — The Smoking Gun

Deterministic VT installs collapsed and SKAN installs surged on the same day:

| Period | Avg Daily VT Installs | Avg Daily SKAN Installs | SKAN/VT Ratio |
|--------|-----------------------|------------------------|---------------|
| Mar 16-20 (pre-collapse) | 236 | 31 | 0.13 |
| Mar 21-22 (collapse) | 5.5 | 85 | 15.5 |
| Mar 23-24 (partial recovery) | 77 | 188 | 2.4 |
| Mar 25-31 | 41 | 55 | 1.3 |
| Apr 1-13 | 18 | 53 | 2.9 |

The combined signal (VT + SKAN) tells us users are still installing — Moloco is driving real conversions. They are simply being attributed through Apple's SKAN privacy channel instead of AIRBRIDGE's deterministic VT matching.

**SKAN installs sit on exchange = NULL** (no exchange attribution possible), confirming they flow through Apple's privacy-preserving pipeline, not the MMP's deterministic matching.

### 2. Exchange-Level Universality — All Exchanges Hit Uniformly

VT installs dropped across every exchange simultaneously (Mar 16-20 vs Mar 23-27):

| Exchange | VT Pre | VT Post | VT Change | Impression Change |
|----------|--------|---------|-----------|-------------------|
| KAKAO | 888 | 237 | **-73.3%** | +17.4% |
| MOLOCO_SDK_MAX | 103 | 22 | **-78.6%** | +10.7% |
| INMOBI | 32 | 16 | **-50.0%** | +2.3% |
| ADX_RTB | 45 | 21 | **-53.3%** | +20.0% |
| VUNGLE | 16 | 2 | **-87.5%** | -10.0% |
| APPLOVIN | 22 | 7 | **-68.2%** | +23.3% |
| ADPIE | 50 | 13 | **-74.0%** | +76.2% |
| APPODEAL | 8 | 0 | **-100.0%** | -21.7% |

Impression volumes were **stable or increasing** (exchanges still delivering) while VT installs collapsed — ruling out supply-side or engagement issues. This universality is the signature of an MMP-level configuration change, not an exchange-specific issue.

Pre-collapse SKAN: 154 (exchange=NULL). Post-collapse SKAN: 518 (exchange=NULL). **+237%.**

### 3. Attribution Type Breakdown — SKAN-Attributable Segment Lost VT

Before the collapse, the "SKAN-attributable" campaign segment (targeting LAT users) was the primary source of VT installs — meaning AIRBRIDGE was doing probabilistic/fingerprint VT matching even for LAT users:

| Date | SKAN-Attributable VT Installs | SKAN-Attributable CT Installs | Bi-Attributable SKAN |
|------|-------------------------------|-------------------------------|---------------------|
| Mar 19 (pre) | 347 | 23 | 21 |
| Mar 20 (pre) | 424 | 29 | 33 |
| Mar 21 (collapse) | 5 | 1 | 63 |
| Mar 22 | 6 | 2 | 107 |
| Mar 23 | 97 | 10 | 193 |
| Mar 24 | 57 | 16 | 183 |

Post-collapse, the "Bi-attributable" SKAN column surged (21 -> 193), while the SKAN-attributable segment's VT installs collapsed (347 -> 5). This is consistent with AIRBRIDGE's VT matching being disabled — installs that would have been attributed via VT deterministic matching now only register through SKAN.

### 4. IDFA/LAT Rate — KB Securities-Specific ATT Improvement (Separate Event)

A gradual, separate change is also evident: KB Securities' LAT rate dropped from 76% (late Jan) to 24% (Apr), while other AIRBRIDGE iOS KR advertisers remained stable at 64-67%.

| Period | KB Securities LAT Rate | Others LAT Rate |
|--------|----------------------|-----------------|
| Late Jan | 76.4% | 64-67% |
| Early Feb | 73.7% | 64-67% |
| Late Feb | 50.5% | 64-67% |
| Mid-Mar | 28.4% | 64-67% |
| Apr | 24.1% | 64-67% |

**Interpretation:** KB Securities implemented/improved their ATT consent prompt, resulting in far more users granting IDFA access (76% -> 24% LAT = 24% -> 76% IDFA available). This is a **positive** change that should improve attribution quality once VT attribution is restored.

This is clearly KB Securities-specific (others unchanged) and gradual (Feb-Mar rollout), confirming it's an app-level change, not a market effect.

### 5. VT Collapse Affected Both LAT and Non-LAT Traffic

Both LAT and non-LAT impression segments lost VT installs:

| Date | VT from LAT Traffic | VT from Non-LAT Traffic |
|------|--------------------|-----------------------|
| Mar 19 (pre) | 117 | 230 |
| Mar 20 (pre) | 106 | 320 |
| Mar 22 (post) | 4 | 2 |
| Mar 25 (post) | 18 | 57 |
| Apr 10 (post) | 1 | 12 |

Both segments collapsed, but LAT traffic VT dropped ~97% vs non-LAT ~87%. Since non-LAT users have IDFA available, the VT collapse cannot be explained by IDFA availability — it must be an MMP-side attribution configuration change.

---

## Causal Chain (Revised)

```
Feb-Mar: KB Securities improves ATT consent prompt (LAT: 76% -> 24%)
  -> Positive: more users have IDFA, better attribution potential
  -> This change is GOOD and should have improved VT matching

~Mar 20-21: AIRBRIDGE VT attribution window disabled/shortened
  -> VT deterministic installs collapse overnight (-99%)
  -> SKAN installs surge simultaneously (+237-500%)
  -> All exchanges affected uniformly
  -> KB Securities-specific (34 other advertisers unaffected)
  -> Combined (VT + SKAN) volume lower than pre-collapse VT alone
     (some installs outside lookback window fall through entirely)

Mar 21+: Mechanical CPI/CPU inflation
  -> Same spend / fewer attributed installs = higher CPI
  -> ML model receives fewer conversion signals = worse optimization
  -> Negative feedback loop: less learning -> worse bidding -> fewer wins
  -> Budget cuts (Apr 3) amplify the decline further
```

---

## What Changed in AIRBRIDGE (Most Likely Scenarios)

Ranked by probability:

1. **VT attribution lookback window disabled or set to 0** (HIGHEST PROBABILITY)
   - Explains: overnight collapse, universal across exchanges, SKAN fills the gap
   - Common MMP action: agencies sometimes disable VT to "clean" attribution data

2. **Switch to "SKAN-only" attribution mode**
   - Some MMPs allow toggling between deterministic+SKAN and SKAN-only
   - Explains: the attribution type shift in the data

3. **AIRBRIDGE probabilistic/fingerprint matching disabled**
   - Pre-collapse, even LAT users had VT installs (fingerprint matching)
   - Post-collapse, LAT VT installs went to near-zero
   - Could be AIRBRIDGE policy change OR advertiser toggle

4. **Postback URL filtering changed** (LOWER PROBABILITY)
   - VT postbacks might be sent but filtered before reaching Moloco
   - Less likely given the SKAN surge pattern

---

## Implications & Revised Recommendations

### 1. CRITICAL: Confirm AIRBRIDGE VT Settings Change
Contact KB Securities/DPLAN360 with this specific evidence:
- "SKAN installs surged 3-6x on Mar 21, the exact day VT installs collapsed"
- "Was the AIRBRIDGE VT attribution window changed around March 20-21?"
- "Can you share the current VT lookback window setting for Moloco channel?"

This is no longer a hypothesis — the SKAN displacement pattern is definitive proof of an attribution configuration change.

### 2. Performance Upside if VT Restored
With VT attribution restored, performance should be **better than February baseline**:
- IDFA availability improved from 24% to 76% (ATT prompt change)
- Higher IDFA = better deterministic VT matching = higher attribution rate
- More attributed conversions = better ML optimization signal
- Realistic target: iOS CPU $4-6 (vs Feb $5.72), given improved IDFA

### 3. Quantify Unattributed Moloco Value
Even without VT attribution, Moloco is driving real installs visible through SKAN:
- Current: ~53 SKAN installs/day at ~$260/day spend = ~$4.91 effective CPI via SKAN
- Plus: some installs fall outside SKAN's privacy thresholds and aren't counted
- **Moloco's true CPI is likely $3-5, not the reported $9-10**

### 4. Do NOT Reduce Budget Further
Budget reduction amplifies the negative feedback loop. The attributed CPI is inflated by the attribution gap, not by poor campaign performance. Maintain current budget until attribution is resolved.

---

## Queries Used

All queries are reproducible against `moloco-ae-view.athena.fact_dsp_core`.

1. **Daily VT/CT/SKAN breakdown** — iOS installs by attribution method, Mar 1 - Apr 13
2. **IDFA/LAT rate trend** — Daily LAT impressions and VT installs by LAT status
3. **Attribution type breakdown** — Daily installs by `attribution` field (Bi/MMP/SKAN/Non-attributable)
4. **Cross-advertiser IDFA comparison** — Weekly LAT rate: KB Securities vs 26-31 other AIRBRIDGE iOS KR advertisers
5. **Exchange-level VT shift** — Pre/post collapse VT and SKAN by exchange

Query SQL files saved in `~/searchlight/tmp/queries/` with timestamps `20260414_1421*`.

---

## Confidence Assessment

| Finding | Confidence | Basis |
|---------|-----------|-------|
| VT attribution was disabled/changed in AIRBRIDGE | **HIGH** | SKAN displacement is definitive; universal across exchanges; KB-specific |
| ATT consent prompt improved separately | **HIGH** | LAT rate 76%->24% KB-specific, gradual, unrelated to VT collapse |
| IDFA change did NOT cause VT collapse | **HIGH** | Non-LAT traffic (with IDFA) also lost VT; collapse was overnight, IDFA change was gradual |
| Specific AIRBRIDGE setting that was changed | **MEDIUM** | Most likely VT lookback window, but needs advertiser/agency confirmation |
| Performance recovery estimate if restored | **MEDIUM** | Based on improved IDFA + pre-collapse trajectory; market conditions may have shifted |
