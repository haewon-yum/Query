"""
Pull Gong calls for an account by matching participant email domains.
Uses Gong REST API with Basic auth (ACCESS_KEY:ACCESS_KEY_SECRET).
"""
import base64
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

import config


def _auth_header() -> str:
    creds = f"{config.GONG_ACCESS_KEY}:{config.GONG_ACCESS_KEY_SECRET}"
    return "Basic " + base64.b64encode(creds.encode()).decode()


def _headers() -> dict:
    return {
        "Authorization": _auth_header(),
        "Content-Type": "application/json",
    }


def _date_range(lookback_days: int) -> tuple[str, str]:
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=lookback_days)
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    return start.strftime(fmt), now.strftime(fmt)


def list_calls(lookback_days: int = config.GONG_LOOKBACK_DAYS) -> list[dict[str, Any]]:
    """List all calls in the lookback window (basic metadata only)."""
    from_dt, to_dt = _date_range(lookback_days)
    calls = []
    cursor = None

    with httpx.Client(base_url=config.GONG_BASE_URL, timeout=30) as client:
        while True:
            params: dict = {"fromDateTime": from_dt, "toDateTime": to_dt}
            if cursor:
                params["cursor"] = cursor
            resp = client.get("/v2/calls", headers=_headers(), params=params)
            resp.raise_for_status()
            data = resp.json()
            calls.extend(data.get("calls", []))
            cursor = data.get("records", {}).get("cursor")
            if not cursor:
                break
            time.sleep(0.3)

    return calls


def get_extensive(call_ids: list[str]) -> list[dict[str, Any]]:
    """Fetch detailed call data (parties, topics, highlights) for a batch of IDs."""
    results = []
    # Gong allows up to 50 IDs per request
    for i in range(0, len(call_ids), 50):
        batch = call_ids[i : i + 50]
        with httpx.Client(base_url=config.GONG_BASE_URL, timeout=30) as client:
            resp = client.post(
                "/v2/calls/extensive",
                headers=_headers(),
                json={
                    "filter": {"callIds": batch},
                    "contentSelector": {"exposedFields": {
                        "parties": True,
                        "content": {
                            "topics": True,
                            "highlights": True,
                            "callOutcome": True,
                            "keyPoints": True,
                        },
                    }},
                },
            )
            resp.raise_for_status()
            results.extend(resp.json().get("calls", []))
        time.sleep(0.3)
    return results


def filter_netmarble_calls(extensive_calls: list[dict]) -> list[dict]:
    """Keep only calls that have at least one participant with a Netmarble email domain."""
    matched = []
    for call in extensive_calls:
        parties = call.get("parties", [])
        domains = {p.get("emailAddress", "").split("@")[-1].lower() for p in parties}
        if domains & set(config.NETMARBLE_DOMAINS):
            matched.append(call)
    return matched


_NETMARBLE_TITLE_HINTS = ["netmarble", "넷마블"]


def pull_netmarble_calls() -> list[dict[str, Any]]:
    """
    Full pipeline: list calls → title pre-filter → get extensive data → domain filter.
    Pre-filtering by title avoids fetching extensive data for all 3,000+ calls.
    """
    print("  Listing Gong calls...")
    all_calls = list_calls()
    print(f"    → {len(all_calls)} total calls in window")

    # Pre-filter by title to avoid fetching extensive data for every call
    candidate_ids = [
        c["id"] for c in all_calls
        if any(h in (c.get("title") or "").lower() for h in _NETMARBLE_TITLE_HINTS)
    ]
    print(f"    → {len(candidate_ids)} candidate calls by title")

    if not candidate_ids:
        print("    → 0 Netmarble calls found")
        return []

    print("  Fetching extensive data in batches...")
    extensive = get_extensive(candidate_ids)

    netmarble = filter_netmarble_calls(extensive)
    print(f"    → {len(netmarble)} Netmarble calls found")
    return netmarble
