import os
import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, Depends, Request, HTTPException
from fastapi.responses import FileResponse, RedirectResponse, Response, StreamingResponse
from dotenv import load_dotenv

load_dotenv()

from app.auth import router as auth_router, require_session, get_session
from app.bq import fetch_scores, fetch_activation, fetch_campaign_detail, fetch_combined_filtered
from app.notes import get_notes, save_note
from app.cache import bust_all

log = logging.getLogger("blueprint")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Pre-warm BQ cache in background so first user request is instant.
    loop = asyncio.get_event_loop()
    loop.run_in_executor(None, _warm_scores)
    loop.run_in_executor(None, _warm_activation)
    yield


def _warm_scores():
    try:
        fetch_scores()
        print("[warm] scores done", flush=True)
    except Exception as e:
        print(f"[warm] scores FAILED: {e}", flush=True)


def _warm_activation():
    try:
        fetch_activation()
        print("[warm] activation done", flush=True)
    except Exception as e:
        print(f"[warm] activation FAILED: {e}", flush=True)


app = FastAPI(title="Blueprint", lifespan=lifespan)
app.include_router(auth_router)

INDEX_HTML = Path(__file__).parent / "templates" / "index.html"


@app.get("/")
def index(request: Request):
    if not get_session(request):
        return RedirectResponse("/auth/login")
    return FileResponse(str(INDEX_HTML))


@app.get("/api/scores")
def api_scores(session: dict = Depends(require_session)):
    return Response(content=fetch_scores(), media_type="application/json")


@app.get("/api/campaign/{campaign_id}/detail")
def api_campaign_detail(campaign_id: str, session: dict = Depends(require_session)):
    return fetch_campaign_detail(campaign_id)


@app.get("/api/activation")
def api_activation(session: dict = Depends(require_session)):
    return fetch_activation()


@app.get("/api/notes")
def api_notes(session: dict = Depends(require_session)):
    return get_notes()


@app.post("/api/notes")
async def api_save_note(request: Request, session: dict = Depends(require_session)):
    payload = await request.json()
    payload["updated_by"] = session.get("email", "")
    return save_note(payload)


@app.post("/api/scores/download")
async def api_scores_download(request: Request, session: dict = Depends(require_session)):
    payload = await request.json()
    conditions = payload.get("conditions", [])
    if not isinstance(conditions, list):
        raise HTTPException(status_code=400, detail="conditions must be a list")
    try:
        csv_bytes = fetch_combined_filtered(conditions)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return Response(
        content=csv_bytes,
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=blueprint_scores.csv"},
    )


@app.post("/api/cache/bust")
def api_cache_bust(session: dict = Depends(require_session)):
    bust_all()
    return {"ok": True}
