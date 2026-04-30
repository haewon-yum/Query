"""Fetch HTML from a public Google Drive file (no credentials required).
Files must be shared as 'Anyone with the link can view'.
"""
import httpx

_DOWNLOAD_URL = "https://drive.google.com/uc?id={id}&export=download"
_DOCS_EXPORT_URL = "https://docs.google.com/document/d/{id}/export?format=html"
_TIMEOUT = 30


async def fetch_html(file_id: str) -> str:
    async with httpx.AsyncClient(follow_redirects=True, timeout=_TIMEOUT) as client:
        resp = await client.get(_DOWNLOAD_URL.format(id=file_id))
        if resp.status_code == 200 and _looks_like_html(resp.text):
            return resp.text

        # Fall back to Google Docs HTML export
        resp = await client.get(_DOCS_EXPORT_URL.format(id=file_id))
        if resp.status_code == 200:
            return resp.text

    raise ValueError(
        f"Could not fetch file from Google Drive (last status: {resp.status_code}). "
        "Make sure the file is set to 'Anyone with the link can view'."
    )


def _looks_like_html(text: str) -> bool:
    snippet = text.lstrip()[:200].lower()
    return "<!doctype" in snippet or "<html" in snippet
