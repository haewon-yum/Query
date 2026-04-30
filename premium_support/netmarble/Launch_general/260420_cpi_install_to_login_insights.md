# 260420 — CPI Campaign Efficiency: Install-to-Login Rate (Netmarble)

**Project:** Netmarble CPI launch analysis — pitch support for KOR CPI campaigns
**Notebook:** `260420_cpi_install_to_login_analysis.ipynb`
**Report generator:** `generate_report.py` → `260420_cpi_install_to_login_report.html`
**Investigation started:** 2026-04-20

---

## Session 2026-04-21

### Context
- **Scope:** Extended analysis from 12 months (3 titles) to 24 months (6 titles); switched unattributed pb source to `focal-elf-631.df_accesslog.pb`; applied CPI-campaign-only filter to Section 2; built standalone HTML report generator
- **Tables used:** `moloco-ae-view.athena.fact_dsp_core`, `focal-elf-631.prod_stream_view.cv`, `focal-elf-631.df_accesslog.pb`, SensorTower (via speedboat MCP)

---

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Is `focal-elf-631.df_accesslog.pb` still active and queryable? | Glean search for deprecation status | Deprecated 2026-03-26 (deadline 2026-04-01); still exists as physical backing store for `moloco-dsp-data-view.postback.pb` view. Migration in progress across Panama, Marvel2, Airflow |
| 2 | Which Netmarble titles launched in the last 24 months and ran CPI in KOR? | SensorTower launch dates + BQ `fact_dsp_core` CPI query for each title's launch window | Solo Leveling Android (May 2024): 40,659 KOR installs @ $3.08; 7DS IDLE Android (Aug 2024): 13,545 KOR @ $3.38; King Arthur Android (Nov 2024): 4,511 KOR @ $2.73 |
| 3 | What login event name do the 5 new bundles use? | Queried `prod_stream_view.cv` for attributed postbacks with `LIKE '%login%'` during each bundle's launch window | All 5 new bundles use `login` (not `login_1st` or `login_complete`). Note: `df_accesslog.pb` returned zero rows → fallback to cv table |
| 4 | Does Section 2 correctly isolate CPI campaign installs? | Code review of cv query filters | **Gap found:** Section 2 was filtering by bundle + date only — no campaign ID filter. CPA (login) campaign installs could contaminate the attributed rate and inflate it. Fix: added `api.campaign.id IN {CAMPAIGN_IDS_SQL}` |
| 5 | Will `df_accesslog.pb` have 2024 unattributed data for Section 3? | Glean docs + agent fallback behavior | Table has ~1-year retention (back to ~Mar 2025). Solo Leveling (May 2024) and 7DS IDLE (Aug 2024) are outside the retention window → Section 3 returns NaN for those titles. King Arthur (Nov 2024) is borderline. 2025 titles unaffected |

---

### Key Findings

1. **All new Netmarble CPI titles ran meaningfully in KOR** — Solo Leveling Android had 40,659 KOR CPI installs at $3.08 CPI; 7DS IDLE had 13,545 at $3.38; King Arthur had 4,511 at $2.73. This confirms sufficient sample size for KOR install-to-login rate measurement for the 2024 cohort.

2. **Login event is uniformly `login` across all new titles** — confirmed via `prod_stream_view.cv` attributed postbacks during each title's launch window. Existing titles: `login_1st` (세나리버스 Android/iOS), `login_complete` (KOF AFK iOS), `login` (GoT Kingsroad Android).

3. **`df_accesslog.pb` has no data for pre-Mar 2025 windows** — despite being the intended source for Section 3 unattributed baseline, the table's ~1-year retention means the 2024 title cohort (Solo Leveling, 7DS IDLE, possibly King Arthur) will return zero rows. Section 3 unattributed data will only be available for 2025-launched titles. User accepted this limitation — 2024 titles appear in Section 2 (attributed) only.

4. **Section 2 methodology fix: CPI-campaign-only filter** — before this session, Section 2 captured all attributed installs for the bundle during the launch window, regardless of campaign type. If Netmarble ran concurrent CPA (login) campaigns, those cherry-picked users would inflate the attributed login rate. Fixed by adding `api.campaign.id IN {CAMPAIGN_IDS_SQL}` to the cv query — campaign IDs come from Section 0 which filters to `OPTIMIZE_CPI_FOR_APP_UA` only.

5. **`moloco-dsp-data-view.postback.pb` is a VIEW backed by `df_accesslog.pb`** — querying either table currently hits the same underlying data. The view was created as a stable interface for the ongoing migration to Iceberg. Long-term, `df_accesslog.pb` will be hidden behind the view; schema is identical today.

---

### Notebook Changes This Session

| Cell | Change |
|------|--------|
| `cell[2]` | `CHART_DIR` updated to `charts/` subfolder; `os.makedirs` added |
| `cell[3]` | `LAUNCH_WINDOWS` expanded: 4 → 9 bundles, 3 → 6 titles; `PARTITION_START` auto-resolves to `2024-05-03` |
| `cell[4]` | Section 0 header: "Last 12 Months" → "Last 24 Months" |
| `cell[8]` | Section 1 query uncommented; table → `focal-elf-631.df_accesslog.pb`; date range → `PARTITION_START/PARTITION_END` |
| `cell[9]` | All 5 new bundle login events confirmed (`login`); TODO markers removed |
| `cell[11]` | Added `AND api.campaign.id IN {CAMPAIGN_IDS_SQL}` — CPI-only filter **(critical fix)** |
| `cell[12]` | Chart titles now show app name via `TITLE_LOOKUP` dict |
| `cell[14]` | pb table → `focal-elf-631.df_accesslog.pb` |
| `cell[17]` | Chart titles now show app name via `TITLE_LOOKUP` dict |
| `cell[19-20]` | Added HTML export cell (`jupyter nbconvert --to html --no-input`) |

---

### Open Questions

- [ ] **Report output**: `generate_report.py` was running at session close — verify `260420_cpi_install_to_login_report.html` was generated successfully and charts render correctly
- [ ] **Section 3 coverage**: Confirm which 2025 titles return unattributed data from `df_accesslog.pb`. King Arthur (Nov 2024) is borderline — check row counts
- [ ] **`com.netmarble.tskgb` Android KOR**: The Android bundle for 세나리버스 wasn't present in original Section 0 output — it ran only iOS CPI. Confirm no Android CPI campaigns exist for this title
- [ ] **Re-run notebook**: All cells need a fresh top-to-bottom run with the 24-month scope + CPI campaign filter before the final notebook export is valid
- [ ] **Pitch readiness**: After re-run, review KOR rates for all 6 titles — identify which titles have the strongest install-to-login + implied login CPA story for the Netmarble pitch
