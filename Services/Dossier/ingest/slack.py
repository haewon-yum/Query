"""
Pull message history and thread replies from Slack channels.
Returns raw message dicts; normalization happens in normalize.py.
"""
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

import config


def _client() -> WebClient:
    return WebClient(token=config.SLACK_TOKEN)


_user_cache: dict[str, str] = {}


def resolve_user_id(user_id: str) -> str:
    """Resolve a Slack user ID to a display name. Cached per process."""
    if not user_id or not user_id.startswith("U"):
        return user_id
    if user_id in _user_cache:
        return _user_cache[user_id]
    try:
        resp = _client().users_info(user=user_id)
        profile = resp["user"].get("profile", {})
        name = profile.get("display_name") or profile.get("real_name") or user_id
    except SlackApiError:
        name = user_id
    _user_cache[user_id] = name
    return name


def _oldest_ts(days: int) -> str:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return str(cutoff.timestamp())


def pull_channel(channel_id: str, lookback_days: int = config.SLACK_LOOKBACK_DAYS) -> list[dict[str, Any]]:
    """Pull all messages (with thread replies) from a channel for the lookback window."""
    client = _client()
    oldest = _oldest_ts(lookback_days)
    messages: list[dict] = []
    cursor = None

    while True:
        kwargs: dict = {"channel": channel_id, "oldest": oldest, "limit": 200}
        if cursor:
            kwargs["cursor"] = cursor
        try:
            resp = client.conversations_history(**kwargs)
        except SlackApiError as e:
            raise RuntimeError(f"Slack conversations.history failed: {e.response['error']}") from e

        batch = resp["messages"]
        for msg in batch:
            msg["_channel_id"] = channel_id
            # Fetch thread replies if the message has them
            if msg.get("thread_ts") and msg.get("reply_count", 0) > 0 and msg["thread_ts"] == msg["ts"]:
                msg["_replies"] = _pull_thread(client, channel_id, msg["thread_ts"])
            else:
                msg["_replies"] = []
            messages.append(msg)

        cursor = resp.get("response_metadata", {}).get("next_cursor")
        if not cursor:
            break
        time.sleep(0.5)  # Slack tier-3 rate limit

    return messages


def _pull_thread(client: WebClient, channel_id: str, thread_ts: str) -> list[dict]:
    """Fetch all reply messages in a thread (excludes the root message)."""
    replies = []
    cursor = None
    while True:
        kwargs: dict = {"channel": channel_id, "ts": thread_ts, "limit": 200}
        if cursor:
            kwargs["cursor"] = cursor
        try:
            resp = client.conversations_replies(**kwargs)
        except SlackApiError:
            return replies

        msgs = resp["messages"]
        # First message is the root — skip it in replies list
        replies.extend(msgs[1:] if not cursor else msgs)
        cursor = resp.get("response_metadata", {}).get("next_cursor")
        if not cursor:
            break
        time.sleep(0.3)

    return replies


def pull_all_netmarble_channels() -> dict[str, list[dict]]:
    """Pull both Netmarble-related Slack channels. Returns {channel_key: [messages]}."""
    results = {}
    for key, channel_id in config.SLACK_CHANNELS.items():
        print(f"  Pulling Slack #{key} ({channel_id})...")
        results[key] = pull_channel(channel_id)
        print(f"    → {len(results[key])} messages")
    return results
