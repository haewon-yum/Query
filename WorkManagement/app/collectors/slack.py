import os
import json
import subprocess
import urllib.request
from datetime import datetime, timedelta, timezone


GLEAN_BASE = "https://moloco-be.glean.com/rest/api/v1"
SLACK_API = "https://slack.com/api"
MY_EMAIL = "haewon.yum@moloco.com"
MY_SLACK_ID = "U078Q43A2MV"
DAYS_BACK = 14


class SlackCollector:
    """
    Collects Slack action items via Glean search API.
    Uses /search (fast, <5s) instead of /chat (slow, AI reasoning).
    Finds messages mentioning Haewon that likely need a response.
    """

    def __init__(self, since=None):
        self.token = os.environ["GLEAN_API_TOKEN"]
        # Prefer user token (xoxp-) — has search.messages + all channels the user is in.
        # Fall back to bot token for DM scanning only.
        self.user_token = os.environ.get("SLACK_USER_TOKEN", "")
        self.slack_token = self.user_token or os.environ.get("SLACK_BOT_TOKEN", "")
        if since:
            self.cutoff = since.strftime("%Y-%m-%d")
            self.oldest_ts = str(since.timestamp())
        else:
            cutoff_dt = datetime.now(timezone.utc) - timedelta(days=DAYS_BACK)
            self.cutoff = cutoff_dt.strftime("%Y-%m-%d")
            self.oldest_ts = str(cutoff_dt.timestamp())

    def _search(self, query: str, page_size: int = 20) -> list[dict]:
        payload = json.dumps({
            "query": query,
            "pageSize": page_size,
            "requestOptions": {
                "datasourceFilter": "SLACK",
            },
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
            return data.get("results", [])
        except json.JSONDecodeError:
            return []

    def collect(self, since=None) -> list[dict]:
        raw_items = []

        # 1. Direct @mentions of haewon in Slack
        mention_results = self._search(f"@haewon after:{self.cutoff}", page_size=30)
        for r in mention_results:
            item = self._result_to_raw(r, signal="mention")
            if item:
                raw_items.append(item)

        # 2. Messages directed at haewon with action keywords
        action_results = self._search(f"haewon can you OR haewon please OR haewon could you after:{self.cutoff}", page_size=20)
        for r in action_results:
            item = self._result_to_raw(r, signal="action_request")
            if item:
                # Deduplicate by URL
                if not any(x.get("source_url") == item.get("source_url") for x in raw_items):
                    raw_items.append(item)

        # 3. Threads Haewon is in that have recent activity (unresponded)
        thread_results = self._search(f"haewon after:{self.cutoff}", page_size=20)
        for r in thread_results:
            item = self._result_to_raw(r, signal="thread_active")
            if item:
                if not any(x.get("source_url") == item.get("source_url") for x in raw_items):
                    raw_items.append(item)

        # 4. DMs and group DMs via Slack API directly (requires im:read + mpim:read scopes)
        dm_items = self._fetch_dm_items()
        for item in dm_items:
            if not any(x.get("source_url") == item.get("source_url") for x in raw_items):
                raw_items.append(item)

        return raw_items

    def _slack_api(self, method: str, params: dict, token: str = "") -> dict:
        """Call Slack Web API."""
        import urllib.parse
        url = f"{SLACK_API}/{method}?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url)
        req.add_header("Authorization", f"Bearer {token or self.slack_token}")
        try:
            resp = urllib.request.urlopen(req, timeout=10)
            return json.loads(resp.read())
        except Exception:
            return {"ok": False}

    def _fetch_dm_items(self) -> list[dict]:
        """
        Fetch DMs and group DMs that need Haewon's attention.
        Detects two patterns:
          1. Incoming messages Haewon hasn't replied to yet
          2. Threads where Haewon asked an open question (waiting for their reply)
        Uses Claude to assess each conversation and generate a meaningful action summary.
        """
        if not self.slack_token:
            return []

        # Collect thread snapshots: {channel_id: {thread_anchor_ts: [messages]}}
        thread_snapshots = []

        for ch_type in ("im", "mpim"):
            resp = self._slack_api("conversations.list", {
                "types": ch_type, "limit": 50, "exclude_archived": "true"
            })
            if not resp.get("ok"):
                continue

            for ch in resp.get("channels", []):
                ch_id = ch.get("id", "")
                if not ch_id:
                    continue

                hist = self._slack_api("conversations.history", {
                    "channel": ch_id,
                    "oldest": self.oldest_ts,
                    "limit": 15,
                })
                if not hist.get("ok"):
                    continue

                messages = hist.get("messages", [])
                if not messages:
                    continue

                # Resolve participant names (cache per channel call)
                name_cache = {}

                def get_name(uid):
                    if uid in name_cache:
                        return name_cache[uid]
                    r = self._slack_api("users.info", {"user": uid})
                    name = (r.get("user") or {}).get("real_name") or uid if r.get("ok") else uid
                    name_cache[uid] = name
                    return name

                # Build readable thread transcript (oldest first)
                transcript = []
                for msg in reversed(messages):
                    uid = msg.get("user", "")
                    who = "Haewon" if uid == MY_SLACK_ID else get_name(uid)
                    transcript.append(f"{who}: {msg.get('text','')[:300]}")

                last_msg = messages[0]  # most recent
                last_sender = last_msg.get("user", "")
                last_ts = last_msg.get("ts", "")
                last_ts_dt = datetime.fromtimestamp(float(last_ts), tz=timezone.utc) if last_ts else None

                # Quick pre-filter: skip if Haewon has no involvement whatsoever
                all_text = " ".join(m.get("text", "") for m in messages)
                has_haewon = (
                    MY_SLACK_ID in all_text
                    or "haewon" in all_text.lower()
                    or any(m.get("user") == MY_SLACK_ID for m in messages)
                )
                if ch_type == "mpim" and not has_haewon:
                    continue

                # Use anchor ts of oldest relevant message as stable ID base
                anchor_ts = messages[-1].get("ts", last_ts)
                ch_url = f"https://slack.com/archives/{ch_id}/p{anchor_ts.replace('.', '')}"

                thread_snapshots.append({
                    "ch_id": ch_id,
                    "ch_type": ch_type,
                    "url": ch_url,
                    "last_ts": last_ts,
                    "last_ts_dt": last_ts_dt,
                    "last_sender_id": last_sender,
                    "last_sender_name": get_name(last_sender) if last_sender else "",
                    "transcript": "\n".join(transcript),
                })

        if not thread_snapshots:
            return []

        # Use Claude to assess which threads need attention
        assessed = self._assess_threads_with_claude(thread_snapshots)
        return assessed

    def _assess_threads_with_claude(self, snapshots: list[dict]) -> list[dict]:
        """Ask Claude to classify each thread and generate a meaningful action title."""
        import anthropic as _anthropic
        import os

        api_key = os.environ.get("ANTHROPIC_API_KEY", "")
        if not api_key:
            return self._fallback_dm_items(snapshots)

        batch_input = [
            {
                "idx": i,
                "transcript": s["transcript"],
                "last_sender_is_haewon": s["last_sender_id"] == MY_SLACK_ID,
            }
            for i, s in enumerate(snapshots)
        ]

        prompt = (
            "You are analyzing Slack DM conversations for Haewon Yum (KOR GDS Lead at Moloco).\n"
            "For each conversation transcript, decide if Haewon needs to take action or is waiting on someone.\n\n"
            "Return ONLY a JSON array, one object per conversation:\n"
            '{"idx": N, "needs_attention": true/false, '
            '"signal": "action_needed"|"waiting_reply"|"no_action", '
            '"action_title": "concise action item (max 80 chars)", '
            '"sender": "who sent the key message"}\n\n'
            "Rules:\n"
            "- needs_attention=true if: someone asked Haewon something, assigned her a task, or Haewon sent a question that hasn't been answered\n"
            "- signal=action_needed: Haewon needs to reply or do something\n"
            "- signal=waiting_reply: Haewon already replied/asked something and is waiting\n"
            "- signal=no_action: resolved, FYI only, or no clear ask\n"
            "- action_title should describe the actual task, not just 'DM from X'\n\n"
            f"Conversations:\n{json.dumps(batch_input, ensure_ascii=False)}"
        )

        try:
            client = _anthropic.Anthropic(api_key=api_key)
            msg = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=1024,
                messages=[{"role": "user", "content": prompt}],
            )
            text = msg.content[0].text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            results = json.loads(text.strip())
            result_map = {r["idx"]: r for r in results}
        except Exception as e:
            print(f"⚠️ Claude DM assessment failed: {e}")
            return self._fallback_dm_items(snapshots)

        items = []
        for i, snap in enumerate(snapshots):
            assessment = result_map.get(i, {})
            if not assessment.get("needs_attention", False):
                continue
            signal = assessment.get("signal", "action_needed")
            title = assessment.get("action_title") or f"DM from {snap['last_sender_name']}"

            items.append({
                "id": f"slack:{abs(hash(snap['url']))}",
                "title": f"[DM] {title}",
                "source": "slack",
                "source_url": snap["url"],
                "last_signal": snap["last_ts_dt"].isoformat() if snap["last_ts_dt"] else "",
                "signal": signal,
                "raw_text": snap["transcript"][-300:],
                "sender": snap["last_sender_name"],
                "channel": "DM",
            })
        return items

    def collect_recent_activity(self, hours: int = 4) -> list[dict]:
        """
        Return [{text, url}] of messages Haewon sent in the last `hours` hours.
        Uses search.messages (user token) when available — sees all channels.
        Falls back to conversations.history (bot token) — limited to invited channels.
        """
        if not self.slack_token:
            return []

        since_dt = datetime.now(timezone.utc) - timedelta(hours=hours)

        if self.user_token:
            return self._activity_via_search(since_dt)
        else:
            return self._activity_via_history(since_dt)

    def _activity_via_search(self, since: datetime) -> list[dict]:
        """Use search.messages to find messages sent by the user. Requires user token."""
        date_str = since.strftime("%Y-%m-%d")
        resp = self._slack_api("search.messages", {
            "query": f"from:me after:{date_str}",
            "count": 20,
            "sort": "timestamp",
            "sort_dir": "desc",
        }, token=self.user_token)
        if not resp.get("ok"):
            print(f"⚠️ search.messages failed: {resp.get('error')}")
            return []

        since_ts = since.timestamp()
        activity = []
        for match in resp.get("messages", {}).get("matches", []):
            msg_ts = float(match.get("ts", 0))
            if msg_ts < since_ts:
                continue
            text = match.get("text", "").strip()
            if not text or len(text) < 5:
                continue
            channel = match.get("channel", {})
            ch_name = channel.get("name", "")
            ch_id = channel.get("id", "")
            label = f"#{ch_name}" if ch_name else "Slack"
            ts_str = match.get("ts", "").replace(".", "")
            url = f"https://moloco.slack.com/archives/{ch_id}/p{ts_str}" if ch_id and ts_str else ""
            activity.append({"text": f"{label}: {text[:120].replace(chr(10), ' ')}", "url": url})

        return activity[:15]

    def _activity_via_history(self, since: datetime) -> list[dict]:
        """Fallback: scan channels the bot can see. Limited to invited channels."""
        oldest_ts = str(since.timestamp())
        activity = []
        for ch_type in ("public_channel", "private_channel", "im", "mpim"):
            resp = self._slack_api("conversations.list", {
                "types": ch_type, "limit": 100, "exclude_archived": "true"
            })
            if not resp.get("ok"):
                continue
            for ch in resp.get("channels", []):
                ch_id = ch.get("id", "")
                ch_name = ch.get("name") or ch_id
                if not ch_id:
                    continue
                hist = self._slack_api("conversations.history", {
                    "channel": ch_id, "oldest": oldest_ts, "limit": 20,
                })
                if not hist.get("ok"):
                    continue
                for msg in hist.get("messages", []):
                    if msg.get("user") != MY_SLACK_ID or msg.get("subtype"):
                        continue
                    text = msg.get("text", "").strip()
                    if not text or len(text) < 5:
                        continue
                    label = "DM" if ch_type == "im" else f"#{ch_name}"
                    ts_str = msg.get("ts", "").replace(".", "")
                    url = f"https://moloco.slack.com/archives/{ch_id}/p{ts_str}" if ts_str else ""
                    activity.append({"text": f"{label}: {text[:120].replace(chr(10), ' ')}", "url": url})
        return activity[:15]

    def _fallback_dm_items(self, snapshots: list[dict]) -> list[dict]:
        """Simple rule-based fallback if Claude is unavailable."""
        items = []
        for snap in snapshots:
            last_is_haewon = snap["last_sender_id"] == MY_SLACK_ID
            signal = "waiting_reply" if last_is_haewon else "action_needed"
            title = f"DM from {snap['last_sender_name']}: {snap['transcript'].split(chr(10))[-1][:60]}"
            items.append({
                "id": f"slack:{abs(hash(snap['url']))}",
                "title": f"[DM] {title}",
                "source": "slack",
                "source_url": snap["url"],
                "last_signal": snap["last_ts_dt"].isoformat() if snap["last_ts_dt"] else "",
                "signal": signal,
                "raw_text": snap["transcript"][-300:],
                "sender": snap["last_sender_name"],
                "channel": "DM",
            })
        return items

    def _result_to_raw(self, result: dict, signal: str) -> dict | None:
        doc = result.get("document", {})
        title = doc.get("title", "").strip()
        url = doc.get("url", "")
        if not title or not url:
            return None

        # Extract channel from metadata
        metadata = doc.get("metadata", {})
        channel = ""
        container = metadata.get("container", "")
        if container:
            channel = container

        # Try to get snippet
        snippets = result.get("snippets", [])
        snippet_text = ""
        for s in snippets:
            for frag in s.get("text", {}).get("structuredText", {}).get("blocks", []):
                snippet_text += frag.get("fullText", "") + " "
        if not snippet_text:
            snippet_text = snippets[0].get("snippet", "") if snippets else ""

        # Infer sender from snippets or title
        sender = metadata.get("author", {}).get("name", "") if isinstance(metadata.get("author"), dict) else ""

        last_signal = doc.get("updatedAt", doc.get("createTime", ""))
        if isinstance(last_signal, (int, float)):
            last_signal = datetime.fromtimestamp(last_signal, tz=timezone.utc).isoformat()

        return {
            "id": f"slack:{abs(hash(url))}",
            "title": f"[{channel}] {title}" if channel else title,
            "source": "slack",
            "source_url": url,
            "last_signal": last_signal,
            "signal": signal,
            "raw_text": snippet_text.strip()[:300],
            "sender": sender,
            "channel": channel,
        }
