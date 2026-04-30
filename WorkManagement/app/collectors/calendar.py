import os
import json
import subprocess
from datetime import datetime, timedelta, timezone


GLEAN_BASE = "https://moloco-be.glean.com/rest/api/v1"


class CalendarCollector:
    def __init__(self):
        self.token = os.environ["GLEAN_API_TOKEN"]

    def _search(self, query: str, page_size: int = 50) -> list[dict]:
        payload = json.dumps({
            "query": query,
            "pageSize": page_size,
            "requestOptions": {"datasourceFilter": "googlecalendar"},
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
            return json.loads(result.stdout).get("results", [])
        except json.JSONDecodeError:
            return []

    def get_upcoming_events(self, days: int = 14) -> list[dict]:
        """Fetch upcoming events for the next N days via Glean search."""
        now = datetime.now(timezone.utc)
        cutoff = now + timedelta(days=days)

        # Empty query returns all calendar events — filter by date client-side
        results = self._search("", page_size=100)

        events = []
        seen_ids = set()

        for r in results:
            doc = r.get("document", {})
            meta = doc.get("metadata", {})

            event_id = doc.get("id", "")
            if event_id in seen_ids:
                continue
            seen_ids.add(event_id)

            title = doc.get("title", "").strip()
            if not title:
                continue

            # createTime = event start time in Glean's calendar indexing
            start_str = meta.get("createTime") or meta.get("updateTime") or ""
            if not start_str:
                continue

            try:
                start_dt = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            except ValueError:
                continue

            # Only keep upcoming events within the window
            if start_dt < now or start_dt > cutoff:
                continue

            # Extract attendees from snippets/metadata
            attendee_count = 0
            attendees = []
            for person in meta.get("attendees", []):
                name = person.get("name", "")
                if name and name != "Haewon Yum":
                    attendees.append(name)
                attendee_count += 1

            # Get snippet for description
            snippets = r.get("snippets", [])
            description = ""
            for s in snippets:
                text_field = s.get("text", {})
                if isinstance(text_field, str):
                    description += text_field + " "
                elif isinstance(text_field, dict):
                    for block in text_field.get("structuredText", {}).get("blocks", []):
                        description += block.get("fullText", "") + " "
                snippet_str = s.get("snippet", "")
                if snippet_str:
                    description += snippet_str + " "
            description = description.strip()[:400]

            organizer = (meta.get("author") or {}).get("name", "")

            events.append({
                "id": event_id,
                "title": title,
                "start": start_str,
                "end": "",
                "attendees": attendees[:5],
                "attendee_count": attendee_count,
                "link": doc.get("url", ""),
                "organizer": organizer,
                "description": description,
                "is_allday": "T00:00:00" in start_str,
            })

        # Sort by start time
        events.sort(key=lambda e: e["start"])
        return events

    def scan_for_meeting_docs(self, months: int = 3) -> list[dict]:
        """Scan calendar event descriptions AND Google Drive for meeting-related docs."""
        import re
        GDOC_RE = re.compile(
            r'https://docs\.google\.com/(?:document|spreadsheets|presentation|forms)/d/[A-Za-z0-9_\-]+[^\s"\'<>]*'
        )
        DRIVE_RE = re.compile(r'https://drive\.google\.com/[^\s"\'<>]+')

        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(days=months * 30)
        found_docs: dict[str, dict] = {}

        # --- Source 1: links embedded in calendar event descriptions ---
        cal_results = self._search("", page_size=200)
        past_event_count = 0
        for r in cal_results:
            doc = r.get("document", {})
            meta = doc.get("metadata", {})
            start_str = meta.get("createTime") or meta.get("updateTime") or ""
            if not start_str:
                continue
            try:
                start_dt = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            except ValueError:
                continue
            if start_dt >= now or start_dt < cutoff:
                continue
            past_event_count += 1
            event_title = doc.get("title", "").strip()
            all_text = ""
            for s in r.get("snippets", []):
                text_field = s.get("text", {})
                if isinstance(text_field, str):
                    all_text += text_field + " "
                elif isinstance(text_field, dict):
                    for block in text_field.get("structuredText", {}).get("blocks", []):
                        all_text += block.get("fullText", "") + " "
                all_text += s.get("snippet", "") + " "
            for url in GDOC_RE.findall(all_text) + DRIVE_RE.findall(all_text):
                url = url.rstrip(".,;)")
                if url not in found_docs:
                    found_docs[url] = {
                        "url": url,
                        "suggested_title": event_title,
                        "event_title": event_title,
                        "event_date": start_dt.strftime("%Y-%m-%d"),
                        "category": "Meeting Agenda",
                    }
        print(f"📅 calendar scan: {len(cal_results)} total, {past_event_count} past events, {len(found_docs)} links found")

        # --- Source 2: Google Drive API (real OAuth-based collector) ---
        try:
            from collectors.drive import DriveCollector
            drive_items = DriveCollector().collect()
            for item in drive_items:
                url = item.get("source_url") or ""
                title = item.get("title", "").strip()
                if not url or not title or url in found_docs:
                    continue
                from main import _guess_doc_category
                category = _guess_doc_category(title)
                found_docs[url] = {
                    "url": url,
                    "suggested_title": title,
                    "event_title": f"Google Drive",
                    "event_date": "",
                    "category": category,
                }
            print(f"📂 drive scan: {len(drive_items)} drive items → {len(found_docs)} total unique docs")
        except Exception as e:
            print(f"⚠️ drive scan skipped: {e}")

        return list(found_docs.values())

    def collect(self) -> list[dict]:
        """Return prep-todo raw items for upcoming meetings."""
        events = self.get_upcoming_events(days=14)
        prep_items = []

        for event in events:
            if event["is_allday"]:
                continue

            try:
                start_dt = datetime.fromisoformat(event["start"].replace("Z", "+00:00"))
            except ValueError:
                continue

            days_until = (start_dt.date() - datetime.now(timezone.utc).date()).days
            flag = "overdue" if days_until < 0 else ("soon" if days_until <= 2 else "this-week")

            prep_items.append({
                "id": f"calendar:prep:{event['id']}",
                "title": f"[Prep] {event['title']}",
                "source": "calendar",
                "source_url": event["link"],
                "last_signal": datetime.now(timezone.utc).isoformat(),
                "signal": "meeting_prep",
                "due_date": start_dt.strftime("%Y-%m-%d"),
                "raw_text": (
                    f"Meeting on {start_dt.strftime('%b %d %H:%M')} — {event['description'][:200]}"
                ).strip(),
                "tags": ["meeting", "prep"],
                "event": event,
            })

        return prep_items
