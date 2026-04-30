import os
import sys
import json
import asyncio
import re
from pathlib import Path


def _guess_doc_category(title: str) -> str:
    """Keyword-based category fallback (used when Claude is not available)."""
    lower = title.lower()
    if any(k in lower for k in ("netmarble", "nexon", "111percent", "mobidays", "coupang", "krafton", "ncsoft", "client")):
        return "Client Work"
    if any(k in lower for k in ("kor", "kr ", "korea", "kr_", "korean")):
        return "KR GDS"
    if any(k in lower for k in ("apac",)):
        return "APAC GDS"
    if any(k in lower for k in ("gds",)):
        return "GDS"
    if any(k in lower for k in ("agenda", "meeting", "sync", "notes", "1:1", "standup", "all hands", "all-hands")):
        return "Meeting Agenda"
    if any(k in lower for k in ("weekly", "cadence", "monthly", "tracker", "dashboard", "scorecard")):
        return "Cadence"
    if any(k in lower for k in ("strategy", "okr", "roadmap", "planning", "plan", "goal")):
        return "Strategy"
    if any(k in lower for k in ("analysis", "deep-dive", "deep dive", "investigation", "report", "experiment")):
        return "Analysis"
    return "Reference"
from datetime import datetime, timezone, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

from dotenv import load_dotenv
load_dotenv(Path(__file__).parent.parent / ".env")

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
import uvicorn

from models import WorkItem, ItemUpdate
from pydantic import BaseModel
from normalize import normalize
from classify import classify
from storage import load_items, save_items, load_manual_items, merge_with_existing, load_tombstone, add_to_tombstone, add_id_to_tombstone

app = FastAPI(title="Work Dashboard")
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")

# Track refresh state
_last_refresh: str | None = None
_refresh_running: bool = False
_refresh_errors: list[str] = []


_banner_cache: dict = {}  # {"summary": str, "generated_at": str}
BANNER_TTL_MINUTES = 15


@app.get("/api/banner")
async def get_banner(force: bool = False):
    """Generate a natural-language 현황판 summary of the last ~4h of activity."""
    global _banner_cache
    # Return cached if fresh
    if not force and _banner_cache.get("summary_4h"):
        cached_at = datetime.fromisoformat(_banner_cache["generated_at"])
        if (datetime.now(timezone.utc) - cached_at).seconds < BANNER_TTL_MINUTES * 60:
            return _banner_cache

    try:
        from concurrent.futures import ThreadPoolExecutor, as_completed
        now = datetime.now(timezone.utc)
        since_2h  = now - timedelta(hours=2)
        since_4h  = now - timedelta(hours=4)
        since_8h  = now - timedelta(hours=8)
        since_24h = now - timedelta(hours=24)
        signals_2h  = {"local": {}, "github": {}, "jira": [], "slack": [], "drive": []}
        signals_4h  = {"local": {}, "github": {}, "jira": [], "slack": [], "drive": []}
        signals_8h  = {"local": {}, "github": {}, "jira": [], "slack": [], "drive": []}
        signals_24h = {"local": {}, "github": {}, "jira": [], "slack": [], "drive": []}

        # Signal items are dicts: {text, url, ts}
        def _item(text: str, url: str = "", ts: str = "") -> dict:
            return {"text": text[:120], "url": url or "", "ts": ts or ""}

        def _fmt_ts(iso: str) -> str:
            """Format ISO timestamp → 'HH:MM' in local time for display."""
            if not iso:
                return ""
            try:
                from datetime import datetime, timezone
                dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
                local = dt.astimezone()
                return local.strftime("%-I:%M %p")
            except Exception:
                return ""

        def _glean_search(query: str, datasource: str, page_size: int, since: datetime) -> list[dict]:
            """Search Glean; return [{text, url}] filtered to actual time window via updatedAt."""
            import subprocess as _sp, json as _json
            token = os.environ.get("GLEAN_API_TOKEN", "")
            payload = _json.dumps({
                "query": query,
                "pageSize": page_size,
                "requestOptions": {"datasourceFilter": datasource},
            })
            r = _sp.run(
                ["curl", "-s", "-X", "POST", "https://moloco-be.glean.com/rest/api/v1/search",
                 "-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json",
                 "-d", payload, "--max-time", "12"],
                capture_output=True, text=True, timeout=15,
            )
            if not r.stdout.strip():
                return []
            results = _json.loads(r.stdout).get("results", [])
            since_ts = since.timestamp()
            items = []
            for res in results:
                doc = res.get("document", {})
                title = doc.get("title", "").strip()
                url = doc.get("url", "").strip()
                if not title:
                    continue
                updated_at = doc.get("updatedAt", 0)
                if isinstance(updated_at, (int, float)) and updated_at > 0:
                    if updated_at < since_ts:
                        continue
                items.append(_item(title, url))
            return items

        def _local_2h():
            from collectors.local_activity import collect_local
            return "local_2h", collect_local(hours=2)

        def _local_4h():
            from collectors.local_activity import collect_local
            return "local_4h", collect_local(hours=4)

        def _local_8h():
            from collectors.local_activity import collect_local
            return "local_8h", collect_local(hours=8)

        def _github_2h():
            from collectors.local_activity import collect_github
            return "github_2h", collect_github(hours=2)

        def _github_4h():
            from collectors.local_activity import collect_github
            return "github_4h", collect_github(hours=4)

        def _github_8h():
            from collectors.local_activity import collect_github
            return "github_8h", collect_github(hours=8)

        def _jira_4h():
            from collectors.jira import JiraCollector
            raw = JiraCollector().collect_my_activity(since=since_4h)
            return "jira_4h", [_item(f"{r['id'].split(':')[1]}: {r['title'][:70]}", r.get("source_url",""), r.get("last_signal","")) for r in raw[:8]]

        def _jira_8h():
            from collectors.jira import JiraCollector
            raw = JiraCollector().collect_my_activity(since=since_8h)
            return "jira_8h", [_item(f"{r['id'].split(':')[1]}: {r['title'][:70]}", r.get("source_url",""), r.get("last_signal","")) for r in raw[:12]]

        def _slack_4h():
            from collectors.slack import SlackCollector
            return "slack_4h", SlackCollector().collect_recent_activity(hours=4)

        def _slack_8h():
            from collectors.slack import SlackCollector
            return "slack_8h", SlackCollector().collect_recent_activity(hours=8)

        def _drive_4h():
            from collectors.drive import DriveCollector
            raw = DriveCollector().collect_my_activity(since=since_4h)
            return "drive_4h", [_item(r.get("title",""), r.get("source_url",""), r.get("last_signal","")) for r in raw[:6]]

        def _drive_8h():
            from collectors.drive import DriveCollector
            raw = DriveCollector().collect_my_activity(since=since_8h)
            return "drive_8h", [_item(r.get("title",""), r.get("source_url",""), r.get("last_signal","")) for r in raw[:8]]

        def _jira_24h():
            from collectors.jira import JiraCollector
            raw = JiraCollector().collect_my_activity(since=since_24h)
            return "jira_24h", [_item(f"{r['id'].split(':')[1]}: {r['title'][:70]}", r.get("source_url",""), r.get("last_signal","")) for r in raw[:15]]

        def _slack_24h():
            from collectors.slack import SlackCollector
            return "slack_24h", SlackCollector().collect_recent_activity(hours=24)

        def _drive_24h():
            from collectors.drive import DriveCollector
            raw = DriveCollector().collect_my_activity(since=since_24h)
            return "drive_24h", [_item(r.get("title",""), r.get("source_url",""), r.get("last_signal","")) for r in raw[:10]]

        def _local_24h():
            from collectors.local_activity import collect_local
            return "local_24h", collect_local(hours=24)

        def _github_24h():
            from collectors.local_activity import collect_github
            return "github_24h", collect_github(hours=24)

        with ThreadPoolExecutor(max_workers=12) as ex:
            fns = (_local_2h, _local_4h, _local_8h, _local_24h,
                   _github_2h, _github_4h, _github_8h, _github_24h,
                   _jira_4h, _jira_8h, _jira_24h,
                   _slack_4h, _slack_8h, _slack_24h,
                   _drive_4h, _drive_8h, _drive_24h)
            futures = [ex.submit(f) for f in fns]
            for fut in as_completed(futures, timeout=50):
                try:
                    key, val = fut.result()
                    if   key == "local_2h":    signals_2h["local"]   = val
                    elif key == "local_4h":    signals_4h["local"]   = val
                    elif key == "local_8h":    signals_8h["local"]   = val
                    elif key == "local_24h":   signals_24h["local"]  = val
                    elif key == "github_2h":   signals_2h["github"]  = val
                    elif key == "github_4h":   signals_4h["github"]  = val
                    elif key == "github_8h":   signals_8h["github"]  = val
                    elif key == "github_24h":  signals_24h["github"] = val
                    elif key == "jira_4h":     signals_4h["jira"]    = val
                    elif key == "jira_8h":     signals_8h["jira"]    = val
                    elif key == "jira_24h":    signals_24h["jira"]   = val
                    elif key == "slack_4h":    signals_4h["slack"]   = val
                    elif key == "slack_8h":    signals_8h["slack"]   = val
                    elif key == "slack_24h":   signals_24h["slack"]  = val
                    elif key == "drive_4h":    signals_4h["drive"]   = val
                    elif key == "drive_8h":    signals_8h["drive"]   = val
                    elif key == "drive_24h":   signals_24h["drive"]  = val
                except Exception as e:
                    print(f"⚠️ banner signal failed: {e}")

        # Build 2h signals: filter 4h jira/slack/drive by timestamp
        def _filter_ts(items: list, cutoff: datetime) -> list:
            result = []
            for item in items:
                if not isinstance(item, dict):
                    continue
                ts = item.get("ts", "")
                if not ts:
                    continue
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    if dt >= cutoff:
                        result.append(item)
                except Exception:
                    pass
            return result

        signals_2h["jira"]  = _filter_ts(signals_4h["jira"],  since_2h)
        signals_2h["slack"] = _filter_ts(signals_4h["slack"], since_2h)
        signals_2h["drive"] = _filter_ts(signals_4h["drive"], since_2h)

        # Deduplicate: 8H shows only what's NOT already in 4H (makes it "4–8h ago" window)
        def _key(item) -> str:
            return (item.get("text","") if isinstance(item, dict) else item)[:60]

        for sig_key in ("jira", "slack", "drive"):
            four_h_keys = {_key(i) for i in signals_4h[sig_key]}
            signals_8h[sig_key] = [i for i in signals_8h[sig_key] if _key(i) not in four_h_keys]

        # Local: deduplicate git commits and files the same way
        def _file_path(f) -> str:
            return f["path"] if isinstance(f, dict) else f

        four_commits = set(signals_4h["local"].get("git_commits", []))
        signals_8h["local"]["git_commits"] = [
            c for c in signals_8h["local"].get("git_commits", []) if c not in four_commits
        ]
        four_file_paths = {_file_path(f) for f in signals_4h["local"].get("modified_files", [])}
        signals_8h["local"]["modified_files"] = [
            f for f in signals_8h["local"].get("modified_files", []) if _file_path(f) not in four_file_paths
        ]

        # Deduplicate 24h: remove anything already in 4h or 8h
        for sig_key in ("jira", "slack", "drive"):
            seen = {_key(i) for i in signals_4h[sig_key]} | {_key(i) for i in signals_8h[sig_key]}
            signals_24h[sig_key] = [i for i in signals_24h[sig_key] if _key(i) not in seen]

        eight_commits = set(signals_8h["local"].get("git_commits", []))
        all_commits = four_commits | eight_commits
        signals_24h["local"]["git_commits"] = [
            c for c in signals_24h["local"].get("git_commits", []) if c not in all_commits
        ]
        eight_file_paths = {_file_path(f) for f in signals_8h["local"].get("modified_files", [])}
        all_file_paths = four_file_paths | eight_file_paths
        signals_24h["local"]["modified_files"] = [
            f for f in signals_24h["local"].get("modified_files", []) if _file_path(f) not in all_file_paths
        ]

        # Build context strings for each window
        # Items are {text, url} dicts; local signals are plain strings
        def _fmt(item) -> str:
            if isinstance(item, dict):
                url = item.get("url", "")
                ts  = _fmt_ts(item.get("ts", ""))
                parts = f"  - {item['text']}"
                if ts:  parts += f" [at {ts}]"
                if url: parts += f" | {url}"
                return parts
            return f"  - {item}"

        def _label_file(path: str) -> str:
            from collectors.local_activity import _rich_label
            return _rich_label(path)

        def _fmt_local_file(f) -> str:
            """Format a {path, ts} file dict for context."""
            if isinstance(f, dict):
                label = _label_file(f["path"])
                ts    = _fmt_ts(f.get("ts", ""))
                return f"  - {label}" + (f" [at {ts}]" if ts else "")
            return f"  - {_label_file(f)}"

        def _build_context(sig: dict) -> str:
            parts = []
            local = sig.get("local", {})
            github = sig.get("github", {})
            if local.get("git_commits"):
                parts.append("Local git commits:\n" + "\n".join(f"  - {c}" for c in local["git_commits"]))
            if github.get("commits"):
                parts.append("GitHub commits (remote repos):\n" + "\n".join(f"  - {c}" for c in github["commits"]))
            if github.get("prs"):
                parts.append("GitHub PRs:\n" + "\n".join(f"  - {p['title']} {p['url']}" for p in github["prs"]))
            if local.get("modified_files"):
                parts.append("Files I modified locally (with timestamps):\n" +
                             "\n".join(_fmt_local_file(f) for f in local["modified_files"]))
            if sig.get("jira"):
                parts.append("Jira tickets:\n" + "\n".join(_fmt(t) for t in sig["jira"]))
            if sig.get("slack"):
                parts.append("Slack messages Haewon sent:\n" + "\n".join(_fmt(s) for s in sig["slack"]))
            if sig.get("drive"):
                parts.append("Google Drive docs:\n" + "\n".join(_fmt(d) for d in sig["drive"]))
            return "\n\n".join(parts)

        ctx_2h  = _build_context(signals_2h)
        ctx_4h  = _build_context(signals_4h)
        ctx_8h  = _build_context(signals_8h)
        ctx_24h = _build_context(signals_24h)

        if not ctx_4h and not ctx_8h and not ctx_24h:
            return {"plain_2h": "", "summary_4h": "No recent activity.", "summary_8h": "No recent activity.",
                    "summary_24h": "No recent activity.",
                    "generated_at": datetime.now(timezone.utc).isoformat()}

        import anthropic as _anthropic
        client = _anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

        def _summarize_prose(context: str) -> str:
            """One or two plain-English sentences: what Haewon is doing right now."""
            if not context:
                return ""
            prompt = (
                "Based ONLY on the signals below, write 1–2 sentences in plain English "
                "describing what Haewon is currently working on. "
                "Rules:\n"
                "- Present tense, active voice: 'Working on X', 'Reviewing Y and Z'\n"
                "- Casual and natural, like a Slack status update\n"
                "- No bullet points, no markdown, no asterisks, no headers\n"
                "- Focus on the 2–3 most important recent activities\n"
                "- Max 35 words total\n"
                "- If signals are sparse, write 1 short sentence\n"
                "No preamble — output only the sentence(s).\n\n"
                + context
            )
            msg = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=80,
                messages=[{"role": "user", "content": prompt}],
            )
            return msg.content[0].text.strip()

        def _summarize(context: str, window: str) -> str:
            if not context:
                return "No activity detected."
            if window == "4h":
                focus = "Focus on the most recent actions — what she is actively doing right now."
            elif window == "8h":
                focus = "Summarize activity from 4–8 hours ago (earlier this session, before the most recent 4h)."
            else:
                focus = "Summarize activity from 8–24 hours ago (earlier today or yesterday, before the most recent 8h)."
            prompt = (
                f"Summarize Haewon Yum's work activity from the last {window} based ONLY on the signals below. {focus}\n"
                "STRICT RULES:\n"
                "- Only describe activity explicitly listed in the signals. Do NOT infer or add anything not present.\n"
                "- Cover ALL signal types present: git commits, locally modified files, Jira tickets, Slack messages, Drive docs.\n"
                "- 'Files I modified locally' signals are important — always include them as bullets describing what was worked on.\n"
                "- If the signals list is sparse, return fewer bullets. Do not pad.\n"
                "- Signals may have a timestamp like [at 2:30 PM]. Include it at the START of the bullet as a dim label: [2:30 PM]\n"
                "- For local files without timestamps, just describe the work: e.g. • Working on **StoneAge performance investigation** notebook\n"
                "- Sort bullets by time descending (most recent first). Local files without timestamps go at the end.\n"
                "- For each bullet, if the signal has an http/https URL (after the | separator), embed it as [link](url) at the end.\n"
                "- Do NOT include local file paths as links. Never output ~/ or / paths.\n"
                "- Wrap key terms (project names, ticket IDs, client names, filenames) in **double asterisks**.\n"
                "- Keep each bullet ≤15 words including the link. Always complete the full bullet — never cut off mid-sentence or mid-URL.\n"
                "No preamble, no headers — just bullets starting with •\n\n"
                + context
            )
            msg = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}],
            )
            return msg.content[0].text.strip()

        with ThreadPoolExecutor(max_workers=4) as ex:
            fp  = ex.submit(_summarize_prose, ctx_2h)
            f4  = ex.submit(_summarize, ctx_4h,  "4h")
            f8  = ex.submit(_summarize, ctx_8h,  "8h")
            f24 = ex.submit(_summarize, ctx_24h, "24h")
            plain_2h    = fp.result()
            summary_4h  = f4.result()
            summary_8h  = f8.result()
            summary_24h = f24.result()

        _banner_cache = {
            "plain_2h":    plain_2h,
            "summary_4h":  summary_4h,
            "summary_8h":  summary_8h,
            "summary_24h": summary_24h,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "signals_4h": {
                "jira_count": len(signals_4h["jira"]),
                "slack_count": len(signals_4h["slack"]),
                "drive_count": len(signals_4h["drive"]),
                "local_files": len(signals_4h["local"].get("modified_files", [])),
                "git_commits": len(signals_4h["local"].get("git_commits", [])),
            },
            "signals_8h": {
                "jira_count": len(signals_8h["jira"]),
                "slack_count": len(signals_8h["slack"]),
                "drive_count": len(signals_8h["drive"]),
                "local_files": len(signals_8h["local"].get("modified_files", [])),
                "git_commits": len(signals_8h["local"].get("git_commits", [])),
            },
            "signals_24h": {
                "jira_count": len(signals_24h["jira"]),
                "slack_count": len(signals_24h["slack"]),
                "drive_count": len(signals_24h["drive"]),
                "local_files": len(signals_24h["local"].get("modified_files", [])),
                "git_commits": len(signals_24h["local"].get("git_commits", [])),
            },
        }
        return _banner_cache

    except Exception as e:
        return {"summary": f"Could not generate summary: {e}", "generated_at": datetime.now(timezone.utc).isoformat()}


@app.get("/api/banner/debug")
async def banner_debug():
    """Return raw signals and contexts for debugging — no Claude synthesis."""
    from concurrent.futures import ThreadPoolExecutor, as_completed as _ac
    now = datetime.now(timezone.utc)
    since_4h  = now - timedelta(hours=4)
    since_8h  = now - timedelta(hours=8)
    since_24h = now - timedelta(hours=24)

    from collectors.local_activity import collect_local
    local_4h  = collect_local(hours=4)
    local_8h  = collect_local(hours=8)
    local_24h = collect_local(hours=24)

    def _fp(f): return f["path"] if isinstance(f, dict) else f

    four_paths  = {_fp(f) for f in local_4h.get("modified_files", [])}
    eight_paths = {_fp(f) for f in local_8h.get("modified_files", [])}
    unique_8h   = [f for f in local_8h.get("modified_files",  []) if _fp(f) not in four_paths]
    unique_24h  = [f for f in local_24h.get("modified_files", []) if _fp(f) not in four_paths | eight_paths]

    four_commits  = set(local_4h.get("git_commits", []))
    eight_commits = set(local_8h.get("git_commits", []))
    unique_commits_8h  = [c for c in local_8h.get("git_commits",  []) if c not in four_commits]
    unique_commits_24h = [c for c in local_24h.get("git_commits", []) if c not in four_commits | eight_commits]

    return {
        "local_4h":  {"files": local_4h.get("modified_files",  []), "commits": local_4h.get("git_commits",  [])},
        "local_8h":  {"files": local_8h.get("modified_files",  []), "commits": local_8h.get("git_commits",  [])},
        "local_24h": {"files": local_24h.get("modified_files", []), "commits": local_24h.get("git_commits", [])},
        "after_dedup": {
            "files_4h":        list(local_4h.get("modified_files", [])),
            "files_8h_only":   unique_8h,
            "files_24h_only":  unique_24h,
            "commits_8h_only":  unique_commits_8h,
            "commits_24h_only": unique_commits_24h,
        },
    }


@app.get("/", response_class=HTMLResponse)
async def index():
    html_path = Path(__file__).parent / "static" / "index.html"
    return html_path.read_text()


@app.get("/api/items")
async def get_items():
    items = load_items()
    return {
        "items": [item.model_dump() for item in items],
        "last_refresh": _last_refresh,
        "refresh_running": _refresh_running,
        "counts": _bucket_counts(items),
    }


@app.get("/api/refresh/status")
async def refresh_status():
    items = load_items()
    return {
        "running": _refresh_running,
        "last_refresh": _last_refresh,
        "errors": _refresh_errors,
        "total": len(items),
        "counts": _bucket_counts(items),
    }


def _do_refresh():
    global _last_refresh, _refresh_running, _refresh_errors
    _refresh_running = True
    _refresh_errors = []
    raw_items = []

    try:
        # Incremental: only fetch items updated since last refresh
        since = None
        if _last_refresh:
            try:
                since = datetime.fromisoformat(_last_refresh)
                print(f"🔄 Incremental refresh since {since.strftime('%Y-%m-%d %H:%M')} UTC")
            except ValueError:
                pass
        else:
            print("🔄 Full refresh (no previous refresh)")

        def run_jira():
            from collectors.jira import JiraCollector
            return JiraCollector().collect(since=since)

        def run_slack():
            from collectors.slack import SlackCollector
            return SlackCollector(since=since).collect()

        def run_drive():
            from collectors.drive import DriveCollector
            return DriveCollector().collect(since=since)

        def run_calendar():
            from collectors.calendar import CalendarCollector
            return CalendarCollector().collect()

        def run_glean():
            from collectors.glean import GleanCollector
            return GleanCollector().collect(since=since)

        def run_manual():
            manual = load_manual_items()
            return [{"source": "manual", **m} for m in manual]

        # Run all collectors in parallel — Drive goes to Docs tab, rest to Kanban
        all_collectors = {
            "jira": run_jira, "slack": run_slack, "glean": run_glean,
            "manual": run_manual, "drive": run_drive,
        }

        drive_items = []
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = {executor.submit(fn): name for name, fn in all_collectors.items()}
            for future in as_completed(futures, timeout=120):
                name = futures[future]
                try:
                    results = future.result(timeout=3)
                    if name == "drive":
                        drive_items = results
                    else:
                        raw_items.extend(results)
                    print(f"✅ {name}: {len(results)} items")
                except Exception as e:
                    _refresh_errors.append(f"{name}: {str(e)}")
                    print(f"❌ {name}: {e}")

        # Upsert new Drive docs into pinned_docs.json
        if drive_items:
            try:
                existing_docs = _load_docs()
                existing_urls = {d["url"] for d in existing_docs}
                added = 0
                for item in drive_items:
                    url = item.get("source_url") or ""
                    title = item.get("title", "Untitled")
                    if not url or url in existing_urls:
                        continue
                    if _is_doc_suppressed(url, item.get("last_signal")):
                        continue
                    category = _guess_doc_category(title)
                    signal = item.get("signal", "")
                    mentions = item.get("my_mentions_in_comments", 0)
                    notes = ""
                    if mentions > 0:
                        notes = f"{mentions} comment(s) mentioning you"
                    elif signal == "shared_with_me":
                        notes = f"Shared by {item.get('shared_by', 'someone')}"
                    existing_docs.append({
                        "id": f"doc:{abs(hash(url + title))}",
                        "title": title, "url": url, "category": category,
                        "notes": notes,
                        "added_at": datetime.now(timezone.utc).isoformat(),
                        "from_drive": True,
                        "mime_type": item.get("mime_type", ""),
                        "last_signal": item.get("last_signal", ""),
                    })
                    existing_urls.add(url)
                    added += 1
                if added > 0:
                    _save_docs(existing_docs)
                print(f"✅ drive→docs: {added} new ({len(drive_items)} fetched)")
            except Exception as e:
                _refresh_errors.append(f"drive→docs: {str(e)}")
                print(f"❌ drive→docs: {e}")

        normalized = normalize(raw_items)
        existing = load_items()
        # Strip any gdrive items that survived from before the Drive→Docs migration
        existing = [i for i in existing if i.source != "gdrive"]
        existing_ids = {item.id for item in existing}
        tombstone = load_tombstone()
        merged = merge_with_existing(normalized, existing, tombstone=tombstone)

        try:
            classified = classify(merged, existing_ids=existing_ids)
        except Exception as e:
            _refresh_errors.append(f"classify: {str(e)}")
            classified = merged

        save_items(classified)
        _last_refresh = datetime.now(timezone.utc).isoformat()
        print(f"✅ Refresh complete: {len(classified)} items, errors: {_refresh_errors}")

    except Exception as e:
        _refresh_errors.append(f"fatal: {str(e)}")
        print(f"❌ Refresh fatal error: {e}")

    finally:
        _refresh_running = False


REFRESH_COOLDOWN_SECONDS = 300  # 5 minutes


@app.post("/api/refresh")
async def refresh(background_tasks: BackgroundTasks, force: bool = False):
    global _refresh_running
    if _refresh_running:
        return {"status": "already_running", "last_refresh": _last_refresh}
    if not force and _last_refresh:
        last_dt = datetime.fromisoformat(_last_refresh)
        elapsed = (datetime.now(timezone.utc) - last_dt).total_seconds()
        remaining = int(REFRESH_COOLDOWN_SECONDS - elapsed)
        if remaining > 0:
            return {"status": "cooldown", "last_refresh": _last_refresh, "retry_in_seconds": remaining}
    background_tasks.add_task(_do_refresh)
    return {"status": "started", "message": "Refresh running in background."}


@app.post("/api/refresh/reset")
async def refresh_reset():
    """Force-reset the refresh flag if it gets stuck."""
    global _refresh_running
    _refresh_running = False
    return {"status": "reset"}


@app.post("/api/migrate-drive-to-docs")
async def migrate_drive_to_docs():
    """One-time: move existing gdrive kanban items into pinned_docs and remove from kanban."""
    items = load_items()
    gdrive_items = [i for i in items if i.source == "gdrive"]
    rest = [i for i in items if i.source != "gdrive"]

    existing_docs = _load_docs()
    existing_urls = {d["url"] for d in existing_docs}
    added = 0

    for item in gdrive_items:
        url = item.source_url or ""
        if not url or url in existing_urls:
            continue
        category = _guess_doc_category(item.title)
        existing_docs.append({
            "id": f"doc:{abs(hash(url + item.title))}",
            "title": item.title,
            "url": url,
            "category": category,
            "notes": item.context or "",
            "added_at": datetime.now(timezone.utc).isoformat(),
            "from_drive": True,
        })
        existing_urls.add(url)
        added += 1

    _save_docs(existing_docs)
    save_items(rest)
    return {"migrated": added, "removed_from_kanban": len(gdrive_items)}


class PrepRequest(BaseModel):
    event: dict


@app.post("/api/prep-suggest")
async def prep_suggest(req: PrepRequest):
    """Use Claude to suggest 3-5 prep to-dos for a meeting."""
    import anthropic, json as _json
    event = req.event
    client = anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    attendees = ", ".join(event.get("attendees", [])[:5]) or "unknown"
    prompt = (
        f"Meeting: {event.get('title', '(no title)')}\n"
        f"Time: {event.get('start', '')}\n"
        f"Attendees ({event.get('attendee_count', 0)}): {attendees}\n"
        f"Description: {event.get('description', 'none')[:300]}\n\n"
        "Suggest 3-5 concise prep action items before this meeting for Haewon Yum (KOR GDS Lead at Moloco).\n"
        "Each item should be a short actionable task.\n"
        "Return ONLY a JSON array of strings, e.g. [\"Review agenda\", \"Prepare metrics\"]"
    )

    print(f"📅 prep-suggest for: {event.get('title')}")
    try:
      msg = await client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=256,
        messages=[{"role": "user", "content": prompt}],
    )
    except Exception as e:
        print(f"❌ prep-suggest Claude error: {e}")
        return {"suggestions": []}
    text = msg.content[0].text.strip()
    print(f"✅ prep-suggest got response: {text[:80]}")
    if text.startswith("```"):
        parts = text.split("```")
        text = parts[1] if len(parts) > 1 else text
        if text.startswith("json"):
            text = text[4:]
    try:
        suggestions = _json.loads(text.strip())
    except Exception as e:
        print(f"❌ prep-suggest JSON parse error: {e} | text: {repr(text[:200])}")
        suggestions = []

    return {"suggestions": suggestions}


@app.get("/api/calendar")
async def get_calendar():
    try:
        from collectors.calendar import CalendarCollector
        events = CalendarCollector().get_upcoming_events(days=14)
        return {"events": events}
    except Exception as e:
        return {"events": [], "error": str(e)}


class QuickAddItem(BaseModel):
    id: str
    title: str
    source: str = "manual"
    source_url: str | None = None
    bucket: int = 1
    status_flag: str = "soon"
    due_date: str | None = None
    notes: str = ""
    context: str = ""
    tags: list[str] = []
    human_confirmed: bool = True
    okr_tag: dict | None = None


@app.post("/api/items/quick-add")
async def quick_add_item(item: QuickAddItem):
    import json as _json
    items = load_items()
    # Avoid duplicates by id
    if any(i.id == item.id for i in items):
        return next(i for i in items if i.id == item.id).model_dump()
    new_item = WorkItem(
        id=item.id,
        title=item.title,
        source=item.source,
        source_url=item.source_url,
        bucket=item.bucket,
        status_flag=item.status_flag,
        due_date=item.due_date,
        notes=item.notes,
        context=item.context,
        tags=item.tags,
        human_confirmed=item.human_confirmed,
        last_signal=datetime.now(timezone.utc).isoformat(),
        okr_tag=item.okr_tag,
    )
    items.append(new_item)
    save_items(items)
    return new_item.model_dump()


@app.patch("/api/items/{item_id:path}")
async def update_item(item_id: str, update: ItemUpdate):
    items = load_items()
    item_map = {item.id: item for item in items}

    if item_id not in item_map:
        raise HTTPException(status_code=404, detail="Item not found")

    item = item_map[item_id]
    if update.bucket is not None:
        item.bucket = update.bucket
    if update.title is not None and update.title.strip():
        item.title = update.title.strip()
    if update.status_flag is not None:
        item.status_flag = update.status_flag
        if update.status_flag == "done":
            add_to_tombstone(item)
    if update.due_date is not None:
        item.due_date = update.due_date
    if update.notes is not None:
        item.notes = update.notes
    if update.human_confirmed is not None:
        item.human_confirmed = update.human_confirmed
    if update.delegated_to is not None:
        item.delegated_to = update.delegated_to
    if update.todos is not None:
        item.todos = update.todos
    if "okr_tag" in update.model_fields_set:
        item.okr_tag = update.okr_tag
    # Any manual edit locks the item from AI re-classification
    item.human_confirmed = True

    save_items(list(item_map.values()))
    return item.model_dump()


class GmailMarkReadRequest(BaseModel):
    source_url: str


@app.post("/api/slack/deep-scan")
async def slack_deep_scan():
    """
    Deep Slack scan using Glean chat — same approach as /weekly-summary.
    Finds unreplied @mentions and explicit action requests directed at Haewon.
    Adds new items directly to kanban (respects tombstone).
    """
    try:
        from collectors.glean import GleanCollector
        from normalize import normalize
        collector = GleanCollector()
        raw_items = collector.scan_slack_action_items()

        if not raw_items:
            return {"added": 0, "message": "No new action items found in Slack."}

        normalized = normalize(raw_items)
        existing = load_items()
        existing_ids = {i.id for i in existing}
        tombstone = load_tombstone()

        new_items = [
            i for i in normalized
            if i.id not in existing_ids
            and i.id not in tombstone
            and f"{i.source}::{i.title.strip().lower()}" not in tombstone
        ]

        if not new_items:
            return {"added": 0, "message": "No new items — all already in kanban or previously dismissed."}

        try:
            from classify import classify
            new_items = classify(new_items, existing_ids=existing_ids)
        except Exception:
            pass

        save_items(existing + new_items)
        return {"added": len(new_items), "message": f"Added {len(new_items)} Slack action item(s) to kanban."}
    except Exception as e:
        return {"added": 0, "error": str(e)}


@app.post("/api/gmail/mark-read-url")
async def gmail_mark_read_url(req: GmailMarkReadRequest):
    try:
        from gmail_client import mark_read_by_url
        result = mark_read_by_url(req.source_url)
        return result
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ── Gmail inbox tab ────────────────────────────────────────────────────────────

@app.get("/api/gmail/inbox")
async def gmail_inbox():
    try:
        from collectors.gmail import fetch_unread, CATEGORIES
        emails = await asyncio.get_running_loop().run_in_executor(None, fetch_unread)
        return {"emails": emails, "categories": CATEGORIES}
    except Exception as e:
        return {"emails": [], "categories": {}, "error": str(e)}


class GmailSummarizeRequest(BaseModel):
    message_id: str
    subject: str
    sender: str
    snippet: str
    category: str = "other"


_URL_RE = re.compile(r'https?://[^\s<>"\')\]]+')

# Domains worth surfacing as links for jira/gdoc categories
_LINK_DOMAINS = (
    "mlc.atlassian.net",
    "docs.google.com",
    "drive.google.com",
    "slides.google.com",
    "sheets.google.com",
    "mail.google.com",
    "moloco.cloud",
)


def _extract_notable_urls(text: str, category: str) -> list[str]:
    """Extract and deduplicate URLs relevant to the email category."""
    seen, results = set(), []
    for url in _URL_RE.findall(text):
        # Strip trailing punctuation
        url = url.rstrip(".,;:)")
        if url in seen:
            continue
        seen.add(url)
        if category in ("jira", "gdoc"):
            if any(d in url for d in _LINK_DOMAINS):
                results.append(url)
        # For all categories, also capture any obvious ticket/doc deep links
        if re.search(r"atlassian\.net/browse/|docs\.google\.com/", url) and url not in results:
            results.append(url)
    return results[:5]  # cap at 5 links


@app.post("/api/gmail/summarize")
async def gmail_summarize(req: GmailSummarizeRequest):
    try:
        import anthropic as _anthropic
        from collectors.gmail import fetch_body

        body = await asyncio.get_running_loop().run_in_executor(None, fetch_body, req.message_id)
        urls = _extract_notable_urls(body, req.category)

        url_block = ""
        if urls:
            url_block = "\n\nRelevant URLs found in this email:\n" + "\n".join(f"- {u}" for u in urls)

        client = _anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        msg = await client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=400,
            messages=[{
                "role": "user",
                "content": (
                    f"Email from: {req.sender}\n"
                    f"Subject: {req.subject}\n\n"
                    f"{body}{url_block}\n\n"
                    "Summarize this email in 2–3 short bullet points for Haewon Yum (KOR GDS Lead at Moloco). "
                    "Focus on: (1) what action is needed from her, if any, (2) key information, (3) urgency. "
                    "Keep each bullet under 15 words. No intro text, just the bullets."
                ),
            }],
        )
        return {
            "summary": msg.content[0].text.strip(),
            "urls": urls,
        }
    except Exception as e:
        return {"summary": None, "urls": [], "error": str(e)}


class GmailMarkReadRequest2(BaseModel):
    message_id: str


@app.post("/api/gmail/mark-read/{message_id}")
async def gmail_mark_read(message_id: str):
    try:
        from collectors.gmail import mark_message_read
        ok = await asyncio.get_running_loop().run_in_executor(None, mark_message_read, message_id)
        return {"ok": ok}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.delete("/api/items/{item_id:path}")
async def delete_item(item_id: str):
    items = load_items()
    deleted = next((i for i in items if i.id == item_id), None)
    items = [i for i in items if i.id != item_id]
    save_items(items)
    if deleted:
        add_to_tombstone(deleted)
    else:
        add_id_to_tombstone(item_id)
    return {"status": "deleted"}


def _bucket_counts(items: list[WorkItem]) -> dict:
    counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
    for item in items:
        counts[item.bucket] = counts.get(item.bucket, 0) + 1
    return counts


# --- OKR ---

OKR_PATH = Path(__file__).parent / "okr_q2.json"

DEFAULT_PILLARS = [
    {"id": "mission",    "title": "Mission Statement",     "icon": "🎯", "objectives": [{"text": "", "key_results": [], "kr_completed": []}], "notes": "", "draft_status": "empty"},
    {"id": "regional",   "title": "Regional Initiative",   "icon": "🇰🇷", "objectives": [{"text": "", "key_results": [], "kr_completed": []}], "notes": "", "draft_status": "empty"},
    {"id": "global",     "title": "Global Initiative",     "icon": "🌏", "objectives": [{"text": "", "key_results": [], "kr_completed": []}], "notes": "", "draft_status": "empty"},
    {"id": "people",     "title": "People & Culture",      "icon": "🤝", "objectives": [{"text": "", "key_results": [], "kr_completed": []}], "notes": "", "draft_status": "empty"},
    {"id": "personal",   "title": "Personal Goal",         "icon": "⭐", "objectives": [{"text": "", "key_results": [], "kr_completed": []}], "notes": "", "draft_status": "empty"},
]


def _load_okr() -> list[dict]:
    if not OKR_PATH.exists():
        OKR_PATH.write_text(json.dumps(DEFAULT_PILLARS, indent=2))
    pillars = json.loads(OKR_PATH.read_text())
    changed = False
    for p in pillars:
        if "objective" in p and "objectives" not in p:
            krs = p.pop("key_results", [])
            done = p.pop("kr_completed", [])
            p["objectives"] = [{
                "text": p.pop("objective", ""),
                "key_results": krs,
                "kr_completed": (done + [False] * len(krs))[:len(krs)],
            }]
            changed = True
        elif "objectives" not in p:
            p["objectives"] = [{"text": "", "key_results": [], "kr_completed": []}]
            changed = True
    if changed:
        _save_okr(pillars)
    return pillars


def _save_okr(pillars: list[dict]):
    OKR_PATH.write_text(json.dumps(pillars, indent=2))


@app.get("/api/okr")
async def get_okr():
    return {"pillars": _load_okr(), "quarter": "Q2 2026"}


class OKRPillarUpdate(BaseModel):
    objectives: list[dict] | None = None
    notes: str | None = None


@app.patch("/api/okr/{pillar_id}")
async def update_okr_pillar(pillar_id: str, update: OKRPillarUpdate):
    pillars = _load_okr()
    for p in pillars:
        if p["id"] == pillar_id:
            if update.objectives is not None:
                p["objectives"] = update.objectives
            if update.notes is not None:
                p["notes"] = update.notes
            p["draft_status"] = "edited"
            _save_okr(pillars)
            return p
    raise HTTPException(status_code=404, detail="Pillar not found")


class OKRDraftRequest(BaseModel):
    pillar_id: str
    pillar_title: str
    context_hint: str = ""


@app.post("/api/okr/draft")
async def draft_okr_pillar(req: OKRDraftRequest):
    """Search Glean for evidence and draft OKR content for a single pillar."""
    try:
        import anthropic as _anthropic

        # Query Glean for context relevant to this pillar
        glean_query = _okr_glean_query(req.pillar_id, req.context_hint)
        glean_context = await asyncio.get_running_loop().run_in_executor(
            None, _glean_search_for_okr, glean_query
        )

        client = _anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        msg = await client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=600,
            messages=[{
                "role": "user",
                "content": (
                    f"You are helping Haewon Yum (KOR GDS Lead & Senior Data Scientist at Moloco) "
                    f"draft her Q2 2026 OKR for the pillar: **{req.pillar_title}**.\n\n"
                    f"Context gathered from her recent work (Slack, Google Docs, Jira):\n{glean_context}\n\n"
                    f"{'Additional hint: ' + req.context_hint if req.context_hint else ''}\n\n"
                    "Draft ONE strong objective sentence and 2–3 measurable key results. "
                    "Objective: starts with an action verb, outcome-focused, aspirational but realistic. "
                    "Key results: specific, measurable, time-bound (by end of Q2). "
                    "Use what you know about her role: KOR GDS strategy, Korean game clients (Netmarble, Nexon), "
                    "Moloco DSP platform, GDS team performance analytics.\n\n"
                    "Respond in this exact JSON format (no markdown):\n"
                    '{"objective": "...", "key_results": ["...", "...", "..."], "notes": "Brief rationale (1-2 sentences)."}'
                ),
            }],
        )
        import json as _json
        text = msg.content[0].text.strip()
        data = _json.loads(text)
        return {"ok": True, "pillar_id": req.pillar_id, **data}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def _okr_glean_query(pillar_id: str, hint: str) -> str:
    base = {
        "mission":  "Haewon Yum KOR GDS strategy goals Q2 2026 mission",
        "regional": "Korea GDS regional initiative game clients Netmarble Nexon performance Q2",
        "global":   "GDS global initiative Moloco DSP collaboration cross-region Q2 2026",
        "people":   "KOR GDS team mentoring hiring culture development Haewon Q2",
        "personal": "Haewon Yum personal development learning growth goals 2026",
    }
    q = base.get(pillar_id, f"Haewon {pillar_id} Q2 2026")
    return f"{q} {hint}".strip()


def _glean_search_for_okr(query: str) -> str:
    """Search Glean and return a short context string for OKR drafting."""
    import subprocess, json as _json
    from collectors.glean import GLEAN_BASE
    token = os.environ.get("GLEAN_API_TOKEN", "")
    if not token:
        return "(Glean not configured)"

    payload = _json.dumps({
        "query": query,
        "pageSize": 8,
        "requestOptions": {"datasourceFilter": "ALL"},
    })
    try:
        result = subprocess.run(
            ["curl", "-s", "-X", "POST", f"{GLEAN_BASE}/search",
             "-H", f"Authorization: Bearer {token}",
             "-H", "Content-Type: application/json",
             "-d", payload, "--max-time", "15"],
            capture_output=True, text=True, timeout=20,
        )
        data = _json.loads(result.stdout)
        snippets = []
        for r in data.get("results", [])[:6]:
            doc = r.get("document", {})
            title = doc.get("title", "")
            for s in r.get("snippets", [])[:1]:
                text = s.get("snippet", "").strip()
                if text:
                    snippets.append(f"• [{title}] {text[:200]}")
        return "\n".join(snippets) if snippets else "(no results found)"
    except Exception as e:
        return f"(Glean search failed: {e})"


# --- Pinned Docs ---

DOCS_PATH = Path(__file__).parent / "pinned_docs.json"
REMOVED_DOCS_PATH = Path(__file__).parent / "removed_docs.json"


def _load_removed_docs() -> dict:
    """Returns {url: removed_at_isostring}."""
    if not REMOVED_DOCS_PATH.exists():
        return {}
    txt = REMOVED_DOCS_PATH.read_text().strip()
    return json.loads(txt) if txt else {}


def _save_removed_docs(removed: dict) -> None:
    with open(REMOVED_DOCS_PATH, "w") as f:
        json.dump(removed, f, indent=2)


def _is_doc_suppressed(url: str, last_modified: str | None) -> bool:
    """Return True if this URL was removed and has no newer activity since removal."""
    removed = _load_removed_docs()
    if url not in removed:
        return False
    removed_at = removed[url]
    if last_modified and last_modified > removed_at:
        # New activity after removal — allow it back
        del removed[url]
        _save_removed_docs(removed)
        return False
    return True


def _load_docs() -> list[dict]:
    if not DOCS_PATH.exists():
        return []
    txt = DOCS_PATH.read_text().strip()
    if not txt:
        return []
    return json.loads(txt)


def _save_docs(docs: list[dict]) -> None:
    with open(DOCS_PATH, "w") as f:
        json.dump(docs, f, indent=2)


class PinnedDoc(BaseModel):
    title: str
    url: str
    category: str = "Reference"
    notes: str = ""


async def _categorize_docs_with_claude(candidates: list[dict]) -> list[dict]:
    """Use Claude to assign categories and clean up titles for a list of doc candidates."""
    if not candidates:
        return candidates
    import anthropic as _anthropic

    titles_json = json.dumps([{"idx": i, "title": c["suggested_title"]} for i, c in enumerate(candidates)])
    prompt = (
        "You are organizing Google Drive documents for Haewon Yum, KOR GDS Lead at Moloco (a mobile ad tech company).\n\n"
        "For each document below, assign:\n"
        "1. A clean, readable title (fix caps, remove noise like '[WIP]' if not meaningful, keep Korean titles as-is)\n"
        "2. A category from this list ONLY:\n"
        "   - Meeting Agenda: recurring syncs, 1:1s, team meetings, all-hands notes\n"
        "   - Cadence: weekly/monthly reports, trackers, dashboards, scorecards\n"
        "   - KR GDS: docs specific to Korea GDS team (KOR, KR, Korea in title/context)\n"
        "   - APAC GDS: docs covering APAC region broadly\n"
        "   - GDS: general GDS (Global Data Science / Go-to-market Data Science) docs not specific to one region\n"
        "   - Client Work: docs for specific advertiser clients (Netmarble, Nexon, 111percent, Mobidays, etc.)\n"
        "   - Strategy: OKRs, planning docs, roadmaps, strategy decks, goal-setting\n"
        "   - Analysis: data analysis, investigation reports, experiment results, deep-dives\n"
        "   - Reference: playbooks, guides, templates, onboarding, background reading\n"
        "   - Other: anything that doesn't fit above\n\n"
        f"Documents:\n{titles_json}\n\n"
        "Return ONLY a JSON array where each object has: idx, title, category\n"
        "Example: [{\"idx\": 0, \"title\": \"KOR GDS Bi-weekly Notes\", \"category\": \"Meeting Agenda\"}]"
    )

    try:
        client = _anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        msg = await client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        text = msg.content[0].text.strip()
        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        results = json.loads(text.strip())
        result_map = {r["idx"]: r for r in results}
        for i, c in enumerate(candidates):
            if i in result_map:
                c["suggested_title"] = result_map[i]["title"]
                c["category"] = result_map[i]["category"]
    except Exception as e:
        print(f"⚠️ Claude categorization failed: {e}")

    return candidates


@app.post("/api/docs/scan-calendar")
async def scan_calendar_docs():
    """Scan past 3 months of calendar events + Drive for docs, categorized by Claude."""
    try:
        from collectors.calendar import CalendarCollector
        candidates = CalendarCollector().scan_for_meeting_docs(months=3)
        existing_urls = {d["url"] for d in _load_docs()}
        candidates = [
            c for c in candidates
            if c["url"] not in existing_urls
            and not _is_doc_suppressed(c["url"], c.get("last_signal"))
        ]
        # Claude categorizes and cleans up titles
        candidates = await _categorize_docs_with_claude(candidates)
        return {"candidates": candidates}
    except Exception as e:
        return {"candidates": [], "error": str(e)}


@app.get("/api/docs")
async def get_docs():
    return {"docs": _load_docs()}


@app.post("/api/docs")
async def add_doc(doc: PinnedDoc):
    docs = _load_docs()
    new_doc = {
        "id": f"doc:{abs(hash(doc.url + doc.title))}",
        "title": doc.title,
        "url": doc.url,
        "category": doc.category,
        "notes": doc.notes,
        "added_at": datetime.now(timezone.utc).isoformat(),
    }
    docs.append(new_doc)
    _save_docs(docs)
    return new_doc


class PinnedDocUpdate(BaseModel):
    title: str | None = None
    url: str | None = None
    category: str | None = None
    notes: str | None = None


@app.patch("/api/docs/{doc_id}")
async def update_doc(doc_id: str, update: PinnedDocUpdate):
    docs = _load_docs()
    for doc in docs:
        if doc["id"] == doc_id:
            if update.title is not None:
                doc["title"] = update.title
            if update.url is not None:
                doc["url"] = update.url
            if update.category is not None:
                doc["category"] = update.category
            if update.notes is not None:
                doc["notes"] = update.notes
            _save_docs(docs)
            return doc
    raise HTTPException(status_code=404, detail="Doc not found")


@app.delete("/api/docs/{doc_id}")
async def delete_doc(doc_id: str):
    docs = _load_docs()
    removed_doc = next((d for d in docs if d["id"] == doc_id), None)
    docs = [d for d in docs if d["id"] != doc_id]
    _save_docs(docs)
    # Record removal so it won't reappear on refresh unless there's new activity
    if removed_doc and removed_doc.get("url"):
        removed = _load_removed_docs()
        removed[removed_doc["url"]] = datetime.now(timezone.utc).isoformat()
        _save_removed_docs(removed)
    return {"status": "deleted"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)
