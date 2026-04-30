from models import WorkItem
from datetime import datetime, timezone


# Jira status → preliminary bucket hint (AI will confirm)
JIRA_STATUS_BUCKET = {
    "To Do": 1,
    "Backlog": 5,
    "In Progress": 2,
    "In Review": 2,
    "Blocked": 3,
    "Waiting": 3,
    "Done": None,  # skip
    "Closed": None,
}

JIRA_STATUS_FLAG = {
    "To Do": "soon",
    "Backlog": "revisit-date",
    "In Progress": "on-track",
    "In Review": "on-track",
    "Blocked": "blocked",
    "Waiting": "waiting-response",
}


def normalize(raw_items: list[dict]) -> list[WorkItem]:
    items = []
    seen_ids = set()

    for raw in raw_items:
        item = _normalize_one(raw)
        if item is None:
            continue
        if item.id in seen_ids:
            continue
        seen_ids.add(item.id)
        items.append(item)

    return items


def _normalize_one(raw: dict) -> WorkItem | None:
    source = raw.get("source", "unknown")

    if source == "jira":
        return _normalize_jira(raw)
    elif source == "slack":
        return _normalize_slack(raw)
    elif source == "gdrive":
        return _normalize_drive(raw)
    elif source == "calendar":
        return _normalize_calendar(raw)
    elif source == "gmail":
        return _normalize_glean(raw)
    elif source == "manual":
        return _normalize_manual(raw)
    return None


def _normalize_jira(raw: dict) -> WorkItem | None:
    status = raw.get("raw_status", "In Progress")
    signal = raw.get("signal", "assigned")

    bucket = JIRA_STATUS_BUCKET.get(status, 2)
    if bucket is None:
        return None  # skip done/closed

    # Watching = delegated signal
    if signal == "watching":
        bucket = 4

    flag = JIRA_STATUS_FLAG.get(status, "on-track")
    if signal == "watching":
        flag = "on-track"

    # Check overdue
    due = raw.get("due_date")
    if due:
        try:
            due_dt = datetime.fromisoformat(due)
            if due_dt.date() < datetime.now().date():
                flag = "overdue"
        except ValueError:
            pass

    return WorkItem(
        id=raw["id"],
        title=raw["title"],
        source="jira",
        source_url=raw.get("source_url"),
        bucket=bucket,
        status_flag=flag,
        due_date=due,
        last_signal=raw.get("last_signal"),
        tags=raw.get("labels", []),
        context=f"Jira {raw['id'].split(':')[1]} — status: {status}, priority: {raw.get('raw_priority', 'Medium')}",
    )


def _normalize_slack(raw: dict) -> WorkItem | None:
    signal = raw.get("signal", "mention")
    channel = raw.get("channel", "")

    if signal in ("mention", "action_request", "action_needed"):
        bucket = 1
        flag = "soon"
    elif signal in ("dm_pending_reply", "waiting_reply"):
        bucket = 3
        flag = "waiting-response"
    else:
        bucket = 1
        flag = "soon"

    title = raw.get("title", "")
    if not title:
        return None

    sender = raw.get("sender", "")
    context = raw.get("raw_text", "")[:200]
    if sender and sender not in context:
        context = f"From {sender}: {context}"

    return WorkItem(
        id=raw["id"],
        title=title,
        source="slack",
        source_url=raw.get("source_url"),
        bucket=bucket,
        status_flag=flag,
        last_signal=raw.get("last_signal"),
        context=context,
        tags=[channel] if channel else [],
    )


def _normalize_calendar(raw: dict) -> WorkItem | None:
    from datetime import datetime, timezone
    due = raw.get("due_date")
    flag = "soon"
    if due:
        try:
            days_until = (datetime.fromisoformat(due) - datetime.now()).days
            flag = "overdue" if days_until < 0 else ("soon" if days_until <= 2 else "this-week")
        except ValueError:
            pass
    return WorkItem(
        id=raw["id"],
        title=raw["title"],
        source="calendar",
        source_url=raw.get("source_url"),
        bucket=1,
        status_flag=flag,
        due_date=due,
        last_signal=raw.get("last_signal"),
        context=raw.get("raw_text", "")[:200],
        tags=["meeting", "prep"],
    )


def _normalize_drive(raw: dict) -> WorkItem | None:
    signal = raw.get("signal", "")
    title = raw.get("title", "Untitled Doc")
    unresolved = raw.get("unresolved_comments", 0)
    my_mentions = raw.get("my_mentions_in_comments", 0)

    # Docs with comment mentions → To-Do (action needed)
    # Docs I modified recently → Ongoing
    # Docs shared with me → Pending (review requested)
    if my_mentions > 0:
        bucket = 1
        flag = "soon"
        context = f"Google Drive doc with {my_mentions} comment(s) mentioning you"
    elif signal == "shared_with_me":
        bucket = 1
        flag = "soon"
        context = f"Shared by {raw.get('shared_by', 'someone')} — review or action may be needed"
    else:
        bucket = 2
        flag = "on-track"
        context = f"Recently modified — in progress"
        if unresolved > 0:
            context += f" ({unresolved} unresolved comment(s))"

    return WorkItem(
        id=raw["id"],
        title=title,
        source="gdrive",
        source_url=raw.get("source_url"),
        bucket=bucket,
        status_flag=flag,
        last_signal=raw.get("last_signal"),
        context=context,
        tags=[raw.get("mime_type", "").split(".")[-1]],
    )


def _normalize_glean(raw: dict) -> WorkItem | None:
    source = raw.get("source", "glean")
    signal = raw.get("signal", "")

    # Gmail items default to Watching (bucket 6) unless they're review requests
    if source == "gmail":
        bucket = 6
        flag = "watching"
    elif signal == "review_requested":
        bucket = 1
        flag = "soon"
    else:
        bucket = 3
        flag = "waiting-response"

    return WorkItem(
        id=raw["id"],
        title=raw["title"],
        source=source,
        source_url=raw.get("source_url"),
        bucket=bucket,
        status_flag=flag,
        last_signal=raw.get("last_signal"),
        context=raw.get("raw_text", "")[:200],
    )


def _normalize_manual(raw: dict) -> WorkItem | None:
    return WorkItem(
        id=raw["id"],
        title=raw["title"],
        source="manual",
        source_url=raw.get("source_url"),
        bucket=raw.get("bucket", 1),
        status_flag=raw.get("status_flag", "soon"),
        due_date=raw.get("due_date"),
        context=raw.get("context", ""),
        tags=raw.get("tags", []),
        notes=raw.get("notes", ""),
        human_confirmed=True,  # manual items are always confirmed
    )
