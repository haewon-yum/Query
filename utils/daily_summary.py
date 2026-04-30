#!/usr/bin/env python3
"""daily_summary.py — Pull last-7-day activity from Glean, format with Claude, post to Slack.

Required env vars (add to .env or GitHub Actions secrets):
  GLEAN_API_TOKEN     - Glean REST API token
  ANTHROPIC_API_KEY   - Anthropic API key
  SLACK_BOT_TOKEN     - Slack bot token (chat:write scope)

Usage:
  python utils/daily_summary.py              # run and post to Slack
  python utils/daily_summary.py --dry-run    # print output, skip Slack post
  python utils/daily_summary.py --days 14   # custom lookback window
"""

import os
import sys
import json
import argparse
import subprocess
from datetime import date, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

import anthropic
import requests
from dotenv import load_dotenv

# Load .env from repo root (one level up from utils/)
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

GLEAN_TOKEN = os.getenv("GLEAN_API_TOKEN", "")
GLEAN_BASE_URL = "https://moloco-be.glean.com/rest/api/v1"
SLACK_TOKEN = os.getenv("SLACK_BOT_TOKEN", "")
SLACK_USER_ID = "U078Q43A2MV"
ANTHROPIC_KEY = os.getenv("ANTHROPIC_API_KEY", "")
USER_EMAIL = "haewon.yum@moloco.com"


# ---------------------------------------------------------------------------
# Glean
# ---------------------------------------------------------------------------

def glean_chat(question: str, timeout: int = 90) -> str:
    """Call Glean chat API and return the response text."""
    payload = {"messages": [{"fragments": [{"text": question}]}]}
    result = subprocess.run(
        [
            "curl", "-s", "-X", "POST",
            f"{GLEAN_BASE_URL}/chat",
            "-H", f"Authorization: Bearer {GLEAN_TOKEN}",
            "-H", "Content-Type: application/json",
            "-d", json.dumps(payload),
        ],
        capture_output=True, text=True, timeout=timeout,
    )
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return f"(parse error: {result.stdout[:200]})"

    texts = []
    for msg in data.get("messages", []):
        for frag in msg.get("fragments", []):
            text = frag.get("text", "")
            if text:
                texts.append(text)
    return "\n".join(texts) or "(no response)"


def build_queries(start: str, end: str) -> dict:
    return {
        "activity": (
            f"Show me all Slack messages, posts, and comments made by {USER_EMAIL} "
            f"from {start} to {end}. Also list any Google Drive documents created or "
            f"edited by {USER_EMAIL} in the same period. "
            f"For each Slack message include the direct URL to the original message. "
            f"For each Google Drive document include the direct document URL. "
            f"Group by: Slack (channel name, message summary, URL) and Google Drive (doc title, action, URL)."
        ),
        "mentions": (
            f"Find all Slack messages that mention @haewon or {USER_EMAIL} "
            f"from {start} to {end}. For each mention: who mentioned her, in which "
            f"channel/thread, what was the context, whether {USER_EMAIL} replied in the same thread, "
            f"and the direct URL to the original Slack message."
        ),
        "announcements": (
            f"What were the key announcements, decisions, or important updates posted in Slack "
            f"channels that {USER_EMAIL} is active in, from {start} to {end}? "
            f"Focus on: team updates, product launches, policy changes, experiment results, "
            f"and any pinned or highlighted messages. "
            f"For each announcement include the direct URL to the original Slack message."
        ),
        "action_items": (
            f"Find all Slack messages from {start} to {end} that were directed at {USER_EMAIL} "
            f"and contained explicit action requests — e.g., 'can you', 'please', 'could you', "
            f"'할 수 있어', '부탁', '확인해줘', '@haewon' followed by a task. "
            f"For each: who asked, what was requested, whether she responded, "
            f"and the direct URL to the original Slack message."
        ),
        "gdocs": (
            f"List all Google Drive / Docs activity involving {USER_EMAIL} from {start} to {end}: "
            f"1. Documents shared with her (new shares) "
            f"2. Documents where she was @mentioned in a comment "
            f"3. Documents she edited or commented on. "
            f"For each: doc title, type of activity, who else is involved, and the direct document URL."
        ),
    }


def run_queries_parallel(queries: dict) -> dict:
    results = {}
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(glean_chat, q): key for key, q in queries.items()}
        for future in as_completed(futures):
            key = futures[future]
            try:
                results[key] = future.result()
            except Exception as e:
                results[key] = f"(error: {e})"
    return results


# ---------------------------------------------------------------------------
# Claude formatting
# ---------------------------------------------------------------------------

def format_with_claude(results: dict, start: str, end: str) -> str:
    client = anthropic.Anthropic(api_key=ANTHROPIC_KEY)

    prompt = f"""You are assembling a weekly activity summary for Haewon Yum (haewon.yum@moloco.com).
Date range: {start} to {end}

Here are the raw Glean query results:

=== ACTIVITY (own Slack posts + Google Drive edits) ===
{results.get('activity', 'N/A')}

=== MENTIONS ===
{results.get('mentions', 'N/A')}

=== ANNOUNCEMENTS ===
{results.get('announcements', 'N/A')}

=== ACTION ITEMS ===
{results.get('action_items', 'N/A')}

=== GOOGLE DOCS ===
{results.get('gdocs', 'N/A')}

Format this as a Slack mrkdwn message. Rules:
- Use *bold* for section headers (not # markdown)
- Use ⏳ for pending/needs response, ✅ for already responded
- Top 5 items max per section — be concise
- Total message length: under 3000 characters
- Omit sections with no meaningful data (write "nothing notable" if truly empty)
- For every item that has a URL, append it as a Slack-formatted link: <url|view>
  - Slack messages → link to the original message
  - Google Drive docs → link to the document
  - If no URL is available for an item, omit the link (do not fabricate URLs)

Output exactly this structure:

📅 *Weekly Summary: {start} – {end}*

*1. My Activity*
*Slack*
- [#channel] summary (date) <url|view>
*Google Drive*
- doc title — action (date) <url|view>

*2. Mentions*
⏳ *Needs Response*
- @who in #channel: context (date) <url|view>
✅ *Already Responded*
- @who in #channel: context (date) <url|view>

*3. Key Announcements*
- #channel: update (date) <url|view>

*4. Pending Action Items*
- @who: request (date) — status <url|view>

*5. Google Docs*
- doc title — activity (date) <url|view>

*6. Unanswered DMs*
_Not available — Glean does not index DMs. Check Slack directly._"""

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2000,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


# ---------------------------------------------------------------------------
# Slack
# ---------------------------------------------------------------------------

def post_to_slack(text: str, dry_run: bool = False):
    if dry_run:
        print("=== DRY RUN — would post to Slack ===")
        print(text)
        return

    resp = requests.post(
        "https://slack.com/api/chat.postMessage",
        headers={"Authorization": f"Bearer {SLACK_TOKEN}", "Content-Type": "application/json"},
        json={"channel": SLACK_USER_ID, "text": text},
        timeout=15,
    )
    data = resp.json()
    if data.get("ok"):
        print("✅ Posted to Slack DM")
    else:
        print(f"❌ Slack error: {data.get('error')}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Daily weekly summary → Slack")
    parser.add_argument("--days", type=int, default=7, help="Lookback window in days (default: 7)")
    parser.add_argument("--dry-run", action="store_true", help="Print output, skip Slack post")
    args = parser.parse_args()

    for var, name in [(GLEAN_TOKEN, "GLEAN_API_TOKEN"), (ANTHROPIC_KEY, "ANTHROPIC_API_KEY"), (SLACK_TOKEN, "SLACK_BOT_TOKEN")]:
        if not var and not args.dry_run:
            print(f"❌ Missing env var: {name}")
            sys.exit(1)

    end = date.today()
    start = end - timedelta(days=args.days)
    start_str, end_str = start.isoformat(), end.isoformat()

    print(f"📅 Summary for {start_str} to {end_str}")
    print("🔍 Querying Glean (5 parallel)...")
    results = run_queries_parallel(build_queries(start_str, end_str))

    print("✍️  Formatting with Claude...")
    summary = format_with_claude(results, start_str, end_str)

    post_to_slack(summary, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
