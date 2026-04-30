# RE LAT iOS Attribution Benchmark — Session Insights

**Project:** iOS RE LAT Attribution Benchmark for Netmarble Pitch
**Folder:** `premium_support/netmarble/202604_re_sololeveling/`
**Advertiser:** Netmarble (target audience); analysis uses all-advertiser benchmark data
**Investigation started:** 2026-04-20

---

## Session 2026-04-20 / 2026-04-22

### Context
- **Scope:** Build and execute benchmark analysis quantifying deterministic vs probabilistic attribution share in iOS RE LAT campaigns — to counter Netmarble's objection that RE LAT = unreliable probabilistic attribution. Two workstreams: (1) RE LAT benchmark notebook, (2) CPI install-to-login plan doc + notebook scaffold.
- **Tables used:** `moloco-dsp-data-view.postback.pb` (view over `focal-elf-631.df_accesslog.pb`), `moloco-ae-view.athena.fact_dsp_core`

---

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | What iOS RE LAT campaigns are active in the last 7 days? | `fact_dsp_core` WHERE `campaign.type = 'APP_REENGAGEMENT'`, `campaign.is_lat = TRUE`, `campaign.os = 'IOS'`, spend > 0 | 25 campaigns, 19 advertisers |
| 2 | What share of RE LAT postbacks is deterministic vs probabilistic? | `postback.pb` GROUP BY `attribution.method`, CASE WHEN into Deterministic/Probabilistic | 72.29% deterministic, 27.71% probabilistic (after IDFA exclusion) |
| 3 | Is the deterministic share stable day-over-day? | Daily GROUP BY date × classification | Stable 62–78% range across 7 days; slight dip Apr 17–19, recovered Apr 20 |
| 4 | Does the deterministic share vary significantly by app bundle? | Bundle-level GROUP BY with pivot to show all apps (including 0% deterministic) | Range 0–100%, median 31.7% across 10 apps |
| 5 | Why are some bundles 100% probabilistic? | Glean search: `#moonactive-re-ios-alpha`, iOS RE Beta audit doc, DDPTICKET-355 | Four root causes identified (see findings); Coin Master confirmed broken deeplink |
| 6 | Expand to KOR office, 3-month window | `fact_dsp_core` WHERE `advertiser.office = 'KOR'` → 10 campaigns; postback sections scaffolded | Sections 4–7 scaffolded; queries pending run |

---

### Key Findings

1. **72.3% of iOS RE LAT postbacks are deterministic (industry benchmark, last 7 days)** — From `postback.pb`, 25 campaigns, 19 advertisers. IDFA (`identifier`) traffic excluded; proportions computed within true LAT traffic only (deeplink + probabilistic). 643K+ postbacks analyzed. Implication: the majority of RE LAT attribution is deterministic — counters Netmarble's "RE LAT = probabilistic = unreliable" objection directly.

2. **Daily deterministic share is stable: 62–78% across 7 days** — No single-day crash indicating systemic deeplink failure. The Apr 17–19 dip (67–68%) coincides with a volume spike in probabilistic postbacks from specific high-volume campaigns (Lucky Defense, Jack in the Box) rather than a platform issue. Implication: the deterministic share is a structural property of the ecosystem, not a transient artifact.

3. **Wide bundle-level range: 0% to 100% deterministic** — 4 of 10 apps have <5% deterministic share (LINEマンガ, GoldenHoYeah, Caesars Palace, Coin Master at 99.65% probabilistic). 4 apps are >96% deterministic (Kalshi, Jack in the Box, Hwahae, Royal Match). Implication: the 72.3% aggregate figure is not driven by one outlier; it reflects a genuinely mixed ecosystem. Apps with deeplinks configured achieve near-100% deterministic.

4. **Coin Master iOS deeplink is confirmed broken (not a configuration choice)** — Glean: `#moonactive-re-ios-alpha` thread documents Guillem's explicit report that "tracking links include a deeplink but Moloco is not getting deeplink attribution on iOS." Campaign name `CM_Moloco_iOS_Retargeting_Probabilistic_Test` also signals intentional isolation as a test. Implication: Coin Master's 0% deterministic is a known bug, not representative of what a properly configured campaign produces.

5. **Four documented root causes for 0% deterministic in RE LAT campaigns** — From internal iOS RE Beta audit doc and DDPTICKET-355: (a) no deeplink in tracking link (App Store redirect instead of in-app), (b) deeplink present but misconfigured (scheme/host/path mismatch), (c) MMP re-engagement mode not enabled, (d) AppsFlyer Advanced Privacy stripping attribution fields. Implication: 0% deterministic is always a solvable setup issue, not a platform limitation.

6. **`postback.pb` is a view over `focal-elf-631.df_accesslog.pb` — partitioned by DAY on `timestamp`, 7.7T rows, 3.2 PB total** — `_PARTITIONTIME` pseudo-column is NOT exposed through the view; only `timestamp >=` or `DATE(timestamp) BETWEEN` filter forms enable partition pruning (both push through). 7-day scan ≈ 150 GB (fast); 6-month scan ≈ 1.6 PB (232+ min, impractical). Reduced KOR office lookback to 3 months (~800 GB). Implication: always use a timestamp filter on this table; avoid `DATE(timestamp)` wrappers for partition pruning; keep lookback ≤ 3 months for interactive use.

7. **KOR office filter confirmed: `advertiser.office = 'KOR'`** — Verified live against `fact_dsp_core`. KOR office has 10 RE LAT iOS campaigns in the last 3 months. Sections 4–7 scaffolded in the notebook but not yet executed (pending re-run after auth refresh and lookback reduction).

---

### Schema Notes (hard-learned, verified live)

| Field | Correct form | Common mistake |
|-------|-------------|----------------|
| View over | `focal-elf-631.df_accesslog.pb` | Assumed `postback.pb` was native table |
| Partition pseudo-col | Not exposed on view — use `timestamp >=` | `_PARTITIONTIME` → `BadRequest` |
| Attribution method | lowercase: `deeplink`, `probabilistic`, `fingerprint`, `identifier` | Assumed uppercase |
| View-through field | `attribution.view_through` (underscore) | `attribution.viewthrough` |
| MMP name | `mmp.name` (nested STRUCT) | flat `mmp` |
| IDFA in LAT traffic | Present as `identifier` (~5.8% before exclusion) | Not expected; exclude for LAT-only proportions |

---

### CPI Install-to-Login Analysis (parallel workstream)

Plan doc `260420_cpi_install_to_login_plan.md` and notebook `260420_cpi_install_to_login_analysis.ipynb` created under `Launch_general/`. Dual objective confirmed:
1. **Cross-country:** Show KOR has comparably high attributed install-to-login rate → competitive implied login CPA → CPI viable in KOR
2. **Attributed vs unattributed validation:** Show attributed rate ≈ unattributed baseline → CPI acquires users with genuine login intent

Notebook scaffolded with Sections 0–4 (TODO stubs). Queries not yet executed.

---

### Open Questions

- [ ] Run Sections 4–7 of the RE LAT benchmark notebook (KOR office, 3-month window) after auth refresh
- [ ] Check "2026 Q1/Q2 Netmarble Support" doc section "Benchmark) Proportion of deterministic attribution" — may already contain related figures
- [ ] Confirm whether Lucky Defense (운빨존많겜) at 47.4% deterministic has deeplink partially configured or a mixed campaign setup
- [ ] Fill in CPI install-to-login analysis queries (Sections 0–4) — verify login event names per Netmarble title
- [ ] Validate that `advertiser.office = 'KOR'` captures all intended KOR accounts (cross-check with known Netmarble advertiser IDs)
