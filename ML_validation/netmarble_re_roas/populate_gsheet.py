import json
import os
import subprocess
import urllib.request

from google.oauth2.credentials import Credentials
import google.auth.transport.requests

SPREADSHEET_ID = "13lGuup0_BN5h3l5_M7a2pHqA-k3VWuMVW0micst8aV0"
QUOTA_PROJECT = "focal-elf-631"

# Get token
adc_path = os.path.expanduser("~/.config/gcloud/application_default_credentials.json")
with open(adc_path) as f:
    info = json.load(f)

creds = Credentials(
    token=None,
    refresh_token=info["refresh_token"],
    token_uri="https://oauth2.googleapis.com/token",
    client_id=info["client_id"],
    client_secret=info["client_secret"],
)
creds.refresh(google.auth.transport.requests.Request())
TOKEN = creds.token


def sheets_update(range_name, values):
    """Update a range via Sheets API v4."""
    import urllib.parse
    encoded_range = urllib.parse.quote(range_name)
    url = f"https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}/values/{encoded_range}?valueInputOption=USER_ENTERED"
    data = json.dumps({"range": range_name, "majorDimension": "ROWS", "values": values}).encode()
    req = urllib.request.Request(url, data=data, method="PUT", headers={
        "Authorization": f"Bearer {TOKEN}",
        "x-goog-user-project": QUOTA_PROJECT,
        "Content-Type": "application/json",
    })
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    print(f"  Updated {result.get('updatedCells', 0)} cells in {range_name}")


def sheets_batch_format(requests_list):
    """Apply formatting via batchUpdate."""
    url = f"https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}:batchUpdate"
    data = json.dumps({"requests": requests_list}).encode()
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "Authorization": f"Bearer {TOKEN}",
        "x-goog-user-project": QUOTA_PROJECT,
        "Content-Type": "application/json",
    })
    resp = urllib.request.urlopen(req)
    print(f"  Formatted {len(requests_list)} request(s)")


def header_format_request(sheet_id, col_count):
    """Return formatting request for header row."""
    return {
        "repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1, "startColumnIndex": 0, "endColumnIndex": col_count},
            "cell": {
                "userEnteredFormat": {
                    "backgroundColor": {"red": 0.18, "green": 0.33, "blue": 0.59},
                    "textFormat": {"bold": True, "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
                }
            },
            "fields": "userEnteredFormat(backgroundColor,textFormat)",
        }
    }


def freeze_row_request(sheet_id):
    return {
        "updateSheetProperties": {
            "properties": {"sheetId": sheet_id, "gridProperties": {"frozenRowCount": 1}},
            "fields": "gridProperties.frozenRowCount",
        }
    }


# ═══════════════════════════════════════════
# Sheet 1: ML Calibration (sheetId=0)
# ═══════════════════════════════════════════
print("Sheet 1: ML Calibration")
calibration_data = [
    ["data_timestamp", "model_timestamp", "num_examples", "sum_label", "sum_prediction", "calibration"],
    ["2026-02-09", "2026-02-08", 353905, 0.0, 8.13, "null"],
    ["2026-02-08", "2026-02-08", 386341, 0.0, 5.29, "null"],
    ["2026-02-08", "2026-02-07", 386341, 0.0, 4.60, "null"],
    ["2026-02-07", "2026-02-07", 451278, 0.0, 7.02, "null"],
    ["2026-02-07", "2026-02-06", 451278, 0.0, 6.73, "null"],
    ["2026-02-06", "2026-02-06", 807360, 0.0, 12.43, "null"],
    ["2026-02-06", "2026-02-05", 403680, 0.0, 10.95, "null"],
    ["2026-02-05", "2026-02-05", 365524, 0.0, 10.12, "null"],
    ["2026-02-05", "2026-02-04", 365524, 0.0, 14.38, "null"],
]
sheets_update("'ML Calibration'!A1", calibration_data)

# ═══════════════════════════════════════════
# Sheet 2: Revenue Attribution (sheetId=1)
# ═══════════════════════════════════════════
print("Sheet 2: Revenue Attribution")
revenue_data = [
    ["date", "attributed_revenue_usd", "attributed_events", "unattributed_revenue_usd", "unattributed_events", "unattr_pct"],
    ["2026-02-11", 62.94, 30, 4137.57, 1043, "98.5%"],
    ["2026-02-10", 79.20, 32, 3139.37, 821, "97.5%"],
    ["2026-02-09", 108.49, 32, 2425.25, 633, "95.7%"],
    ["2026-02-08", 116.67, 36, 2660.80, 665, "95.8%"],
    ["2026-02-07", 151.20, 60, 2971.48, 746, "95.2%"],
    ["2026-02-06", 204.14, 54, 3318.64, 768, "94.2%"],
    ["2026-02-05", 295.44, 70, 5666.87, 1171, "95.0%"],
    ["2026-02-04", 85.89, 31, 2288.48, 617, "96.4%"],
    ["2026-02-03", 97.09, 31, 2664.92, 687, "96.5%"],
    ["2026-02-02", 177.82, 42, 3758.17, 964, "95.5%"],
    ["2026-02-01", 109.43, 42, 3415.76, 825, "96.9%"],
]
sheets_update("'Revenue Attribution (Bundle)'!A1", revenue_data)

# ═══════════════════════════════════════════
# Sheet 3: Attributed Events (sheetId=2)
# ═══════════════════════════════════════════
print("Sheet 3: Attributed Events")
events_data = [
    ["date", "event_name", "event_count", "total_revenue_usd"],
    ["2026-02-11", "visit_shop", 111, 0], ["2026-02-11", "af_app_opened", 67, 0],
    ["2026-02-11", "login_complete", 54, 0], ["2026-02-11", "reengagement", 14, 0],
    ["2026-02-11", "level_achieved_10", 12, 0], ["2026-02-11", "join_clan", 11, 0],
    ["2026-02-11", "reattribution", 9, 0], ["2026-02-11", "level_achieved_30", 9, 0],
    ["2026-02-11", "login", 5, 0], ["2026-02-11", "funnel_first", 5, 0],
    ["2026-02-11", "funnel_second", 4, 0], ["2026-02-11", "funnel_third", 4, 0],
    ["2026-02-11", "create_nickname", 1, 0],
    ["2026-02-10", "af_app_opened", 395, 0], ["2026-02-10", "visit_shop", 188, 0],
    ["2026-02-10", "login_complete", 179, 0], ["2026-02-10", "reengagement", 132, 0],
    ["2026-02-10", "reattribution", 41, 0], ["2026-02-10", "level_achieved_10", 36, 0],
    ["2026-02-10", "level_achieved_30", 26, 0], ["2026-02-10", "join_clan", 23, 0],
    ["2026-02-10", "login", 18, 0], ["2026-02-10", "funnel_first", 12, 0],
    ["2026-02-10", "funnel_second", 9, 0], ["2026-02-10", "create_nickname", 6, 0],
    ["2026-02-10", "funnel_third", 6, 0], ["2026-02-10", "summon_fighter_level_5", 1, 0],
    ["2026-02-09", "af_app_opened", 529, 0], ["2026-02-09", "login_complete", 222, 0],
    ["2026-02-09", "visit_shop", 187, 0], ["2026-02-09", "reengagement", 172, 0],
    ["2026-02-09", "join_clan", 54, 0], ["2026-02-09", "level_achieved_10", 43, 0],
    ["2026-02-09", "reattribution", 32, 0], ["2026-02-09", "level_achieved_30", 27, 0],
    ["2026-02-09", "login", 7, 0], ["2026-02-09", "funnel_second", 6, 0],
    ["2026-02-09", "funnel_first", 6, 0], ["2026-02-09", "funnel_third", 6, 0],
    ["2026-02-09", "create_nickname", 3, 0],
    ["2026-02-08", "af_app_opened", 1010, 0], ["2026-02-08", "login_complete", 324, 0],
    ["2026-02-08", "visit_shop", 281, 0], ["2026-02-08", "reengagement", 270, 0],
    ["2026-02-08", "join_clan", 87, 0], ["2026-02-08", "reattribution", 58, 0],
    ["2026-02-08", "level_achieved_10", 40, 0], ["2026-02-08", "level_achieved_30", 27, 0],
    ["2026-02-08", "login", 20, 0], ["2026-02-08", "funnel_third", 13, 0],
    ["2026-02-08", "funnel_second", 12, 0], ["2026-02-08", "funnel_first", 11, 0],
    ["2026-02-08", "create_nickname", 6, 0], ["2026-02-08", "summon_fighter_level_5", 3, 0],
    ["2026-02-07", "af_app_opened", 1234, 0], ["2026-02-07", "login_complete", 345, 0],
    ["2026-02-07", "visit_shop", 334, 0], ["2026-02-07", "reengagement", 300, 0],
    ["2026-02-07", "join_clan", 72, 0], ["2026-02-07", "reattribution", 47, 0],
    ["2026-02-07", "level_achieved_10", 45, 0], ["2026-02-07", "level_achieved_30", 30, 0],
    ["2026-02-07", "login", 16, 0], ["2026-02-07", "funnel_first", 15, 0],
    ["2026-02-07", "funnel_second", 13, 0], ["2026-02-07", "funnel_third", 12, 0],
    ["2026-02-07", "create_nickname", 5, 0], ["2026-02-07", "buy_adblock", 1, 0],
    ["2026-02-07", "summon_fighter_level_5", 1, 0], ["2026-02-07", "rejected_install", 1, 0],
    ["2026-02-06", "af_app_opened", 1276, 0], ["2026-02-06", "login_complete", 443, 0],
    ["2026-02-06", "reengagement", 334, 0], ["2026-02-06", "visit_shop", 126, 0],
    ["2026-02-06", "reattribution", 40, 0], ["2026-02-06", "level_achieved_10", 39, 0],
    ["2026-02-06", "level_achieved_30", 28, 0], ["2026-02-06", "login", 12, 0],
    ["2026-02-06", "funnel_first", 10, 0], ["2026-02-06", "join_clan", 9, 0],
    ["2026-02-06", "funnel_second", 4, 0], ["2026-02-06", "funnel_third", 2, 0],
    ["2026-02-06", "create_nickname", 1, 0],
    ["2026-02-05", "af_app_opened", 412, 0], ["2026-02-05", "reengagement", 259, 0],
    ["2026-02-05", "login_complete", 160, 0], ["2026-02-05", "visit_shop", 40, 0],
    ["2026-02-05", "reattribution", 30, 0], ["2026-02-05", "login", 13, 0],
    ["2026-02-05", "level_achieved_10", 6, 0], ["2026-02-05", "level_achieved_30", 5, 0],
    ["2026-02-05", "join_clan", 2, 0], ["2026-02-05", "funnel_first", 1, 0],
]
sheets_update("'Attributed Events (by event)'!A1", events_data)

# ═══════════════════════════════════════════
# Sheet 4: Distinct Users (sheetId=3)
# ═══════════════════════════════════════════
print("Sheet 4: Distinct Users")
users_data = [
    ["date", "event_name", "event_count", "distinct_ifa", "distinct_mtid"],
    ["2026-02-11", "af_app_opened", 67, 31, 31],
    ["2026-02-11", "login_complete", 54, 30, 30],
    ["2026-02-11", "visit_shop", 111, 16, 16],
    ["2026-02-11", "reengagement", 14, 14, 14],
    ["2026-02-11", "level_achieved_10", 12, 12, 12],
    ["2026-02-11", "reattribution", 9, 9, 9],
    ["2026-02-11", "level_achieved_30", 9, 9, 9],
    ["2026-02-11", "login", 5, 5, 5],
    ["2026-02-11", "funnel_second", 4, 4, 4],
    ["2026-02-11", "join_clan", 11, 3, 3],
    ["2026-02-11", "funnel_first", 5, 3, 3],
    ["2026-02-11", "funnel_third", 4, 3, 3],
    ["2026-02-11", "create_nickname", 1, 1, 1],
    ["2026-02-10", "af_app_opened", 395, 183, 183],
    ["2026-02-10", "reengagement", 132, 132, 132],
    ["2026-02-10", "login_complete", 179, 109, 109],
    ["2026-02-10", "reattribution", 41, 41, 41],
    ["2026-02-10", "visit_shop", 188, 26, 26],
    ["2026-02-10", "level_achieved_10", 36, 25, 25],
    ["2026-02-10", "level_achieved_30", 26, 19, 19],
    ["2026-02-10", "login", 18, 18, 18],
    ["2026-02-10", "funnel_second", 9, 7, 7],
    ["2026-02-10", "funnel_first", 12, 7, 7],
    ["2026-02-10", "join_clan", 23, 6, 6],
    ["2026-02-10", "create_nickname", 6, 6, 6],
    ["2026-02-10", "funnel_third", 6, 5, 5],
    ["2026-02-10", "summon_fighter_level_5", 1, 1, 1],
    ["2026-02-09", "af_app_opened", 529, 240, 240],
    ["2026-02-09", "reengagement", 172, 172, 172],
    ["2026-02-09", "login_complete", 222, 114, 114],
    ["2026-02-09", "reattribution", 32, 32, 32],
    ["2026-02-09", "level_achieved_10", 43, 21, 21],
    ["2026-02-09", "visit_shop", 187, 19, 19],
    ["2026-02-09", "level_achieved_30", 27, 12, 12],
    ["2026-02-09", "join_clan", 54, 7, 7],
    ["2026-02-09", "login", 7, 7, 7],
    ["2026-02-09", "funnel_third", 6, 5, 5],
    ["2026-02-09", "funnel_first", 6, 4, 4],
    ["2026-02-09", "funnel_second", 6, 4, 4],
    ["2026-02-09", "create_nickname", 3, 3, 3],
    ["2026-02-08", "af_app_opened", 1010, 358, 358],
    ["2026-02-08", "reengagement", 270, 270, 270],
    ["2026-02-08", "login_complete", 324, 163, 163],
    ["2026-02-08", "reattribution", 58, 58, 58],
    ["2026-02-08", "visit_shop", 281, 27, 27],
    ["2026-02-08", "level_achieved_10", 40, 24, 24],
    ["2026-02-08", "login", 20, 20, 20],
    ["2026-02-08", "level_achieved_30", 27, 15, 15],
    ["2026-02-08", "funnel_third", 13, 9, 9],
    ["2026-02-08", "join_clan", 87, 9, 9],
    ["2026-02-08", "funnel_second", 12, 7, 7],
    ["2026-02-08", "funnel_first", 11, 6, 6],
    ["2026-02-08", "create_nickname", 6, 6, 6],
    ["2026-02-08", "summon_fighter_level_5", 3, 3, 3],
    ["2026-02-07", "af_app_opened", 1234, 401, 400],
    ["2026-02-07", "reengagement", 300, 300, 300],
    ["2026-02-07", "login_complete", 345, 159, 159],
    ["2026-02-07", "reattribution", 47, 47, 47],
    ["2026-02-07", "visit_shop", 334, 34, 34],
    ["2026-02-07", "level_achieved_10", 45, 26, 26],
    ["2026-02-07", "level_achieved_30", 30, 22, 22],
    ["2026-02-07", "login", 16, 16, 16],
    ["2026-02-07", "join_clan", 72, 10, 10],
    ["2026-02-07", "funnel_first", 15, 9, 9],
    ["2026-02-07", "funnel_second", 13, 7, 7],
    ["2026-02-07", "funnel_third", 12, 6, 6],
    ["2026-02-07", "create_nickname", 5, 5, 5],
    ["2026-02-07", "rejected_install", 1, 1, 1],
    ["2026-02-07", "buy_adblock", 1, 1, 1],
    ["2026-02-07", "summon_fighter_level_5", 1, 1, 1],
    ["2026-02-06", "af_app_opened", 1276, 422, 422],
    ["2026-02-06", "reengagement", 334, 334, 334],
    ["2026-02-06", "login_complete", 443, 154, 154],
    ["2026-02-06", "reattribution", 40, 40, 40],
    ["2026-02-06", "visit_shop", 126, 22, 22],
    ["2026-02-06", "level_achieved_10", 39, 20, 20],
    ["2026-02-06", "level_achieved_30", 28, 14, 14],
    ["2026-02-06", "login", 12, 12, 12],
    ["2026-02-06", "funnel_first", 10, 6, 6],
    ["2026-02-06", "funnel_second", 4, 4, 4],
    ["2026-02-06", "join_clan", 9, 3, 3],
    ["2026-02-06", "funnel_third", 2, 2, 2],
    ["2026-02-06", "create_nickname", 1, 1, 1],
    ["2026-02-05", "reengagement", 259, 259, 259],
    ["2026-02-05", "af_app_opened", 412, 169, 169],
    ["2026-02-05", "login_complete", 160, 67, 67],
    ["2026-02-05", "reattribution", 30, 30, 30],
    ["2026-02-05", "login", 13, 13, 13],
    ["2026-02-05", "visit_shop", 40, 7, 7],
    ["2026-02-05", "level_achieved_10", 6, 6, 6],
    ["2026-02-05", "level_achieved_30", 5, 5, 5],
    ["2026-02-05", "funnel_first", 1, 1, 1],
    ["2026-02-05", "join_clan", 2, 1, 1],
]
sheets_update("'Distinct Users (IFA-MTID)'!A1", users_data)

# ═══════════════════════════════════════════
# Apply formatting to all sheets
# ═══════════════════════════════════════════
print("Applying formatting...")
format_requests = [
    header_format_request(0, 6),  # ML Calibration
    freeze_row_request(0),
    header_format_request(1, 6),  # Revenue Attribution
    freeze_row_request(1),
    header_format_request(2, 4),  # Attributed Events
    freeze_row_request(2),
    header_format_request(3, 5),  # Distinct Users
    freeze_row_request(3),
    # Auto-resize columns for all sheets
    {"autoResizeDimensions": {"dimensions": {"sheetId": 0, "dimension": "COLUMNS", "startIndex": 0, "endIndex": 6}}},
    {"autoResizeDimensions": {"dimensions": {"sheetId": 1, "dimension": "COLUMNS", "startIndex": 0, "endIndex": 6}}},
    {"autoResizeDimensions": {"dimensions": {"sheetId": 2, "dimension": "COLUMNS", "startIndex": 0, "endIndex": 4}}},
    {"autoResizeDimensions": {"dimensions": {"sheetId": 3, "dimension": "COLUMNS", "startIndex": 0, "endIndex": 5}}},
]
sheets_batch_format(format_requests)

print(f"\nDone! Spreadsheet URL: https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}")
