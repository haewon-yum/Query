import os
import json
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError
from datetime import datetime, timezone, timedelta


GLEAN_BASE = "https://moloco-be.glean.com/rest/api/v1"


class GleanCollector:
    def __init__(self):
        self.token = os.environ["GLEAN_API_TOKEN"]

    def collect(self, since=None) -> list[dict]:
        # Use Glean search (fast) for Gmail action items instead of slow /chat
        items = []
        try:
            gmail_items = self._search_gmail(since=since)
            items.extend(gmail_items)
            print(f"✅ glean/gmail: {len(gmail_items)} items")
        except Exception as e:
            print(f"❌ glean/gmail: {e}")
        return items

    def _search_gmail(self, since=None) -> list[dict]:
        """Find Gmail threads needing a response via Glean search."""
        from datetime import datetime, timedelta, timezone
        if since:
            cutoff = since.strftime("%Y-%m-%d")
        else:
            cutoff = (datetime.now(timezone.utc) - timedelta(days=14)).strftime("%Y-%m-%d")
        payload = json.dumps({
            "query": f"haewon after:{cutoff}",
            "pageSize": 20,
            "requestOptions": {"datasourceFilter": "GMAIL"},
        })
        result = subprocess.run(
            ["curl", "-s", "-X", "POST", f"{GLEAN_BASE}/search",
             "-H", f"Authorization: Bearer {self.token}",
             "-H", "Content-Type: application/json",
             "-d", payload, "--max-time", "15"],
            capture_output=True, text=True, timeout=20,
        )
        if not result.stdout.strip():
            return []
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError:
            return []

        items = []
        for r in data.get("results", []):
            doc = r.get("document", {})
            title = doc.get("title", "").strip()
            url = doc.get("url", "")
            if not title:
                continue
            snippets = r.get("snippets", [])
            snippet = snippets[0].get("snippet", "") if snippets else ""
            last_signal = doc.get("updatedAt", "")
            if isinstance(last_signal, (int, float)):
                from datetime import datetime, timezone
                last_signal = datetime.fromtimestamp(last_signal, tz=timezone.utc).isoformat()
            items.append({
                "id": f"gmail:{abs(hash(url or title))}",
                "title": title,
                "source": "gmail",
                "source_url": url,
                "last_signal": last_signal,
                "signal": "email_mention",
                "raw_text": snippet[:300],
            })
        return items

    def _chat_raw(self, message: str) -> dict:
        """Call Glean chat API and return the raw parsed JSON response."""
        payload = json.dumps({
            "messages": [{"author": "USER", "fragments": [{"text": message}]}]
        })
        result = subprocess.run(
            ["curl", "-s", "-X", "POST",
             f"{GLEAN_BASE}/chat",
             "-H", f"Authorization: Bearer {self.token}",
             "-H", "Content-Type: application/json",
             "-d", payload,
             "--max-time", "120"],
            capture_output=True, text=True, timeout=125,
        )
        if not result.stdout.strip():
            return {}
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return {}

    def _chat(self, message: str) -> str:
        """Call Glean chat API, return text from the final CONTENT message."""
        data = self._chat_raw(message)
        full_text = ""
        for msg in data.get("messages", []):
            if msg.get("messageType") == "CONTENT" and msg.get("author") in ("ASSISTANT", "GLEAN_AI"):
                for frag in msg.get("fragments", []):
                    if "text" in frag:
                        full_text += frag["text"]
        return full_text.strip()

    def _extract_slack_items_from_chat(self, data: dict, signal: str) -> list[dict]:
        """
        Extract Slack action items directly from Glean chat citations.
        Glean returns markdown + inline citation objects with real Slack URLs.
        This is more reliable than parsing pipe-delimited text.
        """
        items = []
        seen_urls = set()

        for msg in data.get("messages", []):
            if msg.get("messageType") != "CONTENT":
                continue
            if msg.get("author") not in ("GLEAN_AI", "ASSISTANT"):
                continue

            fragments = msg.get("fragments", [])
            # Walk fragments: text chunks and citation objects are interleaved.
            # Each citation follows the bullet text describing it.
            pending_text = ""
            for frag in fragments:
                if "text" in frag:
                    pending_text += frag["text"]
                elif "citation" in frag:
                    doc = frag["citation"].get("sourceDocument", {})
                    url = doc.get("url", "")
                    if not url or "slack.com" not in url or url in seen_urls:
                        pending_text = ""
                        continue
                    seen_urls.add(url)

                    # Get message content from citation
                    content_lines = doc.get("content", {}).get("fullTextList", [])
                    content = " ".join(content_lines)[:300]

                    # Use the last bullet line before this citation as the title
                    lines = [l.strip("- *\n") for l in pending_text.split("\n") if l.strip("- *\n")]
                    title_text = lines[-1] if lines else doc.get("title", "Slack message")
                    # Strip markdown bold/italic
                    title_text = re.sub(r'\*+', '', title_text).strip()
                    if not title_text or len(title_text) < 5:
                        title_text = doc.get("title", "Slack action item")

                    # Extract timestamp from Slack URL: /p{unix_ts_seconds}{microseconds}
                    msg_ts = None
                    ts_match = re.search(r'/p(\d{10})', url)
                    if ts_match:
                        msg_ts = datetime.fromtimestamp(int(ts_match.group(1)), tz=timezone.utc)

                    # Skip messages older than 30 days
                    cutoff_dt = datetime.now(timezone.utc) - timedelta(days=30)
                    if msg_ts and msg_ts < cutoff_dt:
                        pending_text = ""
                        continue

                    items.append({
                        "id": f"slack:{abs(hash(url))}",
                        "title": f"[Slack] {title_text[:100]}",
                        "source": "slack",
                        "source_url": url,
                        "last_signal": msg_ts.isoformat() if msg_ts else datetime.now(timezone.utc).isoformat(),
                        "signal": signal,
                        "raw_text": content,
                        "sender": "",
                        "channel": "",
                    })
                    pending_text = ""

        return items

    def scan_slack_action_items(self) -> list[dict]:
        """
        Deep Slack scan using Glean chat — mirrors /weekly-summary steps 2 & 4.
        Runs two queries in parallel: unreplied @mentions + explicit action requests.
        """
        from concurrent.futures import ThreadPoolExecutor, as_completed
        results = []

        def mentions():
            return self._query_slack_mentions()

        def actions():
            return self._query_slack_action_requests()

        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = {executor.submit(mentions): "mentions", executor.submit(actions): "actions"}
            for future in as_completed(futures, timeout=120):
                try:
                    items = future.result()
                    results.extend(items)
                    print(f"✅ glean/slack/{futures[future]}: {len(items)} items")
                except Exception as e:
                    print(f"❌ glean/slack/{futures[future]}: {e}")

        # Deduplicate by URL
        seen = set()
        deduped = []
        for item in results:
            key = item.get("source_url") or item.get("title", "")
            if key not in seen:
                seen.add(key)
                deduped.append(item)
        return deduped

    def _query_slack_mentions(self) -> list[dict]:
        """Unreplied @mentions — mirrors /weekly-summary Step 2."""
        from datetime import datetime, timedelta, timezone
        cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).strftime("%Y-%m-%d")
        data = self._chat_raw(
            f"What Slack messages sent after {cutoff} mention @haewon or haewon.yum@moloco.com? "
            "Show only messages where she has not yet replied. Include links. "
            f"Do NOT include any messages older than {cutoff}."
        )
        return self._extract_slack_items_from_chat(data, signal="mention_unreplied")

    def _query_slack_action_requests(self) -> list[dict]:
        """Explicit action requests directed at Haewon — mirrors /weekly-summary Step 4."""
        from datetime import datetime, timedelta, timezone
        cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).strftime("%Y-%m-%d")
        data = self._chat_raw(
            f"Find Slack messages sent after {cutoff} asking @haewon to do something — "
            "requests, tasks, approvals, reviews. Only include unanswered ones. Include links. "
            f"Do NOT include any messages older than {cutoff}."
        )
        return self._extract_slack_items_from_chat(data, signal="action_request")

    def _query_drive_pending_review(self) -> list[dict]:
        """Google Drive docs shared with me that have unresolved comments."""
        response = self._chat(
            "List Google Drive documents that were shared with haewon.yum@moloco.com in the last 14 days "
            "where there are unresolved comments or review requests directed at her. "
            "Return as a list with: document title, URL, who shared it, what action is needed. "
            "Be concise, one item per line, format: TITLE | URL | FROM | ACTION"
        )
        return self._parse_pipe_response(response, source="gdrive", signal="review_requested")

    def _query_gmail_action_items(self) -> list[dict]:
        """Gmail threads where I need to respond."""
        response = self._chat(
            "Find email threads in haewon.yum@moloco.com's Gmail from the last 14 days "
            "where she is expected to reply but hasn't yet. "
            "Return as a list with: subject line, sender, URL or thread ID, urgency. "
            "Format: SUBJECT | SENDER | URL | URGENCY"
        )
        return self._parse_pipe_response(response, source="gmail", signal="email_pending_reply")

    def _parse_pipe_response(self, text: str, source: str, signal: str) -> list[dict]:
        """Parse pipe-delimited lines from Glean chat response.
        Handles markdown links: [text](url) → extracts url.
        """
        import re
        items = []
        for line in text.strip().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 2:
                continue

            title = parts[0].strip("- *")
            raw_url = parts[-1] if len(parts) > 1 else ""
            context = " | ".join(parts[1:-1]) if len(parts) > 2 else parts[1] if len(parts) > 1 else ""

            # Extract URL from markdown link [label](url) or bare url
            url_match = re.search(r'\[.*?\]\((https?://[^\)]+)\)', raw_url)
            url = url_match.group(1) if url_match else (raw_url if raw_url.startswith("http") else None)

            if not title or title.lower() in ("channel", "title", "subject", "document", "sender"):
                continue  # skip header lines

            items.append({
                "id": f"{source}:{abs(hash(title + (url or '')))}",
                "title": title,
                "source": source,
                "source_url": url,
                "last_signal": datetime.now(timezone.utc).isoformat(),
                "signal": signal,
                "raw_text": context,
            })
        return items
