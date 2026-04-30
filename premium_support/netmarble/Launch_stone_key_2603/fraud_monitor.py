#!/usr/bin/env python3
"""
Fraud Monitoring — Publisher-Level Install Analysis
Runs BQ queries and writes results to a Google Sheet.

Usage:
  python fraud_monitor.py --bundle com.netmarble.stonkey --os ANDROID --country KOR
  python fraud_monitor.py --bundle com.netmarble.stonkey --os ANDROID --country KOR --campaign EQCWerD5mEThZO4P --lookback 14

n8n cron (Execute Command node):
  cd ~/Documents/Queries/premium_support/netmarble/Lunchsupport && python3 fraud_monitor.py --bundle com.netmarble.stonkey --os ANDROID --country KOR
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import urllib.parse
import urllib.request

import google.auth.transport.requests
import pandas as pd
from google.cloud import bigquery
from google.oauth2.credentials import Credentials

QUOTA_PROJECT = "focal-elf-631"


def get_bq_client():
    return bigquery.Client(project='moloco-ods')


def get_auth_token():
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
    return creds.token


def _sheets_request(method, url, body=None, token=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "x-goog-user-project": QUOTA_PROJECT,
        "Content-Type": "application/json",
    })
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read())


def run_query(client, query, label=''):
    try:
        df = client.query(query).result().to_dataframe()
        print(f'  ✅ {label}: {len(df)} rows')
        return df
    except Exception as e:
        print(f'  ❌ {label}: {e}')
        return None


def df_to_sheet_values(df):
    """Convert DataFrame to list-of-lists for gspread, handling special types."""
    header = df.columns.tolist()
    rows = []
    for _, row in df.iterrows():
        r = []
        for v in row:
            if v is None or (hasattr(v, '__class__') and v.__class__.__name__ == 'NaTType'):
                r.append('')
            elif hasattr(v, 'isoformat'):
                r.append(str(v))
            else:
                try:
                    r.append(float(v) if v == v else '')
                except (TypeError, ValueError):
                    r.append(str(v))
        rows.append(r)
    return [header] + rows


def query_daily_publisher(bq, args):
    campaign_filter = f"AND campaign_id = '{args.campaign}'" if args.campaign else ''
    q = f"""
    SELECT
      date_utc,
      publisher.app_market_bundle AS publisher_bundle,
      SUM(installs) AS installs,
      SUM(installs_rejected) AS installs_rejected,
      ROUND(SUM(gross_spend_usd), 2) AS spend_usd,
      ROUND(SAFE_DIVIDE(SUM(gross_spend_usd), NULLIF(SUM(installs), 0)), 2) AS cpi,
      SUM(impressions) AS impressions,
      SUM(clicks) AS clicks,
      ROUND(SAFE_DIVIDE(SUM(retained_users_d1), NULLIF(SUM(installs), 0)) * 100, 1) AS retention_d1_pct,
      ROUND(SAFE_DIVIDE(SUM(retained_users_d3), NULLIF(SUM(installs), 0)) * 100, 1) AS retention_d3_pct,
      ROUND(SAFE_DIVIDE(SUM(clicks), NULLIF(SUM(impressions), 0)) * 100, 2) AS ctr_pct,
      ROUND(SAFE_DIVIDE(SUM(installs), NULLIF(SUM(clicks), 0)) * 100, 2) AS cvr_pct
    FROM `moloco-ae-view.athena.fact_dsp_publisher`
    WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL {args.lookback} DAY) AND CURRENT_DATE()
      AND advertiser.mmp_bundle_id = '{args.bundle}'
      AND campaign.country = '{args.country}'
      AND campaign.os = '{args.os}'
      {campaign_filter}
    GROUP BY 1, 2
    HAVING installs > 0
    ORDER BY date_utc DESC, installs DESC
    """
    df = run_query(bq, q, 'Daily Publisher Summary')
    if df is not None and not df.empty:
        for col in ['installs', 'installs_rejected', 'spend_usd', 'cpi', 'impressions',
                     'clicks', 'retention_d1_pct', 'retention_d3_pct', 'ctr_pct', 'cvr_pct']:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
    return df


def query_hourly_installs(bq, args):
    campaign_filter = f"AND api.campaign.id = '{args.campaign}'" if args.campaign else ''
    q = f"""
    SELECT
      TIMESTAMP_TRUNC(timestamp, HOUR) AS hour_ts,
      req.app.bundle AS publisher_bundle,
      COUNT(*) AS installs
    FROM `focal-elf-631.prod_stream_view.cv`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      AND UPPER(cv.event) = 'INSTALL'
      AND api.product.app.tracking_bundle = '{args.bundle}'
      AND req.device.geo.country = '{args.country}'
      AND req.device.os = '{args.os}'
      {campaign_filter}
    GROUP BY 1, 2
    ORDER BY 1 ASC, 3 DESC
    """
    return run_query(bq, q, 'Hourly Install Trend (24h)')


def query_retention_by_publisher(bq, args):
    campaign_filter = f"AND campaign_id = '{args.campaign}'" if args.campaign else ''
    q = f"""
    SELECT
      publisher.app_market_bundle AS publisher_bundle,
      SUM(installs) AS installs,
      ROUND(SUM(gross_spend_usd), 2) AS spend_usd,
      ROUND(SAFE_DIVIDE(SUM(gross_spend_usd), NULLIF(SUM(installs), 0)), 2) AS cpi,
      ROUND(SUM(retained_users_d1), 1) AS retained_d1,
      ROUND(SUM(retained_users_d3), 1) AS retained_d3,
      ROUND(SAFE_DIVIDE(SUM(retained_users_d1), NULLIF(SUM(installs), 0)) * 100, 1) AS retention_d1_pct,
      ROUND(SAFE_DIVIDE(SUM(retained_users_d3), NULLIF(SUM(installs), 0)) * 100, 1) AS retention_d3_pct
    FROM `moloco-ae-view.athena.fact_dsp_publisher`
    WHERE date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL {args.lookback} DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND advertiser.mmp_bundle_id = '{args.bundle}'
      AND campaign.country = '{args.country}'
      AND campaign.os = '{args.os}'
      {campaign_filter}
    GROUP BY 1
    HAVING installs >= 5
    ORDER BY installs DESC
    """
    return run_query(bq, q, 'D1/D3 Retention by Publisher')


def compute_flags(df_ret, df_hourly):
    """Flag suspicious publishers."""
    flags = []
    if df_ret is not None and not df_ret.empty:
        for col in df_ret.columns:
            if col != 'publisher_bundle':
                df_ret[col] = pd.to_numeric(df_ret[col], errors='coerce')

        total_installs = df_ret['installs'].sum()
        overall_d1 = (df_ret['retained_d1'].sum() / total_installs * 100) if total_installs > 0 else 0
        overall_cpi = (df_ret['spend_usd'].sum() / total_installs) if total_installs > 0 else 0

        for _, row in df_ret.iterrows():
            pub = row['publisher_bundle']
            reasons = []
            if row['installs'] >= 10 and row['retention_d1_pct'] < overall_d1 * 0.3:
                reasons.append(f'Very low D1 retention ({row["retention_d1_pct"]:.1f}% vs avg {overall_d1:.1f}%)')
            if row['retention_d1_pct'] == 0 and row['installs'] >= 20:
                reasons.append(f'Zero D1 retention with {row["installs"]:.0f} installs')
            if overall_cpi > 0 and row['cpi'] < overall_cpi * 0.3 and row['installs'] >= 10:
                reasons.append(f'Suspiciously low CPI (${row["cpi"]:.2f} vs avg ${overall_cpi:.2f})')
            if reasons:
                flags.append({
                    'publisher': pub, 'installs': int(row['installs']),
                    'cpi': float(row['cpi']) if row['cpi'] == row['cpi'] else None,
                    'd1_ret': float(row['retention_d1_pct']),
                    'reasons': '; '.join(reasons),
                })

    if df_hourly is not None and not df_hourly.empty:
        pub_hour_agg = df_hourly.groupby('publisher_bundle').agg(
            total=('installs', 'sum'), hours_active=('hour_ts', 'nunique')).reset_index()
        for _, row in pub_hour_agg.iterrows():
            if row['total'] >= 20 and row['hours_active'] <= 2:
                reason = f'Installs concentrated in {row["hours_active"]} hour(s) only'
                existing = next((f for f in flags if f['publisher'] == row['publisher_bundle']), None)
                if existing:
                    existing['reasons'] += f'; {reason}'
                else:
                    flags.append({
                        'publisher': row['publisher_bundle'], 'installs': int(row['total']),
                        'cpi': None, 'd1_ret': None, 'reasons': reason,
                    })
    return flags


def write_to_gsheet(token, args, df_daily, df_hourly, df_ret, flags):
    ts = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
    title = f'[Fraud Monitor] {args.bundle} / {args.os} / {args.country} — {ts}'

    sheet_defs = [
        {"properties": {"title": "Daily Publisher Summary", "sheetId": 0}},
        {"properties": {"title": "Hourly Installs (24h)", "sheetId": 1}},
        {"properties": {"title": "Retention by Publisher", "sheetId": 2}},
        {"properties": {"title": "Suspicious Flags", "sheetId": 3}},
    ]

    result = _sheets_request("POST", "https://sheets.googleapis.com/v4/spreadsheets", {
        "properties": {"title": title},
        "sheets": sheet_defs,
    }, token)
    spreadsheet_id = result["spreadsheetId"]
    url = result["spreadsheetUrl"]
    print(f'\n  📊 Spreadsheet: {url}')

    def _update_range(range_name, values):
        encoded = urllib.parse.quote(range_name)
        _sheets_request(
            "PUT",
            f"https://sheets.googleapis.com/v4/spreadsheets/{spreadsheet_id}/values/{encoded}?valueInputOption=USER_ENTERED",
            {"range": range_name, "majorDimension": "ROWS", "values": values},
            token,
        )

    def _header_format_req(sheet_id, col_count):
        return {
            "repeatCell": {
                "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1,
                          "startColumnIndex": 0, "endColumnIndex": col_count},
                "cell": {"userEnteredFormat": {
                    "backgroundColor": {"red": 0.18, "green": 0.33, "blue": 0.59},
                    "textFormat": {"bold": True, "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
                }},
                "fields": "userEnteredFormat(backgroundColor,textFormat)",
            }
        }

    def _freeze_req(sheet_id):
        return {
            "updateSheetProperties": {
                "properties": {"sheetId": sheet_id, "gridProperties": {"frozenRowCount": 1}},
                "fields": "gridProperties.frozenRowCount",
            }
        }

    # Sheet 1: Daily Publisher Summary
    if df_daily is not None and not df_daily.empty:
        _update_range("'Daily Publisher Summary'!A1", df_to_sheet_values(df_daily))
    else:
        _update_range("'Daily Publisher Summary'!A1", [["No data"]])

    # Sheet 2: Hourly Install Trend (24h)
    if df_hourly is not None and not df_hourly.empty:
        df_h = df_hourly.copy()
        df_h['hour_ts'] = df_h['hour_ts'].astype(str)
        _update_range("'Hourly Installs (24h)'!A1", df_to_sheet_values(df_h))
    else:
        _update_range("'Hourly Installs (24h)'!A1", [["No data"]])

    # Sheet 3: Retention by Publisher
    if df_ret is not None and not df_ret.empty:
        _update_range("'Retention by Publisher'!A1", df_to_sheet_values(df_ret))
    else:
        _update_range("'Retention by Publisher'!A1", [["No data"]])

    # Sheet 4: Flags
    flag_header = ['publisher', 'installs', 'cpi', 'd1_ret', 'reasons']
    flag_rows = [[f['publisher'], f['installs'], f.get('cpi', ''), f.get('d1_ret', ''), f['reasons']] for f in flags]
    _update_range("'Suspicious Flags'!A1", [flag_header] + (flag_rows or [['(none flagged)']]))

    # Apply formatting
    fmt_requests = []
    col_counts = [
        len(df_daily.columns) if df_daily is not None and not df_daily.empty else 1,
        len(df_hourly.columns) if df_hourly is not None and not df_hourly.empty else 1,
        len(df_ret.columns) if df_ret is not None and not df_ret.empty else 1,
        5,
    ]
    for sid in range(4):
        fmt_requests.append(_header_format_req(sid, col_counts[sid]))
        fmt_requests.append(_freeze_req(sid))
        fmt_requests.append({"autoResizeDimensions": {
            "dimensions": {"sheetId": sid, "dimension": "COLUMNS",
                           "startIndex": 0, "endIndex": col_counts[sid]}
        }})

    if flag_rows:
        fmt_requests.append({
            "repeatCell": {
                "range": {"sheetId": 3, "startRowIndex": 1, "endRowIndex": len(flag_rows) + 1,
                          "startColumnIndex": 0, "endColumnIndex": 5},
                "cell": {"userEnteredFormat": {
                    "backgroundColor": {"red": 1, "green": 0.95, "blue": 0.9},
                }},
                "fields": "userEnteredFormat.backgroundColor",
            }
        })

    _sheets_request(
        "POST",
        f"https://sheets.googleapis.com/v4/spreadsheets/{spreadsheet_id}:batchUpdate",
        {"requests": fmt_requests},
        token,
    )

    return url


def main():
    parser = argparse.ArgumentParser(description='Fraud Monitoring — Publisher-Level Analysis')
    parser.add_argument('--bundle', required=True, help='MMP bundle ID (e.g., com.netmarble.stonkey)')
    parser.add_argument('--os', required=True, choices=['ANDROID', 'IOS'], help='OS')
    parser.add_argument('--country', required=True, help='Country code (e.g., KOR)')
    parser.add_argument('--campaign', default='', help='Campaign ID (optional, default: all)')
    parser.add_argument('--lookback', type=int, default=7, help='Lookback days for daily data (default: 7)')
    parser.add_argument('--no-sheet', action='store_true', help='Skip Google Sheets output (dry run)')
    args = parser.parse_args()

    print(f'\n{"=" * 60}')
    print(f'  Fraud Monitor: {args.bundle} / {args.os} / {args.country}')
    print(f'  Campaign: {args.campaign or "(all)"}  |  Lookback: {args.lookback}d')
    print(f'  {datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")}')
    print(f'{"=" * 60}\n')

    bq = get_bq_client()

    df_daily = query_daily_publisher(bq, args)
    df_hourly = query_hourly_installs(bq, args)
    df_ret = query_retention_by_publisher(bq, args)
    flags = compute_flags(df_ret, df_hourly)

    print(f'\n  🚩 Flags: {len(flags)} publisher(s) flagged')
    for f in flags:
        print(f'    {f["publisher"]}: {f["reasons"]}')

    if not args.no_sheet:
        token = get_auth_token()
        url = write_to_gsheet(token, args, df_daily, df_hourly, df_ret, flags)
        print(f'\n  ✅ Done. Sheet: {url}')
    else:
        print('\n  ✅ Done (dry run, no sheet created)')


if __name__ == '__main__':
    main()
