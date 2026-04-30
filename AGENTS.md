# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Purpose

Personal analytics workspace for Moloco DSP/NEXT data analysis. Contains BigQuery SQL queries, Jupyter notebooks, and Python utilities for campaign analytics, measurement, fraud monitoring, and ad-hoc investigations.

## Environment Setup

- Python 3.13 venv at `.venv/` — activate with `source .venv/bin/activate`
- Key packages: `google-cloud-bigquery`, `pandas`, `numpy`, `matplotlib`, `seaborn`, `plotly`, `gspread`, `gspread-dataframe`, `google-api-python-client`, `python-dotenv`
- No `requirements.txt` — install packages ad-hoc with `pip install`
- Auth: `GLEAN_API_TOKEN` in `.env`; Google Docs/Sheets credentials at `~/.cursor/client_secret_haewon_cursor_mcp.json`

## Searchlight Agent (Data Delegation)

For BigQuery queries, Moloco data lookups, or internal tool access, delegate to the Searchlight agent:

```bash
cd ~/searchlight && claude -p --model opus "YOUR QUESTION HERE"
```

**Delegate for:** SQL/BQ queries, campaign/spend/install data, table schema discovery, experiment results, publisher data, Glean search, Jira tickets, Google Docs/Sheets/Slides, Sensor Tower, Notion, Looker dashboards, `/investigate` root cause analysis.

**Rules:**
- One question per invocation — never multi-part requests
- Timeout: 300000ms (5 min)
- CSV results land at `~/searchlight/tmp/data/...csv`

**URL routing** — delegate internal URLs (mlc.atlassian.net, docs.google.com, moloco.looker.com, notion.so, github.com/moloco) to Searchlight.

**Handle directly (no delegation):** Python/notebook editing, file operations, git, non-data questions.

## Project Structure

```
[Tickets]/{JIRA_ID}/          # Per-ticket investigation folders
[Proj Blueprint] .../         # Multi-week project work
Measurement/                  # VT, ACS measurement analysis
RE activation/                # Retention/Engagement campaign analysis
premium_support/{client}/     # Client-specific analysis
Fraud/                        # Fraud detection queries
BQ_Tables/                    # Reference table definitions (Aggregated, Dim, RAW, Exp, ML_validation)
utils/                        # Shared Python utilities
KOR_GDS_Dashboard/            # Korea GDS dashboard work
```

**File naming:**
- Tickets: `{JIRA_ID}/{JIRA_ID}_{description}.{ext}`
- Notebooks: `{PROJECT}_{DESCRIPTION}.ipynb`
- Context docs: `{topic}_plan.md`, `{topic}_validation.md`

## Notebook Conventions

**Standard query helper pattern (use in all notebooks):**
```python
from google.cloud import bigquery
import pandas as pd, numpy as np
import matplotlib.pyplot as plt, seaborn as sns
import plotly.express as px, plotly.graph_objects as go

client = bigquery.Client(project="moloco-ods")

def run_query(query, label=''):
    df = client.query(query).result().to_dataframe()
    print(f'✅ {label}: {len(df)} rows')
    return df
```

**Structure:** Markdown header (objective/scope/tables/references) → environment setup → parameter config → sequential analysis cells → visualization → output to Google Sheets or Excel.

**Cell order rule:** Markdown section header MUST always precede its code cell. Never start a section with a code cell.

**BQ projects:** `moloco-ods` (primary), `focal-elf-631` (streaming/event-level data).

## Launch Analysis Notebook Sections

Standard order for new title launches:
1. **Event Discovery** — distinct event names from pb/cv last 30d
2. **Campaign List** — id, name, goal, geo, spend-based active status
3. **KPI Metrics** — CPI, Login CPA, D1/D7/D28 ROAS (last 7d)
4. **Monetization Curve** — % of D28 revenue returned at D1/D3/D7/D14
5. **Device/OS Breakdown** — (optional) install/revenue split

## BQ Column Gotchas

These are hard-learned, verified across sessions — always follow them:

- `app_market_bundle` is **nested** — use `product.app_market_bundle`, never top-level
- `advertiser_id` does NOT exist as flat field in cv/pb tables — use `bid.mtid` for attribution joins
- `fact_dsp_all` uses `timestamp_utc` (TIMESTAMP) — filter with `DATE(timestamp_utc)`, not `date_utc`
- `publisher_app_bundle` does NOT exist — use `publisher.app_market_bundle`
- iOS `mmp_bundle_id` in pb/cv = numeric string only (e.g. `"6737408689"`); prepend `"id"` only for App Store ID matching
- Always use `SAFE_DIVIDE(numerator, NULLIF(denominator, 0))` — zero-denominator errors kill cells silently
- `is_active` campaign flag can be stale — use `spend > 0 in last N days` for real-time active status
- Never hardcode `'login'` as event name — use `WHERE LOWER(event_name) LIKE '%login%'` to catch variants (af_login, login_1st, first_login, etc.)

## Utility Scripts

- **`utils/glean_api.py`** — Glean search/chat REST wrapper. CLI: `python utils/glean_api.py search|chat "query"`. Requires `GLEAN_API_TOKEN` in `.env`.
- **`utils/md_to_gdoc.py`** — Markdown → Google Docs converter. Requires Google OAuth credentials at `~/.cursor/client_secret_haewon_cursor_mcp.json`.

## Output Targets

- **Google Sheets** — fraud monitoring, launch checklists, collaborative results (via `gspread`)
- **Excel (.xlsx)** — ticket investigation results, validation matrices
- **Google Docs** — write-ups via `md_to_gdoc.py`
