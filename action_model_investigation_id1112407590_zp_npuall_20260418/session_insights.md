# action-model-investigate Skill — Dev & Test Session

**Skill:** `gds-core:action-model-investigate`
**Branch:** `add-skill/action-model-investigate` → PR #52
**Test subject:** `id1112407590 × ios × zp_npuall × RGPQHVtHfPNlSXcU`
**Session date:** 2026-04-18 → 2026-04-21

---

## Session 2026-04-18

### Context
- **Scope:** Skill refactor (structured JSON output, dynamic model discovery, script extraction) + live test run on ZaloPay iOS bundle
- **Output folder:** `action_model_investigation_id1112407590_zp_npuall_20260418/`
- **Scripts used:** `discover_models.sh`, `get_metadata.sh`, `check_eval.sh`, `check_pbtxt.sh`, `run_query.py` + 6 SQL templates
- **Tables:** `prod.campaign_digest_merged_latest`, `entity_history.prod_entity_history`, `df_accesslog.pb`, `tfexample_action_campaignlog_imp_v2`, `mems_prod.api_log`, `prod_stream_view.imp`
- **GCS:** `gs://tfexample-action/metadata_versions/`, `gs://tfserving-us/`

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 0 | Which campaigns have zp_npuall as KPI? | `campaign_digest_merged_latest` + entity history | 3 campaigns: RGPQHVtHfPNlSXcU (ACTIVE), Nu3RqJ9SKxUQHmK4 (PAUSED 2026-04-09), f6EhdMGNHwGpKD4l (DRAFT) |
| 1 | Does zp_npuall fire in MMP data? | `df_accesslog.pb` last 14d | 55,777 postbacks, ~3,984/day, consistent signal |
| 2 | Is bundle × event registered in training pipeline? | `meta_data_0417*.pbtxt` | Registered; `is_live_campaign_goal: true`; `ACTION_EVENT_KPI` |
| 3 | Are training examples being generated? | `tfexample_action_campaignlog_imp_v2` last 14d | 488,735 examples (OTh3FqM3vteUsp7f + hkSJo4zlGNoIzLbC, not RGPQHVtHfPNlSXcU) |
| 4 | Do eval files contain this bundle×event key? | `evaluations_per_key*.tsv` in all 6 active models | NOT FOUND for `id1112407590:ios:zp_npuall` in all models |
| 4 (follow-up) | Is "NOT FOUND" a path error or genuine absence? | `gcloud storage ls` to verify paths; grep for bundle in eval file | Paths confirmed correct; `cashloan_register` + `login_success` found for same bundle; `zp_npuall` genuinely absent |
| 5 | What normalizer is the model using? | `campaign_stats_set.pbtxt` in all 4 consol_v2 models | Campaign entry found, but `pb_eval_info {}` + `bid_eval_info {}` both empty → FALLBACK normalizer |
| 6 | Is action model actually being applied at impressions? | `mems_prod.api_log` + `prod_stream_view.imp` | YES — TYPE_ACTION (IFA) + TYPE_ACTION_LAT (LAT) both active; ~1.4M imps/day; normalizer 0.33550 via MEMS |

### Key Findings

1. **Action model IS applied, but on FALLBACK normalizer** — Campaign RGPQHVtHfPNlSXcU is active and serving with both `TYPE_ACTION` and `TYPE_ACTION_LAT` at ~1.4M impressions/day. Normalizer 0.33550 used via MEMS. The issue is not model absence but normalizer calibration quality. Implication: bids are scoring against `zp_npuall` but without campaign-level eval calibration.

2. **`zp_npuall` absent from all eval files despite 488K training examples in BQ** — LAT eval file for `action_consol_v2_lat_cont` contains `cashloan_register` (9,773 examples) and `login_success` (17,189 examples) for `id1112407590`, but no `zp_npuall`. Training data in BQ is from campaigns OTh3FqM3vteUsp7f and hkSJo4zlGNoIzLbC — these likely postdate or were excluded from the eval window used when the current model version was built (2026-04-17 deployment).

3. **Eval key format confirmed lowercase** — Keys in eval files use `{bundle}:ios:{event}_UNIFIED_D7` (lowercase `ios`), matching what `check_eval.sh` searches for. Key format mismatch is NOT the cause of NOT FOUND.

4. **`prod_stream_view.imp` schema** — Discovered during live test: `bid` struct does NOT have a `campaign_id` field. Campaign ID lives at `api.campaign.id`. Date column is `timestamp` (not `timestamp_utc`). Confirmed fields: `bid.MODEL.pricing_function`, `bid.MODEL.prediction_logs[]`, `api.campaign.id`. (Bug fixed in `imp_pricing.sql`, committed `24dc381`.)

### Bugs Found and Fixed (committed to branch)

| Bug | Script | Fix | Commit |
|-----|--------|-----|--------|
| `grep -oE '[^/]+(?=/$)'` fails on macOS BSD grep (no lookahead support) | `discover_models.sh` | Replaced with `sed 's\|gs://tfserving-us/\|\|; s\|/$\|\|'` | `24dc381` |
| Today's `meta_data_MMDD*` files may not exist in early morning runs | `get_metadata.sh` | Added yesterday fallback: `date -v-1d` (macOS) / `date -d yesterday` (Linux) | `24dc381` |
| `timestamp_utc` column doesn't exist in `prod_stream_view.imp` | `imp_pricing.sql` | Changed to `timestamp` | `24dc381` |
| `bid.campaign_id` doesn't exist in `prod_stream_view.imp` | `imp_pricing.sql` | Changed to `api.campaign.id` | `24dc381` |

### Open Questions

- [ ] Why don't OTh3FqM3vteUsp7f / hkSJo4zlGNoIzLbC training examples show up in the LAT eval file? Investigate whether there's a minimum example threshold or a training window cutoff that excludes recently-started campaigns.
- [ ] `check_eval.sh` silently swallows file-not-found errors (`2>/dev/null`) — consider adding a log line when the TSV file itself is missing vs. when the key is missing within a found file, for better diagnostics.
- [ ] The normalizer used at impression time (0.33550, from MEMS) differs from the value baked into the pbtxt snapshot (0.35868 IFA / 0.31382 LAT from 2026-04-17 deployment). Understand whether this discrepancy is expected (MEMS updated more frequently than pbtxt export cadence).
