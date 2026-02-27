#!/usr/bin/env python3
"""Convert a Markdown file to a Google Doc, preserving basic formatting."""

import sys
import os
import re
import pickle
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = [
    "https://www.googleapis.com/auth/documents",
    "https://www.googleapis.com/auth/drive.file",
]
CREDENTIALS_FILE = os.path.expanduser("~/.cursor/client_secret_haewon_cursor_mcp.json")
TOKEN_FILE = os.path.expanduser("~/.cursor/gdoc_token.pickle")


def get_credentials():
    creds = None
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, "rb") as f:
            creds = pickle.load(f)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(TOKEN_FILE, "wb") as f:
            pickle.dump(creds, f)
    return creds


def parse_markdown(md_text):
    """Parse markdown into a list of block dicts for Google Docs insertion."""
    blocks = []
    lines = md_text.split("\n")
    i = 0
    in_code_block = False
    code_lines = []

    while i < len(lines):
        line = lines[i]

        if line.startswith("```") and not in_code_block:
            in_code_block = True
            code_lines = []
            i += 1
            continue

        if line.startswith("```") and in_code_block:
            in_code_block = False
            blocks.append({"type": "code", "text": "\n".join(code_lines)})
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        if line.startswith("---"):
            blocks.append({"type": "hr"})
            i += 1
            continue

        if line.startswith("# "):
            blocks.append({"type": "heading1", "text": line[2:].strip()})
            i += 1
            continue

        if line.startswith("## "):
            blocks.append({"type": "heading2", "text": line[3:].strip()})
            i += 1
            continue

        if line.startswith("### "):
            blocks.append({"type": "heading3", "text": line[4:].strip()})
            i += 1
            continue

        if line.startswith("|") and line.endswith("|"):
            table_lines = []
            while i < len(lines) and lines[i].startswith("|") and lines[i].endswith("|"):
                table_lines.append(lines[i])
                i += 1
            blocks.append({"type": "table", "lines": table_lines})
            continue

        if line.strip() == "":
            i += 1
            continue

        blocks.append({"type": "paragraph", "text": line})
        i += 1

    return blocks


def build_requests(blocks):
    """Convert parsed blocks into Google Docs API batchUpdate requests."""
    requests = []
    idx = 1  # current insertion index in the document

    for block in blocks:
        btype = block["type"]

        if btype == "heading1":
            text = block["text"] + "\n"
            requests.append({"insertText": {"location": {"index": idx}, "text": text}})
            requests.append({
                "updateParagraphStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(text)},
                    "paragraphStyle": {"namedStyleType": "HEADING_1"},
                    "fields": "namedStyleType",
                }
            })
            idx += len(text)

        elif btype == "heading2":
            text = block["text"] + "\n"
            requests.append({"insertText": {"location": {"index": idx}, "text": text}})
            requests.append({
                "updateParagraphStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(text)},
                    "paragraphStyle": {"namedStyleType": "HEADING_2"},
                    "fields": "namedStyleType",
                }
            })
            idx += len(text)

        elif btype == "heading3":
            text = block["text"] + "\n"
            requests.append({"insertText": {"location": {"index": idx}, "text": text}})
            requests.append({
                "updateParagraphStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(text)},
                    "paragraphStyle": {"namedStyleType": "HEADING_3"},
                    "fields": "namedStyleType",
                }
            })
            idx += len(text)

        elif btype == "code":
            text = block["text"] + "\n"
            requests.append({"insertText": {"location": {"index": idx}, "text": text}})
            requests.append({
                "updateParagraphStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(text)},
                    "paragraphStyle": {
                        "namedStyleType": "NORMAL_TEXT",
                        "indentStart": {"magnitude": 36, "unit": "PT"},
                        "shading": {"backgroundColor": {"color": {"rgbColor": {"red": 0.95, "green": 0.95, "blue": 0.95}}}},
                    },
                    "fields": "namedStyleType,indentStart,shading",
                }
            })
            requests.append({
                "updateTextStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(text)},
                    "textStyle": {
                        "weightedFontFamily": {"fontFamily": "Courier New"},
                        "fontSize": {"magnitude": 9, "unit": "PT"},
                    },
                    "fields": "weightedFontFamily,fontSize",
                }
            })
            idx += len(text)

        elif btype == "hr":
            text = "─" * 50 + "\n"
            requests.append({"insertText": {"location": {"index": idx}, "text": text}})
            requests.append({
                "updateTextStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(text)},
                    "textStyle": {
                        "foregroundColor": {"color": {"rgbColor": {"red": 0.7, "green": 0.7, "blue": 0.7}}},
                        "fontSize": {"magnitude": 8, "unit": "PT"},
                    },
                    "fields": "foregroundColor,fontSize",
                }
            })
            idx += len(text)

        elif btype == "table":
            raw_lines = block["lines"]
            header_cells = [c.strip() for c in raw_lines[0].split("|")[1:-1]]
            data_rows = []
            for line in raw_lines[1:]:
                cells = [c.strip() for c in line.split("|")[1:-1]]
                if all(set(c) <= set("- :") for c in cells):
                    continue
                data_rows.append(cells)

            num_cols = len(header_cells)
            num_rows = 1 + len(data_rows)

            requests.append({
                "insertTable": {
                    "rows": num_rows,
                    "columns": num_cols,
                    "location": {"index": idx},
                }
            })
            # Tables are complex; we'll insert a simplified text version instead
            # Remove the insertTable and use text representation
            requests.pop()

            table_text = "\t".join(header_cells) + "\n"
            for row in data_rows:
                table_text += "\t".join(row) + "\n"
            table_text += "\n"

            requests.append({"insertText": {"location": {"index": idx}, "text": table_text}})
            requests.append({
                "updateTextStyle": {
                    "range": {"startIndex": idx, "endIndex": idx + len(table_text)},
                    "textStyle": {
                        "weightedFontFamily": {"fontFamily": "Courier New"},
                        "fontSize": {"magnitude": 9, "unit": "PT"},
                    },
                    "fields": "weightedFontFamily,fontSize",
                }
            })
            idx += len(table_text)

        elif btype == "paragraph":
            raw_text = block["text"]
            # We'll handle bold (**text**) inline
            segments = parse_inline(raw_text)
            full_text = "".join(s["text"] for s in segments) + "\n"
            requests.append({"insertText": {"location": {"index": idx}, "text": full_text}})

            offset = idx
            for seg in segments:
                seg_len = len(seg["text"])
                if seg.get("bold"):
                    requests.append({
                        "updateTextStyle": {
                            "range": {"startIndex": offset, "endIndex": offset + seg_len},
                            "textStyle": {"bold": True},
                            "fields": "bold",
                        }
                    })
                if seg.get("code"):
                    requests.append({
                        "updateTextStyle": {
                            "range": {"startIndex": offset, "endIndex": offset + seg_len},
                            "textStyle": {
                                "weightedFontFamily": {"fontFamily": "Courier New"},
                                "backgroundColor": {"color": {"rgbColor": {"red": 0.93, "green": 0.93, "blue": 0.93}}},
                            },
                            "fields": "weightedFontFamily,backgroundColor",
                        }
                    })
                offset += seg_len
            idx += len(full_text)

    return requests


def parse_inline(text):
    """Parse inline markdown: **bold** and `code`."""
    segments = []
    pattern = re.compile(r"(\*\*(.+?)\*\*|`([^`]+?)`)")
    last_end = 0
    for m in pattern.finditer(text):
        if m.start() > last_end:
            segments.append({"text": text[last_end : m.start()]})
        if m.group(2):
            segments.append({"text": m.group(2), "bold": True})
        elif m.group(3):
            segments.append({"text": m.group(3), "code": True})
        last_end = m.end()
    if last_end < len(text):
        segments.append({"text": text[last_end:]})
    return segments


def main():
    if len(sys.argv) < 2:
        print("Usage: md_to_gdoc.py <markdown_file> [doc_title]")
        sys.exit(1)

    md_path = sys.argv[1]
    doc_title = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(os.path.basename(md_path))[0]

    with open(md_path, "r") as f:
        md_text = f.read()

    creds = get_credentials()
    docs_service = build("docs", "v1", credentials=creds)

    doc = docs_service.documents().create(body={"title": doc_title}).execute()
    doc_id = doc["documentId"]
    print(f"Created doc: https://docs.google.com/document/d/{doc_id}/edit")

    blocks = parse_markdown(md_text)
    requests = build_requests(blocks)

    if requests:
        docs_service.documents().batchUpdate(
            documentId=doc_id, body={"requests": requests}
        ).execute()

    print(f"Done! {len(blocks)} blocks written.")


if __name__ == "__main__":
    main()
