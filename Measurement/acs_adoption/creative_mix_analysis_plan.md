# Section 9: ACS Advanced Adoption by Engaged Creative Format Mix

## Objective

Analyze whether bundles with a **higher share of engaged creative formats** (VI, RI, NV) are more likely to adopt ACS Advanced — and how this relationship varies across offices.

Section 8 already compares ACS adoption **per format** (e.g., "what % of VI spend is Advanced?"). This section flips the perspective to the **bundle level**: "given a bundle's overall creative mix, does heavier use of engaged formats correlate with Advanced adoption?"

## Key Metric

**Engaged Format Share (EFS)**: For each bundle, the percentage of total spend allocated to engaged formats (VI + RI + NV) vs. non-engaged formats (Banner, Other).

```
EFS = (VI_spend + RI_spend + NV_spend) / total_spend
```

## Bucketization

EFS will be bucketed into discrete ranges for the heatmap:


| Bucket | EFS Range                   |
| ------ | --------------------------- |
| 0%     | EFS = 0 (Banner/Other only) |
| 1–25%  | 0 < EFS ≤ 0.25              |
| 26–50% | 0.25 < EFS ≤ 0.50           |
| 51–75% | 0.50 < EFS ≤ 0.75           |
| 76–99% | 0.75 < EFS < 1.00           |
| 100%   | EFS = 1 (Engaged only)      |


## Analysis Steps

### 9-0. Compute Bundle-Level EFS

- **Input**: `df_fmt` from cell 40 (already queried: bundle × cr_format × ACS mode × spend) and `bundle_profile` from cell 41 (format share columns per bundle).
- For each bundle (office × product_id × app_market_bundle):
  - Sum spend across VI + RI + NV → `engaged_spend`
  - `EFS = engaged_spend / bundle_total_spend`
  - Assign `efs_bucket` based on the ranges above
- Also carry forward: dominant `acs_mode`, `is_advanced`, `bundle_total_spend`
- Print distribution of bundles and spend across EFS buckets.

### 9-1. Heatmap: ACS Advanced Adoption by EFS Bucket × Office

- **Axes**: rows = EFS bucket (ordered 0% → 100%), columns = office (sorted by overall Advanced adoption rate, same order as Section 2/8)
- **Cell value**: Advanced adoption rate (spend-weighted)
  - = `sum(spend where acs_mode = Advanced) / sum(total spend)` for that bucket × office
- **Filter**: offices with ≥ $10K total spend; top 15 offices by total spend
- **Annotation**: show rate as percentage; cell size/text annotation with spend volume ($M) as secondary info
- **Color**: RdYlGn (red = low adoption, green = high)

**Expected insight**: If engaged formats and Advanced ACS are complementary, we should see higher Advanced adoption in higher EFS buckets. If KOR/JPN deviate from this pattern, it highlights a specific opportunity.

### 9-2. Distribution: Bundle Count & Spend by EFS Bucket × Office

- Stacked bar chart or grouped bar showing:
  - **x-axis**: Office
  - **y-axis**: Spend (or bundle count)
  - **color**: EFS bucket
- This contextualizes the heatmap — shows whether low-adoption cells have meaningful spend volume.

### 9-3. Scatter: EFS vs. Advanced Adoption Rate (Office-Level)

- One dot per office
- **x-axis**: Average EFS (spend-weighted) for that office
- **y-axis**: Advanced adoption rate (spend-weighted) for that office
- **Size**: Total spend
- **Label**: Office name
- Overlay a trend line to show correlation.

**Expected insight**: Offices with higher average EFS may naturally have higher Advanced adoption. Offices below the trend line are underperforming given their creative mix.

### 9-4. KOR/JPN Deep-Dive: EFS Bucket Breakdown

- For KOR and JPN specifically:
  - Show the EFS distribution of bundles (histogram)
  - Within each EFS bucket, show Advanced vs. non-Advanced split (spend)
  - Identify "quick win" bundles: high EFS + non-Advanced (these bundles already use engaged formats but haven't adopted Advanced ACS → natural migration candidates)

## Data Dependencies

All data is already available from existing queries:

- `df_fmt` (cell 40): bundle × cr_format × ACS mode × spend
- `bundle_profile` (cell 41): bundle-level format shares + dominant ACS mode

No new BQ queries needed — this is purely a post-processing and visualization extension.

## Output Summary


| Step | Type      | Description                                         |
| ---- | --------- | --------------------------------------------------- |
| 9-0  | Data prep | Compute EFS, assign buckets                         |
| 9-1  | Heatmap   | ACS Advanced adoption: EFS bucket × office          |
| 9-2  | Bar chart | Spend distribution: EFS bucket × office             |
| 9-3  | Scatter   | Office-level EFS vs. Advanced adoption              |
| 9-4  | Deep-dive | KOR/JPN bundle-level EFS histogram + quick-win list |


