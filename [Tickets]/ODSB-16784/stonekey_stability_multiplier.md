# Stonekey - CPI Balancer Stability Multiplier

**Date calculated**: 2026-03-06 (using impression data from 2026-03-05)

## Campaign Overview

All 13 campaigns are **Stonekey** Android campaigns launched Mar 3-4, 2026.


| Campaign ID      | Title                                          | Goal | Geo                                           |
| ---------------- | ---------------------------------------------- | ---- | --------------------------------------------- |
| HvtBaZCEslMI1rJf | stonekey_launch_JP_And_tROAS_260303            | ROAS | JPN                                           |
| I1UFqtzeIhRkfCrK | stonekey_launch_TW_And_AEO(buy_pet_lv3)_260303 | CPA  | TWN                                           |
| NMrtO3Y5EN9EAiYm | stonekey_launch_DE_And_login_1st_260304        | CPA  | DEU                                           |
| NpO7UWUJVrOW83bd | stonekey_launch_NZ_And_login_1st_260304        | CPA  | NZL                                           |
| UdK42Uv8F2ZdIK5r | stonekey_launch_TW_And_tROAS_260303            | ROAS | TWN                                           |
| VsHwYSeUhcTRbuDQ | stonekey_launch_TW_And_login_1st_260303        | CPA  | TWN                                           |
| cLMYkp0auemwutTK | stonekey_launch_US_And_tROAS_260303            | ROAS | USA                                           |
| huSii8ixFBbQjDXt | stonekey_launch_WW3_And_tROAS_260304           | ROAS | Multi-geo (100+ countries)                    |
| jVkXbQ2LIdIKoaQg | stonekey_launch_WW2_And_tROAS_260303           | ROAS | Multi-geo (HKG, MYS, ITA, ESP, IDN, CYP, MAC) |
| jfPWAJwwT0sXpYGv | stonekey_launch_SG_And_login_1st_260304        | CPA  | SGP                                           |
| nazpxG3J5MareHRz | stonekey_launch_KR_And_tROAS_260303            | ROAS | KOR                                           |
| unbUzFob1WCmTrVD | stonekey_launch_WW1_And_tROAS_260303           | ROAS | Multi-geo (~30 countries)                     |
| znFCczWhy5JTsQHx | stonekey_launch_FR_And_login_1st_260304        | CPA  | FRA                                           |


## Stability Multiplier Results

Calculated using the query templates from [CPI Adjuster doc](https://docs.google.com/document/d/14Egzm6BXQ9X-CFgovlEq4nGijo4WdkDFK2-X4aKZS0M).

### ROAS Campaigns

Formula: `AVG(pred[1] * pred[2] / (norm[1] * norm[2]))`


| Campaign ID      | Title              | Geo               | Stability Multiplier |
| ---------------- | ------------------ | ----------------- | -------------------- |
| jVkXbQ2LIdIKoaQg | stonekey_WW2_tROAS | Multi (7 geos)    | **1.07**             |
| unbUzFob1WCmTrVD | stonekey_WW1_tROAS | Multi (30 geos)   | **1.75**             |
| cLMYkp0auemwutTK | stonekey_US_tROAS  | USA               | **1.94**             |
| UdK42Uv8F2ZdIK5r | stonekey_TW_tROAS  | TWN               | **1.97**             |
| HvtBaZCEslMI1rJf | stonekey_JP_tROAS  | JPN               | **2.07**             |
| nazpxG3J5MareHRz | stonekey_KR_tROAS  | KOR               | **2.51**             |
| huSii8ixFBbQjDXt | stonekey_WW3_tROAS | Multi (100+ geos) | **3.29**             |


### CPA Campaigns

Formula: `AVG(pred[1] / norm[1])`


| Campaign ID      | Title                        | Geo | Stability Multiplier |
| ---------------- | ---------------------------- | --- | -------------------- |
| NMrtO3Y5EN9EAiYm | stonekey_DE_login_1st        | DEU | **0.89**             |
| znFCczWhy5JTsQHx | stonekey_FR_login_1st        | FRA | **1.07**             |
| NpO7UWUJVrOW83bd | stonekey_NZ_login_1st        | NZL | **1.09**             |
| jfPWAJwwT0sXpYGv | stonekey_SG_login_1st        | SGP | **1.22**             |
| VsHwYSeUhcTRbuDQ | stonekey_TW_login_1st        | TWN | **1.46**             |
| I1UFqtzeIhRkfCrK | stonekey_TW_AEO(buy_pet_lv3) | TWN | **11.08**            |


### Flags

- **I1UFqtzeIhRkfCrK (TWN CPA)**: Abnormally high stability multiplier of **11.08** (typical range ~0.5-2.0). May warrant setting a conservative manual multiplier.
- **huSii8ixFBbQjDXt (WW3 ROAS)**: Elevated at **3.29**, likely due to broad 100+ country targeting.
- **nazpxG3J5MareHRz (KR ROAS)**: Elevated at **2.51**.

## Model Architecture Note

These campaigns use `I2I_TF_JOINT` model architecture with prediction_logs structure:

- **ROAS campaigns**: `[I2I_TF_JOINT, ACTION, REVENUE]` at offsets 0/1/2
- **CPA campaigns**: `[I2I_TF_JOINT, ACTION]` at offsets 0/1

## Queries

### ROAS campaigns

```sql
SELECT
  api.campaign.id AS campaign_id,
  AVG(
    SAFE_DIVIDE(
      bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred
        * bid.MODEL.prediction_logs[SAFE_OFFSET(2)].pred,
      bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer
        * bid.MODEL.prediction_logs[SAFE_OFFSET(2)].wrapper.normalizer
    )
  ) AS stability_multiplier
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND api.campaign.id IN (
    'HvtBaZCEslMI1rJf',
    'UdK42Uv8F2ZdIK5r',
    'cLMYkp0auemwutTK',
    'huSii8ixFBbQjDXt',
    'jVkXbQ2LIdIKoaQg',
    'nazpxG3J5MareHRz',
    'unbUzFob1WCmTrVD'
  )
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].type IN ('ACTION', 'ACTION_LAT')
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred > 0
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred <= 1
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer > 0
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer <= 1
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(2)].type = 'REVENUE'
  AND COALESCE(bid.MODEL.prediction_logs[SAFE_OFFSET(1)].reason, '') != 'tf serving prediction is zero'
  AND COALESCE(bid.MODEL.prediction_logs[SAFE_OFFSET(2)].reason, '') NOT IN (
    'tf serving prediction is zero',
    'ineligible and normalizer does not exist due to source data, so revert to action and/or install model',
    'eligible but normalizer does not exist due to source data, so revert to action and/or install model',
    'ineligible, normalizer is used as mapped revenue'
  )
GROUP BY 1
```

### CPA campaigns

```sql
SELECT
  api.campaign.id AS campaign_id,
  AVG(
    SAFE_DIVIDE(
      bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred,
      bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer
    )
  ) AS stability_multiplier
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND api.campaign.id IN (
    'I1UFqtzeIhRkfCrK',
    'NMrtO3Y5EN9EAiYm',
    'NpO7UWUJVrOW83bd',
    'VsHwYSeUhcTRbuDQ',
    'jfPWAJwwT0sXpYGv',
    'znFCczWhy5JTsQHx'
  )
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].type IN ('ACTION', 'ACTION_LAT')
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred > 0
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].pred <= 1
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer > 0
  AND bid.MODEL.prediction_logs[SAFE_OFFSET(1)].wrapper.normalizer <= 1
  AND COALESCE(bid.MODEL.prediction_logs[SAFE_OFFSET(1)].reason, '') != 'tf serving prediction is zero'
GROUP BY 1
```

