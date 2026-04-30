# ODSB-17086 — [KOR] iOS RE Campaign Targeting Accuracy (YANOLJA)

**Ticket:** [ODSB-17086](https://mlc.atlassian.net/browse/ODSB-17086)
**Advertiser:** 야놀자 (Yanolja) — `Os7oojpjTo8JwHIt`
**Investigation date:** 2026-03-25 ~ 2026-04-02

---

## Campaigns in Scope

| Campaign ID | Name | Goal | OS | Traffic |
|-------------|------|------|----|---------|
| `KaJKya01zKIrfph1` | RE-roas-ios-outbound | OPTIMIZE_ROAS_FOR_APP_RE | iOS | IDFA only (LAT excluded) |
| `wrim1I3PJS6d017p` | RE-roas-ios-intrabound | OPTIMIZE_ROAS_FOR_APP_RE | iOS | IDFA only |
| `cTicyo2cW52zb5t6` | RE-appopen-ios-intrabound-lat | OPTIMIZE_REATTRIBUTION_FOR_APP | iOS | **Both LAT ON + LAT OFF** |

All campaigns: KOR, MMP = AppsFlyer, Platform = YANOLJA.

---

## Campaign: KaJKya01zKIrfph1 (RE-roas-ios-outbound)

### Target Exclusion Config

**Campaign-level:**
- Excludes LAT devices (`ANDROID_LAT_IDFA`, `IOS_LAT_IDFA`) — IDFA-only traffic
- Excludes Yanolja own app as publisher (`436731843`, `id436731843`)

**Ad group-level (shared across all ad groups):**
- Excludes OkCashbag publisher bundles: `com.skmc.okcashbag.home_google`, `com.skmc.okcashbag.homegoogle`, `358731598`

**Audience exclusion by ad group:**

| Ad Group | Key Exclusion Logic | User Bucket |
|----------|---------------------|-------------|
| `g_cross-always-NOLINTGCVdapps_OP30d` | Excludes `af_app_opened` in last 30d | 0–25 |
| `pkg-pdp` groups | Ref target `onD25GN18zGEtJht` (GL CV180d/PU7d) | 25–35 |
| `g_cross-always-NOLINTGCVdapps_None` | No event recency exclusion | 35–60 |
| `tna-always-TNACV90dorTRIP30d` | Requires `content_view_tna` last 90d | 60–80 |
| `tna-always-JPCV90d_None` | JP customer set | 80–100 |

**Key insight:** The 30-day recent opener exclusion (`af_app_opened`) is applied as a **dynamic postback filter** in the ad group config (not baked into the customer set CSV). User bucket banding prevents ad groups from competing for the same users.

---

## Campaign: cTicyo2cW52zb5t6 (RE-appopen-ios-intrabound-lat)

### Target Audience Config

- **Single ad group:** `xQFf2DlXX3tlWBBf` (`d_cross-always-PU365d_OP30d-260306`)
- **Audience target:** `aNTBY35WbJ4z2v20` (`RE_LAT_IOS_BETA_Incl_Purchase365_Excl_Open30`)
- **Customer set:** `tNfrTtz2roqYIWbt` (referenced as `YANOLJA#tNfrTtz2roqYIWbt` and `Os7oojpjTo8JwHIt#tNfrTtz2roqYIWbt`)
- **No dynamic postback filters** — the "365d purchaser + exclude 30d opener" logic is encoded in the static CSV, not in audience target rules
- **No id_type filter** at campaign or ad group level → both LAT ON and LAT OFF traffic flow through the same audience

### Publisher exclusions
- Campaign-level: Yanolja app (`436731843`, `id436731843`)
- Ad group-level: OkCashbag bundles

### Special configs
- `min_imp_interval_min = 360` (1 impression per user per 6 hours)
- `max_cpm = 70`, `pricing_model = cloud_v1`, `target_cost = 1`

---

## Customer Set: tNfrTtz2roqYIWbt

**Name:** `RE_LAT_IOS_BETA_Incl_Purchase365_Excl_Open30`

| Field | Value |
|-------|-------|
| `id_type` | `APPLE_IDFA` only — **no IDFV or other ID types** |
| `status` | `GENERATION_SUCCEEDED` |
| `data_file_path` | `https://storage.moloco.com/asset-userlist/YANOLJA/Os7oojpjTo8JwHIt/mm9j1uto_few4gfz_vjzwpleajfuqzojh.csv` |
| `created_at` | 2026-03-02 18:43:38 UTC (by `guillem@moloco.com`) |
| `last_file_update` | 2026-03-05 20:23:31 UTC |
| Upload method | MCP manual upload (`https://storage.moloco.com/...` → `MCP_UPLOAD` classification) |

**Audience seed (SQL):** `gs://lat-user-tagging-beta/asset-userlist/sql/YANOLJA/Os7oojpjTo8JwHIt/tNfrTtz2roqYIWbt.sql`
Configured in `airflow/dags/ml/re_audience_tagging/constants.py`:
- `platform_id = "YANOLJA"`, `advertiser_id = "Os7oojpjTo8JwHIt"`, `seed_type = 0` (SQL)

**History:**
1. 2026-03-02 18:43:38 — DRAFT created
2. 2026-03-02 18:55:46 — GENERATION_SUCCEEDED (first upload)
3. 2026-03-05 20:23:31 — Last file update
4. No updates since → **~28 days stale as of 2026-04-02**

---

## Key Findings & Issues

### 1. Audience Staleness
- `tNfrTtz2roqYIWbt` last refreshed 2026-03-05, ~28 days stale as of today
- The "never been refreshed" claim in the ticket is partially wrong — it was refreshed **once** on 2026-03-05, but never again
- Staleness affects **both LAT ON and LAT OFF** traffic in `cTicyo2cW52zb5t6` (single shared customer set, no per-traffic-type split)

### 2. Customer Set ID Type Coverage — IDFA + IDFV Both Supported
- **Updated (2026-04-07):** The RE LAT beta pipeline supports **both IDFA and IDFV** for target generation and UPT tagging. The customer set `tNfrTtz2roqYIWbt` is not exclusively IDFA-only at the pipeline level — IDFV-based targeting is structurally supported.
- Source: [iOS RE Beta Campaign Investigation doc](https://docs.google.com/document/d/1IKLONGjj1_3xlxcszBHOCV_-weF3jI1DuIcyw0dhQII/edit?tab=t.0#bookmark=id.oury7awl4yq)
- The entity-level `id_type = APPLE_IDFA` in the customer set metadata reflects the seed ID type, but does NOT preclude IDFV matching at bid time via the LAT RE beta UPT tagging path
- **Revised implication:** LAT ON users (no IDFA) may be matched via IDFV if UPT tagging ran correctly — audience staleness (Finding #1) is a more likely root cause of targeting inaccuracy than ID type mismatch alone

### 3. No Dynamic Postback Filters → Stale Exclusions Confirmed in PB Data
- Unlike `KaJKya01zKIrfph1` which uses dynamic `postback_event` recency filters (e.g., exclude `af_app_opened` last 30d), campaign `cTicyo2cW52zb5t6` has **no dynamic exclusion rules** in its audience target
- The exclusion logic (Purchase365, ExcludeOpen30) is entirely baked into the static CSV — if the CSV is stale, users who opened the app recently are NOT excluded at bid time
- **Confirmed (as of 2026-03-26 KST):** **1,251 IDFAs** in the targeted audience were identified as having `af_app_opened` events in the last 30 days via PB data
  - **959 (76.7%)** — events dated Mar 25–26 only → **explained by inherent 1-day lag** in the daily customer set refresh schedule (users opened the app *after* the daily computation ran, before the next refresh)
  - **292 (23.3%)** — genuine violations: users who slipped past the ExcludeOpen30 window; **being investigated by RS Mingyu Kim**
- **Key distinction:** The 959 cases are a product limitation (unavoidable 1-day lag), not a targeting bug. The 292 cases are the actual accuracy issue.
- **Open metric:** % of genuine violations = `292 / total_targeted_IDFAs` — **needs BQ validation** (see notebook `ODSB-17086_audience_staleness_validation.ipynb`)

### 4. Two Separate Audience Pipelines (cross-campaign)
| Pipeline | Campaigns | Refresh | bypassTagging |
|----------|-----------|---------|---------------|
| `re_mvp_audience_management` DAG (CSE) | IDFA campaigns (e.g., `KaJKya01zKIrfph1`) | Automated, scheduled | No — writes to UPT Bigtable |
| LAT RE beta pipeline (`airflow/dags/ml/re_audience_tagging/`) | LAT campaign (`cTicyo2cW52zb5t6`) | Manual / no confirmed schedule | Likely yes (MCP upload pattern) |

The LAT pipeline is in `gs://lat-user-tagging-beta/` — "beta" suffix confirms non-production status with no guaranteed automated refresh.

### 5. bypassTagging Status
- `bypassTagging` for `tNfrTtz2roqYIWbt` could not be confirmed from entity_history
- Architecturally expected to be `true` given MCP upload + APPLE_IDFA id_type pattern
- If `true`: no UPT Bigtable tags written → bid-time matching cannot use standard UPT `"t"` column family lookup

---

## Open Questions
- [ ] What is the scheduled cadence (if any) for the LAT re_audience_tagging DAG? Was 2026-03-05 a manual trigger or DAG run?
- [ ] Confirm `bypassTagging` value via internal RTB_CUSTOMER_SET entity inspection
- [ ] How does LAT ON (IDFV) audience matching work at bid time — does UPT tagging path differ for IDFV vs IDFA lookups?
- [ ] **Total IDFA count in customer set CSV** → needed to compute: `1,251 / total` = % of targeted users actively using the app (→ notebook)
- [ ] User count in the CSV: `gsutil wc -l gs://asset-userlist/YANOLJA/Os7oojpjTo8JwHIt/mm9j1uto_few4gfz_vjzwpleajfuqzojh.csv`

## Validation Plan
→ See notebook: `ODSB-17086_audience_staleness_validation.ipynb`

**Goal:** Quantify what % of targeted IDFA users were actively opening the app (violating the ExcludeOpen30 rule), and assess whether the doc's validation methodology is sound.

**Validation approach (from doc):**
1. Get tagged mpids from `moloco-ods.lat_user_tagging_beta.tagging_full_latest` for customer set `tNfrTtz2roqYIWbt`
2. Map mpids → raw IDFAs via IGv5 (`moloco-dsp-identity-prod.release_v5_1.final_cc_release`, filter `id LIKE 'i:%'`)
3. Cross-reference against `moloco-dsp-data-view.postback.pb` for `af_app_opened` events in last 30 days (field: `device.idfa`)
4. Result: 1,251 total matched → decomposed as:
   - **959 (76.7%)** — events on Mar 25–26 only → explained by **1-day lag** in daily refresh cadence (not a bug)
   - **292 (23.3%)** — genuine violations: opened app before Mar 25 but still in target list (shared with RS Mingyu Kim)

**Is this approach legitimate?**
- **Yes, structurally sound:** Using UPT-tagged mpids → IGv5 IDFA mapping → PB validation is the correct end-to-end pipeline for IDFA-level audience accuracy checks.
- **Caveat 1 — PB attribution scope:** `postback.pb` captures only Moloco-attributed events. Organic opens or cross-channel opens won't appear → 292 genuine violations is a **lower bound**.
- **Caveat 2 — 1-day lag is expected behavior:** 76.7% of the flagged cases are day-of events due to the daily refresh cadence — this is not a bug. Framing all 1,251 as "targeting errors" overstates the issue.
- **Caveat 3 — IDFV users excluded from check:** The validation only covers IDFAs with IGv5 coverage. IDFV-targeted (LAT ON) users are not validated by this method.
- **Recommended framing:** `292 / total_targeted_IDFAs` = true stale rate. `1,251 / total` = upper-bound exposure rate (includes acceptable lag).

---

## Reference: LAT Audience Seed SQL Template

The following is the Jinja2 template used to generate LAT audience CSVs (e.g., for `DbpyjmweONzxki6Y`, app_bundle `id6482291732`, exclude any event L7D):

```sql
-- Rendered with: include_time_window=0, exclude_time_window=7, no event filters, no country filter
SELECT maid, seed_type, date_utc, customer_set
FROM (
  SELECT DISTINCT maid, "including" AS seed_type,
         DATE('2026-03-25') AS date_utc, 'DbpyjmweONzxki6Y' AS customer_set
  FROM `focal-elf-631.rs.ios_re_closed_beta_summary_table`
  WHERE date_utc IS NOT NULL
    AND date_utc < DATE_SUB(DATE('2026-03-25'), INTERVAL 7 DAY)  -- all history before L7D
    AND app_bundle IN ('id6482291732', '6482291732')
)
UNION ALL
(
  SELECT DISTINCT maid, "excluding" AS seed_type,
         DATE('2026-03-25') AS date_utc, 'DbpyjmweONzxki6Y' AS customer_set
  FROM `focal-elf-631.rs.ios_re_closed_beta_summary_table`
  WHERE date_utc >= DATE_SUB(DATE('2026-03-25'), INTERVAL 7 DAY)  -- last 7 days
    AND date_utc <= DATE('2026-03-25')
    AND app_bundle IN ('id6482291732', '6482291732')
);
```
Logic: Include all MAIDs with any event before L7D; exclude MAIDs with any event in L7D.
