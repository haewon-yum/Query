# Personal Work Dashboard — Plan

**Owner:** Haewon Yum  
**Created:** 2026-04-06  
**Goal:** Single-pane kanban web app showing all in-flight work across Jira, Slack, Drive, Gmail — auto-triaged by Claude, manually refinable.

---

## Problem

Work is scattered across Jira (ODSB), Slack (active channels), Google Docs, and email. No single view of what's active, blocked, overdue, or parked. Things fall through the cracks.

---

## Platform Decision: Google Cloud Run

| | Cloud Run | Apps Script |
|---|---|---|
| Python + Anthropic SDK | ✅ Native | ❌ JS only, REST workarounds |
| Jira/Slack auth | ✅ Simple API token | ❌ OAuth dance required |
| Execution time | ✅ No limit | ❌ 6-min cap (kills parallel calls) |
| Kanban drag-drop | ✅ Any JS library | ❌ Sheets only |
| gcloud already set up | ✅ Reuse | N/A |
| Cost | ~$2-5/mo | Free |

**Decision: Cloud Run.** GCP already configured (`moloco-ods`), Python-native, reuses existing API patterns from `daily_summary.py`.

---

## Tech Stack

```
┌─────────────────────────────────────────────────────┐
│  Frontend (static HTML served by FastAPI)           │
│  Tailwind CSS + Alpine.js + SortableJS              │
│  → Kanban board, drag-drop, status badges           │
├─────────────────────────────────────────────────────┤
│  Backend: FastAPI (Python)                          │
│  GET  /                   → serve dashboard HTML    │
│  GET  /api/items          → return items.json       │
│  POST /api/refresh        → trigger data collection │
│  POST /api/items/{id}     → update bucket/flag/note │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│  Data Pipeline (runs on /api/refresh)               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │  jira.py    │  │  slack.py   │  │  glean.py   │ │
│  │  ODSB proj  │  │ active chns │  │ Drive+Gmail │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │
│         └────────────────┼────────────────┘         │
│                  ┌───────▼──────┐                   │
│                  │ normalize.py │                    │
│                  └───────┬──────┘                   │
│                  ┌───────▼──────┐                   │
│                  │ classify.py  │ ← Claude API       │
│                  │ (AI suggest) │                    │
│                  └───────┬──────┘                   │
│                  ┌───────▼──────┐                   │
│                  │  items.json  │ ← Cloud Storage    │
│                  └─────────────┘                    │
└─────────────────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│  Cloud Scheduler: daily 8am KST → POST /api/refresh │
└─────────────────────────────────────────────────────┘
```

---

## 5 Buckets

| # | Bucket | Definition | Status Flags |
|---|--------|------------|--------------|
| 1 | **To-Do** | Not started; clear action needed | `soon` / `this-week` / `overdue` |
| 2 | **Ongoing** | In progress | `on-track` / `at-risk` / `overdue` |
| 3 | **Pending** | Blocked on someone/something | `waiting-response` / `waiting-info` |
| 4 | **Delegated** | Handed off; tracking outcome | `on-track` / `no-update` / `done` |
| 5 | **Deprioritized** | Deliberately parked | `revisit-date` |

---

## Work Item Schema

```json
{
  "id": "jira:ODSB-16203",
  "title": "PB event volume check for Kakao",
  "source": "jira",
  "source_url": "https://mlc.atlassian.net/browse/ODSB-16203",
  "bucket": 2,
  "status_flag": "on-track",
  "due_date": "2026-04-10",
  "owner": "me",
  "delegated_to": null,
  "last_signal": "2026-04-05T14:23:00Z",
  "context": "Investigating unusually low PB event volume for Kakao campaign since Mar 28",
  "tags": ["kakao", "measurement", "ticket"],
  "ai_suggested_bucket": 2,
  "ai_confidence": 0.87,
  "human_confirmed": false,
  "notes": ""
}
```

---

## Data Sources

### Jira (ODSB project)
- Assigned + open: `project = ODSB AND assignee = currentUser() AND resolution = Unresolved`
- Watching (delegated signal): `project = ODSB AND watcher = currentUser() AND resolution = Unresolved AND assignee != currentUser()`
- Commented recently (pending signal): issues I commented on in last 14d with no subsequent reply from assignee
- **API:** Jira REST v3 with API token

### Slack (active channels only)
- Channels where I've posted in last 30 days → auto-detected
- Scan for: unresponded `@haewon` mentions, DMs with no reply from me, threads I'm in still active
- Keyword scan: "haewon can you", "haewon please", "FYI haewon", "action item"
- **API:** Slack Web API with user token (not bot — needs personal token for DMs)

### Google Drive + Gmail (via Glean)
- Drive: docs I've edited in last 14d (in-progress signal)
- Drive: docs shared with me + unresolved comments (pending review signal)
- Gmail: threads where I'm last needed to respond (Glean query: "emails waiting for my reply")
- **API:** `mcp__glean_default__chat` queries (Glean indexes both Drive + Gmail)

### Manual
- `manual_items.yaml` — hand-edited, survives across refreshes
- Items added via "Add manually" button in the UI

---

## Classification (AI + Human confirm)

Claude classifies each item in a single batch call:

**Prompt pattern:**
```
You are a work prioritization assistant. For each work item below, suggest:
1. bucket (1=Todo, 2=Ongoing, 3=Pending, 4=Delegated, 5=Deprioritized)
2. status_flag (from allowed list per bucket)
3. due_date (infer from context if not explicit)
4. 1-sentence context summary

Return JSON array. Items without enough signal → bucket 3 (Pending).
```

Human confirms or overrides in the UI — confirmed items are not re-classified on next refresh.

---

## UI Design

```
┌──────────────────────────────────────────────────────────────────┐
│  My Work Dashboard          [Refresh] [+ Add]      Last: 8:02am  │
├──────────────┬──────────────┬──────────────┬──────────┬──────────┤
│  📋 To-Do    │  🔄 Ongoing  │  ⏳ Pending  │  👥 Del  │  💤 Park │
│  (3)         │  (7)         │  (4)         │  (2)     │  (5)     │
├──────────────┼──────────────┼──────────────┼──────────┼──────────┤
│ ┌──────────┐ │ ┌──────────┐ │ ┌──────────┐ │          │          │
│ │ODSB-1234 │ │ │ODSB-1620 │ │ │Slack:    │ │          │          │
│ │due Apr 8 │ │ │🟡at-risk │ │ │@haewon   │ │          │          │
│ │[confirm] │ │ │[confirm] │ │ │Apr 3     │ │          │          │
│ └──────────┘ │ └──────────┘ │ └──────────┘ │          │          │
│              │              │              │          │          │
│  drag ↕      │  drag ↕      │  drag ↕      │  drag ↕  │  drag ↕  │
└──────────────┴──────────────┴──────────────┴──────────┴──────────┘
```

- Drag between columns = manual bucket override (persisted, skips AI reclassification)
- `[confirm]` badge = AI suggested, awaiting human confirmation
- Color coding: 🔴 overdue, 🟡 at-risk, 🟢 on-track
- Click card = expand context, edit notes, set due date

---

## File Structure

```
WorkManagement/
├── plan.md                     ← this file
├── config.yaml                 ← API tokens, Jira projects, Slack channels
├── manual_items.yaml           ← hand-edited items
│
├── app/                        ← Cloud Run service
│   ├── main.py                 ← FastAPI app + routes
│   ├── collectors/
│   │   ├── jira.py
│   │   ├── slack.py
│   │   └── glean.py
│   ├── normalize.py
│   ├── classify.py             ← Claude API batch classification
│   ├── storage.py              ← read/write items.json (Cloud Storage)
│   ├── static/
│   │   ├── index.html          ← dashboard UI
│   │   ├── style.css
│   │   └── app.js              ← Alpine.js + SortableJS
│   ├── requirements.txt
│   └── Dockerfile
│
└── deploy/
    ├── deploy.sh               ← gcloud run deploy one-liner
    └── scheduler.sh            ← Cloud Scheduler setup
```

---

## Credentials Needed

| Service | What | Where to get |
|---------|------|--------------|
| Jira | API token | atlassian.com/manage-profile/security/api-tokens |
| Slack | User OAuth token (xoxp-) | api.slack.com/apps → OAuth & Permissions |
| Anthropic | API key | console.anthropic.com |
| Glean | API token | Already in `~/Documents/Queries/.env` |
| GCP | Service account | Already set up via gcloud (`moloco-ods`) |

All stored as Cloud Run environment variables (Secret Manager for prod).

---

## Build Phases

| Phase | Scope | Effort |
|-------|-------|--------|
| **1 — Jira MVP** | Jira collector + normalize + classify + basic HTML table | 1 day |
| **2 — Slack** | Slack collector, active channels auto-detect, mentions scan | 1 day |
| **3 — Drive + Gmail** | Glean queries for Drive docs + Gmail threads | 0.5 day |
| **4 — Kanban UI** | SortableJS drag-drop, confirm flow, card expand | 1 day |
| **5 — Deploy + Schedule** | Dockerfile, Cloud Run deploy, Cloud Scheduler | 0.5 day |

---

## Open Questions — Resolved

- ✅ Platform: Cloud Run
- ✅ Jira scope: ODSB project
- ✅ Slack scope: channels where active (auto-detected from post history)
- ✅ Classification: AI suggests → human confirms

## Remaining Decisions

- [ ] Storage backend: Cloud Storage (JSON file) vs Firestore? → **Lean to Cloud Storage** (simpler, no DB setup)
- [ ] Slack token type: user token (xoxp-) or bot token? → **User token** (needed for DMs + personal context)
- [ ] UI: serve HTML from FastAPI, or separate static hosting? → **FastAPI serves static** (single service, simpler deploy)
