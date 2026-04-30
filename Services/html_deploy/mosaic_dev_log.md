# Mosaic — Internal HTML Report Sharing Platform

**Project:** Mosaic (`html_deploy/`)
**Deployed at:** https://mosaic-326198683934.asia-northeast3.run.app
**Cloud Run project:** `gds-apac` · region `asia-northeast3`
**GCS bucket:** `gds-apac-html-reports`
**Investigation started:** 2026-04-21

---

## Session 2026-04-21

### Context
- **Scope**: Built and deployed Mosaic v1 from scratch; added category edit feature; added sub-category feature
- **Stack**: FastAPI (Python 3.12) + React 18/TypeScript/Vite, deployed to Cloud Run via Cloud Build (no local Docker)
- **Auth**: Google OAuth 2.0, @moloco.com domain restriction, itsdangerous signed session cookies
- **Storage**: GCS JSON blobs for metadata (`meta/categories/`, `meta/reports/`), GCS for HTML uploads (`uploaded/`)

### Process & Hypotheses

| Step | Hypothesis / Question | Approach | Finding |
|------|-----------------------|----------|---------|
| 1 | Can we use Firestore for metadata? | Attempted Firestore setup | Permission denied — `gcp-gds@` group lacks Firestore create + SA admin roles |
| 2 | Can we use Drive API for HTML serving? | Planned user-token Drive access | Safety hook blocked credential storage approach |
| 3 | GCS as metadata store viable? | Replaced Firestore with GCS JSON blobs in `meta.py` | Works cleanly; no extra permissions needed (compute SA has editor) |
| 4 | OAuth redirect URI mismatch on Cloud Run | Cloud Run proxy reports `http://` for `request.base_url` | Fixed by setting `APP_BASE_URL=https://mosaic-326198683934.asia-northeast3.run.app` env var |
| 5 | `npm ci` fails in Cloud Build | No `package-lock.json` existed | Ran `npm install --package-lock-only` to generate lockfile; committed it |
| 6 | `docker: command not found` locally | Switched from local docker build/push to `gcloud builds submit --tag` | Cloud Build handles image build + push to GCR |
| 7 | Cloud Build "Dockerfile required when specifying --tag" | `deploy.sh` invoked from wrong working dir | Added `cd "$(dirname "${BASH_SOURCE[0]}")"` at top of script |
| 8 | Secret Manager permission denied on Cloud Run | Compute SA lacked `secretmanager.secretAccessor` | Granted via `gcloud projects add-iam-policy-binding` |

### Key Findings

1. **GCS JSON blob store replaces Firestore cleanly** — `meta/categories/{id}.json` and `meta/reports/{id}.json` blobs serve as a lightweight KV store. No Firestore permissions needed. List + read + write all work with the default compute SA (editor role on `gds-apac`).

2. **APP_BASE_URL env var required for OAuth on Cloud Run** — Cloud Run's internal proxy strips HTTPS, causing `request.base_url` to return `http://`. The OAuth callback must be explicitly set via `APP_BASE_URL=https://...run.app` as a Cloud Run env var (`gcloud run services update --set-env-vars`).

3. **Cloud Build is the correct build path** — `gcloud builds submit --tag gcr.io/gds-apac/mosaic:latest` builds and pushes in one step; no local Docker needed. `deploy.sh` must `cd` to the project root first so Cloud Build can find the Dockerfile.

4. **Category edit (v2)** — Added `PUT /api/categories/{id}` endpoint backed by `meta.get_category` + `meta.put_category`. Frontend: `CategoryRow` sub-component with hover pencil (✎) → inline name input + 8 color swatches → Save/Cancel. `api.put()` added to `api.ts`.

5. **Sub-category feature (v3)** — `parent_id?: string` added to `Category` type and backend models. Sidebar filters to `parent_id == null` (top-level only). Sidebar count for a top-level category includes all its children's reports. Sub-category tabs appear as horizontal pills in the main content area when a top-level category is selected. "All" tab shows union of top-level + all sub-category reports. Sub-categories inherit parent color at creation. Upload modal uses `<optgroup>` grouping with `↳ SubName` indentation.

### Architecture Reference

```
html_deploy/
├── backend/
│   ├── main.py           # FastAPI app, mounts static + routers
│   ├── auth.py           # Google OAuth flow, APP_BASE_URL fix, session cookie
│   ├── models.py         # Pydantic: CategoryCreate/Update (parent_id), ReportCreate
│   ├── services/
│   │   ├── meta.py       # GCS JSON blob KV store for categories + reports
│   │   └── gcs.py        # GCS upload/download helpers
│   └── routes/
│       ├── categories.py # GET/POST/PUT/DELETE /api/categories
│       ├── reports.py    # GET /api/reports, POST /api/reports/upload, DELETE
│       └── serve.py      # GET /api/serve/{report_id} — proxy HTML from GCS
├── frontend/
│   ├── src/
│   │   ├── types.ts              # User, Category (parent_id?), Report
│   │   ├── api.ts                # get/post/put/del helpers + extractGDriveId
│   │   ├── pages/
│   │   │   ├── Home.tsx          # Main page: sidebar + sub-cat tabs + report grid
│   │   │   └── Viewer.tsx        # Sandboxed iframe viewer
│   │   └── components/
│   │       ├── CategorySidebar.tsx  # Top-level only; CategoryRow with inline edit
│   │       ├── ReportCard.tsx       # Card with delete on hover
│   │       └── UploadModal.tsx      # Drag-drop upload; optgroup category select
│   └── index.css         # All styles incl. subcategory-tabs, btn-edit-cat
├── Dockerfile            # Multi-stage: node:20-slim build → python:3.12-slim serve
├── deploy.sh             # gcloud builds submit + gcloud run deploy
└── setup.sh              # One-time: APIs, GCS bucket, Secret Manager secrets
```

### Open Questions
- [x] Category delete: cascade-deletes empty sub-categories; blocked if any sub-cat has reports — resolved in session 2026-04-23
- [x] Sub-category edit: inline edit added for sub-category tabs — resolved in session 2026-04-23
- [x] Report re-categorization: edit modal added — resolved in session 2026-04-23
- [x] Access control: uploader-only edit/delete + private sub-categories — resolved in session 2026-04-23
- [ ] HTML file size: current 20MB limit hardcoded in `reports.py`. Revisit if large Plotly exports hit this.

---

## Session 2026-04-23

### Context
- **Scope**: v4 feature additions — report editing, private sub-categories, back-navigation filter persistence, architecture doc; then file picker hint, section deep-links, roadmap doc
- **Files changed**: `backend/routes/reports.py`, `backend/routes/categories.py`, `backend/routes/serve.py`, `backend/models.py`, `frontend/src/pages/Home.tsx`, `frontend/src/pages/Viewer.tsx`, `frontend/src/components/EditReportModal.tsx` (new), `frontend/src/components/ReportCard.tsx`, `frontend/src/types.ts`, `frontend/src/index.css`
- **New files**: `mosaic_architecture.html`, `mosaic_roadmap.html`, `README.md`, `sync-to-gds.sh`

### Process & Hypotheses

| Step | Feature / Question | Approach | Outcome |
|------|--------------------|----------|---------|
| 1 | Report editing (title, description, category, HTML replace) | `PUT /api/reports/{id}` for metadata; `POST /api/reports/{id}/replace` for file; new `EditReportModal.tsx` | Implemented; uploader-only enforced at API layer |
| 2 | Private sub-categories | `is_private` field on Category; `_can_see()` / `_can_access_category()` helpers at every API boundary; 404 (not 403) for non-owners | Implemented; privacy enforced on list, get, serve, upload |
| 3 | Back-navigation loses filter state | `useSearchParams` in Home.tsx; filter state written to `?cat=&sub=` URL params with `replace: true`; ReportCard passes `state: { from: location }` | Resolved — URL persists filter, Viewer back button restores exact view |
| 4 | Cascade category delete | `list_sub_categories()` in meta.py; delete handler removes empty sub-cats before parent; `category_has_reports()` checks sub-cat IDs in set union | Implemented |
| 5 | Sub-category inline edit | `SubCatTab` component in Home.tsx with name input + color swatches + privacy toggle | Implemented; edit pencil only shown to owner |
| 6 | File picker: show original filename as hint | Store `original_filename` at upload and replace time in reports.py; display in EditReportModal drop zone | Implemented; browsers cannot be directed to a specific local path — hint only |
| 7 | Section deep-links in report viewer | Inject `_ANCHOR_SCRIPT` into served HTML (auto-IDs headings, adds `#` buttons, postMessages parent); Viewer reads hash on load + listens for messages | Implemented; URL becomes `/view/{id}#section-slug`; "Section link copied" toast |
| 8 | Sync Mosaic to moloco/gds | `sync-to-gds.sh` using sparse clone + rsync, branch `haewon/mosaic-sync` | 40 files synced to `projects/google_cloud_run/mosaic/` |

### Key Findings

1. **URL hash is the right mechanism for section deep-links** — The Viewer page holds the hash (`/view/{id}#slug`); the injected script in the iframe listens for `postMessage({ type: 'mosaic-scroll-to' })` from the parent after load. Same-origin iframes allow this without restrictions. `onLoad` fires after the injected script has run, so an 80ms timeout before posting ensures the listener is registered.

2. **`False` is not filtered by `if v is not None`** — The `CategoryUpdate` patch logic `{k: v for k, v in body.model_dump().items() if v is not None}` correctly includes `is_private: False` since `False is not None`. No special handling needed for booleans.

3. **Private sub-categories return 404, not 403** — Returning 403 leaks existence. Using 404 for non-owners at every boundary (list, get, serve, upload) keeps the privacy model consistent and avoids information disclosure.

4. **`replace: true` for filter URL sync prevents history pollution** — Using `setSearchParams(p, { replace: true })` means every category click doesn't push a new history entry. The user gets clean back-navigation without needing to press back multiple times to exit the report list.

5. **Sparse clone is the right approach for moloco/gds sync** — `--filter=blob:none --sparse` with `git sparse-checkout set projects/google_cloud_run` avoids downloading the full repo. rsync with `--delete` keeps the target in sync with local on every run.

### Open Questions
- [ ] Feedback / comments: in-app comment panel (GCS-backed) deferred to v5. See `mosaic_roadmap.html` for full options analysis.
- [ ] Glean searchability: GDrive mirror approach recommended but blocked on Drive API access for compute SA. See `mosaic_roadmap.html`.
- [ ] Private sub-category reports: if GDrive mirror is implemented, must skip or restrict sharing for private-category reports.
- [ ] Slack notification on upload: lowest-effort feedback mechanism (P0 in roadmap). Needs a `#mosaic-reports` channel and a webhook/Slack MCP call in `upload_report`.
- [ ] Tag search UI: `tags` field already stored in report metadata but no UI filter exists yet.
