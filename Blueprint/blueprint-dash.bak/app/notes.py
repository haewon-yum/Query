import os
from datetime import datetime, timezone
from googleapiclient.discovery import build
from google.auth import default

HEADERS = [
    "advertiser_id", "advertiser_title", "sales_note", "gds_note",
    "status", "jira_tickets", "pso_validated", "updated_by", "updated_at",
]


_svc = None

def _service():
    global _svc
    if _svc is None:
        creds, _ = default(scopes=["https://www.googleapis.com/auth/spreadsheets"])
        _svc = build("sheets", "v4", credentials=creds, cache_discovery=False).spreadsheets()
    return _svc


def _sheet_id() -> str:
    return os.environ["BLUEPRINT_NOTES_SHEET_ID"]


def get_notes() -> dict:
    result = _service().values().get(
        spreadsheetId=_sheet_id(),
        range="Notes!A:I",
    ).execute()
    rows = result.get("values", [])
    if len(rows) <= 1:
        return {}
    notes = {}
    for row in rows[1:]:
        row += [""] * (len(HEADERS) - len(row))  # pad short rows
        obj = dict(zip(HEADERS, row))
        if obj["advertiser_id"]:
            notes[obj["advertiser_id"]] = obj
    return notes


def save_note(payload: dict) -> dict:
    svc = _service()
    sid = _sheet_id()
    now = datetime.now(timezone.utc).isoformat()

    row_values = [
        payload.get("advertiser_id", ""),
        payload.get("advertiser_title", ""),
        payload.get("sales_note", ""),
        payload.get("gds_note", ""),
        payload.get("status", ""),
        payload.get("jira_tickets", ""),
        "true" if payload.get("pso_validated") else "false",
        payload.get("updated_by", ""),
        now,
    ]

    # Read column A to find existing row
    col_result = svc.values().get(
        spreadsheetId=sid, range="Notes!A:A"
    ).execute()
    col_a = [r[0] if r else "" for r in col_result.get("values", [])]

    adv_id = payload.get("advertiser_id", "")
    for i, cell in enumerate(col_a[1:], start=2):  # skip header at row 1
        if cell == adv_id:
            # Overwrite columns C–I (preserve A and B)
            svc.values().update(
                spreadsheetId=sid,
                range=f"Notes!C{i}:I{i}",
                valueInputOption="RAW",
                body={"values": [row_values[2:]]},
            ).execute()
            return {"ok": True, "action": "updated"}

    # Append new row
    svc.values().append(
        spreadsheetId=sid,
        range="Notes!A:I",
        valueInputOption="RAW",
        insertDataOption="INSERT_ROWS",
        body={"values": [row_values]},
    ).execute()
    return {"ok": True, "action": "created"}
