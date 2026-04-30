#!/usr/bin/env python3
"""
Test Glean API (Moloco instance): Search and optionally Chat.
Usage:
  export GLEAN_TOKEN="your-token"
  python test_glean_api.py
Or pass token as first arg (avoid committing): python test_glean_api.py "$(cat ~/.cursor/mcp.json | jq -r '.mcpServers.glean.args[-1]')"
"""
import os
import sys
import json
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    print("Install requests: pip install requests")
    sys.exit(1)

# Set to True only for local testing if you hit SSL cert issues (e.g. corporate proxy)
VERIFY_SSL = os.environ.get("GLEAN_VERIFY_SSL", "true").lower() in ("1", "true", "yes")
if not VERIFY_SSL:
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE = "https://moloco-be.glean.com/rest/api/v1"

def get_token():
    token = os.environ.get("GLEAN_TOKEN")
    if token:
        return token
    if len(sys.argv) > 1:
        return sys.argv[1]
    # Fallback: read from mcp.json (same machine only)
    mcp_path = os.path.expanduser("~/.cursor/mcp.json")
    if os.path.exists(mcp_path):
        with open(mcp_path) as f:
            data = json.load(f)
        args = data.get("mcpServers", {}).get("glean", {}).get("args", [])
        for i, a in enumerate(args):
            if a == "--token" and i + 1 < len(args):
                return args[i + 1]
    return None

def test_search(token: str) -> dict:
    url = f"{BASE}/search"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    body = {
        "query": "haewon.yum",
        "pageSize": 5,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    r = requests.post(url, headers=headers, json=body, timeout=15, verify=VERIFY_SSL)
    r.raise_for_status()
    return r.json()

def test_chat(token: str) -> dict:
    url = f"{BASE}/chat"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    body = {
        "messages": [
            {
                "fragments": [
                    {"text": "What did haewon.yum recently write about?"}
                ]
            }
        ]
    }
    # Chat can take longer; use streaming to avoid timeout
    r = requests.post(url, headers=headers, json=body, timeout=60, verify=VERIFY_SSL, stream=True)
    r.raise_for_status()
    # Collect streamed response
    content = b""
    for chunk in r.iter_content(chunk_size=8192):
        content += chunk
    return json.loads(content) if content else {}

def main():
    token = get_token()
    if not token:
        print("Set GLEAN_TOKEN or pass token as first argument.")
        sys.exit(1)
    print("Testing Glean API (moloco-be)...")
    print("-" * 50)
    try:
        out = test_search(token)
        print("[Search] OK")
        results = out.get("results") or []
        print(f"  Results: {len(results)} tab(s)")
        for tab in results:
            docs = tab.get("document", []) if isinstance(tab.get("document"), list) else []
            if not docs and isinstance(tab.get("document"), dict):
                docs = [tab["document"]]
            for d in (docs or [])[:3]:
                title = (d.get("document") or d).get("title") or (d.get("title") or "?")
                url = (d.get("document") or d).get("url") or (d.get("url") or "")
                print(f"    - {title[:60]} | {url[:70]}")
        print()
        try:
            chat_out = test_chat(token)
            print("[Chat] OK")
            print(f"  Response keys: {list(chat_out.keys())[:10]}")
        except requests.HTTPError as e:
            if e.response.status_code == 400:
                print("[Chat] 400 Bad Request (payload may need different fields for your instance)")
            else:
                raise
    except requests.HTTPError as e:
        print(f"HTTP error: {e.response.status_code}")
        print(e.response.text[:500])
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    print("-" * 50)
    print("Done.")

if __name__ == "__main__":
    main()
