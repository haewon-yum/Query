# 7DS Origin Launch Analysis Plan
**Client:** Netmarble
**Title:** The Seven Deadly Sins: Origin (7DS Origin)
**Funnel:** Install (300MB) → Game Start click → In-app packet download (9–16GB) → Login
**Launch date:** 2026-03-24
**Analysis due:** 2026-03-14 (this week, ~10 days before launch)
**Created:** 2026-03-10
**Owner:** Haewon

---

## Objective

Benchmark and prepare targeting strategy for 7DS Origin, a new Netmarble title with a unique two-stage download structure:
- **Stage 1 (store install):** 300MB initial download
- **Stage 2 (in-app packet):** 9–16GB packet download triggered after user clicks "Game Start"
- **Login fires only after Stage 2 completes** — the packet download is the primary drop-off point

The target CPA for login is **KRW 15,000**. This creates a significant install→login funnel gap that inflates effective CPA. The goal is to identify comparable heavy titles, map the gap event structure, and de-target low-spec devices that fail to complete the packet download.

---

## Scope

| # | Section | Goal |
|---|---------|------|
| 1 | Heavy game identification | Find comparable titles by file size via SensorTower |
| 2 | Event structure audit | Map events between install and login (e.g. packet download) |
| 3 | Campaign event usage | Check if campaigns use install→login intermediate events |
| 4 | Device/OS performance | Analyze performance of heavy titles by device spec to inform de-targeting |

---

## Section 1 — Heavy Game Identification (SensorTower)

**Goal:** Find games with a similar two-stage download structure (small store install + large in-app packet), focusing on the same genre/region (Netmarble's competitive set).

**Known:** 7DS Origin = 300MB store install + 9–16GB in-app packet.

**Questions to answer:**
- Which titles in the RPG/action genre have comparable total file sizes (≥ 5GB in-app packet)?
- Does SensorTower expose in-app download size, or only the store install size?
- Does SensorTower expose minimum device spec requirements (min RAM, min OS version)? If so, can we use high minimum specs as a proxy for heavy titles?
- What are their bundle IDs for BQ lookups?

**Data source:** SensorTower (app intelligence → app details)

**Approach:**
1. **Check SensorTower data availability first — two potential signals:**
   - **File size:** Does SensorTower expose in-app packet/OBB size separately from store size? If yes, filter on `install_size + packet_size`. If not, use store size as proxy.
   - **Minimum device specs:** Does SensorTower expose min RAM / min OS version requirements? Games requiring high specs (e.g. min 4GB RAM, Android 9+, iOS 14+) are strong proxies for heavy titles — use this as an additional or alternative filter if file size data is limited.
2. Pull top RPG/strategy titles by downloads (KOR, global) from SensorTower
3. Filter by heavy title proxies: large file size and/or high minimum device spec
4. Output: list of bundle IDs + app names for downstream BQ analysis

**Output:** `heavy_titles_list.csv` — columns: `bundle_id`, `app_name`, `platform`, `store_size_mb`, `packet_size_mb` (if available), `total_size_mb`, `min_ram_gb` (if available), `min_os_version` (if available), `genre`, `publisher`

---

## Section 2 — Event Structure Audit (Install → Login Gap)

**Goal:** For 7DS Origin, the known funnel is: Install → Game Start click → 9–16GB packet download → Login. Confirm whether comparable heavy titles have similar intermediate events trackable in BQ, which could be used as optimization targets instead of waiting for login.

**Known funnel for 7DS Origin:**
```
install (300MB store)
  → [game start click — may or may not be tracked]
  → in-app packet download (9–16GB)
  → login  ← optimization event, target CPA = KRW 15,000
```

**Questions to answer:**
- Do comparable heavy titles have intermediate events tracked between install and login (e.g. `game_start`, `download_start`, `download_complete`, `patch_finish`)?
- What is the typical install→login time gap for these titles (proxy for download duration)?
- What fraction of installs ever reach login (to quantify the funnel drop)?

**Data source:** BQ — event tables for identified bundle IDs

**Key tables:**
- `moloco-ods.prod_stream.*` or equivalent event tables
- Filter: `event_type NOT IN ('install', 'login')` between first install and first login timestamp per user

**Approach:**
```sql
-- Pseudo-structure
WITH install_login AS (
  SELECT user_id, bundle_id,
    MIN(IF(event_type = 'install', event_ts, NULL)) AS install_ts,
    MIN(IF(event_type = 'login', event_ts, NULL)) AS login_ts
  FROM event_table
  WHERE bundle_id IN (<heavy_titles>)
  GROUP BY 1, 2
),
gap_events AS (
  SELECT e.bundle_id, e.event_type, COUNT(*) AS event_count
  FROM event_table e
  JOIN install_login il USING (user_id, bundle_id)
  WHERE e.event_ts BETWEEN il.install_ts AND il.login_ts
    AND e.event_type NOT IN ('install', 'login')
  GROUP BY 1, 2
)
SELECT * FROM gap_events ORDER BY bundle_id, event_count DESC
```

**Output:** `gap_events_by_title.csv` — columns: `bundle_id`, `event_type`, `event_count`, `median_time_from_install_sec`

---

## Section 3 — Campaign Structure at Launch

**Goal:** Understand how comparable heavy titles structured their Moloco campaigns during their **launch phase** — specifically which events they optimized toward. Only analyze titles for which we have Moloco campaign data overlapping with their launch window.

**Questions to answer:**
- What event type did each title optimize toward at launch (login, game_start, download_complete, etc.)?
- Are any of the gap events from Section 2 used as campaign optimization events at launch?

**Data source:**
- **SensorTower** — pull release date per title (App Intelligence → App Details → Release Date)
- **BQ** — campaign/ad group config tables, filtered to the launch window

**Approach:**
1. Pull release dates for all identified heavy titles from SensorTower
2. Define launch window as D0–D30 from release date per title
3. Check BQ for Moloco campaign data within that window — skip titles with no data
4. For titles with launch-phase campaigns, pull optimization event config
5. Cross-reference with gap event list from Section 2

**Output:** `launch_campaign_structure.csv` — columns: `bundle_id`, `app_name`, `release_date`, `has_moloco_data`, `campaign_id`, `optimization_event`, `is_gap_event`

---

## Section 4 — Device/OS Performance Analysis (De-targeting)

**Goal:** For the identified heavy titles, analyze install-to-login conversion and downstream performance by device model and OS version. Identify low-spec device segments with poor conversion to recommend de-targeting for 7DS Origin.

**Questions to answer:**
- Which device models have significantly lower install→login CVR for heavy titles?
- Which OS versions show poor performance (e.g. very old Android versions)?
- What is the performance delta (CVR, ROAS) between high-spec and low-spec devices?

**Data source:** BQ — bid/event/revenue tables joined on device metadata

**Key dimensions:**
- `device_model`, `os_version`, `platform` (iOS/Android)
- Metrics: install→login CVR, login CPA, D7/D14 retention proxy, revenue per install

**Approach:**
```sql
-- Pseudo-structure
SELECT
  device_model,
  os_version,
  COUNT(DISTINCT IF(event_type='install', user_id, NULL)) AS installs,
  COUNT(DISTINCT IF(event_type='login', user_id, NULL)) AS logins,
  SAFE_DIVIDE(
    COUNT(DISTINCT IF(event_type='login', user_id, NULL)),
    COUNT(DISTINCT IF(event_type='install', user_id, NULL))
  ) AS install_to_login_cvr,
  SAFE_DIVIDE(
    SUM(spend_krw),
    COUNT(DISTINCT IF(event_type='login', user_id, NULL))
  ) AS login_cpa_krw
FROM event_table
JOIN spend_table USING (campaign_id, ...)  -- join bid/spend data
WHERE bundle_id IN (<heavy_titles>)
GROUP BY 1, 2
ORDER BY installs DESC
```

**Output:** `device_performance.csv` + visualization (heatmap of CVR and login CPA by device tier)

**De-targeting recommendation:** Define low-spec threshold (e.g. CVR < 50% of median or login CPA > 2× KRW 15,000 target) → output blocklist of `device_model` / `os_version` pairs for 7DS Origin campaign setup.

---

## Deliverables

| Deliverable | Format | Section |
|-------------|--------|---------|
| Heavy title benchmark list | CSV + summary table | 1 |
| Gap event audit | CSV | 2 |
| Campaign event config review | CSV | 3 |
| Device/OS performance heatmap | Notebook + visualization | 4 |
| De-targeting blocklist | CSV / Google Sheet | 4 |
| Final write-up | Google Doc (via md_to_gdoc.py) | All |

---

## Open Questions

- [x] 7DS Origin file size: 300MB store install + 9–16GB in-app packet download
- [x] Login fires after packet download completes; target CPA = KRW 15,000
- [ ] Does Netmarble have specific target markets / platforms (Android KOR only? Global iOS too)?
- [ ] Is the "Game Start click" event tracked by the MMP, or only login?
- [ ] What is the campaign go-live date — do we need this before launch or for optimization?
- [ ] Does Netmarble already have a device blocklist from previous titles (e.g. Ni no Kuni)?
- [ ] Are minimum device spec requirements published for 7DS Origin (RAM, storage)? Check SensorTower or official store listing.

---

## References

- SensorTower: app intelligence for competitor file size data
- BQ project: `moloco-ods`
- Related: `Lunchsupport/launch_checklist_v2.ipynb`
