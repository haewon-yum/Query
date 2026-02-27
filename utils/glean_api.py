#!/usr/bin/env python3
"""Glean REST API utility for search and chat."""

import os
import json
import subprocess
from dotenv import load_dotenv

load_dotenv()

API_TOKEN = os.getenv("GLEAN_API_TOKEN", "")
BASE_URL = "https://moloco-be.glean.com/rest/api/v1"


def _request(endpoint: str, payload: dict) -> dict:
    result = subprocess.run(
        [
            "curl", "-s", "-X", "POST",
            f"{BASE_URL}/{endpoint}",
            "-H", f"Authorization: Bearer {API_TOKEN}",
            "-H", "Content-Type: application/json",
            "-d", json.dumps(payload),
        ],
        capture_output=True, text=True, timeout=30,
    )
    return json.loads(result.stdout)


def search(query: str, page_size: int = 10) -> dict:
    return _request("search", {"query": query, "pageSize": page_size})


def chat(question: str) -> dict:
    return _request("chat", {
        "messages": [{"fragments": [{"text": question}]}]
    })


def get_document(url: str) -> dict:
    return _request("getdocumentbyurl", {"url": url})


def print_search_results(data: dict):
    results = data.get("results", [])
    if not results:
        print("No results found.")
        return
    for r in results:
        doc = r.get("document", {})
        title = doc.get("title", "Untitled")
        url = doc.get("url", "")
        snippets = r.get("snippets", [])
        print(f"- {title}")
        if url:
            print(f"  {url}")
        if snippets:
            text = snippets[0].get("text", "")
            if text:
                print(f"  {text[:120]}")
        print()


def print_chat_response(data: dict):
    messages = data.get("messages", [])
    for msg in messages:
        for frag in msg.get("fragments", []):
            text = frag.get("text", "")
            if text:
                print(text)


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: glean_api.py <search|chat> <query>")
        print("  glean_api.py search 'how to set up BigQuery'")
        print("  glean_api.py chat 'what is our data retention policy?'")
        sys.exit(1)

    action = sys.argv[1]
    query = " ".join(sys.argv[2:])

    if action == "search":
        print_search_results(search(query))
    elif action == "chat":
        print_chat_response(chat(query))
    else:
        print(f"Unknown action: {action}. Use 'search' or 'chat'.")
