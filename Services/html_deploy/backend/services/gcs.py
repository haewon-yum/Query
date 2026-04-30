import os
from google.cloud import storage

_client = None


def _bucket():
    global _client
    if _client is None:
        _client = storage.Client(project=os.environ.get("GCS_PROJECT", "gds-apac"))
    return _client.bucket(os.environ.get("GCS_BUCKET_NAME", "gds-apac-html-reports"))


def cache_exists(report_id: str) -> bool:
    return _bucket().blob(f"cache/{report_id}.html").exists()


def read_cache(report_id: str) -> str:
    return _bucket().blob(f"cache/{report_id}.html").download_as_text()


def write_cache(report_id: str, content: str):
    _bucket().blob(f"cache/{report_id}.html").upload_from_string(content, content_type="text/html")


def delete_cache(report_id: str):
    blob = _bucket().blob(f"cache/{report_id}.html")
    if blob.exists():
        blob.delete()


def write_upload(report_id: str, content: bytes):
    _bucket().blob(f"uploaded/{report_id}.html").upload_from_string(content, content_type="text/html")


def read_upload(report_id: str) -> str:
    return _bucket().blob(f"uploaded/{report_id}.html").download_as_text()


def delete_upload(report_id: str):
    blob = _bucket().blob(f"uploaded/{report_id}.html")
    if blob.exists():
        blob.delete()
