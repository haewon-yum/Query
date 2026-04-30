import os
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

load_dotenv()

from backend.auth import router as auth_router
from backend.routes.categories import router as categories_router
from backend.routes.reports import router as reports_router
from backend.routes.serve import router as serve_router

app = FastAPI(title="Mosaic")

app.include_router(auth_router)
app.include_router(categories_router)
app.include_router(reports_router)
app.include_router(serve_router)


STATIC_DIR = Path(__file__).parent / "static"
if STATIC_DIR.exists():
    assets_dir = STATIC_DIR / "assets"
    if assets_dir.exists():
        app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")

    @app.get("/{full_path:path}")
    async def spa_fallback(full_path: str):
        if full_path.startswith(("api/", "auth/")):
            raise HTTPException(status_code=404)
        return FileResponse(str(STATIC_DIR / "index.html"))
