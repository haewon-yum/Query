import os
import requests
from requests.auth import HTTPBasicAuth
from datetime import datetime, timezone


class JiraCollector:
    def __init__(self):
        self.base_url = os.environ["JIRA_URL"]
        self.username = os.environ["JIRA_USERNAME"]
        self.auth = HTTPBasicAuth(self.username, os.environ["JIRA_API_TOKEN"])
        self.projects = [p.strip() for p in os.environ.get("JIRA_PROJECTS", "ODSB").split(",")]
        self.headers = {"Accept": "application/json"}

    def _search(self, jql: str, fields: list[str]) -> list[dict]:
        url = f"{self.base_url}/rest/api/3/search/jql"
        results = []
        next_page_token = None
        max_results = 50
        while True:
            body = {"jql": jql, "fields": fields, "maxResults": max_results}
            if next_page_token:
                body["nextPageToken"] = next_page_token
            resp = requests.post(
                url,
                auth=self.auth,
                headers={**self.headers, "Content-Type": "application/json"},
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
            issues = data.get("issues", [])
            results.extend(issues)
            if data.get("isLast") or not issues:
                break
            next_page_token = data.get("nextPageToken")
            if not next_page_token:
                break
        return results

    def collect_my_activity(self, since) -> list[dict]:
        """
        Return only tickets where *I* did something (assigned, commented, or made any update)
        within the given time window. Uses updatedBy JQL — Jira Cloud records any change
        (comment, status, field edit) as an update by that user.
        """
        projects_jql = " OR ".join(f"project = {p}" for p in self.projects)
        fields = ["summary", "status", "priority", "assignee", "duedate", "updated", "comment", "labels"]
        since_str = since.strftime("%Y-%m-%d %H:%M")

        seen_keys = set()
        raw_items = []

        # updatedBy catches: comments, status changes, field edits — any action by me
        issues = self._search(
            f'({projects_jql}) AND updatedBy = "{self.username}" AND updated >= "{since_str}" ORDER BY updated DESC',
            fields,
        )
        for issue in issues:
            if issue["key"] not in seen_keys:
                seen_keys.add(issue["key"])
                raw_items.append(self._to_raw(issue, signal="my_activity"))

        return raw_items

    def collect(self, since=None) -> list[dict]:
        projects_jql = " OR ".join(f"project = {p}" for p in self.projects)
        fields = ["summary", "status", "priority", "assignee", "duedate", "updated", "comment", "watches", "labels"]

        # Add incremental filter if since is provided
        since_clause = ""
        if since:
            since_str = since.strftime("%Y-%m-%d %H:%M")
            since_clause = f' AND updated >= "{since_str}"'

        raw_items = []

        # 1. Assigned + open (my primary work)
        assigned = self._search(
            f'({projects_jql}) AND assignee = "{self.username}" AND resolution = Unresolved{since_clause} ORDER BY updated DESC',
            fields,
        )
        for issue in assigned:
            raw_items.append(self._to_raw(issue, signal="assigned"))

        # 2. Watching but not assigned (delegated / tracking)
        watching = self._search(
            f'({projects_jql}) AND watcher = "{self.username}" AND assignee != "{self.username}" AND resolution = Unresolved{since_clause} ORDER BY updated DESC',
            fields,
        )
        for issue in watching:
            raw_items.append(self._to_raw(issue, signal="watching"))

        return raw_items

    def _to_raw(self, issue: dict, signal: str) -> dict:
        f = issue["fields"]
        key = issue["key"]

        # Extract last comment timestamp as last_signal
        comments = f.get("comment", {}).get("comments", [])
        last_comment_ts = comments[-1]["updated"] if comments else None

        return {
            "id": f"jira:{key}",
            "title": f["summary"],
            "source": "jira",
            "source_url": f"{self.base_url}/browse/{key}",
            "raw_status": f["status"]["name"],
            "raw_priority": (f.get("priority") or {}).get("name", "Medium"),
            "due_date": f.get("duedate"),
            "last_signal": last_comment_ts or f.get("updated"),
            "labels": f.get("labels", []),
            "signal": signal,  # "assigned" or "watching"
        }
