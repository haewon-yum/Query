# CPI Campaign Efficiency Analysis — Install-to-Login Rate (Netmarble)

| Field | Value |
|-------|-------|
| **Author** | Haewon Yum |
| **Date** | 2026-04-20 |
| **Client** | Netmarble |
| **Folder** | `premium_support/netmarble/Launch_general/` |

---

## Objective

Two complementary analyses using historical CPI campaign data across all Netmarble titles (last 12 months):

1. **Cross-country install-to-login rate** — show KOR has a comparably high attributed install-to-login rate relative to other countries, and that KOR's implied login CPA (= CPI ÷ rate) is competitive. This is the primary argument to convince Netmarble to try CPI campaigns in KOR.

2. **Attributed vs unattributed validation** — show that the attributed install-to-login rate is at a similar level to the unattributed baseline for the same titles and countries. This validates that CPI installs convert to login at a rate consistent with the general install population — i.e., the attributed rate is genuine and not inflated by model targeting toward inherently high-converting users.

---

## Hypotheses

Netmarble's internal KPI is login CPA, which is why they run CPA (login event) campaigns. However:

> **Implied login CPA from CPI** = CPI ÷ install-to-login rate

**Hypothesis 1 (cross-country):** KOR users who install via CPI campaigns convert to login at a higher rate than users in other countries. Even if KOR CPI is relatively high, the high install-to-login rate keeps the implied login CPA competitive — making CPI a viable and potentially more scalable alternative to CPA in KOR.

**Confirmed if:** KOR attributed install-to-login rate is materially higher than other geographies, and KOR implied login CPA is in a reasonable range compared to other countries.

**Hypothesis 2 (attributed vs unattributed):** The attributed install-to-login rate from CPI campaigns is comparable to the unattributed baseline for the same titles and countries. If the two rates are similar, it confirms the attributed rate reflects genuine user behavior — CPI campaigns are acquiring users who convert to login at a rate consistent with the broader install population, not just cherry-picking inherently high-converting users.

**Confirmed if:** Attributed and unattributed install-to-login rates are at a similar level (not dramatically divergent) across most title × country combinations.

---

## Scope

| Dimension | Value |
|-----------|-------|
| **Client** | Netmarble (all advertiser IDs) |
| **Titles** | All Netmarble titles with CPI campaigns in the last 12 months — discovered from BQ |
| **Campaign goal** | `OPTIMIZE_CPI_FOR_APP_UA` only |
| **Platform** | iOS and Android — analyzed separately at OS level |
| **Countries** | KOR always shown; other countries included if ≥50 installs |
| **Lookback** | Last 12 months from analysis date |
| **Login window** | D1 (login event occurring within 1 day of install) — configurable |

---

## Out of Scope

- Direct CPA (login) campaign performance — no CPA vs CPI campaign comparison
- ROAS campaigns
- RE (re-engagement) campaigns
- Titles where Netmarble did not run CPI campaigns
- Post-D1 login rate (secondary analysis only if needed)

---

## Key Tables

| Table | Purpose |
|-------|---------|
| `moloco-ae-view.athena.fact_dsp_core` | Discover Netmarble CPI campaigns; get install counts, spend (CPI), campaign metadata |
| `focal-elf-631.prod_stream_view.pb` | Login event postbacks for attributed users (install-to-login join); unattributed baseline |
| `focal-elf-631.prod_stream_view.cv` | Alternative to pb for attributed post-install events (cv.pb.event.name) |

**Login event note:** Login event names vary by title and MMP configuration. Names may include: `login_1st`, `first_login`, `af_login`, `LOGIN`, etc. Must be discovered per title before querying conversion rates.

---

## Analysis Sections

### Section 0 — Netmarble CPI Campaign Discovery (Last 12 Months)
**Goal:** Identify all Netmarble CPI campaigns, grouped by title, OS, and country, to scope the rest of the analysis.

From `fact_dsp_core`:
- Filter: `campaign.goal = 'OPTIMIZE_CPI_FOR_APP_UA'`, Netmarble advertiser IDs, last 12 months
- Group by: title, OS, country
- Output: campaign IDs, app_name, bundle_id, MMP, spend, installs, CPI (spend/installs), date range
- Flag: countries with <50 installs per title (excluded from rate analysis)

---

### Section 1 — Login Event Discovery per Title
**Goal:** Identify the correct login event name(s) for each title before computing conversion rates.

From `pb` table:
- Filter: campaign IDs from Section 0, event_name LIKE '%login%' (case-insensitive)
- Distinct event names per title, ordered by postback count
- Output: title → candidate login event names with postback count

Manual review step: confirm the primary first-login event per title before proceeding.

---

### Section 2 — Attributed Install-to-Login Rate by Country (CPI Campaigns)
**Goal:** The core analysis. For each CPI campaign title × OS, compute install-to-login rate by country. KOR should show a materially higher rate.

Approach (two options — validate which is feasible):
- **Option A (pb join):** Join attributed install postbacks to login event postbacks for the same user (`mtid` / `event_pb`) within D1. Rate = login count / install count.
- **Option B (cv table):** Among cv rows for CPI campaigns, compute fraction of install sessions with a login event within D1.

Group by: title × OS × country  
Filter: KOR always included; other countries if ≥50 installs  
Output: country, install count, login count, install-to-login rate (%), CPI, **implied login CPA** = CPI ÷ rate

**Key chart:** install-to-login rate by country (bar), with KOR highlighted. Second chart: implied login CPA by country.

---

### Section 3 — Unattributed Install-to-Login Rate (Validation Baseline)
**Goal:** Compute unattributed install-to-login rate for the same titles and countries, to validate that the attributed rate from CPI campaigns reflects genuine user behavior. Note: unattributed traffic may include users from other paid channels — it is not a clean organic baseline.

From `pb` table:
- Filter: `attribution.attributed = FALSE`, same bundles/titles, same login event names
- Same D1 window, same country breakdown

Output: unattributed install-to-login rate (%) by country — shown alongside attributed rate in Section 4. If attributed ≈ unattributed, the CPI install-to-login rate is validated as genuine.

---

### Section 4 — Summary: Country-Level Install-to-Login Rate + Implied Login CPA
**Goal:** Final comparison table and visualization for the Netmarble pitch. KOR highlighted as the target market.

Output table per title × OS:

| Country | Install-to-Login Rate (Attributed) | Install-to-Login Rate (Unattributed) | CPI | Implied Login CPA |
|---------|-----------------------------------|------------------------------------|-----|-------------------|
| KOR | **XX%** | XX% | $X.XX | **$X.XX** |
| USA | XX% | XX% | $X.XX | $X.XX |
| ... | | | | |

Visualization: grouped bar chart — install-to-login rate by country, colored by attributed vs unattributed, KOR bar highlighted. Second panel: implied login CPA by country.

**Pitch takeaways:**
- *Cross-country:* "KOR install-to-login rate is X% vs Y% average for other countries. At current CPI levels, implied login CPA for KOR CPI campaigns would be $Z — competitive for this market."
- *Validation:* "Attributed install-to-login rate (X%) is consistent with unattributed baseline (Y%) — confirming that CPI campaigns are acquiring users with genuine login intent, not gaming the metric."

---

## Output Targets

- Country-level table: install-to-login rate (attributed + unattributed) + implied login CPA, all titles × OS
- KOR callout: headline rate and implied login CPA for the pitch
- Sample size flags: countries with <50 installs noted as low-confidence

---

## Open Questions (to resolve in Sections 0–1)

1. Are login events tracked in the pb table for all Netmarble CPI campaigns, or primarily in cv?
2. Which Netmarble titles actually ran CPI campaigns in the last 12 months, and do they have sufficient KOR install volume?
3. What is the user identifier for joining install → login events within D1 in the pb table (`mtid`? `event_pb`?)?
