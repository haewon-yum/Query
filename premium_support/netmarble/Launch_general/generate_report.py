#!/usr/bin/env python3
"""
Netmarble CPI Campaign — Install-to-Login Analysis
Standalone HTML report generator with interpretations.
Run: python generate_report.py
Output: 260420_cpi_install_to_login_report.html
"""

from google.cloud import bigquery
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.io as pio
from datetime import date, timedelta
import pathlib, sys

# ─── CONFIG ───────────────────────────────────────────────────────────────────

OUT_DIR = pathlib.Path(__file__).parent
OUT_HTML = OUT_DIR / "260420_cpi_install_to_login_report.html"

client = bigquery.Client(project="moloco-ods")

ANALYSIS_DATE     = str(date.today())
LOGIN_WINDOW_DAYS = 1

LAUNCH_WINDOWS = {
    "com.netmarble.sololv":      ("2024-05-03", "2024-06-03"),  # Solo Leveling: Arise (Android)
    "1662742277":                ("2024-05-03", "2024-06-03"),  # Solo Leveling: Arise (iOS)
    "com.netmarble.nanarise":    ("2024-08-13", "2024-09-13"),  # Seven Deadly Sins: IDLE (Android)
    "6469305531":                ("2024-08-13", "2024-09-13"),  # Seven Deadly Sins: IDLE (iOS)
    "com.kabam.knights.legends": ("2024-11-14", "2024-12-14"),  # King Arthur: Legends Rise (Android)
    "com.netmarble.got":         ("2025-05-20", "2025-06-20"),  # Game of Thrones: Kingsroad (Android)
    "6499177365":                ("2025-09-04", "2025-10-04"),  # THE KING OF FIGHTERS AFK (iOS)
    "com.netmarble.tskgb":       ("2025-09-12", "2025-10-12"),  # 세븐나이츠 리버스 (Android)
    "6479595079":                ("2025-09-12", "2025-10-12"),  # 세븐나이츠 리버스 (iOS)
}

LOGIN_EVENTS = {
    "com.netmarble.sololv":      "login",
    "id1662742277":              "login",
    "com.netmarble.nanarise":    "login",
    "id6469305531":              "login",
    "com.kabam.knights.legends": "login",
    "com.netmarble.got":         "login",
    "com.netmarble.tskgb":       "login_1st",
    "id6479595079":              "login_1st",
    "id6499177365":              "login_complete",
}

PARTITION_START = min(s for s, _ in LAUNCH_WINDOWS.values())
PARTITION_END   = str(max(date.fromisoformat(e) for _, e in LAUNCH_WINDOWS.values())
                      + timedelta(days=1))

STORE_IDS   = list(LAUNCH_WINDOWS.keys())
PB_BUNDLES  = [f"id{b}" if b.isdigit() else b for b in STORE_IDS]

LOGIN_EVENT_NAMES = list(set(e.lower() for e in LOGIN_EVENTS.values()))

def _sql_list(items): return "('" + "', '".join(items) + "')"

STORE_IDS_SQL      = _sql_list(STORE_IDS)
BUNDLE_IDS_SQL     = _sql_list(PB_BUNDLES)
LOGIN_EVENTS_SQL   = _sql_list(LOGIN_EVENT_NAMES)

# ─── QUERY HELPERS ────────────────────────────────────────────────────────────

def run_query(sql, label):
    print(f"  ▶ {label} …", flush=True)
    df = client.query(sql).result().to_dataframe()
    for col in df.select_dtypes("object").columns:
        df[col] = pd.to_numeric(df[col], errors="ignore")
    print(f"    ✓ {len(df)} rows", flush=True)
    return df

# ─── SECTION 0 ────────────────────────────────────────────────────────────────

def query_section0():
    clauses = " OR\n    ".join(
        f"(product.app_market_bundle = '{b}' AND date_utc BETWEEN '{s}' AND '{e}')"
        for b, (s, e) in LAUNCH_WINDOWS.items()
    )
    sql = f"""
WITH daily AS (
  SELECT
    product.app_name                                             AS app_name,
    product.app_market_bundle                                    AS bundle_id,
    campaign.os                                                  AS os,
    campaign.country                                             AS country,
    campaign_id,
    date_utc, gross_spend_usd, installs
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN '{PARTITION_START}' AND '{PARTITION_END}'
    AND LOWER(advertiser.title) LIKE '%netmarble%'
    AND campaign.goal = 'OPTIMIZE_CPI_FOR_APP_UA'
    AND ({clauses})
),
agg AS (
  SELECT
    app_name, bundle_id, os, country, campaign_id,
    SUM(gross_spend_usd)                                          AS total_spend_usd,
    SUM(installs)                                                 AS total_installs,
    SAFE_DIVIDE(SUM(gross_spend_usd), NULLIF(SUM(installs), 0))  AS cpi_usd,
    MIN(date_utc) AS first_date, MAX(date_utc) AS last_date
  FROM daily GROUP BY 1,2,3,4,5
)
SELECT * FROM agg WHERE total_installs > 0
ORDER BY app_name, os, total_installs DESC
"""
    return run_query(sql, "Section 0 — CPI campaign discovery")

# ─── SECTION 2 ────────────────────────────────────────────────────────────────

def query_section2(campaign_ids_sql, store_ids_sql):
    cv_clauses = " OR\n    ".join(
        f"(api.product.app.store_id = '{b}' AND DATE(cv.install_at_pb) BETWEEN '{s}' AND '{e}')"
        for b, (s, e) in LAUNCH_WINDOWS.items()
    )
    sql = f"""
WITH events AS (
  SELECT
    api.product.app.store_id  AS store_id,
    req.device.os             AS os,
    req.device.geo.country    AS country,
    bid.mtid                  AS mtid,
    cv.event_pb               AS event_name,
    cv.install_at_pb          AS install_at,
    timestamp                 AS event_ts
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE DATE(timestamp) BETWEEN '{PARTITION_START}' AND '{PARTITION_END}'
    AND api.product.app.store_id IN {store_ids_sql}
    AND api.campaign.id IN {campaign_ids_sql}
    AND ({cv_clauses})
    AND (cv.event_pb = 'install' OR LOWER(cv.event_pb) IN {LOGIN_EVENTS_SQL})
),
per_user AS (
  SELECT
    store_id, os, country, mtid,
    MAX(CASE WHEN event_name = 'install' THEN 1 ELSE 0 END)  AS has_install,
    MIN(CASE WHEN event_name = 'install' THEN install_at END) AS install_at,
    MAX(CASE WHEN LOWER(event_name) IN {LOGIN_EVENTS_SQL}
              AND TIMESTAMP_DIFF(event_ts, install_at, HOUR) BETWEEN 0 AND 24
             THEN 1 ELSE 0 END)                               AS has_d1_login
  FROM events GROUP BY 1,2,3,4
)
SELECT
  store_id, os, country,
  COUNT(DISTINCT CASE WHEN has_install=1 THEN mtid END)                        AS installs,
  COUNT(DISTINCT CASE WHEN has_install=1 AND has_d1_login=1 THEN mtid END)     AS d1_logins,
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN has_install=1 AND has_d1_login=1 THEN mtid END),
    COUNT(DISTINCT CASE WHEN has_install=1 THEN mtid END)), 4)                 AS install_to_login_rate
FROM per_user WHERE has_install=1
GROUP BY 1,2,3
HAVING COUNT(DISTINCT CASE WHEN has_install=1 THEN mtid END) >= 50 OR country='KOR'
ORDER BY store_id, installs DESC
"""
    return run_query(sql, "Section 2 — attributed install-to-login (CPI only)")

# ─── SECTION 3 ────────────────────────────────────────────────────────────────

def query_section3():
    pb_map   = {(f"id{b}" if b.isdigit() else b): (s, e) for b, (s, e) in LAUNCH_WINDOWS.items()}
    clauses  = " OR\n    ".join(
        f"(app.bundle = '{b}' AND DATE(event.install_at) BETWEEN '{s}' AND '{e}')"
        for b, (s, e) in pb_map.items()
    )
    sql = f"""
WITH events AS (
  SELECT
    app.bundle      AS bundle,
    device.os       AS os,
    device.country  AS country,
    device.idfa     AS idfa,
    event.name      AS event_name,
    event.install_at AS install_at,
    timestamp        AS event_ts
  FROM `focal-elf-631.df_accesslog.pb`
  WHERE DATE(timestamp) BETWEEN '{PARTITION_START}' AND '{PARTITION_END}'
    AND app.bundle IN {BUNDLE_IDS_SQL}
    AND attribution.attributed = FALSE
    AND ({clauses})
    AND (LOWER(event.name) = 'install' OR LOWER(event.name) IN {LOGIN_EVENTS_SQL})
    AND device.idfa IS NOT NULL AND device.idfa != ''
    AND MOD(ABS(FARM_FINGERPRINT(device.idfa)), 10) = 0
),
per_device AS (
  SELECT
    bundle, os, country, idfa,
    MAX(CASE WHEN LOWER(event_name)='install' THEN 1 ELSE 0 END)  AS has_install,
    MIN(CASE WHEN LOWER(event_name)='install' THEN install_at END) AS install_at,
    MAX(CASE WHEN LOWER(event_name) IN {LOGIN_EVENTS_SQL}
              AND TIMESTAMP_DIFF(event_ts, install_at, HOUR) BETWEEN 0 AND 24
             THEN 1 ELSE 0 END)                                    AS has_d1_login
  FROM events GROUP BY 1,2,3,4
)
SELECT
  bundle, os, country,
  COUNT(DISTINCT CASE WHEN has_install=1 THEN idfa END)                    AS installs_sampled,
  COUNT(DISTINCT CASE WHEN has_install=1 AND has_d1_login=1 THEN idfa END) AS d1_logins_sampled,
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN has_install=1 AND has_d1_login=1 THEN idfa END),
    COUNT(DISTINCT CASE WHEN has_install=1 THEN idfa END)), 4)             AS install_to_login_rate
FROM per_device WHERE has_install=1
GROUP BY 1,2,3
HAVING COUNT(DISTINCT CASE WHEN has_install=1 THEN idfa END) >= 5 OR country='KOR'
ORDER BY bundle, installs_sampled DESC
"""
    return run_query(sql, "Section 3 — unattributed baseline (df_accesslog.pb, 10% sample)")

# ─── CHART BUILDERS ───────────────────────────────────────────────────────────

COLORS = {"attr": "#4C78A8", "attr_kor": "#DC143C",
          "unattr": "#AEC7E8", "unattr_kor": "#FF7F7F"}

def _chart_html(fig):
    return pio.to_html(fig, include_plotlyjs=False, full_html=False, config={"responsive": True})

def chart_i2l_rate(grp, title_str):
    grp = grp.sort_values("install_to_login_pct", ascending=False)
    fig = go.Figure(go.Bar(
        x=grp["country"], y=grp["install_to_login_pct"],
        marker_color=[COLORS["attr_kor"] if c == "KOR" else COLORS["attr"] for c in grp["country"]],
        text=grp["install_to_login_pct"].apply(lambda v: f"{v:.1f}%"),
        textposition="outside",
    ))
    fig.update_layout(
        title=f"{title_str}<br><sup>Attributed D{LOGIN_WINDOW_DAYS} Install-to-Login Rate — CPI campaigns only</sup>",
        xaxis_title="Country", yaxis_title="Install-to-Login Rate (%)",
        height=380, template="plotly_white", margin=dict(t=80),
    )
    return _chart_html(fig)

def chart_implied_cpa(grp, title_str):
    grp = grp.sort_values("install_to_login_pct", ascending=False)
    fig = go.Figure(go.Bar(
        x=grp["country"], y=grp["implied_login_cpa_usd"],
        marker_color=[COLORS["attr_kor"] if c == "KOR" else COLORS["attr"] for c in grp["country"]],
        text=grp["implied_login_cpa_usd"].apply(lambda v: f"${v:.2f}" if pd.notna(v) else "N/A"),
        textposition="outside",
    ))
    fig.update_layout(
        title=f"{title_str}<br><sup>Implied Login CPA = CPI ÷ Install-to-Login Rate</sup>",
        xaxis_title="Country", yaxis_title="Implied Login CPA (USD)",
        height=380, template="plotly_white", margin=dict(t=80),
    )
    return _chart_html(fig)

def chart_comparison(grp, title_str, has_unattr):
    grp = grp.sort_values("i2l_pct_attr", ascending=False)
    fig = go.Figure()
    fig.add_trace(go.Bar(
        name=f"Moloco CPI (D{LOGIN_WINDOW_DAYS})",
        x=grp["country"], y=grp["i2l_pct_attr"],
        marker_color=[COLORS["attr_kor"] if c == "KOR" else COLORS["attr"] for c in grp["country"]],
        text=grp["i2l_pct_attr"].apply(lambda v: f"{v:.1f}%"),
        textposition="outside",
    ))
    if has_unattr:
        fig.add_trace(go.Bar(
            name="Non-Moloco Baseline (10% sample)",
            x=grp["country"], y=grp["i2l_pct_unattr"],
            marker_color=[COLORS["unattr_kor"] if c == "KOR" else COLORS["unattr"] for c in grp["country"]],
            text=grp["i2l_pct_unattr"].apply(lambda v: f"{v:.1f}%" if pd.notna(v) else "N/A"),
            textposition="outside",
        ))
    fig.update_layout(
        title=f"{title_str}<br><sup>Attributed (CPI) vs Non-Moloco Baseline</sup>",
        barmode="group", xaxis_title="Country", yaxis_title="Install-to-Login Rate (%)",
        height=400, template="plotly_white", margin=dict(t=80),
        legend=dict(orientation="h", y=-0.25),
    )
    return _chart_html(fig)

# ─── INTERPRETATION ENGINE ────────────────────────────────────────────────────

def _pct(v):  return f"{v:.1f}%"
def _usd(v):  return f"${v:.2f}"

def interpret_title(title_name, store_id, os_val, grp):
    lines = []
    kor   = grp[grp["country"] == "KOR"]
    other = grp[grp["country"] != "KOR"]

    if kor.empty:
        lines.append(f"No KOR install volume found for {title_name} ({os_val}) during the launch window.")
        return " ".join(lines)

    kor_rate     = float(kor["install_to_login_pct"].iloc[0])
    kor_installs = int(kor["installs"].iloc[0])
    kor_cpi      = kor["cpi_usd"].iloc[0]
    kor_cpa      = kor["implied_login_cpa_usd"].iloc[0]

    if len(other) >= 2:
        other_avg = float(other["install_to_login_pct"].mean())
        diff      = kor_rate - other_avg
        direction = "higher than" if diff > 3 else ("in line with" if abs(diff) <= 3 else "lower than")
        lines.append(
            f"KOR install-to-login rate: <strong>{_pct(kor_rate)}</strong> "
            f"({kor_installs:,} CPI installs), {direction} the {_pct(other_avg)} average across "
            f"{len(other)} other countries."
        )
    else:
        lines.append(
            f"KOR install-to-login rate: <strong>{_pct(kor_rate)}</strong> "
            f"({kor_installs:,} CPI installs)."
        )

    if pd.notna(kor_cpi) and pd.notna(kor_cpa):
        if len(other) >= 2:
            other_cpas = other["implied_login_cpa_usd"].dropna()
            other_cpa_avg = float(other_cpas.mean()) if len(other_cpas) > 0 else None
            if other_cpa_avg:
                ratio = kor_cpa / other_cpa_avg
                verdict = ("competitive" if ratio < 1.5 else
                           "moderately premium" if ratio < 2.5 else "premium")
                lines.append(
                    f"At a KOR CPI of {_usd(float(kor_cpi))}, the implied login CPA is "
                    f"<strong>{_usd(float(kor_cpa))}</strong> — {verdict} relative to the "
                    f"{_usd(other_cpa_avg)} average for other markets."
                )
            else:
                lines.append(
                    f"At a KOR CPI of {_usd(float(kor_cpi))}, implied login CPA: "
                    f"<strong>{_usd(float(kor_cpa))}</strong>."
                )
        else:
            lines.append(
                f"At a KOR CPI of {_usd(float(kor_cpi))}, implied login CPA: "
                f"<strong>{_usd(float(kor_cpa))}</strong>."
            )
    else:
        lines.append("CPI data not available for KOR in this title — implied login CPA cannot be computed.")

    # Attributed vs unattributed commentary
    kor_unattr = kor["i2l_pct_unattr"].iloc[0] if "i2l_pct_unattr" in grp.columns else np.nan
    if pd.notna(kor_unattr):
        gap = abs(kor_rate - float(kor_unattr))
        if gap <= 5:
            verdict = "closely aligned with"
        elif kor_rate > float(kor_unattr):
            verdict = "slightly above"
        else:
            verdict = "slightly below"
        lines.append(
            f"The attributed CPI rate ({_pct(kor_rate)}) is {verdict} the non-Moloco baseline "
            f"({_pct(float(kor_unattr))}), confirming that CPI-acquired users convert to login "
            f"at rates consistent with the general install population."
        )
    else:
        lines.append(
            "Non-Moloco baseline not available for this title/launch window "
            "(historical postback data outside retention window)."
        )

    return " ".join(lines)

def build_exec_summary(df4, titles):
    kor_rows = df4[df4["country"] == "KOR"].copy()
    kor_rows["i2l_pct_attr"] = pd.to_numeric(kor_rows["i2l_pct_attr"], errors="coerce")
    kor_rows = kor_rows.dropna(subset=["i2l_pct_attr"])
    if kor_rows.empty:
        return "KOR data not available in the current scope."

    avg_kor   = float(kor_rows["i2l_pct_attr"].mean())
    best_row  = kor_rows.loc[kor_rows["i2l_pct_attr"].idxmax()]
    n_titles  = kor_rows["store_id"].nunique()
    kor_with_cpa = kor_rows.dropna(subset=["implied_login_cpa_usd"])

    parts = [
        f"Across <strong>{n_titles} Netmarble title{'s' if n_titles > 1 else ''}</strong> "
        f"that ran CPI campaigns in KOR during their launch phase, the D{LOGIN_WINDOW_DAYS} "
        f"install-to-login rate averaged <strong>{_pct(avg_kor)}</strong>. "
    ]
    parts.append(
        f"The strongest KOR result was <strong>{titles.get(best_row['store_id'], best_row['store_id'])}</strong> "
        f"({best_row['os']}) at {_pct(float(best_row['i2l_pct_attr']))}. "
    )
    if not kor_with_cpa.empty:
        avg_cpa = float(kor_with_cpa["implied_login_cpa_usd"].mean())
        min_cpa = float(kor_with_cpa["implied_login_cpa_usd"].min())
        parts.append(
            f"Implied login CPA across KOR CPI campaigns ranged from "
            f"<strong>{_usd(min_cpa)}</strong> to "
            f"{_usd(float(kor_with_cpa['implied_login_cpa_usd'].max()))}, "
            f"averaging {_usd(avg_cpa)}. "
        )
    parts.append(
        "These figures support the hypothesis that CPI campaigns in KOR achieve "
        "install-to-login conversion rates high enough to yield competitive login CPAs — "
        "making CPI a viable complement to CPA (login) campaigns for KOR launch phases."
    )
    return "".join(parts)

# ─── HTML TEMPLATE ────────────────────────────────────────────────────────────

CSS = """
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       background: #f8f9fa; color: #212529; margin: 0; padding: 0; }
.header { background: #1a1a2e; color: #fff; padding: 40px 60px 32px; }
.header h1 { margin: 0 0 6px; font-size: 1.9rem; font-weight: 700; }
.header .sub { color: #adb5bd; font-size: .95rem; margin: 0; }
.container { max-width: 1100px; margin: 0 auto; padding: 32px 24px; }
.exec-box { background: #fff; border-left: 5px solid #DC143C; border-radius: 6px;
            padding: 20px 24px; margin: 0 0 32px; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
.exec-box h2 { margin: 0 0 10px; font-size: 1.1rem; color: #DC143C; text-transform: uppercase;
               letter-spacing: .05em; }
.exec-box p  { margin: 0; line-height: 1.7; }
.title-section { background: #fff; border-radius: 8px; padding: 24px 28px;
                 margin-bottom: 28px; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
.title-section h2 { margin: 0 0 4px; font-size: 1.25rem; font-weight: 700; }
.title-section .meta { color: #6c757d; font-size: .85rem; margin: 0 0 18px; }
.interp { background: #f1f3f5; border-radius: 6px; padding: 14px 18px;
          margin: 16px 0 0; font-size: .92rem; line-height: 1.75; color: #343a40; }
.interp::before { content: '💡 '; }
.chart-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 16px; }
.chart-full { margin-top: 16px; }
.scope-table { width: 100%; border-collapse: collapse; font-size: .88rem; margin-top: 16px; }
.scope-table th { background: #343a40; color: #fff; padding: 8px 12px; text-align: left; }
.scope-table td { padding: 7px 12px; border-bottom: 1px solid #dee2e6; }
.scope-table tr:hover td { background: #f8f9fa; }
.kor-row td { background: #fff5f5 !important; font-weight: 600; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: .78rem;
         font-weight: 600; }
.badge-and { background: #d3f9d8; color: #2f9e44; }
.badge-ios { background: #d0ebff; color: #1864ab; }
.footer { text-align: center; color: #adb5bd; font-size: .8rem; padding: 32px;
          border-top: 1px solid #dee2e6; margin-top: 24px; }
h3 { font-size: 1rem; color: #495057; margin: 20px 0 8px; }
"""

def scope_table_html(df0, titles):
    rows = ""
    summary = (
        df0.groupby(["bundle_id", "app_name", "os"], as_index=False)
        .agg(spend=("total_spend_usd", "sum"),
             installs=("total_installs", "sum"),
             cpi=("cpi_usd", "mean"))
        .sort_values("installs", ascending=False)
    )
    for _, r in summary.iterrows():
        badge = "badge-ios" if r["os"] == "IOS" else "badge-and"
        os_label = r["os"].title()
        launch_s, launch_e = LAUNCH_WINDOWS.get(r["bundle_id"], ("—", "—"))
        rows += (
            f"<tr><td>{r['app_name']}</td>"
            f"<td><code>{r['bundle_id']}</code></td>"
            f"<td><span class='badge {badge}'>{os_label}</span></td>"
            f"<td>{launch_s} → {launch_e}</td>"
            f"<td>${float(r['spend']):,.0f}</td>"
            f"<td>{int(r['installs']):,}</td>"
            f"<td>${float(r['cpi']):.2f}</td></tr>"
        )
    return f"""
<table class='scope-table'>
  <thead><tr>
    <th>Title</th><th>Bundle</th><th>OS</th><th>Launch Window</th>
    <th>CPI Spend</th><th>CPI Installs</th><th>Avg CPI</th>
  </tr></thead>
  <tbody>{rows}</tbody>
</table>"""

def title_section_html(store_id, os_val, app_name, chart_i2l, chart_cpa, chart_cmp, interp_text, has_unattr):
    badge = "badge-ios" if os_val == "IOS" else "badge-and"
    cmp_label = "Attributed vs Baseline" if has_unattr else "Attributed Rate"
    return f"""
<div class='title-section'>
  <h2>{app_name}</h2>
  <p class='meta'><code>{store_id}</code> &nbsp;|&nbsp;
     <span class='badge {badge}'>{os_val.title()}</span> &nbsp;|&nbsp;
     Launch window: {LAUNCH_WINDOWS.get(store_id, ('—','—'))[0]} →
                   {LAUNCH_WINDOWS.get(store_id, ('—','—'))[1]}</p>
  <div class='chart-row'>
    <div>{chart_i2l}</div>
    <div>{chart_cpa}</div>
  </div>
  <div class='chart-full'>
    <h3>{cmp_label}</h3>
    {chart_cmp}
  </div>
  <div class='interp'>{interp_text}</div>
</div>"""

def build_html(exec_summary, scope_html, sections_html):
    plotlyjs = '<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>'
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Netmarble CPI — Install-to-Login Analysis</title>
{plotlyjs}
<style>{CSS}</style>
</head>
<body>
<div class='header'>
  <h1>CPI Campaign Efficiency — Install-to-Login Analysis</h1>
  <p class='sub'>Netmarble &nbsp;|&nbsp; 24-Month Launch Phase (May 2024 – Oct 2025) &nbsp;|&nbsp;
     D{LOGIN_WINDOW_DAYS} Login Window &nbsp;|&nbsp; Generated {ANALYSIS_DATE}</p>
</div>
<div class='container'>

  <div class='exec-box'>
    <h2>Executive Summary</h2>
    <p>{exec_summary}</p>
  </div>

  <div class='title-section'>
    <h2>Campaign Scope — Section 0</h2>
    <p class='meta'>CPI campaigns (<code>OPTIMIZE_CPI_FOR_APP_UA</code>) during each title's launch month.
    Source: <code>moloco-ae-view.athena.fact_dsp_core</code></p>
    {scope_html}
  </div>

  {sections_html}

</div>
<div class='footer'>
  Analysis by Haewon Yum · KOR GDS · Moloco &nbsp;|&nbsp; {ANALYSIS_DATE}<br>
  CPI source: fact_dsp_core &nbsp;·&nbsp; Attributed rate: prod_stream_view.cv (CPI campaigns only)
  &nbsp;·&nbsp; Baseline: df_accesslog.pb (10% device sample, non-Moloco attributed)
</div>
</body>
</html>"""

# ─── MAIN ─────────────────────────────────────────────────────────────────────

def main():
    print("=== Netmarble CPI Install-to-Login Report Generator ===\n")

    print("[1/3] Running BQ queries …")
    df0 = query_section0()

    # Build derived filters from Section 0
    campaign_ids    = [c for c in df0["campaign_id"].unique() if c]
    bundle_ids      = df0["bundle_id"].unique().tolist()
    campaign_ids_sql = _sql_list(campaign_ids)
    store_ids_sql    = _sql_list(bundle_ids)

    df2 = query_section2(campaign_ids_sql, store_ids_sql)
    df3 = query_section3()

    print("\n[2/3] Processing data …")

    # Numeric coercions
    for col in ["install_to_login_rate"]:
        df2[col] = pd.to_numeric(df2[col], errors="coerce")

    # CPI lookup from Section 0
    cpi_lookup = (
        df0.assign(store_id=df0["bundle_id"])
        .groupby(["store_id", "os", "country"], as_index=False)
        .agg(cpi_usd=("cpi_usd", "mean"))
    )
    df2e = df2.merge(cpi_lookup, on=["store_id", "os", "country"], how="left")
    df2e["cpi_usd"]               = pd.to_numeric(df2e["cpi_usd"], errors="coerce")
    df2e["install_to_login_pct"]  = (df2e["install_to_login_rate"] * 100).round(1)
    df2e["implied_login_cpa_usd"] = (df2e["cpi_usd"] / df2e["install_to_login_rate"]).round(2)

    # Unattributed — normalize bundle → store_id
    df3b = df3.copy()
    df3b["store_id"] = df3b["bundle"].str.replace(r"^id(\d+)$", r"\1", regex=True)
    df3b["install_to_login_rate"] = pd.to_numeric(df3b["install_to_login_rate"], errors="coerce")

    df4 = df2e.merge(
        df3b[["store_id", "os", "country", "installs_sampled",
              "d1_logins_sampled", "install_to_login_rate"]],
        on=["store_id", "os", "country"],
        suffixes=("_attr", "_unattr"),
        how="left",
    )
    df4["i2l_pct_attr"]   = pd.to_numeric(df4["install_to_login_rate_attr"],   errors="coerce") * 100
    df4["i2l_pct_attr"]   = df4["i2l_pct_attr"].round(1)
    df4["i2l_pct_unattr"] = pd.to_numeric(df4["install_to_login_rate_unattr"], errors="coerce") * 100
    df4["i2l_pct_unattr"] = df4["i2l_pct_unattr"].round(1)

    # Title name lookup
    titles = {
        row["bundle_id"]: row["app_name"]
        for _, row in df0[["bundle_id", "app_name"]].drop_duplicates().iterrows()
    }

    print("[3/3] Generating HTML …")

    exec_summary = build_exec_summary(df4, titles)
    scope_html   = scope_table_html(df0, titles)

    sections = []
    for (store_id, os_val), grp in df4.groupby(["store_id", "os"]):
        grp         = grp.copy()
        app_name    = titles.get(store_id, store_id)
        title_str   = f"{app_name} ({store_id})"
        has_unattr  = grp["i2l_pct_unattr"].notna().any()

        c_i2l = chart_i2l_rate(grp, title_str)
        c_cpa = chart_implied_cpa(grp, title_str)
        c_cmp = chart_comparison(grp, title_str, has_unattr)
        interp = interpret_title(app_name, store_id, os_val, grp)

        sections.append(
            title_section_html(store_id, os_val, app_name, c_i2l, c_cpa, c_cmp, interp, has_unattr)
        )

    html = build_html(exec_summary, scope_html, "\n".join(sections))
    OUT_HTML.write_text(html, encoding="utf-8")

    size_kb = OUT_HTML.stat().st_size // 1024
    print(f"\n✅ Report saved: {OUT_HTML}  ({size_kb} KB)")
    print("   Open in any browser — all Plotly charts are interactive.")

if __name__ == "__main__":
    main()
