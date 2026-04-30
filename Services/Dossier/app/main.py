"""
Dossier web app — FastAPI + Jinja2.
Routes:
  GET  /                         → account index
  GET  /{account}                → Dossier timeline for that account
  GET  /api/{account}            → raw events JSON
  POST /api/{account}/refresh    → start background refresh, returns job status
  GET  /api/{account}/refresh    → poll refresh status
"""
import sys
import os
import subprocess
import time
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from jinja2 import Environment, FileSystemLoader

from store import gcs
import config

app = FastAPI(title="Dossier")

_tmpl_dir = os.path.join(os.path.dirname(__file__), "templates")
_env = Environment(loader=FileSystemLoader(_tmpl_dir), autoescape=True)

KNOWN_ACCOUNTS = ["netmarble"]

# In-memory refresh state per account
_refresh_state: dict[str, dict[str, Any]] = {}

_SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "scripts")


def _refresh_status(account: str) -> dict:
    state = _refresh_state.get(account, {})
    proc: subprocess.Popen | None = state.get("proc")
    if proc is not None:
        rc = proc.poll()
        if rc is None:
            return {"status": "running", "started_at": state.get("started_at")}
        # Process finished — clear proc, keep result
        _refresh_state[account] = {
            "status": "done" if rc == 0 else "error",
            "started_at": state.get("started_at"),
            "finished_at": time.time(),
            "exit_code": rc,
        }
    return _refresh_state.get(account, {"status": "idle"})


@app.get("/", response_class=HTMLResponse)
async def index():
    links = "".join(f'<li><a href="/{a}">{a.capitalize()}</a></li>' for a in KNOWN_ACCOUNTS)
    return f"""
    <html><body style="font-family:sans-serif;padding:40px">
    <h1>Dossier</h1><ul>{links}</ul>
    </body></html>
    """


@app.get("/api/{account}", response_class=JSONResponse)
async def events_json(account: str):
    if account not in KNOWN_ACCOUNTS:
        raise HTTPException(404, f"Unknown account: {account}")
    return {"events": gcs.read_events(account)}


@app.post("/api/{account}/refresh", response_class=JSONResponse)
async def start_refresh(account: str):
    if account not in KNOWN_ACCOUNTS:
        raise HTTPException(404, f"Unknown account: {account}")
    current = _refresh_status(account)
    if current.get("status") == "running":
        return {"status": "running", "message": "Refresh already in progress"}
    script = os.path.join(_SCRIPTS_DIR, "refresh.py")
    proc = subprocess.Popen(
        [sys.executable, script, "--account", account],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=os.path.dirname(_SCRIPTS_DIR),
    )
    _refresh_state[account] = {"proc": proc, "started_at": time.time(), "status": "running"}
    return {"status": "running", "message": "Refresh started"}


@app.get("/api/{account}/refresh", response_class=JSONResponse)
async def get_refresh_status(account: str):
    if account not in KNOWN_ACCOUNTS:
        raise HTTPException(404, f"Unknown account: {account}")
    return _refresh_status(account)


@app.get("/{account}", response_class=HTMLResponse)
async def dossier(account: str):
    if account not in KNOWN_ACCOUNTS:
        raise HTTPException(404, f"Unknown account: {account}")
    events = gcs.read_events(account)
    tmpl = _env.get_template("dossier.html")
    return tmpl.render(account=account, events=events)
