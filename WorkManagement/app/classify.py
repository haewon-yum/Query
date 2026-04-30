import os
import json
import anthropic
from models import WorkItem


BUCKET_NAMES = {
    1: "To-Do (not started, clear action needed)",
    2: "Ongoing (actively in progress)",
    3: "Pending (blocked/waiting on someone else)",
    4: "Delegated (handed off, tracking outcome)",
    5: "Deprioritized (deliberately parked)",
    6: "Watching (monitoring, not actively engaged)",
}

FLAG_OPTIONS = {
    1: ["soon", "this-week", "overdue"],
    2: ["on-track", "at-risk", "overdue"],
    3: ["waiting-response", "waiting-info", "blocked"],
    4: ["on-track", "no-update", "done"],
    5: ["revisit-date"],
    6: ["watching"],
}

SYSTEM_PROMPT = """You are a work prioritization assistant for Haewon Yum, KOR GDS Lead & Senior Data Scientist at Moloco.
Classify each work item into the correct bucket and status flag based on available context.

Buckets:
1 = To-Do: Not started, clear action needed from Haewon
2 = Ongoing: Actively in progress by Haewon
3 = Pending: Blocked or waiting on someone else — Haewon cannot proceed
4 = Delegated: Haewon handed off, tracking outcome
5 = Deprioritized: Deliberately parked, lower priority

Status flags by bucket:
- Bucket 1: soon | this-week | overdue
- Bucket 2: on-track | at-risk | overdue
- Bucket 3: waiting-response | waiting-info | blocked
- Bucket 4: on-track | no-update | done
- Bucket 5: revisit-date

Rules:
- Jira tickets where Haewon is watcher (not assignee) → bucket 4 (delegated)
- Slack DMs with no reply from Haewon → bucket 3 (pending)
- Slack @mentions not yet responded → bucket 1 (todo) if action needed, else bucket 3
- Google Drive docs pending review → bucket 1 (todo)
- Gmail threads awaiting Haewon's reply → bucket 1 or 3 depending on context
- Overdue = due_date is in the past
- At-risk = due_date is within 2 days or item has been open 14+ days without update
- If context is ambiguous → bucket 3, flag waiting-info, confidence 0.5

Return ONLY a JSON array. Each element: {"id": "...", "bucket": N, "flag": "...", "due_date": "YYYY-MM-DD or null", "context": "1-sentence summary", "confidence": 0.0-1.0}"""


def classify(items: list[WorkItem], existing_ids: set[str] | None = None) -> list[WorkItem]:
    """Batch classify only NEW unconfirmed items using Claude. Already-classified items are skipped."""
    # Only classify items that are new (not in existing_ids) AND not human-confirmed
    # Items already in storage keep their current bucket/flag — no re-classification
    if existing_ids is None:
        existing_ids = set()

    needs_classify = [
        item for item in items
        if not item.human_confirmed and item.id not in existing_ids
    ]
    skip = [item for item in items if item.human_confirmed or item.id in existing_ids]

    print(f"🤖 classify: {len(needs_classify)} new items to classify, {len(skip)} skipped (already classified)")

    if not needs_classify:
        return items

    # Rename for clarity
    unconfirmed = needs_classify
    confirmed = skip

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    # Build batch input (max 50 items per call to stay within context)
    batch_size = 50
    classified_map: dict[str, dict] = {}

    for i in range(0, len(unconfirmed), batch_size):
        batch = unconfirmed[i : i + batch_size]
        batch_input = [
            {
                "id": item.id,
                "title": item.title,
                "source": item.source,
                "current_bucket": item.bucket,
                "current_flag": item.status_flag,
                "due_date": item.due_date,
                "last_signal": item.last_signal,
                "context": item.context,
                "tags": item.tags,
            }
            for item in batch
        ]

        message = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": f"Classify these {len(batch)} work items:\n\n{json.dumps(batch_input, indent=2)}",
                }
            ],
        )

        try:
            text = message.content[0].text.strip()
            # Strip markdown code fences if present
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            suggestions = json.loads(text)
            for s in suggestions:
                classified_map[s["id"]] = s
        except (json.JSONDecodeError, IndexError, KeyError):
            # If parsing fails, leave items with current normalization
            pass

    # Apply AI suggestions to unconfirmed items
    updated_unconfirmed = []
    for item in unconfirmed:
        suggestion = classified_map.get(item.id)
        if suggestion:
            item.ai_suggested_bucket = suggestion.get("bucket", item.bucket)
            item.ai_suggested_flag = suggestion.get("flag", item.status_flag)
            item.ai_confidence = suggestion.get("confidence", 0.7)
            # Apply AI suggestion as the working value (human can override)
            item.bucket = item.ai_suggested_bucket
            item.status_flag = item.ai_suggested_flag
            if suggestion.get("due_date") and not item.due_date:
                item.due_date = suggestion["due_date"]
            if suggestion.get("context"):
                item.context = suggestion["context"]
        updated_unconfirmed.append(item)

    return skip + updated_unconfirmed
