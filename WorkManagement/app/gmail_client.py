"""Gmail API client — mark threads as read."""
import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone
from pathlib import Path

CREDS_PATH = Path.home() / ".config/mcp-gdrive/gmail_credentials.json"
KEYS_PATH  = Path.home() / ".config/mcp-gdrive/gcp-oauth.keys.json"


def _get_token() -> str:
    creds = json.loads(CREDS_PATH.read_text())

    # Refresh if expired
    expiry = creds.get("expiry_date", 0)
    if isinstance(expiry, (int, float)) and expiry > 0:
        if datetime.fromtimestamp(expiry / 1000, tz=timezone.utc) > datetime.now(timezone.utc) + timedelta(minutes=5):
            return creds["access_token"]

    keys = json.loads(KEYS_PATH.read_text())["installed"]
    data = urllib.parse.urlencode({
        "client_id":     keys["client_id"],
        "client_secret": keys["client_secret"],
        "refresh_token": creds["refresh_token"],
        "grant_type":    "refresh_token",
    }).encode()
    resp = json.loads(urllib.request.urlopen(
        urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    ).read())

    creds["access_token"] = resp["access_token"]
    creds["expiry_date"] = int((datetime.now(timezone.utc).timestamp() + resp.get("expires_in", 3600)) * 1000)
    CREDS_PATH.write_text(json.dumps(creds, indent=2))
    return creds["access_token"]


def _extract_thread_id(url: str) -> str | None:
    """Extract Gmail thread/message ID from a Gmail URL."""
    import re
    # e.g. https://mail.google.com/mail/u/0/#inbox/FMfcgzQXKGVx...
    m = re.search(r"#(?:inbox|all|sent|search/[^/]+)/([A-Za-z0-9]+)", url)
    if m:
        return m.group(1)
    # fallback: last path segment
    m = re.search(r"/([A-Za-z0-9]{10,})(?:\?|$)", url)
    return m.group(1) if m else None


def mark_thread_read(thread_id: str) -> bool:
    """Remove UNREAD label from a Gmail thread."""
    token = _get_token()
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/threads/{thread_id}/modify"
    payload = json.dumps({"removeLabelIds": ["UNREAD"]}).encode()
    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        urllib.request.urlopen(req)
        return True
    except Exception as e:
        print(f"❌ mark_thread_read: {e}")
        return False


def mark_read_by_url(source_url: str) -> dict:
    """Given a Gmail source URL, extract thread ID and mark as read."""
    if not source_url:
        return {"ok": False, "error": "No URL"}
    thread_id = _extract_thread_id(source_url)
    if not thread_id:
        return {"ok": False, "error": f"Could not extract thread ID from: {source_url}"}
    ok = mark_thread_read(thread_id)
    return {"ok": ok, "thread_id": thread_id}
