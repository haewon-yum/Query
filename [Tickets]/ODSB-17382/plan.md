# ODSB-17382 — Supply Volume Analysis: Device Model De-targeting Risk
**Client:** Netmarble — The Seven Deadly Sins Origin (iOS, bundle: `6744205088`)  
**Requestor:** Dabin Son  
**Created:** 2026-04-03  
**SLA:** 2026-04-14

---

## Background

Netmarble wants to de-target 22 specific iPhone/iPad models from their 7DS Origin iOS campaigns across **JPN, KOR, USA, TWN** due to low CPA (login_1st) performance.

Before confirming the de-targeting, we need to assess the **supply volume risk**: what percentage of total iOS bidrequests in each country come from these device models? If the share is large, blocking them could significantly reduce reach and impression volume.

---

## Hypothesis

These models skew toward older/mid-tier devices (iPhone 6S–11 range). They likely represent a **meaningful but non-dominant** share of iOS supply — estimated 20–40% combined. If the aggregate share per country is >30%, we should flag the volume risk to the client before proceeding.

---

## Device Models to Check (22 models)

| # | Device Model |
|---|---|
| 1 | iPhone11 |
| 2 | iPhone11Pro |
| 3 | iPhone11ProMax |
| 4 | iPhoneXR |
| 5 | iPhoneXSMax |
| 6 | iPhoneXS |
| 7 | iPhoneX |
| 8 | iPhoneSE2ndGen |
| 9 | iPhone8Plus |
| 10 | iPhone8 |
| 11 | iPhone7Plus |
| 12 | iPhone7 |
| 13 | iPhone6S |
| 14 | iPad9thGen(WiFi) |
| 15 | iPad9thGen(WiFiCellular) |
| 16 | iPad8thGen(WiFi) |
| 17 | iPad8thGen(WiFiCellular) |
| 18 | iPadAir3 |
| 19 | iPadAir13inch7thGen(WiFi+Cellular) |
| 20 | iPadMini5 |
| 21 | iPad7thGen |
| 22 | iPad6thGen |

---

## Countries & Campaign IDs in Scope

| Country | Campaign ID |
|---------|-------------|
| JPN | `YjcyETRHCzihe0yk` |
| KOR | `wtxzCfjzlievxX0V` |
| USA | `lNyyzhG43M95lTj7` |
| TWN | `AYSY8kiQSuKNGpDy` |

---

## Analysis Plan

### Step 0 — Schema & Device Model Name Verification
- Confirm device model column name in `focal-elf-631.prod.bidrequest{YYYY}*`
- Expected: `device.model` or `hw_model` or similar — verify exact field name via BQ Agent
- **Sample distinct device model values** from the table (iOS, JPN/KOR/USA/TWN) to understand the actual encoding (e.g., Apple internal codes like `"iPhone12,1"` vs display names like `"iPhone11Pro"`)
- **Map each of the 22 ticket model names** to the corresponding values found in the table — build a verified lookup list before querying Steps 1–2
- If encoding mismatches exist, define explicit `IN` list or `LIKE` patterns using the verified values
- **Verify whether the impression-level campaign log table carries a device model field** — look up the correct imp-level table (e.g., `focal-elf-631.prod.campaignlog*`) and confirm device model column availability; this determines the join path for Step 4

### Step 1 — Total iOS Bidrequest Volume by Country
Query total iOS bidrequests per country (last 14 days) as the denominator:
```
Table: focal-elf-631.prod.bidrequest2026*
Filter: UPPER(os) = 'IOS', country IN ('JPN', 'KOR', 'USA', 'TWN')
Date: last 7 days
Sampling: ×10,000 extrapolation (1/10,000 sampling rate)
```

### Step 2 — Device Model Volume by Country
Query iOS bidrequests broken down by device model × country, filtered to the 22 target models.
- Apply same date range and country filter
- Group by `country`, `device_model`
- Compute: `bidrequest_count * 10000` (extrapolated), `% of country total`

### Step 3 — Aggregate Risk Score per Country
For each country, compute:
- **Combined %** of all 22 models together
- Rank by % descending
- Flag countries where combined % > 30% as **high volume risk**

### Step 4 — Campaign-Level Device Share & CPA Performance

For each of the 4 campaigns (JPN / KOR / USA / TWN):

**4a — Impression Share by Device Group**
- Query impression volume split by device group: `target_devices` (the 22 models) vs. `other_devices`
- Output: campaign_id, device_group, impressions, % of total impressions
- Data source: campaign log / impression-level table with device model field (verify table in Step 0)

**4b — CPA(login_1st) Comparison**
- Query installs and login_1st events by device group per campaign
- Compute: `CPA = total_spend / login_1st_events` for each device group
- **Spend must be device-level** — use spend from the impression-level table (verified in Step 0), not `fact_dsp_*` which does not break down by device
- Output: campaign_id, device_group, impressions, installs, login_1st_events, spend_usd, CPA
- Data source: imp-level table (device model + spend) joined with MMP postback table for login_1st events

**Key question to answer:** Are the target devices materially underperforming vs. the rest of the fleet? A >2× CPA gap would justify de-targeting even with high volume risk.

### Step 5 — Output Table
| Country | Device Model | Estimated Bidrequests | % of iOS Total |
|---------|-------------|----------------------|----------------|
| JPN | iPhone11 | ... | ...% |
| ... | ... | ... | ... |

Plus a summary row per country (all 22 models combined).

---

## Data Source

| Table | Purpose |
|-------|---------|
| `focal-elf-631.prod.bidrequest2026*` | Supply-side iOS bidrequests with device model |

**Note:** `fact_supply` does not contain device model — must use raw `bidrequest` table.

---

## Output

- **Google Sheet:** `ODSB-17382 — Device Supply Volume (7DS Origin iOS)`
  - Tab 1: Country-level summary — aggregate % of all 22 models combined, with risk flag
  - Tab 2: Per-device model breakdown by country (country × model matrix with bidrequest count + % of iOS total)
  - Tab 3: Campaign-level impression share — target devices vs. others, per campaign
  - Tab 4: CPA comparison — login_1st CPA for target devices vs. others, per campaign
  - Tab 5: Supporting data — raw query results for auditability
- Recommendation memo embedded in Tab 1: safe to block (< 15% aggregate) / caution (15–30%) / high risk (> 30%)

---

## Open Questions

1. **Exact device model encoding** in bidrequest table — Apple uses internal codes (e.g., `"iPhone12,1"` for iPhone11). Need to confirm mapping or use LIKE patterns.
2. **Date range** — using last 7 days to manage compute cost; confirm with Dabin if a different range is needed.
3. **CPA data** — ticket also requests CPA(login_1st) by device model. Scope that separately (fact_dsp + pb/cv join) if needed after supply volume check.
