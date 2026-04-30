"""
Normalize raw Slack messages and Gong calls into the shared Dossier event schema.

Event schema:
{
  "event_id":    str,
  "account":     str,
  "source":      "slack" | "gong",
  "type":        "escalation" | "launch" | "call" | "alert" | "decision" | "context" | "question",
  "timestamp":   str (ISO 8601),
  "title":       str,
  "summary":     str,
  "participants": [str],
  "source_url":  str,
  "tags":        [str],
  "raw":         dict,
}
"""
import re
from datetime import datetime, timezone
from typing import Any

import summarize
import config
from ingest import slack as slack_ingest

_SLACK_ID_RE = re.compile(r'^U[A-Z0-9]{6,11}$')


def _ts_to_iso(ts: float | str) -> str:
    return datetime.fromtimestamp(float(ts), tz=timezone.utc).isoformat()


# ── Slack ──────────────────────────────────────────────────────────────────────

def normalize_slack_messages(
    messages: list[dict],
    channel_key: str,
    channel_id: str,
    account: str = config.NETMARBLE_ACCOUNT,
) -> list[dict[str, Any]]:
    """
    Convert raw Slack messages into events.
    Only root messages (no parent_ts) are processed; replies are included in the thread.
    Threads with reply_count > 0 get summarized; standalone messages get a lightweight event.
    """
    events = []
    for msg in messages:
        # Skip reply messages — they're bundled with their root
        if msg.get("parent_user_id") or msg.get("thread_ts", msg["ts"]) != msg["ts"]:
            continue

        # Build the full thread for summarization
        thread = [msg] + msg.get("_replies", [])
        claude_result = summarize.summarize_slack_thread(thread, channel_key)

        permalink = (
            f"https://moloco.slack.com/archives/{channel_id}/p{msg['ts'].replace('.','')}"
        )
        raw_participants = claude_result.get("participants", [])
        if not raw_participants:
            raw_participants = [
                m.get("user", m.get("username", ""))
                for m in thread if m.get("user")
            ]
        # Resolve any Slack user IDs (U...) to display names
        participants = list(dict.fromkeys(
            slack_ingest.resolve_user_id(p) if _SLACK_ID_RE.match(p) else p
            for p in raw_participants if p
        ))

        title_en = claude_result.get("title_en") or claude_result.get("title", "Slack thread")
        title_ko = claude_result.get("title_ko") or title_en
        summary_en = claude_result.get("summary_en") or claude_result.get("summary", "")
        summary_ko = claude_result.get("summary_ko") or summary_en

        event: dict[str, Any] = {
            "event_id":    f"slack_{channel_id}_{msg['ts'].replace('.', '_')}",
            "account":     account,
            "source":      "slack",
            "type":        claude_result.get("type", "context"),
            "timestamp":   _ts_to_iso(msg["ts"]),
            "title":       title_en,
            "title_en":    title_en,
            "title_ko":    title_ko,
            "summary":     summary_en,
            "summary_en":  summary_en,
            "summary_ko":  summary_ko,
            "participants": participants,
            "source_url":  permalink,
            "tags":        claude_result.get("tags", []),
            "channel_key": channel_key,
            "reply_count": len(thread) - 1,
            "raw":         {"ts": msg["ts"], "text": msg.get("text", "")[:500]},
        }
        events.append(event)

    return events


# ── Gong ───────────────────────────────────────────────────────────────────────

def normalize_gong_call(
    call: dict,
    account: str = config.NETMARBLE_ACCOUNT,
) -> dict[str, Any]:
    """Convert an extensive Gong call dict into a Dossier event."""
    meta = call.get("metaData", {})
    parties = call.get("parties", [])
    content = call.get("content", {})

    claude_result = summarize.summarize_gong_call(call)

    participants = [
        p.get("emailAddress") or p.get("name", "unknown")
        for p in parties
    ]

    call_url = meta.get("url", f"https://app.gong.io/call?id={meta.get('id','')}")
    started = meta.get("started", "")
    duration_min = (meta.get("duration") or 0) // 60

    tags = claude_result.get("tags", [])
    if any(d in p for d in config.NETMARBLE_DOMAINS for p in participants):
        tags.append("external_client")

    title = meta.get("title", "Gong call")
    summary_en = claude_result.get("summary_en") or claude_result.get("summary", "")
    summary_ko = claude_result.get("summary_ko") or summary_en
    action_items_en = claude_result.get("action_items_en") or claude_result.get("action_items", [])
    action_items_ko = claude_result.get("action_items_ko") or action_items_en

    return {
        "event_id":         f"gong_{meta.get('id', '')}",
        "account":          account,
        "source":           "gong",
        "type":             "call",
        "timestamp":        started if started.endswith("Z") else started + "Z" if started else "",
        "title":            title,
        "title_en":         title,
        "title_ko":         title,
        "summary":          summary_en,
        "summary_en":       summary_en,
        "summary_ko":       summary_ko,
        "participants":     participants,
        "source_url":       call_url,
        "tags":             tags,
        "duration_min":     duration_min,
        "action_items":     action_items_en,
        "action_items_en":  action_items_en,
        "action_items_ko":  action_items_ko,
        "raw": {
            "title":    meta.get("title"),
            "started":  started,
            "duration": meta.get("duration"),
        },
    }


def normalize_all(
    slack_by_channel: dict[str, list[dict]],
    gong_calls: list[dict],
    account: str = config.NETMARBLE_ACCOUNT,
) -> list[dict[str, Any]]:
    """Normalize all sources and return a unified, sorted event list."""
    events: list[dict] = []

    for key, messages in slack_by_channel.items():
        channel_id = config.SLACK_CHANNELS.get(key, "")
        print(f"  Normalizing Slack #{key} ({len(messages)} messages)...")
        slack_events = normalize_slack_messages(messages, key, channel_id, account)
        events.extend(slack_events)
        print(f"    → {len(slack_events)} events")

    print(f"  Normalizing {len(gong_calls)} Gong calls...")
    for call in gong_calls:
        events.append(normalize_gong_call(call, account))

    # Sort newest first
    events.sort(key=lambda e: e.get("timestamp", ""), reverse=True)
    return events
