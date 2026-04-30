# Section 11: CTR as a Proxy for Click Sensitivity × ACS Advanced Adoption

## Hypothesis

Advertisers (or their AMs) with lower click tolerance may resist ACS Advanced because it adds incremental attribution clicks (engaged view clicks, engaged clicks), inflating the MMP-visible CTR. Bundle-level CTR might serve as a proxy for this tolerance. If so, we'd expect CTR patterns to differ between Advanced vs. non-Advanced bundles, and between offices (especially KOR/JPN vs. others).

## Key Challenge: Endogeneity (Resolved)

Initial concern: ACS Advanced mechanically increases CTR, so comparing raw CTR across modes would be circular.

**Resolution via metric definitions** (verified empirically on 2026-02-28 data):

| Field | Definition | Approx. rate |
|-------|-----------|-------------|
| `clicks` | **True user clicks** (tap on ad) — independent of ACS mode | ~2.6–3.7% |
| `clicks_ev` | Engaged View clicks (3s video view → attribution click, ACS-generated) | 0–4.9% |
| `clicks_ec` | Engaged Clicks (impression-based attribution, ACS-generated) | 0–1.3% |

These three fields are **separate and additive** — `clicks` does NOT include `clicks_ev` or `clicks_ec`:

| ACS Mode | User CTR (`clicks`) | EV rate (`clicks_ev`) | EC rate (`clicks_ec`) | **Total CTR (MMP-visible)** |
|----------|--------------------|-----------------------|----------------------|---------------------------|
| Advanced | 2.63% | 4.91% | 1.29% | **8.83%** |
| Recommended | 2.75% | 1.54% | 0.63% | **4.92%** |
| Conservative | 2.97% | 1.09% | 0.18% | **4.23%** |
| ACS_CUSTOM | 3.71% | 1.77% | 0.08% | **5.56%** |
| NO_ACS | 2.70% | 0.0% | 0.0% | **2.70%** |

**Implication**: We can safely use `clicks / impressions` as "User CTR" without endogeneity concerns. And `(clicks_ev + clicks_ec) / impressions` captures the ACS-generated click uplift that MMPs see (and that may trigger CTR/rejected-install concerns from advertisers).

## CTR Metrics

- **User CTR** = `clicks / impressions` — true user taps, clean across ACS modes
- **MMP-visible CTR** = `(clicks + clicks_ev + clicks_ec) / impressions` — what the advertiser/MMP sees
- **ACS Click Uplift** = `(clicks_ev + clicks_ec) / impressions` — the incremental CTR from ACS

## Analysis Steps

### 11-0. Compute bundle-level CTR metrics

For each bundle (office × product_id):

- `user_ctr` = clicks / impressions
- `mmp_ctr` = (clicks + clicks_ev + clicks_ec) / impressions
- `acs_uplift` = (clicks_ev + clicks_ec) / impressions
- Carry: `office`, `genre`, `is_advanced`, `acs_mode`, total spend, impressions

### 11-1. CTR distribution: Advanced vs. Non-Advanced

- Side-by-side histogram of **User CTR** for Advanced vs. Non-Advanced bundles (globally)
- Verify that User CTR is comparable across ACS modes (confirming it's a clean metric)
- Print summary: median/mean User CTR, MMP CTR, and ACS Uplift by ACS mode

### 11-2. Heatmap: User CTR bucket × office → Advanced adoption rate

- Bucketize **User CTR** into quantile-based bins (e.g., Q1–Q5 or deciles)
- For each User CTR bucket × office: compute spend-weighted Advanced adoption rate
- Heatmap with KOR/JPN first (consistent with Section 9)

**Expected insight**: If CTR tolerance drives adoption, we might see higher Advanced adoption in higher User CTR buckets (advertisers already comfortable with clicks). If the pattern is flat, CTR tolerance is not a meaningful barrier.

### 11-3. ACS Click Uplift by office

- For Advanced bundles only: show the distribution of ACS click uplift by office
- This quantifies "how much does Advanced inflate MMP-visible CTR?" — if KOR/JPN AMs cite CTR concerns, this shows the actual magnitude they'd face

### 11-4. Scatter: Office-level User CTR vs. Advanced adoption

- One dot per office
- x = median User CTR (all bundles — this metric is ACS-mode-independent)
- y = Advanced adoption rate
- Size = spend
- Trend line

**Expected insight**: Do offices with higher user CTR environments adopt Advanced more readily? Or is it unrelated (supporting the "office decision" finding from Section 10)?

### 11-5. KOR/JPN focus: CTR distribution + what would Advanced add?

- For non-Advanced KOR/JPN bundles: show User CTR distribution
- From Advanced bundles globally (same genre/spend tier): estimate the expected ACS click uplift
- Show: "If these bundles switched to Advanced, their MMP-visible CTR would go from X% to ~Y%" — quantifies the CTR impact that KOR/JPN AMs might fear

## Data Dependencies

All data is already in `df` (base dataset from cell 4-5): `clicks`, `clicks_ev`, `clicks_ec`, `impressions`, `acs_mode`, `office`, `genre`.

No new BQ queries needed.

## Output Summary

| Step | Type | Description |
|------|------|-------------|
| 11-0 | Data prep | Compute bundle-level User CTR, MMP CTR, ACS uplift |
| 11-1 | Histogram | User CTR distribution: Advanced vs Non-Advanced |
| 11-2 | Heatmap | User CTR bucket × office → Advanced adoption rate |
| 11-3 | Box/violin | ACS click uplift distribution by office (Advanced only) |
| 11-4 | Scatter | Office-level User CTR vs. Advanced adoption |
| 11-5 | Deep-dive | KOR/JPN: CTR distribution + estimated Advanced uplift |
