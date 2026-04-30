# Blueprint Dashboard — Cloud Run Migration

**Project:** Blueprint campaign health dashboard
**Repo:** [haewon-yum/blueprint-dashboard](https://github.com/haewon-yum/blueprint-dashboard) → merged to [moloco/gds](https://github.com/moloco/gds/tree/main/projects/google_cloud_run/blueprint)
**Working directory:** `~/gds/projects/google_cloud_run/blueprint/`
**Investigation started:** 2026-04-23

---

## Session 2026-04-23

### Context
- **Scope:** Migrating Blueprint from Google Apps Script to FastAPI on Cloud Run; debugging 403/500 errors on scores and activation endpoints; pushing code to remote repo
- **GCP project:** `gds-apac`, region `asia-northeast3`, service `blueprint`
- **Service account:** `326198683934-compute@developer.gserviceaccount.com`
- **Files touched:** `app/bq.py`, `app/cache.py`, `app/main.py`, `app/auth.py`, `app/notes.py`, `requirements.txt`, `README.md`

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Scores endpoint returning 500 — 403 on `ads-bpd-guard-china` table | Attempted IAM grant via `gcloud projects add-iam-policy-binding` | No permission to set IAM on `ads-bpd-guard-china`; user does not have `setIamPolicy` |
| 2 | Can we use a copy of the same table in `moloco-ods`? | User confirmed `moloco-ods.alaricjames.project_blueprint_combined_data` exists | Switched table reference in `_SCORES_SQL` — deployed as revision `blueprint-00017-jx8` |
| 3 | Activation endpoint returning 500 | Checked Cloud Run logs | Root cause: `ValueError: Out of range float values are not JSON compliant: nan` — BQ results contain NaN floats that crash FastAPI's default serializer |
| 4 | Fix NaN serialization | Round-trip through `df.to_json(orient="records")` → `json.loads()` in `_run()` | NaN → null in JSON; deployed as revision `blueprint-00018-fxh` |
| 5 | Notes endpoint returning 500 | Checked logs: `HttpError 403` on Sheets API | Cloud Run SA not granted access to the Notes Google Sheet — requires manual share |
| 6 | Push code to `moloco/gds` remote | Tried direct push, fork, org repo creation | Direct push: 403; fork: blocked by org policy; org repo creation: no permission; resolved by getting write access to `moloco/gds` and opening PR from `feat/blueprint-cloud-run` branch |
| 7 | Establish sync workflow | Cloned `moloco/gds` to `~/gds/` | Working directory set at `~/gds/projects/google_cloud_run/blueprint/`; PR/deploy workflow documented in README |

### Key Findings

1. **`ads-bpd-guard-china` inaccessible from Cloud Run SA** — SA `326198683934-compute@developer.gserviceaccount.com` has `roles/editor` on `gds-apac` but no access to `ads-bpd-guard-china`. Mirror table exists at `moloco-ods.alaricjames.project_blueprint_combined_data`. Use the `moloco-ods` copy going forward.

2. **NaN floats crash FastAPI JSON serialization** — BQ float columns with missing values return `NaN` in pandas, which the Python `json` module rejects. Fix: replace `.to_dict(orient="records")` with `json.loads(df.to_json(orient="records"))` in `_run()`. Affects any endpoint returning BQ float data.

3. **Notes Google Sheet requires manual SA share** — `notes.py` uses the Sheets API with application-default credentials (the Cloud Run SA). The sheet `1yzriLZh1vgQtTv5xTAlDBaiQ4GzHW8D9fKyOcEtTWUU` must be shared with `326198683934-compute@developer.gserviceaccount.com` as Editor. This is a one-time manual step.

4. **App Script `runQuery()` was silently truncating results** — The old App Script version showed only ~6,140 campaigns because `runQuery()` reads only the first response page (~10 MB cap) without pagination. The Cloud Run version correctly returns all ~19k campaigns.

5. **`blueprint_scores_pivoted` has pipeline fanout bug** — The scheduled query produces ~18 rows per campaign instead of 1. Using the raw `project_blueprint_combined_data` table with a GROUP BY pivot in SQL is the correct fix. Upstream scheduled query should still be fixed separately.

### Open Questions

- [ ] Share Notes Google Sheet with SA `326198683934-compute@developer.gserviceaccount.com` (Editor) — blocks Notes tab
- [ ] Fix upstream `blueprint_scores_pivoted` scheduled query (fanout bug producing ~18 rows/campaign) — in `moloco/gds/projects/blueprint/scheduled_queries/`
- [ ] `.env.example` has `BLUEPRINT_NOTES_SHEET_ID` hardcoded — confirm this is intentional or rotate if sensitive
- [ ] Transfer `haewon-yum/blueprint-dashboard` personal repo to `moloco` org (requires org admin) — currently code lives in both repos; `moloco/gds` is canonical
