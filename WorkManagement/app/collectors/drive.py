import os
import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone


CREDENTIALS_PATH = os.path.expanduser("~/.config/mcp-gdrive/credentials.json")
OAUTH_PATH = os.path.expanduser("~/.config/mcp-gdrive/gcp-oauth.keys.json")
DAYS_BACK = 14
MY_EMAIL = "haewon.yum@moloco.com"

SKIP_MIME_TYPES = {
    "application/vnd.google-apps.folder",
    "application/vnd.google-apps.shortcut",
}


class DriveCollector:
    def __init__(self):
        self.token = self._get_token()

    def _get_token(self) -> str:
        """Return a valid access token, refreshing if needed."""
        creds = json.load(open(CREDENTIALS_PATH))

        # Check if token is still valid (with 5-min buffer)
        expiry = creds.get("expiry_date", 0)
        if isinstance(expiry, (int, float)):
            expiry_dt = datetime.fromtimestamp(expiry / 1000, tz=timezone.utc)
            if expiry_dt > datetime.now(timezone.utc) + timedelta(minutes=5):
                return creds["access_token"]

        # Refresh token
        oauth = json.load(open(OAUTH_PATH))
        client = oauth["installed"]
        data = urllib.parse.urlencode({
            "client_id": client["client_id"],
            "client_secret": client["client_secret"],
            "refresh_token": creds["refresh_token"],
            "grant_type": "refresh_token",
        }).encode()
        req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
        resp = json.loads(urllib.request.urlopen(req).read())
        new_token = resp["access_token"]

        # Save refreshed token
        creds["access_token"] = new_token
        creds["expiry_date"] = int((datetime.now(timezone.utc).timestamp() + resp.get("expires_in", 3600)) * 1000)
        with open(CREDENTIALS_PATH, "w") as f:
            json.dump(creds, f)

        return new_token

    def _drive_get(self, path: str) -> dict:
        req = urllib.request.Request(
            f"https://www.googleapis.com/drive/v3/{path}",
            headers={"Authorization": f"Bearer {self.token}"},
        )
        return json.loads(urllib.request.urlopen(req, timeout=20).read())

    def collect_my_activity(self, since: datetime) -> list[dict]:
        """
        Use Drive Activity API to get files I actually interacted with (view, edit, comment)
        since `since`. Much more accurate than viewedByMeTime which has 30min+ lag.
        Falls back to the standard Drive files query if Activity API isn't authorized.
        """
        try:
            return self._activity_api(since)
        except Exception as e:
            if "403" in str(e) or "insufficient" in str(e).lower() or "scope" in str(e).lower():
                print(f"⚠️ Drive Activity API not authorized (need drive.activity.readonly scope) — falling back")
            else:
                print(f"⚠️ Drive Activity API error: {e}")
            return self.collect(since=since)

    def _activity_api(self, since: datetime) -> list[dict]:
        """Query Drive Activity API v2 for recent file interactions."""
        payload = json.dumps({
            "pageSize": 50,
            "filter": f'time >= "{since.strftime("%Y-%m-%dT%H:%M:%SZ")}"',
        }).encode()
        req = urllib.request.Request(
            "https://driveactivity.googleapis.com/v2/activity:query",
            data=payload,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
        )
        resp = json.loads(urllib.request.urlopen(req, timeout=20).read())

        items = []
        seen_ids = set()
        for activity in resp.get("activities", []):
            # Only include activities where Haewon herself was the actor
            actors = activity.get("actors", [])
            is_mine = any(
                a.get("user", {}).get("knownUser", {}).get("isCurrentUser", False)
                for a in actors
            )
            if not is_mine:
                continue

            # Get file targets
            for target in activity.get("targets", []):
                drive_item = target.get("driveItem", {})
                file_id = drive_item.get("name", "").replace("items/", "")
                title = drive_item.get("title", "").strip()
                if not file_id or not title or file_id in seen_ids:
                    continue
                seen_ids.add(file_id)

                # Determine action type
                action_detail = activity.get("primaryActionDetail", {})
                if "edit" in action_detail:
                    signal = "edited"
                elif "view" in action_detail:
                    signal = "viewed"
                elif "comment" in action_detail:
                    signal = "commented"
                elif "create" in action_detail:
                    signal = "created"
                else:
                    signal = "activity"

                # Get timestamp
                ts = activity.get("timestamp") or (activity.get("timeRange") or {}).get("endTime", "")

                items.append({
                    "id": f"gdrive:{file_id}",
                    "title": title,
                    "source": "gdrive",
                    "source_url": f"https://drive.google.com/open?id={file_id}",
                    "file_id": file_id,
                    "mime_type": "",
                    "last_signal": ts,
                    "signal": signal,
                    "shared_by": "",
                    "unresolved_comments": 0,
                    "my_mentions_in_comments": 0,
                })
        return items

    def collect(self, since=None) -> list[dict]:
        raw_items = []
        if since:
            cutoff = since.strftime("%Y-%m-%dT%H:%M:%S")
        else:
            cutoff = (datetime.now(timezone.utc) - timedelta(days=DAYS_BACK)).strftime("%Y-%m-%dT%H:%M:%S")

        seen_ids = set()

        # 1. Files I've recently modified (in-progress work)
        my_files = self._list_files(
            query=f"modifiedTime > '{cutoff}' and 'me' in owners and trashed = false",
            label="modified_by_me",
        )
        for f in my_files:
            seen_ids.add(f["file_id"])
        raw_items.extend(my_files)

        # 2. Files shared with me that I haven't created (pending review / action needed)
        shared_files = self._list_files(
            query=f"modifiedTime > '{cutoff}' and 'me' in readers and not 'me' in owners and trashed = false",
            label="shared_with_me",
        )
        for f in shared_files:
            if f["file_id"] not in seen_ids:
                seen_ids.add(f["file_id"])
                raw_items.append(f)

        # 3. Files I've recently viewed (opened but not necessarily edited)
        viewed_files = self._list_files(
            query=f"viewedByMeTime > '{cutoff}' and trashed = false",
            label="viewed_by_me",
        )
        for f in viewed_files:
            if f["file_id"] not in seen_ids:
                seen_ids.add(f["file_id"])
                raw_items.append(f)

        # 4. For docs/sheets/slides with comments, check for unresolved comments directed at me
        raw_items = self._enrich_with_comments(raw_items)

        return raw_items

    def _list_files(self, query: str, label: str) -> list[dict]:
        fields = "files(id,name,mimeType,modifiedTime,viewedByMeTime,webViewLink,owners,sharingUser)"
        encoded_q = urllib.parse.quote(query)
        data = self._drive_get(
            f"files?orderBy=modifiedTime+desc&pageSize=20&fields={fields}&q={encoded_q}"
        )
        results = []
        for f in data.get("files", []):
            if f.get("mimeType") in SKIP_MIME_TYPES:
                continue
            results.append({
                "id": f"gdrive:{f['id']}",
                "title": f["name"],
                "source": "gdrive",
                "source_url": f.get("webViewLink"),
                "file_id": f["id"],
                "mime_type": f.get("mimeType", ""),
                "last_signal": f.get("viewedByMeTime") or f.get("modifiedTime"),
                "signal": label,
                "shared_by": (f.get("sharingUser") or {}).get("displayName", ""),
            })
        return results

    def _enrich_with_comments(self, items: list[dict]) -> list[dict]:
        """Add comment_count and has_my_mention flags for docs/sheets."""
        doc_mime_types = {
            "application/vnd.google-apps.document",
            "application/vnd.google-apps.spreadsheet",
            "application/vnd.google-apps.presentation",
        }
        for item in items:
            if item.get("mime_type") not in doc_mime_types:
                continue
            try:
                file_id = item["file_id"]
                comments_data = self._drive_get(
                    f"files/{file_id}/comments?fields=comments(id,resolved,content,author,mentions)&pageSize=20"
                )
                comments = comments_data.get("comments", [])
                unresolved = [c for c in comments if not c.get("resolved")]
                # Check if any unresolved comment mentions me or I'm the only one who hasn't replied
                my_mentions = [
                    c for c in unresolved
                    if MY_EMAIL in c.get("content", "") or
                    any(MY_EMAIL in str(m) for m in c.get("mentions", []))
                ]
                item["unresolved_comments"] = len(unresolved)
                item["my_mentions_in_comments"] = len(my_mentions)
            except Exception:
                item["unresolved_comments"] = 0
                item["my_mentions_in_comments"] = 0
        return items

    def to_raw_items(self) -> list[dict]:
        return self.collect()
