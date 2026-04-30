import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Request, HTTPException
from backend.models import CategoryCreate, CategoryUpdate
from backend.services import meta
from backend.auth import require_session

router = APIRouter(prefix="/api/categories")


def _can_see(cat: dict, email: str) -> bool:
    return not cat.get("is_private") or cat.get("created_by") == email


@router.get("")
def list_categories(request: Request):
    session = require_session(request)
    return [c for c in meta.list_categories() if _can_see(c, session["email"])]


@router.post("")
def create_category(request: Request, body: CategoryCreate):
    session = require_session(request)
    data = {
        "id": str(uuid.uuid4()),
        **body.model_dump(),
        "created_by": session["email"],
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    meta.put_category(data)
    return data


@router.put("/{category_id}")
def update_category(request: Request, category_id: str, body: CategoryUpdate):
    session = require_session(request)
    existing = meta.get_category(category_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Category not found")
    if not _can_see(existing, session["email"]):
        raise HTTPException(status_code=404, detail="Category not found")
    patch = {k: v for k, v in body.model_dump().items() if v is not None}
    updated = {**existing, **patch}
    meta.put_category(updated)
    return updated


@router.delete("/{category_id}")
def delete_category(request: Request, category_id: str):
    require_session(request)
    if not meta.get_category(category_id):
        raise HTTPException(status_code=404, detail="Category not found")
    if meta.category_has_reports(category_id):
        raise HTTPException(
            status_code=409,
            detail="Category (or its sub-categories) has reports — reassign or delete them first",
        )
    # cascade: remove empty sub-categories before removing the parent
    for sub in meta.list_sub_categories(category_id):
        meta.delete_category(sub["id"])
    meta.delete_category(category_id)
    return {"ok": True}
