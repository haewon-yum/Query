"""Gmail collector — fetch unread messages and categorize them."""
import json
import re
import base64
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path


CREDS_PATH = Path.home() / ".config/mcp-gdrive/gmail_credentials.json"
KEYS_PATH  = Path.home() / ".config/mcp-gdrive/gcp-oauth.keys.json"

# Senders whose emails always go to Digest regardless of IMPORTANT label
DIGEST_SENDERS = {
    "no-reply@dtdg.co",
    "no-reply@account.pagerduty.com",
    "notify@mail.notion.so",
    "notebooklm-noreply@google.com",
    "team@mail.notion.so",
    "no-reply@email.claude.com",
}
DIGEST_SENDER_DOMAINS = {"sensortower.com", "dtdg.co", "pagerduty.com"}

# Human @moloco.com senders that are NOT bots
BOT_SENDERS = {
    "jira@mlc.atlassian.net",
    "noreply@moloco.cloud",
    "comments-noreply@docs.google.com",
}

CATEGORIES = {
    "explab":        {"label": "ExpLab",       "icon": "🧪", "color": "violet"},
    "gdoc":          {"label": "Doc Mentions",  "icon": "💬", "color": "blue"},
    "jira":          {"label": "Jira",          "icon": "🎫", "color": "cyan"},
    "launch_doc":    {"label": "Launch Doc",    "icon": "🚀", "color": "orange"},
    "calendar":      {"label": "Calendar",      "icon": "📅", "color": "teal"},
    "announcement":  {"label": "Announcements", "icon": "📢", "color": "red"},
    "digest":        {"label": "Digest",        "icon": "📊", "color": "gray"},
    "other":         {"label": "Other",         "icon": "📩", "color": "slate"},
}


def _get_token() -> str:
    from datetime import timedelta
    creds = json.loads(CREDS_PATH.read_text())
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


def _gmail_get(path: str, token: str) -> dict:
    req = urllib.request.Request(
        f"https://gmail.googleapis.com/gmail/v1/{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=20).read())


def _header(msg: dict, name: str) -> str:
    for h in msg.get("payload", {}).get("headers", []):
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def _extract_email(sender: str) -> str:
    m = re.search(r"<([^>]+)>", sender)
    return m.group(1).lower() if m else sender.lower().strip()


def _extract_display(sender: str) -> str:
    """Return human-readable sender: 'Name' or email if no name."""
    m = re.match(r'^"?([^"<]+)"?\s*<', sender)
    if m:
        return m.group(1).strip().strip('"')
    m2 = re.search(r"<([^>]+)>", sender)
    return m2.group(1) if m2 else sender.strip()


def _decode_body(payload: dict) -> str:
    """Extract plain-text body from message payload (first 1500 chars)."""
    mime = payload.get("mimeType", "")
    if mime == "text/plain":
        data = payload.get("body", {}).get("data", "")
        if data:
            return base64.urlsafe_b64decode(data + "==").decode("utf-8", errors="replace")[:1500]
    if mime == "text/html":
        data = payload.get("body", {}).get("data", "")
        if data:
            html = base64.urlsafe_b64decode(data + "==").decode("utf-8", errors="replace")
            text = re.sub(r"<[^>]+>", " ", html)
            text = re.sub(r"\s+", " ", text).strip()
            return text[:1500]
    for part in payload.get("parts", []):
        text = _decode_body(part)
        if text:
            return text
    return ""


def categorize(subject: str, sender_email: str, labels: list[str]) -> str:
    """Rule-based categorization — deterministic, no LLM needed."""
    subj = subject.lower()
    sender = sender_email.lower()

    # Digest: known automated senders
    if sender in DIGEST_SENDERS:
        return "digest"
    for domain in DIGEST_SENDER_DOMAINS:
        if sender.endswith(domain):
            return "digest"
    if "CATEGORY_PROMOTIONS" in labels:
        return "digest"
    if any(kw in subj for kw in ["daily digest", "weekly digest", "weekly analytics report",
                                  "weekly report", "monthly report", "health report",
                                  "market update", "newsletter"]):
        return "digest"

    # ExpLab
    if sender == "noreply@moloco.cloud":
        return "explab"

    # Google Docs/Slides/Sheets mentions
    if sender == "comments-noreply@docs.google.com":
        return "gdoc"

    # Jira
    if "jira@mlc.atlassian.net" in sender or "atlassian.net" in sender:
        return "jira"

    # Calendar invites
    calendar_prefixes = (
        "invitation:", "updated invitation:", "accepted:", "declined:",
        "tentative:", "cancelled:", "new event:", "reminder:"
    )
    if any(subj.startswith(p) for p in calendar_prefixes):
        return "calendar"
    if "CATEGORY_PERSONAL" in labels and any(kw in subj for kw in ["invitation", "accepted", "declined"]):
        return "calendar"

    # Launch docs (DSP/feature launch threads)
    launch_patterns = ["[dsp launch approval]", "[dsp launch fyi]", "[launch approval]",
                       "[launch fyi]", "launch doc", "launch approval"]
    if any(p in subj for p in launch_patterns):
        return "launch_doc"

    # Announcements: IMPORTANT + human @moloco.com sender (not a bot)
    if ("IMPORTANT" in labels and sender.endswith("@moloco.com")
            and sender not in BOT_SENDERS):
        return "announcement"

    return "other"


def fetch_unread(max_results: int = 500) -> list[dict]:
    """Fetch ALL unread inbox messages via pagination, return categorized list."""
    token = _get_token()

    # Paginate through all unread messages (Gmail caps each page at 500)
    encoded = urllib.parse.quote("is:unread in:inbox")
    messages = []
    page_token = None
    while True:
        page_size = min(500, max_results - len(messages))
        url = f"users/me/messages?q={encoded}&maxResults={page_size}"
        if page_token:
            url += f"&pageToken={urllib.parse.quote(page_token)}"
        data = _gmail_get(url, token)
        messages.extend(data.get("messages", []))
        page_token = data.get("nextPageToken")
        if not page_token or len(messages) >= max_results:
            break

    from concurrent.futures import ThreadPoolExecutor, as_completed
    from email.utils import parsedate_to_datetime

    def fetch_one(m: dict) -> dict | None:
        try:
            msg = _gmail_get(
                f"users/me/messages/{m['id']}?format=metadata"
                "&metadataHeaders=Subject&metadataHeaders=From"
                "&metadataHeaders=Date&metadataHeaders=To",
                token,
            )
            subject      = _header(msg, "Subject") or "(no subject)"
            sender_raw   = _header(msg, "From") or ""
            date_raw     = _header(msg, "Date") or ""
            labels       = msg.get("labelIds", [])
            snippet      = msg.get("snippet", "")[:200]
            sender_email = _extract_email(sender_raw)
            sender_display = _extract_display(sender_raw)
            category     = categorize(subject, sender_email, labels)
            try:
                date_iso = parsedate_to_datetime(date_raw).astimezone(timezone.utc).isoformat()
            except Exception:
                date_iso = date_raw
            return {
                "id": m["id"],
                "thread_id": msg.get("threadId", m["id"]),
                "subject": subject,
                "sender_display": sender_display,
                "sender_email": sender_email,
                "date": date_iso,
                "snippet": snippet,
                "category": category,
                "labels": labels,
                "is_important": "IMPORTANT" in labels,
                "gmail_url": f"https://mail.google.com/mail/u/0/#inbox/{msg.get('threadId', m['id'])}",
                "summary": None,
            }
        except Exception as e:
            print(f"⚠️ gmail: skipping {m['id']}: {e}")
            return None

    results = []
    with ThreadPoolExecutor(max_workers=20) as pool:
        futures = {pool.submit(fetch_one, m): m for m in messages}
        for future in as_completed(futures):
            item = future.result()
            if item:
                results.append(item)

    # Sort newest first
    results.sort(key=lambda e: e["date"], reverse=True)
    return results


def fetch_body(message_id: str) -> str:
    """Fetch the full plain-text body of a single message."""
    token = _get_token()
    msg = _gmail_get(f"users/me/messages/{message_id}?format=full", token)
    return _decode_body(msg.get("payload", {}))


def mark_message_read(message_id: str) -> bool:
    """Remove UNREAD label from a single message."""
    token = _get_token()
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message_id}/modify"
    payload = json.dumps({"removeLabelIds": ["UNREAD"]}).encode()
    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        urllib.request.urlopen(req, timeout=10)
        return True
    except Exception as e:
        print(f"❌ mark_message_read {message_id}: {e}")
        return False
