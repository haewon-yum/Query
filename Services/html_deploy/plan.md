# HTML Deploy Platform — Plan Doc

**Owner:** Haewon Yum (KOR GDS)  
**GCP Project:** `gds-apac`  
**Date:** 2026-04-20  
**Status:** Draft

---

## 1. Problem Statement

Two compounding pain points drive this platform:

**1. No centralized home for analytics outputs.** Notebook exports, Searchlight reports, and launch checklists are shared as raw files or ad-hoc GDrive links with no consistent structure. There's no way to browse, discover, or revisit past analyses without knowing the exact file location. Work gets lost, duplicated, or siloed within individuals.

**2. Sharing interactive HTML is expensive to set up.** Every time someone wants to share a self-contained HTML report (with Plotly charts, JS interactivity), they either send a file attachment that breaks in email/Slack, or they spin up a one-off webapp just to host it — each person reinventing the same deployment boilerplate. This friction discourages sharing and creates inconsistent, unmaintainable one-offs.

This platform eliminates both problems: a single, centralized hub where any team member can publish an interactive HTML report in seconds — no infra knowledge required — and anyone with a Moloco account can find and view it.

---

## 2. Goals

- **G1** — Serve HTML reports from Google Drive (on-demand fetch) or direct upload (stored in GCS), embedded in a sandboxed iframe
- **G2** — Organize reports by user-defined categories (create/edit/delete)
- **G3** — Restrict access to `@moloco.com` via Google OAuth
- **G4** — Each report has a permanent, shareable URL
- **G5** — Deployable to Cloud Run on `gds-apac` with minimal ops overhead

## Non-Goals (v1)

- Public / external access
- Version history per report
- Inline editing of HTML content
- Comment threads or annotations
- Notifications / subscriptions

---

## 3. Architecture

```
Browser (SPA)
    │  Google OAuth (restricted to @moloco.com)
    ▼
Cloud Run — FastAPI backend
    ├── Auth middleware  (verify Google ID token, domain check)
    ├── GET  /api/categories       — list / create / delete
    ├── POST /api/reports          — register report (GDrive ID or file upload)
    ├── GET  /api/reports          — list with filter by category / search
    ├── GET  /api/reports/{id}     — metadata
    ├── GET  /api/serve/{id}       — fetch HTML from GDrive or GCS, return content
    └── Static files               — React SPA bundle
         │
         ├── Firestore (metadata)
         │    ├── reports   collection
         │    └── categories collection
         │
         ├── GCS bucket `gds-apac-html-reports`
         │    └── uploaded/{report_id}.html
         │
         └── Google Drive API
              └── read HTML file by document ID
```

**Key design choice — GDrive proxy:** The platform fetches GDrive HTML server-side and re-serves it through `/api/serve/{id}`. This avoids GDrive's iframe-blocking restriction and ensures auth is enforced at the platform level, not GDrive sharing settings.

---

## 4. Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Backend | **FastAPI** (Python) | Team is Python-native; async support for GDrive/GCS calls |
| Frontend | **React + Vite** (SPA) | Component model suits category navigation + report viewer |
| Auth | **Google OAuth 2.0** (PKCE flow) + domain check | `@moloco.com` enforcement; no separate identity store |
| Metadata DB | **Firestore** | Serverless, no infra; flexible schema for dynamic categories |
| File storage | **GCS** (`gds-apac-html-reports` bucket) | Direct upload path; lifecycle rules for cleanup |
| GDrive reads | **Google Drive API v3** | Service account with read scope |
| Hosting | **Cloud Run** (single service) | Stateless; auto-scales to zero; fits `gds-apac` |
| Container | **Docker** (backend + frontend bundled) | Single image = single Cloud Run service |

---

## 5. Data Model

### `categories` (Firestore collection)
```
id          : string   (auto)
name        : string   "Launch Analysis"
description : string?
color       : string   "#4A90E2"  (hex, for UI badge)
created_by  : string   (email)
created_at  : timestamp
```

### `reports` (Firestore collection)
```
id           : string   (auto)
title        : string
description  : string?
category_id  : string   → categories.id
source_type  : enum     "gdrive" | "upload"
source_ref   : string   GDrive file ID  OR  GCS object path
uploader     : string   (email)
created_at   : timestamp
updated_at   : timestamp
tags         : string[] (optional, for search)
```

---

## 6. Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/categories` | List all categories |
| `POST` | `/api/categories` | Create category |
| `DELETE` | `/api/categories/{id}` | Delete (only if no reports assigned) |
| `GET` | `/api/reports?category=&q=` | List reports; supports category filter + text search |
| `POST` | `/api/reports` | Register GDrive report (body: `{title, category_id, gdrive_id, ...}`) |
| `POST` | `/api/reports/upload` | Upload HTML file directly (multipart form) |
| `DELETE` | `/api/reports/{id}` | Remove report (GCS file deleted; GDrive untouched) |
| `GET` | `/api/serve/{id}` | Fetch + return raw HTML content (proxied, cached in GCS) |

`/api/serve/{id}` behavior:
1. Check GCS cache (`cache/{report_id}.html`) — serve directly if present
2. On miss: fetch from GDrive API, write to GCS cache, then serve
3. Cache invalidated on report update or manual delete

Response headers:
- `X-Frame-Options: SAMEORIGIN` (iframe allowed only from same origin)
- `Content-Security-Policy: sandbox allow-scripts allow-same-origin`

---

## 7. Frontend UX Flow

```
Landing / Home
├── Category sidebar (left)
│   ├── All Reports
│   ├── [Category A]
│   ├── [Category B]
│   └── + New Category
│
└── Report grid (right)
    ├── Search bar
    ├── Sort (newest / title)
    └── Report cards
        └── [Title] [Category badge] [Uploader] [Date]
             └── Click → /view/{id}

/view/{id}
├── Header: title, category, uploader, date, [Share button]
└── Full-width sandboxed iframe  ← /api/serve/{id}

Upload modal (triggered by "+" button)
├── Title, description, category (select or create new)
├── Tab A: Paste GDrive link or file ID
└── Tab B: Upload HTML file directly
```

---

## 8. Auth Model

1. Frontend initiates Google OAuth 2.0 PKCE flow (client-side)
2. On callback, backend validates Google ID token:
   - Token signature verified against Google certs
   - `hd` claim must equal `moloco.com` → 403 otherwise
3. Backend issues a short-lived session cookie (httpOnly, Secure)
4. All `/api/*` and `/api/serve/*` routes require valid session
5. GDrive API calls use a **service account** (`html-deploy-sa@gds-apac.iam.gserviceaccount.com`) with `Drive: readonly` scope — users grant read access to the service account when using GDrive source

---

## 9. Deployment

### Cloud Run service
```
Service name:  html-deploy
Region:        asia-northeast3 (Seoul) or us-central1
GCP project:   gds-apac
Memory:        512Mi
CPU:           1
Min instances: 0 (scale to zero)
Max instances: 3
Auth:          Allow unauthenticated (OAuth handled in-app)
```

### Environment variables (Secret Manager)
```
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
SERVICE_ACCOUNT_KEY_JSON
GCS_BUCKET_NAME
SESSION_SECRET
FIRESTORE_PROJECT
```

### Build & deploy
```bash
# Build
docker build -t gcr.io/gds-apac/html-deploy:latest .

# Push
docker push gcr.io/gds-apac/html-deploy:latest

# Deploy
gcloud run deploy html-deploy \
  --image gcr.io/gds-apac/html-deploy:latest \
  --region asia-northeast3 \
  --project gds-apac \
  --set-secrets=...
```

### CI/CD (v2 — optional)
Cloud Build trigger on `main` branch push → build → deploy.

---

## 10. Repo Structure

```
html-deploy/
├── backend/
│   ├── main.py           # FastAPI app entry
│   ├── auth.py           # Google OAuth + session middleware
│   ├── routes/
│   │   ├── categories.py
│   │   ├── reports.py
│   │   └── serve.py      # HTML proxy (GDrive + GCS)
│   ├── services/
│   │   ├── firestore.py
│   │   ├── gdrive.py
│   │   └── gcs.py
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── App.tsx
│   │   ├── pages/
│   │   │   ├── Home.tsx
│   │   │   └── Viewer.tsx
│   │   └── components/
│   │       ├── CategorySidebar.tsx
│   │       ├── ReportCard.tsx
│   │       └── UploadModal.tsx
│   ├── package.json
│   └── vite.config.ts
├── Dockerfile            # Multi-stage: build frontend → copy into backend image
└── cloudbuild.yaml
```

---

## 11. Implementation Phases

### Phase 1 — MVP (core value, ~2 weeks)
- [ ] FastAPI backend scaffolding + Firestore connection
- [ ] Google OAuth login with `@moloco.com` domain check
- [ ] GDrive proxy endpoint (`/api/serve/{id}` for GDrive source)
- [ ] Report registration via GDrive ID (no file upload yet)
- [ ] React frontend: home grid + category sidebar + viewer iframe
- [ ] Deploy to Cloud Run on `gds-apac`

### Phase 2 — Full upload + polish (~1 week)
- [ ] Direct HTML file upload → GCS
- [ ] Upload modal (dual tab: GDrive link / file upload)
- [ ] Category create/delete in UI
- [ ] Search + filter
- [ ] Shareable URL with clipboard copy

### Phase 3 — Team features (optional)
- [ ] Report owner can update metadata or replace source
- [ ] "Pinned" reports per category
- [ ] Last-viewed / recently added widgets
- [ ] Cloud Build CI/CD pipeline

---

## 12. Decisions Log

| # | Question | Decision |
|---|----------|----------|
| 1 | Cache GDrive-sourced HTML in GCS after first fetch? | **Yes** — cache in `cache/{report_id}.html`; invalidate on update/delete |
| 2 | TTL / expiry for reports? | **Manual delete only** — no automatic expiry |
| 3 | Category deletion behavior when reports exist? | **Block delete** — must reassign or delete reports first |
| 4 | Cloud Run URL | **Default `.run.app`** — no custom domain for v1 |
