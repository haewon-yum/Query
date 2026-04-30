# Action Model Investigation — Concepts, Terminology, and Pipeline Research

**Investigation started:** 2026-04-17

---

## Session 2026-04-17

### Context
- **Scope:** Two parallel tracks — (1) draft Slack reply review for Kimberly Chan re: campaign IV7TA5O07K4JNsjn reactivation (bundle `id6739246483`, iOS, `af_ad_revenue`); (2) deep research into action model + revenue model ML pipeline to correct imprecise terminology in `/gds-core:action-model-investigate` SKILL.md
- **Tables used:** `focal-elf-631.mems_prod.api_log`, `moloco-dsp-ml-prod.training_dataset_prod.tfexample_action_campaignlog_imp_v2`, GCS `gs://tfexample-action/metadata_versions/`, GCS `gs://tfserving-us/`
- **HTML reports read:** `investigation_summary_id6739246483_af_ad_revenue.html`, `investigation_summary_id6739246483_af_ad_revenue+af_purchase.html`
- **Company knowledge sources:** Glean Slack search (multiple channels), GitHub code (`meta.py`, `constants.py`, `compute_campaign_stats.py`, revenue model DAG files)

---

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Does `meta_data.pbtxt` being in training metadata mean training data is being generated? | Glean search + code review (`meta.py`) | NO — it is an append-only bundle registry. Entries never deleted. Presence ≠ training data generating. |
| 2 | Does the 60-day `inactive_window` gate training data rows? | Code review of `read_target_events()`, `compute_campaign_stats.py` | NO — 60-day window only gates (1) new bundle additions to `meta_data.pbtxt` and (2) revenue bundle classification (MAIN vs REF). Existing entries and training rows are NOT removed. |
| 3 | What does `is_live_campaign_goal` actually mean? | Code review of `update_event_live_status()` in `meta.py` | Set to `false` the moment a campaign stops being `STATE=ACTIVE AND enabled`. Not 60-day dependent — immediate. |
| 4 | Can IFA model have postback eval without any Moloco campaign traffic? | Code review (`constants.py`: `pb_normalizer_datasource_lat`) | YES — IFA pb eval source = `tfexample_action_postback` (organic/unattributed MMP installs). LAT pb eval source = `campaignlog` (requires Moloco bid traffic). 3,500 examples in IFA eval = organic IFA installs scored by model. |
| 5 | What is `campaign_stats_set.pbtxt`? | Code review of `compute_campaign_stats.py` | NOT a TFServing model config. Text-format `CampaignStatsSet` proto — a per-campaign × per-KPI × per-prediction-type normalizer snapshot. Read ONCE at model export time; embedded as `tf.lookup.StaticHashTable`. Bidder never reads it directly. |
| 6 | What does `mems_prod.api_log` actually record? | Code + Glean search | Control-plane MEMS audit log. Each row = one `UpdatePricingMetadata` API call from ML pipeline pushing new config. NOT impression-level. Upstream of bidding. |
| 7 | How to verify pricing model at impression level? | Research | Use `prod_stream_view.imp`, field `bid.model.pricing_function` + UNNEST `bid.model.prediction_logs[]` → `type`, `tf_model_name`, `prediction_type`, `wrapper.normalizer`. |
| 8 | Does revenue model require attributed (Moloco-matched) revenue data? | DAG code review (`generate_upstream_tables.py`, `exclude_unmatched_examples.sql`) | YES in practice — organic installs land in `'3. no match'` bucket and are excluded by `--exclude_unmatched_examples = true` (production default). Organic postbacks to Moloco do NOT contribute to revenue model training. |
| 9 | What happens to revenue model when campaign is paused 120 days? | Pipeline logic review | Revenue model requires Moloco req/imp match. 120-day pause = no bid traffic = no new matched examples. Bundle also classified as `REV_BUNDLE_REF` (stale, not `MAIN`) if last ROAS activity >60 days ago. |

---

### Key Findings

1. **`meta_data.pbtxt` is a bundle registry, not a training gate** — Append-only file in `gs://tfexample-action/metadata_versions/`. Entries are never deleted or expired. `is_kpi: true` is sticky. `is_live_campaign_goal` flips immediately on campaign inactivity (not 60-day lag). Being in this file ≠ training data is being generated. Implication: Step 2 of the investigation skill should be renamed "Bundle Registry" not "Training Scope."

2. **60-day `inactive_window` scope is narrow** — It only gates: (1) whether new bundles are added to `meta_data.pbtxt` via `read_target_events()`, and (2) revenue bundle classification as MAIN vs REF. It does NOT remove existing `meta_data.pbtxt` entries, does NOT delete training data rows, does NOT gate `training_data.sql` results. Implication: the "60-day inactive window" column was misleading in the investigation skill's campaign audit table.

3. **IFA pb eval exists without Moloco campaign traffic — that's expected** — Source: `tfexample_action_postback` (organic/unattributed MMP postbacks). The 3,500 examples in IFA eval for `id6739246483 × ios × af_ad_revenue` are organic IFA installs that the model scored. This does NOT mean the action model is serving on this campaign with real predictions. Implication: "model trained" ≠ "LAT model has signal" — must check LAT eval separately.

4. **LAT model requires Moloco bid traffic — absent for this bundle** — `pb_normalizer_datasource_lat = "campaignlog"` (confirmed in `constants.py`). Both campaigns for `id6739246483` were PAUSED (IV7TA5O07K4JNsjn since 2025-12-18 = 120 days, SqHUbqoeXYnCj6Ow since 2026-04-14). Zero LAT training examples in last 14 days. LAT model not found in eval files. Implication: reactivation is required for LAT model to accumulate signal.

5. **Current serving: IFA action model, not LAT** — Step 6 (`mems_prod.api_log`) shows `TYPE_ACTION` (IFA), 3-6 requests/day for IV7TA5O07K4JNsjn while paused. Explanation: MEMS keeps pricing configs for non-ARCHIVED/FINISHED campaigns; bidder checks campaign eligibility separately. The IFA normalizer = 0.625 (D7), `num_examples = 3,500`, `data_source = POSTBACK`. No LAT-based normalizer in pbtxt. Implication: campaign is IFA-priced, not LAT-priced — action model IS applied, but using organic postback signal only.

6. **Revenue model does not train on organic-only postbacks** — `generate_upstream_tables.py` performs LEFT JOIN between Moloco reqs/imps and MMP installs. Unmatched installs are assigned `source_with_priority = '3. no match'`. Production training run passes `--exclude_unmatched_examples = true` which deletes all `'3. no match'` rows before training. Organic IAA postbacks flowing to Moloco do NOT help revenue model training. Requires actual Moloco bid wins. Implication: 120-day campaign pause = no new revenue model training data for this bundle.

7. **Draft Slack answer had one key gap** — The draft correctly identified the IFA/LAT distinction but did not directly address whether unattributed postback data = Revenue Model training data. Correct answer: NO, because production config excludes `'3. no match'` installs at training time. The draft was otherwise accurate on: bundle registered but `is_live_campaign_goal` absent, 0 training examples, IFA model serving with POSTBACK normalizer, LAT not applicable yet.

---

### SKILL.md Updates Made (all 8 edits in one session)

| Section | Change |
|---------|--------|
| Step 0 Interpret | Removed "expired from training scope" language; replaced with accurate text about impressions and `is_live_campaign_goal`; removed 60-day column reference |
| Step 2 title | Renamed "Training Scope" → "Bundle Registry" |
| Step 2 blockquote | Added: append-only nature, `is_kpi: true` sticky, `is_live_campaign_goal` = `STATE=ACTIVE AND enabled`, presence ≠ training data generating |
| Step 3 blockquote | Added: Moloco-attributed impression pairs, daily batch write, rows never deleted on pause, LAT vs IFA eval source split |
| Step 4 table | Added IFA pb eval = organic postback (no campaign traffic needed) vs LAT pb eval = campaignlog (requires bid traffic) |
| Step 5 title | Renamed "Serving pbtxt" → "Normalizer Snapshot" with precise `CampaignStatsSet` proto definition |
| Step 6 | Renamed "Current Pricing Model" → "Pricing Model Configuration"; split into 6a (control-plane: `mems_prod.api_log`) and 6b (data-plane: `prod_stream_view.imp` inline SQL) |
| Constraints + Gotchas | Removed inaccurate `inactive_window = 60 days` gate language; added 3 new gotchas (IFA pb eval ≠ Moloco traffic; paused ≠ absent from pbtxt; `mems_prod.api_log` is control-plane) |

---

### Open Questions

- [ ] Why does `mems_prod.api_log` still show 3-6 `UpdatePricingMetadata` requests/day for IV7TA5O07K4JNsjn when it is PAUSED? Is this expected behavior (MEMS keeps pricing config alive for non-ARCHIVED campaigns)?
- [ ] Revenue model new pipeline code pointers to review for full understanding: `generate_upstream_tables.py` → `generate_reqs_imps_and_installs.sql`, `generate_daily_actions.sql`, `generate_relevant_metadata.sql`, `exclude_unmatched_examples.sql`
- [ ] Does reactivating IV7TA5O07K4JNsjn immediately qualify for LAT model, or is there a minimum impression threshold / warm-up period?
- [ ] Is the `REV_BUNDLE_REF` classification for this bundle recoverable within the 60-day window once campaign is reactivated?
