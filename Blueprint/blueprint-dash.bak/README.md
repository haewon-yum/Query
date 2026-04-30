# Blueprint Dashboard

Campaign health scores and activation tracker for the GDS team. Runs on Google Cloud Run (FastAPI + vanilla JS).

---

## Architecture

```
FastAPI (Cloud Run, gds-apac, asia-northeast3)
  ├── /api/scores       — pivoted campaign scores from BQ (TTL 6h)
  ├── /api/activation   — activation tracker from BQ (TTL 1h)
  └── /api/notes        — GDS notes stored in Google Sheets
```

Auth: Google OAuth (restricted to @moloco.com). Sessions signed with `itsdangerous`.

BQ queries run against `moloco-ods` billed to `gds-apac`. Data sources:
- `moloco-ods.alaricjames.project_blueprint_combined_data` — raw scores (pivot in query)
- `moloco-ods.alaricjames.blueprint_activation_summary`
- `moloco-ods.alaricjames.blueprint_activation_campaigns`

---

## Prerequisites

- `gcloud` CLI authenticated (`gcloud auth login`)
- Access to GCP project `gds-apac`
- The following secrets already provisioned in Secret Manager (`gds-apac`):
  - `blueprint-google-client-id`
  - `blueprint-google-client-secret`
  - `blueprint-session-secret`
  - `blueprint-notes-sheet-id`
- Google Sheet shared with `326198683934-compute@developer.gserviceaccount.com` (Editor)

---

## Deploy

After any code change, run from this directory:

```bash
bash deploy.sh
```

This does two things in sequence:
1. **Build** — submits the Docker image to Cloud Build and pushes to `gcr.io/gds-apac/blueprint:latest`
2. **Deploy** — creates a new Cloud Run revision and shifts 100% of traffic to it

Typical deploy time: ~2 minutes. The new revision is live immediately after the script exits.

### First-time setup

If deploying to a brand-new GCP project or service name, also run:

```bash
bash setup.sh
```

This enables required APIs (Cloud Run, Cloud Build, Sheets) and creates the Secret Manager secrets. Run it once; it's idempotent.

### After deploy

The script prints the service URL and two reminders:

1. **Set `APP_BASE_URL`** (only needed once, or if the URL changes):
   ```bash
   gcloud run services update blueprint --region asia-northeast3 --project gds-apac \
     --set-env-vars APP_BASE_URL=https://<service-url>
   ```

2. **Add redirect URI** to the OAuth client in Google Cloud Console → APIs & Services → Credentials:
   ```
   https://<service-url>/auth/callback
   ```

---

## Local development

```bash
pip install -r requirements.txt

export GOOGLE_CLIENT_ID=...
export GOOGLE_CLIENT_SECRET=...
export SESSION_SECRET=any-random-string
export BLUEPRINT_NOTES_SHEET_ID=...
export ENV=development          # disables secure cookie flag

uvicorn app.main:app --reload --port 8080
```

For BQ access locally, authenticate with:
```bash
gcloud auth application-default login
```

---

## Cache management

Scores cache: 6-hour TTL. Activation cache: 1-hour TTL. Both warm on startup.

To force a refresh without redeploying, hit the bust endpoint (requires active session):
```bash
curl -X POST https://<service-url>/api/cache/bust \
  -H "Cookie: hd_session=<your-session-cookie>"
```

Or use the **Refresh** button on the Activation Guide tab.

---

## Secrets reference

| Secret name | What it holds |
|---|---|
| `blueprint-google-client-id` | OAuth 2.0 client ID |
| `blueprint-google-client-secret` | OAuth 2.0 client secret |
| `blueprint-session-secret` | Random string for signing session cookies |
| `blueprint-notes-sheet-id` | Google Sheet ID for GDS notes |

Manage via Cloud Console → Secret Manager (project: `gds-apac`), or:
```bash
echo -n "value" | gcloud secrets versions add <secret-name> --data-file=- --project gds-apac
```
