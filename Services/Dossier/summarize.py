"""
Claude API summarization for Slack threads and Gong call transcripts.
Produces bilingual (EN + KO) digests and event type classification.
"""
import json

import anthropic

import config

_client = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=config.ANTHROPIC_API_KEY)
    return _client


def _strip_fences(raw: str) -> str:
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    return raw.strip()


THREAD_SYSTEM = """You are a business intelligence assistant for Moloco, a mobile ad tech company.
You read internal Slack threads about client accounts and extract key business context.
Respond with both English and Korean versions of the title and summary.
Be concise, factual, and precise.
"""

THREAD_PROMPT = """Slack thread from channel {channel} ({num_messages} messages):

{thread_text}

Respond with JSON only:
{{
  "title_en": "<5-8 word descriptive title in English>",
  "title_ko": "<5-8 word descriptive title in Korean>",
  "summary_en": "<2-3 sentence business summary in English — what happened, what was decided or flagged>",
  "summary_ko": "<2-3 sentence business summary in Korean>",
  "type": "<one of: escalation | launch | decision | alert | context | question>",
  "tags": ["<tag1>", "<tag2>"],
  "participants": ["<email or display name>"]
}}

Type guide:
- escalation: client complaint, budget cut, performance crisis requiring urgent action
- launch: new title, new campaign, or geo going live
- decision: strategic or operational choice made (budget, targeting, measurement setup)
- alert: performance issue, metric miss, anomaly flagged
- context: background information, FYI, market intel
- question: open question or request for analysis"""


GONG_SYSTEM = """You are a business intelligence assistant for Moloco.
You summarize Gong call notes about advertiser accounts into concise bilingual business briefs.
Provide both English and Korean versions of summaries and action items.
Focus on decisions made, commitments, and key context.
"""

GONG_PROMPT = """Gong call: {title} ({date}, {duration}min)
Participants: {participants}

Topics discussed:
{topics}

Key highlights:
{highlights}

Respond with JSON only:
{{
  "summary_en": "<2-3 sentence summary in English of what was discussed and decided>",
  "summary_ko": "<2-3 sentence summary in Korean of what was discussed and decided>",
  "action_items_en": ["<action 1 in English>", "<action 2 in English>"],
  "action_items_ko": ["<action 1 in Korean>", "<action 2 in Korean>"],
  "tags": ["<tag1>", "<tag2>"]
}}"""


def summarize_slack_thread(thread_messages: list[dict], channel_key: str) -> dict:
    """
    Summarize a Slack thread using Claude.
    Returns {title_en, title_ko, summary_en, summary_ko, type, tags, participants}.
    """
    lines = []
    for msg in thread_messages:
        author = msg.get("user", msg.get("username", "unknown"))
        text = msg.get("text", "").strip()
        if text:
            lines.append(f"[{author}]: {text}")

    if not lines:
        return {
            "title_en": "Empty thread", "title_ko": "빈 스레드",
            "summary_en": "", "summary_ko": "",
            "type": "context", "tags": [], "participants": [],
        }

    thread_text = "\n".join(lines)
    prompt = THREAD_PROMPT.format(
        channel=channel_key,
        num_messages=len(thread_messages),
        thread_text=thread_text[:6000],
    )

    resp = _get_client().messages.create(
        model="claude-sonnet-4-6",
        max_tokens=800,
        system=THREAD_SYSTEM,
        messages=[{"role": "user", "content": prompt}],
    )

    raw = _strip_fences(resp.content[0].text.strip())
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        title = lines[0][:60]
        return {
            "title_en": title, "title_ko": title,
            "summary_en": raw[:300], "summary_ko": "",
            "type": "context", "tags": [], "participants": [],
        }


def summarize_gong_call(call: dict) -> dict:
    """
    Generate bilingual summary + action items for a Gong call.
    Returns {summary_en, summary_ko, action_items_en, action_items_ko, tags}.
    """
    content = call.get("content", {})
    topics = content.get("topics", [])
    highlights = content.get("highlights", [])
    key_points = content.get("keyPoints", [])
    parties = call.get("parties", [])

    topic_text = "\n".join(f"- {t.get('name','')}: {t.get('duration',0)//60}min" for t in topics[:10])

    # Prefer keyPoints (richer) over highlights for input
    if key_points:
        highlight_items = [kp.get("text", "") for kp in key_points[:12] if kp.get("text")]
    else:
        highlight_items = []
        for h in highlights[:8]:
            for item in h.get("items", []):
                if item.get("text"):
                    highlight_items.append(item["text"])
            if h.get("text"):
                highlight_items.append(h["text"])

    highlight_text = "\n".join(f"- {t[:300]}" for t in highlight_items[:12])
    participant_text = ", ".join(
        p.get("name") or p.get("emailAddress", "unknown") for p in parties[:8]
    )

    meta = call.get("metaData", {})
    prompt = GONG_PROMPT.format(
        title=meta.get("title", "Untitled"),
        date=meta.get("started", "")[:10],
        duration=meta.get("duration", 0) // 60,
        participants=participant_text,
        topics=topic_text or "(no topics)",
        highlights=highlight_text or "(no highlights)",
    )

    resp = _get_client().messages.create(
        model="claude-sonnet-4-6",
        max_tokens=800,
        system=GONG_SYSTEM,
        messages=[{"role": "user", "content": prompt}],
    )

    raw = _strip_fences(resp.content[0].text.strip())
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {
            "summary_en": raw[:300], "summary_ko": "",
            "action_items_en": [], "action_items_ko": [],
            "tags": [],
        }
