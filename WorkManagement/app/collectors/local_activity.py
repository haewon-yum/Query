"""Collect local Mac activity signals for the 현황판 banner."""
import subprocess
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
import time as _time

WATCHED_REPOS = [
    "~/Documents/Queries",
    "~/Documents/Queries/WorkManagement",
    "~/searchlight",
]

MY_GIT_EMAIL = "haewon.yum@moloco.com"
GH_USER = "haewon-yum"

# Roots used to compute relative paths for file labels
_PATH_ROOTS = [
    Path.home() / "Documents" / "Queries",
    Path.home() / "searchlight",
    Path.home() / "mobius",
    Path.home() / "claude-bq-agent",
]

SKIP_PATTERNS = [".git", "__pycache__", ".DS_Store", "node_modules",
                 "items.json", "tombstone.json", "pinned_docs.json", "removed_docs.json",
                 ".venv", ".ipynb_checkpoints"]


def _expand(p: str) -> str:
    return str(Path(p).expanduser())


def _rich_label(display_path: str) -> str:
    """Convert a display path (~/...) to a human-readable label with parent context.

    Strategy: express the path relative to the nearest known project root,
    keeping up to 2 directory components above the filename.

    Examples:
      ~/Documents/Queries/WorkManagement/app/static/index.html
        → WorkManagement/static/index (page)
      ~/Documents/Queries/[Tickets]/ODSB-15998/analysis.ipynb
        → [Tickets]/ODSB-15998/analysis (notebook)
      ~/searchlight/app/collectors/glean.py
        → searchlight/collectors/glean (script)
    """
    ext_map = {
        ".ipynb": "notebook", ".md": "doc", ".py": "script",
        ".sql": "query", ".xlsx": "spreadsheet", ".csv": "data",
        ".pptx": "slides", ".html": "page", ".js": "script",
        ".ts": "script", ".yaml": "config", ".json": "config",
    }
    abs_path = Path(display_path.replace("~/", str(Path.home()) + "/")).resolve()
    kind = ext_map.get(abs_path.suffix, abs_path.suffix.lstrip(".") or "file")
    stem = abs_path.stem

    # ~/Documents/Queries is a workspace containing sub-projects; other roots ARE the project
    _WORKSPACE_ROOTS = {str(Path.home() / "Documents" / "Queries")}

    # Try to express relative to a known root
    for root in _PATH_ROOTS:
        try:
            rel = abs_path.relative_to(root)
            parts = rel.parts[:-1]  # directory components only (no filename)
            is_workspace = str(root) in _WORKSPACE_ROOTS

            if len(parts) == 0:
                return f"{root.name}/{stem} ({kind})"
            elif len(parts) == 1:
                project = parts[0] if is_workspace else root.name
                return f"{project}/{stem} ({kind})"
            else:
                # project = first sub-dir (under Queries) or root name (standalone repos)
                project = parts[0] if is_workspace else root.name
                immediate = parts[-1]
                if project == immediate:
                    return f"{project}/{stem} ({kind})"
                return f"{project}/{immediate}/{stem} ({kind})"
        except ValueError:
            continue

    # Fallback: show parent/grandparent/stem
    parts = abs_path.parts
    dirs = parts[:-1]
    if len(dirs) >= 2:
        return f"{dirs[-2]}/{dirs[-1]}/{stem} ({kind})"
    elif len(dirs) == 1:
        return f"{dirs[-1]}/{stem} ({kind})"
    return f"{stem} ({kind})"


def collect_github(hours: int = 4) -> dict:
    """Fetch recent GitHub commits and PRs authored by the user."""
    from datetime import datetime, timezone, timedelta
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    cutoff_str = cutoff.strftime("%Y-%m-%dT%H:%M:%SZ")

    commits = []
    prs = []

    # --- Recent commits via gh search commits (tab-separated output) ---
    try:
        result = subprocess.run(
            ["gh", "search", "commits", "--author", GH_USER,
             "--sort", "committer-date", "--limit", "20"],
            capture_output=True, text=True, timeout=15,
        )
        for line in result.stdout.strip().splitlines():
            parts = line.split("\t")
            if len(parts) < 5:
                continue
            repo, _sha, message, _author, date_str = parts[0], parts[1], parts[2], parts[3], parts[4]
            try:
                dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
            except ValueError:
                continue
            if dt < cutoff:
                continue
            first_line = message.split("\n")[0][:80]
            # Skip merge commits
            if first_line.startswith("Merge pull request") or first_line.startswith("Merge branch"):
                continue
            repo_short = repo.split("/")[-1]
            commits.append(f"[{repo_short}] {first_line} ({dt.strftime('%H:%M')})")
    except Exception as e:
        pass

    # --- Recent PRs opened/merged via gh search prs ---
    try:
        result = subprocess.run(
            ["gh", "search", "prs", "--author", "@me",
             "--sort", "updated", "--limit", "15",
             "--json", "title,url,state,updatedAt,repository"],
            capture_output=True, text=True, timeout=15,
        )
        import json as _json
        pr_list = _json.loads(result.stdout)
        for pr in pr_list:
            updated = pr.get("updatedAt", "")
            try:
                dt = datetime.fromisoformat(updated.replace("Z", "+00:00"))
            except ValueError:
                continue
            if dt < cutoff:
                continue
            repo_short = pr.get("repository", {}).get("name", "")
            title = pr.get("title", "")[:70]
            state = pr.get("state", "").lower()
            url = pr.get("url", "")
            prs.append({
                "title": f"[{repo_short}] PR ({state}): {title}",
                "url": url,
                "state": state,
            })
    except Exception:
        pass

    return {"commits": commits, "prs": prs}


def collect_local(hours: int = 4) -> dict:
    """Returns dict with keys: modified_files, git_commits, shell_commands."""
    minutes = hours * 60
    signals = {}

    # 1. Recently modified files via Spotlight (mdfind)
    try:
        result = subprocess.run(
            ["mdfind", "-onlyin", _expand("~/Documents"),
             f"kMDItemContentModificationDate >= $time.now(-{hours * 3600})"],
            capture_output=True, text=True, timeout=10
        )
        files = []
        for path in result.stdout.strip().splitlines():
            if any(skip in path for skip in SKIP_PATTERNS):
                continue
            if not any(path.endswith(ext) for ext in [".py", ".ipynb", ".md", ".sql", ".js", ".ts", ".go", ".html", ".yaml", ".json", ".xlsx", ".csv", ".pptx"]):
                continue
            display = path.replace(os.path.expanduser("~"), "~")
            # Get actual mtime as ISO string
            try:
                mtime = os.stat(path).st_mtime
                ts_iso = datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()
            except Exception:
                ts_iso = ""
            files.append({"path": display, "ts": ts_iso})
        # Sort by mtime descending (most recent first)
        files.sort(key=lambda x: x["ts"], reverse=True)
        signals["modified_files"] = files[:25]
    except Exception:
        signals["modified_files"] = []

    # 2. Recent git commits across known repos
    commits = []
    for repo in WATCHED_REPOS:
        try:
            result = subprocess.run(
                ["git", "-C", _expand(repo), "log", "--oneline",
                 f"--since={hours} hours ago", f"--author={MY_GIT_EMAIL}", "--format=%h %s"],
                capture_output=True, text=True, timeout=5
            )
            for line in result.stdout.strip().splitlines()[:5]:
                if line.strip():
                    repo_name = Path(_expand(repo)).name
                    commits.append(f"[{repo_name}] {line.strip()}")
        except Exception:
            pass
    signals["git_commits"] = commits

    # 3. Recent shell commands (zsh history)
    try:
        result = subprocess.run(
            ["tail", "-50", os.path.expanduser("~/.zsh_history")],
            capture_output=True, text=True, timeout=5
        )
        raw = result.stdout
        # zsh extended history format: ": timestamp:elapsed;command"
        cmds = []
        for line in raw.splitlines():
            if ";" in line:
                cmd = line.split(";", 1)[-1].strip()
            else:
                cmd = line.strip()
            # Filter noise
            if not cmd or cmd in ("claude", "ls", "cd", "pwd", "clear", "exit", "history"):
                continue
            if any(cmd.startswith(x) for x in ("ls ", "cd ", "echo ", "cat ", "head ", "tail ")):
                continue
            cmds.append(cmd)
        signals["shell_commands"] = list(dict.fromkeys(cmds))[-10:]  # deduplicated, last 10
    except Exception:
        signals["shell_commands"] = []

    return signals
