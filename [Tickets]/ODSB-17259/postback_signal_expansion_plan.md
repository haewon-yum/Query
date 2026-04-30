# ODSB-17259 Follow-up: Postback Signal Expansion → Bid Spike Causality

**Date:** 2026-04-03  
**Author:** Haewon  
**Context:** GM shared that "the postback signal for in-app events was expanded on Day 2 — events previously received as attributed-only are now available via full postback." Follow-up question: could this have affected bidding in the install model or retention model?

---

## Campaign & Bundle Reference

| Campaign ID | Label | Role |
|-------------|-------|------|
| `BhTo5PHbtcsuQwkh` | KR iOS Install | CPI spike on Mar 27 |
| `VveaqT1OAcxlbXSv` | US iOS Install | CPI spike on Mar 27 |
| `onLf8YMrzBKrT80y` | KR Retention | No ML training data; never bid |
| `ttIK8j9coo7UMK9r` | Healthy Retention | Control for model comparison |

**App bundle:** `id6550902247` (iOS)  
**Platform:** iOS only

---

## Day Numbering Alignment

The GM's "Day 2" is ambiguous relative to our analysis framework:

| GM's term | UTC date | Label in our existing analysis |
|-----------|----------|-------------------------------|
| Day 1 (launch) | Mar 26 | Day 0 |
| **Day 2 (postback expansion)** | **Mar 27** | **Day 1** |
| Day 3 | Mar 28 | Day 2 |

The bid/win price spike already confirmed on **Mar 27 UTC** aligns exactly with GM's "Day 2." This is the key date for all timing comparisons.

---

## Hypothesis

There are two competing causal mechanisms depending on which event type surged on Mar 27. Both are plausible and not mutually exclusive.

### Hypothesis 1 — In-app events only surged → LTV inflation (retention model)
The expansion unlocked in-app event signals (purchases, logins, retention events) that were previously suppressed for non-Moloco-attributed users. The model saw a sudden enrichment of engagement signals for bundle `id6550902247`, raised its LTV estimate, and the install model bid higher as a result.

```
Postback expansion (Mar 27)
  → In-app event volume ↑ in cv table (install volume stable)
  → Retention model updates LTV estimate for bundle id6550902247
  → Install model bid ↑ via LTV scaling (bid = P(install) × estimated_LTV)
  → Win prices ↑, spend exhausted faster, CPI ↑
  → Budget capper overreacts on Mar 28 → CPI drops sharply
```

### Hypothesis 2 — Install events also surged → P(install) inflation (install model)
If the expansion included non-Moloco-attributed installs (i.e., Moloco now receives full-postback for organic or other-DSP installs), then the install model would have seen more positive install signals for this app and raised P(install) directly — a more direct and stronger mechanism than LTV scaling.

```
Postback expansion (Mar 27)
  → Install event volume ↑ in cv table (attributed + unattributed installs)
  → Install model P(install) estimate ↑ for bundle id6550902247
  → Bid price ↑ directly (bid = P(install) × target_CPI)
  → Win prices ↑, spend exhausted faster, CPI ↑
  → Budget capper overreacts on Mar 28 → CPI drops sharply
```

**Key distinction between the two:**

| | Hypothesis 1 | Hypothesis 2 |
|-|-------------|-------------|
| What surged | In-app events only | Install events (+ possibly in-app) |
| Affected model | Retention model → install model (indirect) | Install model directly |
| Magnitude of effect | Moderate (LTV scaling factor) | Stronger (core probability estimate) |
| Validated by | Check D: install count flat, in-app count ↑ | Check D: install count ↑ on Mar 27 |

**Alternative (null) hypothesis:**  
The spike is a standard cold-start pacing overshoot, and the postback expansion was coincidental. The model increased bids after receiving Day 0 install signals (already attributed), regardless of any expansion. Under this hypothesis, the timing correlation between postback volume and win price is spurious.

**Note on "install model" signal source:**  
If the postback expansion is strictly attributed-only → full postback for in-app events (as GM described), install event count should remain flat — installs were already being postbacked. In that case, Hypothesis 1 is the operative mechanism. Hypothesis 2 applies only if the expansion also included organic/cross-DSP install signals, which would be a broader MMP config change. Check D resolves this directly.

---

## Validation Checks

### Check A — Postback volume step change + event composition (MOST CRITICAL)
**Questions:**
1. Did total postback signal volume (attributed + unattributed) actually increase on Mar 27?
2. Was the surge driven by in-app events only, install events only, or both?

**Source:** `focal-elf-631.prod_stream_view.pb`  
**Rationale:** The `cv` table only contains attributed conversions. The `pb` table records all postback signals received from the MMP regardless of attribution — capturing exactly what the full postback expansion would unlock.

**Granularity:** Hourly, Mar 24–28 (baseline + spike + recovery)  
**Filter:** bundle = `id6550902247`, iOS  
**Group by:** `TIMESTAMP_TRUNC(timestamp, HOUR)`, classify as `install` vs. `in-app`  

**Metrics — report both absolute counts and ratio:**
1. `COUNT(CASE WHEN LOWER(pb.event.name) = 'install' THEN 1 END)` — install event volume per hour
2. `COUNT(CASE WHEN LOWER(pb.event.name) != 'install' THEN 1 END)` — in-app event volume per hour
3. `in_app_count / install_count` — ratio per day (derived from hourly data)

**Interpretation matrix:**

| Install events Mar 26→27 | In-app events Mar 26→27 | Conclusion |
|--------------------------|-------------------------|------------|
| Flat / stable | **Surge** | Expansion unlocked in-app signals only → H1 (LTV inflation) |
| **Surge** | Flat | Expansion unlocked unattributed installs → H2 (direct P(install) effect) |
| **Both surge** | **Both surge** | Full postback for all events; both H1 and H2 active |
| Both flat | Both flat | No expansion visible in pb table; check MMP config |

The hourly split also feeds directly into Check B (timing comparison) — no separate query needed.

---

### Check B — Win price timing vs. postback volume (REVISED from original plan)
**Question:** Did the win price increase precede, coincide with, or follow the postback volume increase?

**Source:** `focal-elf-631.prod_stream_view.imp`  
**Granularity:** Hourly, Mar 26–27  
**Filter:** `api.campaign.id IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv')`  
**Metric:** `AVG(imp.win_price_usd.amount_micro / 1e6)` per hour

> **Note on original point 2:** Hourly bid prices from `focal-elf-631.prod_stream_view.pricing` are theoretically possible but expensive (full table scan with UNNEST). Win price from `imp` is cheaper, already validated via Q4, and is a direct proxy for model aggressiveness on won impressions — sufficient for timing comparison.

**Interpretation logic:**
| Timing pattern | Interpretation |
|---------------|----------------|
| Win price ↑ **before** postback surge | Postback expansion NOT the cause; model reacted to something else (e.g., install signals from Day 0) |
| Win price ↑ **at the same time** as postback surge | Consistent with causal link; need model update cadence to confirm |
| Win price ↑ **hours after** postback surge | Strong temporal evidence for causality |
| No clear hourly postback surge | Expansion may have been gradual; daily comparison still useful |

---

### Check C — Postback training signal quality shift
**Question:** Did the `d1_avg_action_labels` or `cnt` in the postback training table jump on Mar 26–27?

**Source:** `tfexample_action_postback_imp_v4_beta5_merged` (same table queried in existing `onLf8YMrzBKrT80y_postback_training_data.csv`)  
**Existing data covers:** Mar 23–25 (`cnt` = 6, 4, 16)  
**Need to extend to:** Mar 26–28  

**What to look for:**
- Spike in `cnt` on Mar 26 or Mar 27 → model received materially more training signals
- Change in `d1_avg_action_labels` → user quality profile of the signals changed (if organic users from full postback behave differently from attributed users, the label distribution shifts)

**Why this matters:** If `cnt` jumps from ~10/day → 100+/day on Mar 27, that is direct evidence that the model saw dramatically more signal, which would cause it to update its LTV estimate.

---

### Check D — Retention model training data availability
**Question:** Did the retention model gain training data around Mar 27 that it didn't have before?

**Finding from prior analysis:** `onLf8YMrzBKrT80y` (KR Retention) has **zero** impression-level ML training data (`tfexample_action_campaignlog_imp_v2`) — the campaign has never bid, so no finetuning samples exist.

**But:** the postback training table (`tfexample_action_postback_imp_v4_beta5_merged`) shows data from Mar 23. If full postback expanded the signals available here, the `cnt` jump in Check C is the key signal.

**Additional check:** Does the install model for `id6550902247` share a bundle-level LTV signal with the retention model? If yes, the postback expansion would propagate into install model bids even though installs themselves weren't affected. This is an Engineering question — cannot answer from BQ.

---

### Check E — Cross-campaign isolation test
**Question:** Did other iOS install campaigns for the same bundle (`id6550902247`) also show bid spikes? Were campaigns on other bundles unaffected?

**Source:** `moloco-ae-view.athena.fact_dsp_core` (daily, existing data)  
**Approach:** From the 346 cold-start comparison campaigns already pulled, check:
1. What fraction of campaigns launched Mar 26 showed Day 1 spikes? (vs. campaigns launched Mar 24–25 which would not be on "Day 2" of the postback expansion)
2. Are only `id6550902247` campaigns affected, or is it broader?

**Interpretation:**
- If only `id6550902247` campaigns spike on Day 1 → postback expansion is app-specific → supports hypothesis
- If all Mar 26 launches spike on Day 1 → it's a systemic cold-start pattern, not postback-specific
- Already established: 14% of all new iOS CPI campaigns had >1.5x spike; the question is whether the Mar 26 cohort spiked disproportionately

---

### Check F — Model update cadence (Engineering input required)
**Cannot be answered from BQ.** Must ask ML/Infra team:

1. Does the install/retention model retrain on a batch schedule (daily, weekly) or continuously?
2. What was the model version active on Mar 27 for bundle `id6550902247`?
3. When were Mar 26 postback signals ingested into training? (Mar 27 batch? Mar 28?)

**Why this matters for the hypothesis:**
- If batch daily retrain (e.g., 2am UTC): Mar 26 signals → Mar 27 model update → Mar 27 bids. Timing is perfect.
- If online/streaming: Mar 27 signals could affect same-day bids, with a 1–6 hour lag.
- If weekly batch: postback signals from Day 2 couldn't have affected Day 2 bids at all → hypothesis is falsified.

---

## Data Feasibility Summary

| Check | Source | Granularity | Cost | BQ-answerable? |
|-------|--------|-------------|------|----------------|
| A. Postback volume + event composition | `pb` | Hourly | Medium | Yes |
| B. Win price timing | `imp` | Hourly | Low | Yes (Q4 pattern) |
| C. Postback training signal quality | `postback_imp_v4_beta5` | Daily | Low | Yes (extend existing file) |
| D. Retention model training data | `campaignlog_imp_v2` | Daily | Low | Partially (retention campaign has 0) |
| E. Cross-campaign isolation | `fact_dsp_core` | Daily | Low | Yes (existing 346-campaign file) |
| F. Model update cadence | Engineering | — | — | No — requires Engineering |

---

## What We Cannot Determine from BQ

- Whether the model explicitly used postback signals as an input to the install bid price on Mar 27
- Exact model version or checkpoint active on Mar 27
- Whether attributed vs. full postback users have different downstream action rates (would need holdout experiment)
- Causal attribution with certainty — even with perfect timing correlation, install model cold-start alone (as established in prior analysis) is a plausible alternative explanation

---

## Implementation Order

1. **Check C first** (cheap, daily, existing table) — extend `postback_training_data.csv` to Mar 26–28. If `cnt` is stable (~10-20/day), postback expansion had no material impact on model training volume and the hypothesis weakens significantly.
2. **Check A** (hourly pb events) — confirm volume step-change and decompose into install vs. in-app to determine H1 vs. H2.
3. **Check B** (hourly win price) — overlay with Check A results to assess timing lag.
4. **Check D + E** (retention model training data + cross-campaign) — fast sanity checks using existing or cheap queries.
5. **Check F** — formulate one Engineering question after BQ checks are complete.

---

## Output Target

Add a new section to `ODSB-17259_install_cpi_spike.ipynb`:

```
## 9. Postback Signal Expansion — Causal Analysis
  9.1 Postback volume (pb): hourly Mar 24–28, install vs. in-app split
  9.2 Win price timing (imp): hourly Mar 26–27 overlaid with postback volume
  9.3 Training signal quality: extend postback_training_data to Mar 26–28
  9.4 Cross-campaign isolation check
  9.5 Summary: supports / weakens / inconclusive on postback hypothesis
```
