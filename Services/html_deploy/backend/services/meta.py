"""GCS-backed metadata store for categories and reports (replaces Firestore)."""
import json
from backend.services.gcs import _bucket


def _read(blob) -> dict:
    return json.loads(blob.download_as_text())


def _write(blob, data: dict):
    blob.upload_from_string(
        json.dumps(data, default=str), content_type="application/json"
    )


# ── Categories ─────────────────────────────────────────────────────────────────

def list_categories() -> list[dict]:
    blobs = list(_bucket().list_blobs(prefix="meta/categories/"))
    cats = [_read(b) for b in blobs]
    return sorted(cats, key=lambda c: c.get("name", "").lower())


def get_category(id: str) -> dict | None:
    blob = _bucket().blob(f"meta/categories/{id}.json")
    return _read(blob) if blob.exists() else None


def put_category(data: dict):
    _write(_bucket().blob(f"meta/categories/{data['id']}.json"), data)


def delete_category(id: str):
    _bucket().blob(f"meta/categories/{id}.json").delete()


def list_sub_categories(parent_id: str) -> list[dict]:
    return [c for c in list_categories() if c.get("parent_id") == parent_id]


def category_has_reports(category_id: str) -> bool:
    sub_ids = {c["id"] for c in list_categories() if c.get("parent_id") == category_id}
    check_ids = {category_id} | sub_ids
    for b in _bucket().list_blobs(prefix="meta/reports/"):
        if _read(b).get("category_id") in check_ids:
            return True
    return False


# ── Reports ────────────────────────────────────────────────────────────────────

def list_reports(category_id: str | None = None, q: str | None = None) -> list[dict]:
    reports = [_read(b) for b in _bucket().list_blobs(prefix="meta/reports/")]
    if category_id:
        reports = [r for r in reports if r.get("category_id") == category_id]
    if q:
        ql = q.lower()
        reports = [
            r for r in reports
            if ql in r.get("title", "").lower()
            or ql in (r.get("description") or "").lower()
        ]
    reports.sort(key=lambda r: r.get("created_at", ""), reverse=True)
    return reports


def get_report(id: str) -> dict | None:
    blob = _bucket().blob(f"meta/reports/{id}.json")
    return _read(blob) if blob.exists() else None


def put_report(data: dict):
    _write(_bucket().blob(f"meta/reports/{data['id']}.json"), data)


def delete_report(id: str):
    _bucket().blob(f"meta/reports/{id}.json").delete()
