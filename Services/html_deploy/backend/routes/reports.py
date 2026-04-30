import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Request, HTTPException, UploadFile, File, Form
from backend.models import ReportCreate, ReportUpdate
from backend.services import meta, gcs
from backend.auth import require_session

router = APIRouter(prefix="/api/reports")

MAX_UPLOAD_BYTES = 20 * 1024 * 1024  # 20 MB


def _can_access_category(cat: dict | None, email: str) -> bool:
    if cat is None:
        return True  # orphaned report stays visible
    return not cat.get("is_private") or cat.get("created_by") == email


def _check_report_access(report: dict, session: dict):
    cat = meta.get_category(report["category_id"])
    if not _can_access_category(cat, session["email"]):
        raise HTTPException(status_code=404, detail="Report not found")


@router.get("")
def list_reports(request: Request, category: Optional[str] = None, q: Optional[str] = None):
    session = require_session(request)
    all_cats = {c["id"]: c for c in meta.list_categories()}
    reports = meta.list_reports(category_id=category, q=q)
    return [
        r for r in reports
        if _can_access_category(all_cats.get(r.get("category_id", "")), session["email"])
    ]


@router.post("/upload")
async def upload_report(
    request: Request,
    title: str = Form(...),
    description: str = Form(""),
    category_id: str = Form(...),
    file: UploadFile = File(...),
):
    session = require_session(request)
    cat = meta.get_category(category_id)
    if cat and not _can_access_category(cat, session["email"]):
        raise HTTPException(status_code=403, detail="Cannot upload to a private category you do not own")
    if not (file.filename or "").lower().endswith(".html"):
        raise HTTPException(status_code=400, detail="Only .html files are accepted")

    content = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds 20 MB limit")

    report_id = str(uuid.uuid4())
    gcs.write_upload(report_id, content)

    now = datetime.now(timezone.utc).isoformat()
    data = {
        "id": report_id,
        "title": title.strip(),
        "description": description.strip() or None,
        "category_id": category_id,
        "source_type": "upload",
        "source_ref": f"uploaded/{report_id}.html",
        "original_filename": file.filename or None,
        "uploader": session["email"],
        "created_at": now,
        "updated_at": now,
        "tags": [],
    }
    meta.put_report(data)
    return data


@router.get("/{report_id}")
def get_report(request: Request, report_id: str):
    session = require_session(request)
    report = meta.get_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    _check_report_access(report, session)
    return report


@router.post("")
def create_report(request: Request, body: ReportCreate):
    session = require_session(request)
    now = datetime.now(timezone.utc).isoformat()
    data = {
        "id": str(uuid.uuid4()),
        **body.model_dump(),
        "uploader": session["email"],
        "created_at": now,
        "updated_at": now,
    }
    meta.put_report(data)
    return data


@router.put("/{report_id}")
def update_report(request: Request, report_id: str, body: ReportUpdate):
    session = require_session(request)
    report = meta.get_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    _check_report_access(report, session)
    if report["uploader"] != session["email"]:
        raise HTTPException(status_code=403, detail="Only the uploader can edit this report")
    patch = {k: v for k, v in body.model_dump().items() if v is not None}
    updated = {**report, **patch, "updated_at": datetime.now(timezone.utc).isoformat()}
    meta.put_report(updated)
    return updated


@router.post("/{report_id}/replace")
async def replace_report_file(
    request: Request,
    report_id: str,
    file: UploadFile = File(...),
):
    session = require_session(request)
    report = meta.get_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    _check_report_access(report, session)
    if report["uploader"] != session["email"]:
        raise HTTPException(status_code=403, detail="Only the uploader can replace this file")
    if report.get("source_type") != "upload":
        raise HTTPException(status_code=400, detail="Cannot replace file for GDrive-sourced reports")
    if not (file.filename or "").lower().endswith(".html"):
        raise HTTPException(status_code=400, detail="Only .html files are accepted")

    content = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds 20 MB limit")

    gcs.write_upload(report_id, content)
    gcs.delete_cache(report_id)

    updated = {**report, "original_filename": file.filename or report.get("original_filename"), "updated_at": datetime.now(timezone.utc).isoformat()}
    meta.put_report(updated)
    return updated


@router.delete("/{report_id}")
def delete_report(request: Request, report_id: str):
    session = require_session(request)
    report = meta.get_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    _check_report_access(report, session)
    if report["uploader"] != session["email"]:
        raise HTTPException(status_code=403, detail="Only the uploader can delete this report")
    if report.get("source_type") == "upload":
        gcs.delete_upload(report_id)
    gcs.delete_cache(report_id)
    meta.delete_report(report_id)
    return {"ok": True}
