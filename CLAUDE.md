# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal analytics workspace for Moloco data analysis — BigQuery queries, Jupyter notebooks, and Python utilities for DSP/NEXT campaign data, measurement, fraud monitoring, and ad-hoc investigations.

## Searchlight Agent (Primary Data Tool)

Searchlight is an AI investigation agent combining BigQuery, Glean, Jira, Google Docs/Sheets/Slides, Looker, Notion, Slack, Sensor Tower, and experiment analysis into skill-based workflows. It operates as a **Senior Applied Scientist** — hypothesis-driven, statistically rigorous, and causally reasoned.

### Invocation

Always invoke via a skill — never send a bare question without a skill prefix:

```bash
# Root cause analysis, metric questions, general investigations (15-30 min, high confidence)
cd ~/searchlight && claude -p --model opus "/investigate YOUR QUESTION"

# Quick triage — 80% of the value in 3-7 min (use for scoping or time-sensitive checks)
cd ~/searchlight && claude -p --model opus "/investigate-fast YOUR QUESTION"

# Campaign health one-pager with spend chart, AST filters, creative performance
cd ~/searchlight && claude -p --model opus "/campaign-status <campaign_id> [start_date] [end_date]"
```

**Rules:**
- One question per invocation — never send multi-part requests
- Set timeout to 300000ms (5 minutes)
- Returned CSV files land at `~/searchlight/tmp/data/...csv`

### When to use which skill

| Skill | Use when |
|-------|----------|
| `/investigate` | High-confidence RCA, complex cross-domain questions, need exhaustive validation |
| `/investigate-fast` | Quick scoping, time-sensitive checks, single-domain questions |
| `/campaign-status` | Campaign health check — spend, AST, creatives, blocking analysis |

**Delegate when the request involves:** SQL/BigQuery queries, campaign/spend/install data, BQ table schema discovery, experiment results, publisher/supply data, Glean search, Jira tickets, Google Docs/Sheets/Slides, Sensor Tower, Notion, Looker dashboards, or root cause analysis.

**Handle directly (no delegation):** Python/notebook editing, file operations, git, questions unrelated to data or Moloco tools.

### URL routing — pass internal URLs directly into the skill prompt

| URL pattern | Searchlight CLI (used internally) |
|-------------|----------------------------------|
| `mlc.atlassian.net/browse/PROJ-123` | `poetry run jira get PROJ-123` |
| `docs.google.com/document/d/<ID>/...` | `poetry run docs read <ID>` |
| `docs.google.com/spreadsheets/d/<ID>/...` | `poetry run sheets read <ID>` |
| `docs.google.com/presentation/d/<ID>/...` | `poetry run slides read <ID>` |
| `moloco.looker.com/...` | `poetry run looker decode-url "<URL>"` |
| `notion.so/...` | `poetry run notion read <page_id_or_url>` |
| `moloco.slack.com/archives/<channel>/p<ts>` | `poetry run slack fetch-thread --url "<URL>"` |
| `github.com/moloco/...` | `gh` CLI |

## Project Structure

```
[Tickets]/{JIRA_ID}/          # Per-ticket investigation folders
[Proj Blueprint] .../         # Multi-week project work
Measurement/                  # VT, ACS, and other measurement analysis
RE activation/                # Retention/Engagement campaign analysis
premium_support/{client}/     # Client-specific analysis (Netmarble, Nexon)
Fraud/                        # Fraud detection queries and analysis
BQ_Tables/                    # Reference table definitions and scheduled query templates
utils/                        # Shared Python utilities (glean_api, md_to_gdoc)
```

**File naming conventions:**
- Tickets: `{JIRA_ID}/{JIRA_ID}_{description}.{ext}`
- Notebooks: `{PROJECT}_{DESCRIPTION}.ipynb`
- Context docs: `{topic}_plan.md`, `{topic}_validation.md`

## Notebook Conventions

**Standard imports:**
```python
from google.cloud import bigquery
import pandas as pd, numpy as np
import matplotlib.pyplot as plt, seaborn as sns
import plotly.express as px, plotly.graph_objects as go
```

**Standard query helper pattern:**
```python
client = bigquery.Client(project="moloco-ods")

def run_query(query, label=''):
    df = client.query(query).result().to_dataframe()
    print(f'✅ {label}: {len(df)} rows')
    return df
```

**Notebook structure:** Markdown header (objective/scope/tables/references) → environment setup → parameter config → sequential analysis cells → visualization → output to Google Sheets or Excel.

## Key BigQuery Projects

- `moloco-ods` — primary project for most queries
- `focal-elf-631` — detailed streaming/event-level data

**Common SQL patterns:**
- Date ranges: `BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL N DAY) AND CURRENT_DATE()`
- Safe division: `SAFE_DIVIDE(numerator, NULLIF(denominator, 0))`
- Multi-level aggregations with CTEs

## Utility Scripts

- **`utils/glean_api.py`** — Glean internal search REST wrapper. CLI: `python glean_api.py search|chat "query"`. Auth via `GLEAN_API_TOKEN` in `.env`.
- **`utils/md_to_gdoc.py`** — Markdown to Google Docs converter. Credentials at `~/.cursor/client_secret_haewon_cursor_mcp.json`.
- **`premium_support/netmarble/Lunchsupport/fraud_monitor.py`** — Fraud detection CLI. Usage: `python fraud_monitor.py --bundle COM.BUNDLE --os ANDROID --country KOR [--campaign ID] [--lookback DAYS]`. Outputs color-coded Google Sheets with suspension rules.

## Output Targets

- **Google Sheets** — fraud monitoring, launch checklists, collaborative results
- **Excel (.xlsx)** — ticket investigation results, validation matrices
- **Google Docs** — write-ups via `md_to_gdoc.py`

## HTML Report Standards

Every HTML report must include a **fixed, collapsible left sidebar navigator** (not a top nav bar):
- Position: `fixed`, left side, full height, expanded 220px / collapsed 48px
- Toggle button: small circular button at the right edge of the sidebar (`right: -12px`), rotates 180° when collapsed
- When collapsed: labels hidden (`opacity: 0; width: 0`), only emoji icons remain visible in 48px strip
- Main content area: `margin-left: 220px` (expanded) / `margin-left: 48px` (collapsed), both with `transition: margin-left 0.22s ease`
- Sidebar state persisted in `localStorage` key `sidebarCollapsed` — restored on page load
- Sidebar stays visible while scrolling through long reports
- Nav links use `<span class="nav-icon">` + `<span class="nav-label">` structure so icons survive collapse

**Standard sidebar CSS classes:** `.sidebar`, `.sidebar.collapsed`, `.sidebar-toggle`, `.nav-icon`, `.nav-label`, `.main.sidebar-collapsed`

## BQ Column Gotchas (hard-learned, verified across sessions)

- `app_market_bundle` is **nested** in fact_dsp tables — use `product.app_market_bundle`, never top-level
- `advertiser_id` does NOT exist as a flat field in cv/pb tables — use `bid.mtid` for attribution joins
- `fact_dsp_all` uses `timestamp_utc` (TIMESTAMP type) — filter with `DATE(timestamp_utc)`, not `date_utc`
- `publisher_app_bundle` does NOT exist — use `publisher.app_market_bundle`
- iOS `mmp_bundle_id` in pb/cv tables = numeric string only (e.g. `"6737408689"`); prepend `"id"` only when matching against App Store IDs
- Always use `SAFE_DIVIDE(numerator, NULLIF(denominator, 0))` — zero-denominator errors kill cells silently
- `is_active` campaign flag can be stale — use `spend > 0 in last N days` for real-time active status check

## Login Event Discovery

Never hardcode `'login'` as the event name — it varies by MMP and advertiser config:
```sql
WHERE LOWER(event_name) LIKE '%login%'
-- Catches: login_1st, login_first, af_login, first_login, etc.
```

## Notebook Cell Order Rule

**Markdown section header MUST always come before its code cell.** This has been corrected multiple times. Structure is always:
```
[Markdown: ## Section N — Title]
[Code cell: query stub]
```
Never start a section with a code cell.

## Standard Launch Analysis Sections

Every new title launch notebook follows this section order:
```
Section 0: Event Discovery     — distinct event names from pb/cv last 30d
Section 1: Campaign List       — id, name, goal, geo, spend-based active status
Section 2: KPI Metrics         — CPI, Login CPA, D1/D7/D28 ROAS (last 7d)
Section 3: Monetization Curve  — % of D28 revenue returned at D1/D3/D7/D14
Section 4: Device/OS Breakdown — (optional) install/revenue split for de-targeting
```

## Client Bundle IDs (Netmarble)

| Title | Platform | Bundle ID |
|-------|----------|-----------|
| Stonekey | Android | `com.netmarble.stonkey` |
| Stonekey | iOS | `id6737408689` (App Store ID: `6737408689`) |
| Seven Knights Rebirth | Android | `com.netmarble.tskgb` |

Always verify against live BQ for new titles — bundle IDs can differ by region or soft-launch phase.
