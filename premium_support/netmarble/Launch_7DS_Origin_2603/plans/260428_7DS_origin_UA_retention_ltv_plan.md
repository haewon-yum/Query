# 7DS: Origin — UA Opportunity: Retention as a Predictor of I2P and ARPPU

**Date:** 2026-04-28
**Bundle:** `com.netmarble.nanaori` (Android)
**Ticket context:** [ODSB-17637](https://mlc.atlassian.net/browse/ODSB-17637)
**Related plan:** `260428_7DS_origin_RE_opportunity_analysis_plan.md`

---

## 1. Objective

Validate whether users with longer early retention deliver higher Install-to-Purchase (I2P) rates and higher ARPPU — and if so, quantify the LTV premium of a retained user relative to a churned one. The goal is to establish a data-grounded case for targeting user quality (not just volume) in UA campaigns for 7DS: Origin.

---

## 2. Hypothesis Structure

**Core hypothesis:** Early retention is a positive predictor of lifetime monetization.

Decomposed into three testable sub-hypotheses:

| # | Sub-hypothesis | What we expect to see |
|---|---------------|-----------------------|
| H1 | **Retained users convert to payers at higher rates** | I2P for D7-retained users > I2P for D1-only retained users > I2P for D0-only (installed, never returned) |
| H2 | **Retained users spend more per payer (higher ARPPU)** | ARPPU at DX is monotonically higher for cohorts with longer observed retention |
| H3 | **The revenue gap widens over time** | At D7, the retained/churned ARPU gap is already visible; by D21 it has widened further |

> **Causal note:** Retention and monetization are both driven by underlying user quality. Longer retention does not *cause* higher ARPPU — a highly engaged user will do both naturally. The actionable implication is not "keep users retained to make them pay more" but rather "early retention is a leading indicator of LTV, so UA should be evaluated against D7 retention quality, not just CPI."

---

## 3. Key Metrics

| Metric | Definition | Why it matters |
|--------|-----------|----------------|
| **Retention rate at DX** | % of D0 installers who had ≥1 non-install event on day X (or within D0–DX window) | Establishes the retention curve shape for this title |
| **I2P (Install-to-Purchase)** | % of cohort users with `event.name = 'revenue'` at any point during observation window | Direct measure of monetization penetration |
| **ARPU at DX** | Cumulative revenue / all cohort users at day X | Includes zero-revenue users; conservative LTV proxy |
| **ARPPU at DX** | Cumulative revenue / paying users at day X | Revenue intensity for payers; excludes non-payers |
| **Time-to-first-purchase (TTP)** | Day of first revenue event relative to install date | Reveals whether payers convert early (within D1) or progressively |
| **Cumulative revenue share** | % of observed D21 revenue earned by D1 / D3 / D7 | Monetization curve shape; tells us how front-loaded revenue is |

---

## 4. Cohort Design

### 4.1 Install cohort

**Base cohort:** All users with `event.name = 'install'` for `com.netmarble.nanaori` since launch (2026-04-06).

**Retention milestone segments** (mutually exclusive, escalating):

| Segment | Definition | Expected characteristic |
|---------|-----------|------------------------|
| D0-only | Installed but never returned (0 non-install events after install day) | Lowest quality — likely non-engaged installs |
| D1-retained | Had ≥1 non-install event on D1 but not D7 | Mild engagement, churned early |
| D7-retained | Had ≥1 non-install event within D1–D7 window AND active at D7 | Core engaged users |
| D14-retained | Active at D7 AND D14 | Sticky users — highest LTV expected |

> **Scope constraint:** 7DS: Origin launched 2026-04-06 (22 days ago as of today). D14-retained is observable for all install cohorts. D21 is observable only for the earliest cohorts (installed Apr 6–7). Design analysis to use **D14 as the primary LTV proxy**, with D21 as a directional supplement where sample allows.

### 4.2 Revenue observation window

- **Primary:** Cumulative revenue at D7 and D14 from install date
- **Supplemental:** D21 for early-cohort users (installed Apr 6–10)

---

## 5. Analysis Sections

### Section 0 — Retention Curve (pre-requisite)

Plot D1, D3, D7, D14, D21 retention rates for the full install cohort. This establishes:
- How quickly users churn (decay shape)
- Whether there is a natural "stickiness threshold" (e.g., if D7 retention is high, the title retains well)
- Baseline to benchmark against genre norms

**Output:** Retention curve chart (% retained by day, line chart)

---

### Section 1 — I2P by Retention Milestone

For each retention segment (D0-only, D1-retained, D7-retained, D14-retained):
- Count users
- Count payers (ever paid within observation window)
- Compute I2P = payers / users
- Compute 95% confidence interval on I2P (binomial CI)

**Expected pattern:** I2P should increase monotonically across retention segments. If H1 holds, D7-retained users will have significantly higher I2P than D1-only users.

**Output:** Bar chart of I2P by retention segment, with CI error bars

---

### Section 2 — ARPPU by Retention Milestone

For paying users within each retention segment:
- Cumulative ARPPU at D7 and D14
- Distribution of per-user revenue (median, P75, P90) to understand skewness
- Flag if a small number of whales drives ARPPU differences

**Expected pattern:** ARPPU should be higher in longer-retained segments. If a handful of high-spenders are driving the signal, flag the P90 contribution.

**Output:** Bar chart of ARPPU at D7 and D14 by retention segment; revenue distribution violin plot

---

### Section 3 — ARPU Progression (Monetization Curve)

For the full install cohort (not segmented):
- Cumulative ARPU at D1, D3, D7, D14 (and D21 where observable)
- What % of D14 revenue is earned by D1 / D3 / D7?

This answers: **how front-loaded is 7DS: Origin monetization?** A front-loaded title (most revenue by D3) has different UA economics than a back-loaded title.

**Cross-reference with RE plan:** The RE analysis showed D7 revenue per user decays sharply after ~7 days inactive. This section shows the mirror: how revenue accumulates *within* an active user's early life.

**Output:** Line chart of cumulative ARPU by day (D0–D14); table of % D14 revenue captured at each milestone

---

### Section 4 — Time-to-First-Purchase Distribution

For all payers:
- Day of first `revenue` event relative to install date
- Histogram of TTP (D0, D1, D2, ..., D14)
- Cumulative % of payers converted by day X

This answers: **when do users decide to pay?** If 80% of payers convert within D3, then D3 is the critical monetization window and UA creative/targeting should prioritize early engagement.

**Output:** Histogram + CDF of TTP; highlight the day by which 50% / 80% of payers have converted

---

### Section 5 — UA Implication: LTV-Adjusted CPA Target

If H1–H3 are validated, translate findings into a UA CPA target framework:

```
Expected ARPU at D14 = f(D7 retention rate, I2P, ARPPU)

LTV-adjusted max CPI = Expected ARPU at D14 × (1 - target margin)
```

Segment this by install cohort quality proxy (e.g., if Moloco-attributed users have higher D7 retention than unattributed, the Moloco-attributed CPI can be higher).

**Key comparison:** Moloco-attributed users vs unattributed users — do they differ on retention and I2P? If Moloco drives higher-quality users (better D7 retention, higher I2P), this directly supports a higher CPI bid and better CPI Balancer target.

**Output:** Summary table: retention rate, I2P, ARPU@D14 by attribution segment; LTV-adjusted CPI range

---

## 6. Data Sources

| Purpose | Table | Notes |
|---------|-------|-------|
| Install events | `focal-elf-631.prod_stream_view.pb` | `event.name = 'install'` — defines D0 cohort |
| Retention events | Same pb table, `event.name != 'install'` | Non-install events define retention |
| Revenue | Same pb table, `event.name = 'revenue'`, `event.revenue_usd.amount` | Only non-null on revenue rows |
| Attribution flag | `moloco.attributed` BOOLEAN | For Section 5 attribution split |

**Date range:** `DATE(timestamp) >= '2026-04-06'` (launch date)

---

## 7. Caveats & Limitations

| Caveat | Implication |
|--------|-------------|
| **22-day title history** | D21+ retention observable only for the earliest install cohorts (Apr 6–10). All conclusions are directional. Re-run at D30 and D60 for mature-title validation. |
| **User quality ≠ retained causally** | Retention predicts LTV but does not cause it. The mechanism is user quality → both. Do not frame as "longer retention makes users pay more." |
| **Revenue is right-censored** | Users installed later in the window have fewer days of observation. Use only fully-observed windows (e.g., for D7 revenue, restrict to users installed ≥ 14 days ago). |
| **pb table is unsampled** | `prod_stream_view.pb` — no scaling needed. |
| **No holdout for attribution quality** | Comparing Moloco vs unattributed users (Section 5) has selection bias — Moloco targeted specific user segments. The observed quality difference may reflect targeting precision, not incremental quality. |
| **ARPPU skewness** | Mobile RPG revenue is heavily whale-driven. Small n in high-retention segments may produce unstable ARPPU estimates. Flag any segment with n_payers < 30 as unreliable. |

---

## 8. Implementation Plan

### Step 0 — Install cohort extraction
Query all distinct `device.ifa` with `event.name = 'install'` since launch. Record install date and `moloco.attributed` flag.

### Step 1 — Retention milestone tagging
For each install user, compute: active at D1 (Y/N), D3, D7, D14. Assign to retention segment (D0-only, D1-retained, D7-retained, D14-retained).

### Step 2 — Revenue aggregation
For each install user, sum `event.revenue_usd.amount` within D0–D7 and D0–D14 windows. Tag payer (Y/N).

### Step 3 — Section 0: Retention curve
Aggregate by install day + observation day. Plot.

### Step 4 — Sections 1–2: I2P and ARPPU by retention segment
Groupby retention segment. Compute I2P with CI. Compute ARPPU distribution.

### Step 5 — Section 3: Monetization curve
Compute daily cumulative ARPU for the full cohort.

### Step 6 — Section 4: TTP distribution
For payers, group by days-since-install at first revenue event.

### Step 7 — Section 5: UA implication
Attribution split. LTV-adjusted CPI table.

---

## 9. Output Destination

- **Notebook:** `260428_7DS_origin_UA_retention_ltv_analysis.ipynb`
- **Report:** HTML export (expandable KOR sensitivity section, same format as RE report)
- **Deck slide:** Retention curve + LTV-adjusted CPI table — 2 slides for Netmarble pitch

---

## 10. Open Questions

- [ ] What is the genre benchmark for D7 retention in Korean mobile RPG? (needed to contextualize the title's retention curve)
- [ ] Does Moloco have app-level attribution data showing which creative or audience segment drove the highest-retention installs?
- [ ] Is D14 retention sufficient as LTV proxy, or should we wait for D28 before drawing UA pricing conclusions?
- [ ] For the LTV-adjusted CPI (Section 5): does Netmarble have a target ROAS or margin requirement for UA that we should back-solve against?
