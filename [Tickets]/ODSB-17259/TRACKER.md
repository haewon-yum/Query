# ODSB-17259 — iOS Install Campaign CPI Spike: Analysis Tracker

**Last updated:** 2026-04-04  
**Analyst:** Haewon  
**Status:** Postback causal analysis complete; pending GM timeline confirmation + Engineering model cadence

---

## Ticket Summary

iOS install campaigns for bundle `id6550902247` experienced a CPI spike on Mar 27 (Day 2 of campaign launch). GM shared that postback signal for in-app events was expanded on Day 2 — events previously received as attributed-only are now available via full postback.

| Campaign ID | Label | Observation |
|-------------|-------|-------------|
| `BhTo5PHbtcsuQwkh` | KR iOS Install | CPI spike on Mar 27 |
| `VveaqT1OAcxlbXSv` | US iOS Install | CPI spike on Mar 27 |
| `onLf8YMrzBKrT80y` | KR Retention | Zero ML training data; never bid |
| `ttIK8j9coo7UMK9r` | Healthy Retention | Control |

**Bundle:** `id6550902247` (iOS)

---

## Notebook

**Local:** `searchlight/ODSB-17259_install_cpi_spike.ipynb` (64 cells)  
**Colab:** https://colab.research.google.com/drive/189a8I4uQqVgriMD72mSLYarsevzwiIEE  
**Drive file ID:** `189a8I4uQqVgriMD72mSLYarsevzwiIEE`

### Notebook Sections

| Section | Content | Status |
|---------|---------|--------|
| 1–2 | Data loading, daily CPI KR vs US vs market | Done |
| 3 | Hourly spend — budget cap evidence | Done |
| 4 | Bid price & win price evolution | Done |
| 5 | Budget capper (Reason 030) & priced volume | Done |
| 6 | Cold-start comparison (346 campaigns) | Done |
| 7 | Funnel composition — no compatible creatives | Done |
| 8 | Impression volume & win price scatter | Done |
| 9 | **Postback signal expansion causal analysis** | Done |
| 10 | **KST-based re-analysis** | Done |
| 11 (unlabeled) | Check C hourly training signal count | Done |
| 12 (unlabeled) | Win price extended Mar 26–28 | Done |
| 13 (unlabeled) | Bid price from pricing table (install prediction proxy) | Done |

---

## Key Findings

### 1. Cold-start baseline (prior analysis)
- 14% of all new iOS CPI campaigns have a >1.5x CPI spike on Day 1 — spike alone is not anomalous
- KR and US campaigns show identical timing → shared model, not campaign-specific

### 2. Postback expansion causal chain (Section 9)

**Check C — Training signal count (daily):**
- Mar 23: 14 → Mar 24: 6 → Mar 25: 50 → **Mar 26: 106,799** (+2,136x)
- Confirmed: `b_kpi_action = '#retention'` (not `#install`) for this bundle

**Check C — Training signal count (hourly):**
- Surge onset: **Mar 26 03:00 UTC** — 16,336 signals in a single hour
- Sustains at ~3,200–6,800/hour through Mar 26 23:00 UTC
- Zero data for Mar 27–28 → one-time MMP config flush, not ongoing

**Check A — pb event volume (hourly, Mar 24–28):**
- Both install AND in-app events surged simultaneously at Mar 26 03:00 UTC
- Confirms H2 (direct P(install) inflation) is active alongside H1 (LTV inflation)
- `install_at` values trace back to 2025-04-23 → expansion sent postbacks for long-term organic users
- `click_at = 1970-01-01` (epoch) → unattributed organic users newly visible

**Check B — Win price timing:**
- Win price spike: **Mar 27 20:00–21:00 UTC** (both KR and US, identical hour)
- Lag from surge: **~41 hours** after Mar 26 03:00 UTC
- Identical timing across campaigns = batch model update signature (not per-campaign)

**Check A2 — Received vs event timestamp:**
- Using `timestamp` (received) vs `event.event_at` makes no material difference
- Both show surge at Mar 26 03:00 UTC → surge is real, not a timestamp artifact

**Bid price from pricing table (install prediction proxy):**
- KR campaign: ~27x spike at Mar 27 20:00 UTC (~$0.027/bid vs baseline ~$0.001)
- Mar 28 gap (01:00–14:00 UTC): no bids → budget capper overcorrection
- Mar 28 resume at much lower prices → model corrected or capper forced lower bids

### 3. KST timing (Section 10)
| Event | UTC | KST |
|-------|-----|-----|
| Postback/training surge onset | Mar 26 03:00 | Mar 26 12:00 (Day 1 noon) |
| Win price spike | Mar 27 20:00 | Mar 28 05:00 (Day 3 early AM) |

GM's "Day 2" (Mar 27 KST) doesn't align with the surge (Mar 26 KST) — need GM to confirm exact timeline.

### 4. ~41h lag explanation
- `ua_consol_install_prod_daily` (pre-training DAG) uses 7-day postback lookback, runs `@daily`
- If Mar 26 surge arrived after that day's batch had already run → signals waited for Mar 27 batch
- Mar 27 daily batch deployed → win price spike at Mar 27 20:00 UTC
- Total lag: ~17h (Mar 26 03:00 → Mar 26 20:00 batch) + ~24h training/deploy = ~41h ✓

---

## Data Files

| File | Contents | Notes |
|------|----------|-------|
| `check_a_pb_hourly_events.csv` | Hourly pb events by type (install/in_app), Mar 24–28 | Uses `app.bundle`, `event_name` |
| `check_a2_received_vs_event_date.csv` | Received vs event date comparison | No material difference |
| `check_b_imp_hourly_winprice.csv` | Hourly win price Mar 26–27, by campaign | From `imp` table |
| `check_c_postback_training_cnt.csv` | Daily training signal count Mar 23–26 | cnt: 14→6→50→106799 |
| `check_c_hourly_training_cnt.csv` | Hourly training signal count Mar 23–26 | Surge at Mar 26 03:00 UTC |
| `check_d_hourly_bid_price.csv` | Hourly win price Mar 26–28 extended (imp table) | 104 rows |
| `check_d2_hourly_bid_price_pricing.csv` | Hourly bid price Mar 26–28 (pricing table, CommitBid) | 98 rows; cleaner p(install) proxy |

---

## SQL Reference (Validated Queries)

### Check A — pb hourly event volume
```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS hour_utc,
  DATE(timestamp) AS date_utc,
  CASE WHEN LOWER(event_name) = 'install' THEN 'install' ELSE 'in_app' END AS event_type,
  COUNT(*) AS event_count
FROM `focal-elf-631.prod_stream_view.pb`
WHERE DATE(timestamp) BETWEEN '2026-03-24' AND '2026-03-28'
  AND app.bundle = 'id6550902247'
GROUP BY 1, 2, 3
ORDER BY 1, 3
```

### Check B — hourly win price
```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS hour_utc,
  api.campaign.id AS campaign_id,
  COUNT(*) AS impressions,
  ROUND(AVG(imp.win_price_usd.amount_micro / 1e6), 6) AS avg_win_price_usd,
  ROUND(APPROX_QUANTILES(imp.win_price_usd.amount_micro / 1e6, 100)[OFFSET(50)], 6) AS p50_win_price_usd,
  ROUND(APPROX_QUANTILES(imp.win_price_usd.amount_micro / 1e6, 100)[OFFSET(90)], 6) AS p90_win_price_usd
FROM `focal-elf-631.prod_stream_view.imp`
WHERE DATE(timestamp) BETWEEN '2026-03-26' AND '2026-03-27'
  AND api.campaign.id IN ('BhTo5PHbtcsuQwkh', 'VveaqT1OAcxlbXSv')
GROUP BY 1, 2
ORDER BY 1, 2
```

### Check C — training signal count (hourly)
```sql
SELECT
  TIMESTAMP_TRUNC(install_timestamp, HOUR) AS hour_utc,
  COUNT(*) AS cnt
FROM `moloco-dsp-ml-prod.training_dataset_prod.tfexample_action_postback_imp_v4_beta5_merged`
WHERE DATE(install_timestamp) BETWEEN '2026-03-23' AND '2026-03-28'
  AND b_product_app_bundle_dev_os LIKE '%id6550902247%'
  AND b_kpi_action LIKE '%retention%'
GROUP BY 1
ORDER BY 1
```
> Note: `b_kpi_action = '#retention'` for this bundle — NOT `#install`

---

## Airflow DAGs (Install Model Pipeline)

| Stage | DAG | Schedule | URL |
|-------|-----|----------|-----|
| Pre-training | `ua_consol_install_prod_daily` | `@daily` | https://clzvofruy0h8n01htzvl6ne32.astronomer.run/d4cu8x7e/dags/ua_consol_install_prod_daily/grid |
| Fine-tuning | `ua_consol_install_prod_hourly` | `@hourly` | https://clzvofruy0h8n01htzvl6ne32.astronomer.run/d4cu8x7e/dags/ua_consol_install_prod_hourly/grid |
| Deployment | `ua_consol_install_prod_deploy` | `@hourly` (chains) | https://clzvofruy0h8n01htzvl6ne32.astronomer.run/d4cu8x7e/dags/ua_consol_install_prod_deploy/grid |

**Runtime:** `ua_consol_install_prod_deploy` typical run ~3–4 hours. Runs chain sequentially (`max_active_runs=1`).

---

## pb Table Timestamp Fields (Confirmed Schema)

| Field | Meaning |
|-------|---------|
| `timestamp` | Server-side ingestion time (partition key) — **use this for received time** |
| `event.event_at` | When event occurred on device (MMP-reported) |
| `event.install_at` | Original install time |
| `event.click_at` | Ad click time (epoch `1970-01-01` = organic/unattributed) |
| `event.download_at` | Download start (sparsely populated) |

MMP-to-Moloco delivery lag: ~1–4 seconds for AppsFlyer/Adjust. `timestamp` ≈ received time.

---

## Pending / Open Questions

- [ ] **GM timeline confirmation**: Surge visible at Mar 26 03:00 UTC (not Mar 27 as GM stated). Ask GM for exact signal expansion timestamp. Jira comment drafted (needs sending).
- [ ] **Check F (Engineering)**: Confirm exact `ua_consol_install_prod_daily` cron start time UTC + whether Mar 26 surge was caught in Mar 26 or Mar 27 batch. This resolves the 41h lag ambiguity.
- [ ] **Second spike investigation**: Win price chart shows a second spike at Mar 28 ~03:00–06:00 UTC. Hypotheses: (a) budget capper release + still-inflated model, (b) hourly fine-tuning amplification, (c) low impression volume artifact. Check impression count at those hours from `check_d_hourly_bid_price.csv`.
- [ ] **Attribution split**: Check A query doesn't split `moloco.attributed` — if needed, re-run with `moloco.attributed` as group-by to confirm surge is from unattributed (organic) users.

---

## Jira Comment Draft (Ready to Send)

Drafted in conversation — proofread and edited. Includes queries for Check A/B/C. Waiting for GM response on expansion timeline before finalizing conclusion section.
