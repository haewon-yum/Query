"""One-time Gmail pattern scan — shows unread email subjects/senders/snippets to inform categorization rules."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from gmail_client import _get_token
import json, urllib.request, urllib.parse, base64, re


def gmail_get(path, token):
    req = urllib.request.Request(
        f"https://gmail.googleapis.com/gmail/v1/{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=20).read())


def decode_body(payload):
    """Extract plain text from message payload."""
    if payload.get("mimeType") == "text/plain":
        data = payload.get("body", {}).get("data", "")
        if data:
            return base64.urlsafe_b64decode(data + "==").decode("utf-8", errors="replace")[:500]
    for part in payload.get("parts", []):
        text = decode_body(part)
        if text:
            return text
    return ""


def header(msg, name):
    for h in msg.get("payload", {}).get("headers", []):
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def main():
    token = _get_token()

    # Fetch up to 50 unread messages
    result = gmail_get("users/me/messages?q=is:unread&maxResults=50", token)
    messages = result.get("messages", [])
    print(f"Found {len(messages)} unread messages\n")
    print("=" * 80)

    for i, m in enumerate(messages):
        msg = gmail_get(f"users/me/messages/{m['id']}?format=full", token)
        subject = header(msg, "Subject") or "(no subject)"
        sender  = header(msg, "From") or ""
        date    = header(msg, "Date") or ""
        snippet = msg.get("snippet", "")[:200]
        labels  = msg.get("labelIds", [])

        print(f"[{i+1:02d}] {subject}")
        print(f"     From:    {sender}")
        print(f"     Date:    {date}")
        print(f"     Labels:  {', '.join(labels)}")
        print(f"     Snippet: {snippet[:120]}")
        print()


if __name__ == "__main__":
    main()
