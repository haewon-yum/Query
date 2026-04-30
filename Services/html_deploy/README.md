# Mosaic

Internal HTML report sharing platform for the KOR GDS team.

**Live:** https://mosaic-326198683934.asia-northeast3.run.app  
**Auth:** Google OAuth 2.0 — @moloco.com accounts only

---

## What it does

- Upload self-contained `.html` files as shareable reports
- Organize into categories and sub-categories (with optional private workspaces)
- Edit report metadata or replace the HTML file after upload
- Deep-link to specific sections within a report (`/view/{id}#section-slug`)
- Uploader-only edit and delete

## Stack

| Layer | Tech |
|-------|------|
| Backend | FastAPI (Python 3.12) + uvicorn |
| Frontend | React 18 + TypeScript + Vite |
| Storage | GCS — metadata as JSON blobs, HTML files as objects |
| Auth | Google OAuth 2.0, `itsdangerous` signed session cookies |
| Infra | Cloud Run (`gds-apac`, `asia-northeast3`) via Cloud Build |
| Secrets | Secret Manager (`mosaic-*` secrets) |

## Project structure

```
html_deploy/
├── backend/
│   ├── main.py              # FastAPI app
│   ├── auth.py              # OAuth flow + session cookie
│   ├── models.py            # Pydantic request models
│   ├── routes/
│   │   ├── categories.py    # Category CRUD + privacy
│   │   ├── reports.py       # Report CRUD + file upload/replace
│   │   └── serve.py         # HTML proxy from GCS (injects section anchors)
│   └── services/
│       ├── gcs.py           # GCS read/write helpers
│       ├── gdrive.py        # Google Drive fetch (for gdrive-sourced reports)
│       └── meta.py          # JSON blob KV store for categories + reports
├── frontend/src/
│   ├── pages/
│   │   ├── Home.tsx         # Category sidebar + report grid
│   │   └── Viewer.tsx       # Sandboxed iframe viewer + deep-link support
│   └── components/
│       ├── CategorySidebar.tsx
│       ├── UploadModal.tsx
│       ├── EditReportModal.tsx
│       └── ReportCard.tsx
├── Dockerfile               # Multi-stage: node:20-slim build → python:3.12-slim serve
├── deploy.sh                # Cloud Build + Cloud Run deploy
├── setup.sh                 # One-time infra setup (APIs, GCS bucket, secrets)
└── sync-to-gds.sh           # Sync to moloco/gds at projects/google_cloud_run/mosaic/
```

## GCS storage layout

```
gds-apac-html-reports/
├── meta/
│   ├── categories/{id}.json
│   ├── reports/{id}.json
│   └── comments/{report_id}/{comment_id}.json  # (planned)
├── uploaded/{report_id}.html
└── cache/{report_id}.html    # GDrive reports cached here
```

## Deploy

Requires `gcloud` CLI authenticated to `gds-apac`.

```bash
bash deploy.sh
```

Builds the Docker image via Cloud Build, pushes to GCR, and deploys to Cloud Run. No local Docker needed.

## Local development

```bash
# Backend
cd backend
pip install -r requirements.txt
cp ../.env.example .env  # fill in secrets
uvicorn backend.main:app --reload --port 8000

# Frontend (separate terminal)
cd frontend
npm install
npm run dev  # proxies /api/* to localhost:8000
```

## One-time setup (new GCP project)

```bash
bash setup.sh  # enables APIs, creates GCS bucket, sets up Secret Manager entries
```

Then add the OAuth callback URL to the Google Cloud Console:  
`https://{SERVICE_URL}/auth/callback`

