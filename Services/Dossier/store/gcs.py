"""
Event store: write/read account events as JSON.
- Production: Google Cloud Storage (GCS)
- Development: local file at LOCAL_DATA_DIR/{account}_events.json
"""
import json
import os
from pathlib import Path
from typing import Any

import config


def _local_path(account: str) -> Path:
    p = Path(config.LOCAL_DATA_DIR)
    p.mkdir(parents=True, exist_ok=True)
    return p / f"{account}_events.json"


def _gcs_blob(account: str):
    from google.cloud import storage
    client = storage.Client()
    bucket = client.bucket(config.GCS_BUCKET)
    return bucket.blob(f"{config.GCS_PREFIX}{account}_events.json")


def write_events(events: list[dict[str, Any]], account: str) -> None:
    payload = {"account": account, "events": events, "count": len(events)}
    if config.APP_ENV == "development":
        path = _local_path(account)
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
        print(f"  Wrote {len(events)} events → {path}")
    else:
        blob = _gcs_blob(account)
        blob.upload_from_string(
            json.dumps(payload, ensure_ascii=False),
            content_type="application/json",
        )
        print(f"  Wrote {len(events)} events → gs://{config.GCS_BUCKET}/{config.GCS_PREFIX}{account}_events.json")


def read_events(account: str) -> list[dict[str, Any]]:
    if config.APP_ENV == "development":
        path = _local_path(account)
        if not path.exists():
            return []
        data = json.loads(path.read_text())
    else:
        blob = _gcs_blob(account)
        if not blob.exists():
            return []
        data = json.loads(blob.download_as_text())
    return data.get("events", [])
