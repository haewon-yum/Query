"""
Build interactive D3 + D7 ROAS combined HTML report for MapleStory Idle AOS.
Date range: 2026-01-01 → today. Uses Plotly for interactive charts.
"""
from google.cloud import bigquery
import pandas as pd
import plotly.graph_objects as go
import warnings
warnings.filterwarnings('ignore')

client  = bigquery.Client(project='moloco-ods')
BUNDLE  = 'com.nexon.ma'
OS      = 'ANDROID'
START   = '2026-01-01'
D3_TGT  = 25.0
D7_TGT  = 39.0

GEO_COLORS = {
    'KOR': '#4f46e5', 'USA': '#f59e0b',
    'THA': '#10b981', 'TWN': '#ef4444',
    'SGP': '#8b5cf6', 'MYS': '#06b6d4',
}
FOCUS_GEOS = ['KOR', 'USA', 'THA', 'TWN']

# ── Queries ────────────────────────────────────────────────────────────────

Q_OVERALL = f"""
SELECT
  DATE_TRUNC(date_utc, WEEK(MONDAY))                                          AS week_start,
  SUM(gross_spend_usd)                                                         AS spend_usd,
  SUM(installs)                                                                AS installs,
  SAFE_DIVIDE(SUM(revenue_d3), SUM(gross_spend_usd))                          AS d3_roas,
  SAFE_DIVIDE(SUM(revenue_d7), SUM(gross_spend_usd))                          AS d7_roas,
  SAFE_DIVIDE(SUM(capped_revenue_d3), SUM(gross_spend_usd))                   AS d3_croas,
  SAFE_DIVIDE(SUM(capped_revenue_d7), SUM(gross_spend_usd))                   AS d7_croas
FROM `moloco-ae-view.athena.fact_dsp_core`
WHERE product.app_market_bundle = '{BUNDLE}'
  AND campaign.os = '{OS}'
  AND date_utc >= DATE('{START}')
GROUP BY 1 ORDER BY 1
"""

Q_GEO = f"""
WITH base AS (
  SELECT
    DATE_TRUNC(date_utc, WEEK(MONDAY)) AS week_start,
    CASE WHEN campaign.country IN ('KOR','TWN','USA','THA','CAN','SGP','MYS') THEN campaign.country
         ELSE 'Other' END AS geo,
    SUM(revenue_d3)         AS rev_d3,
    SUM(revenue_d7)         AS rev_d7,
    SUM(capped_revenue_d3)  AS cap_rev_d3,
    SUM(capped_revenue_d7)  AS cap_rev_d7,
    SUM(gross_spend_usd)    AS spend_usd
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE product.app_market_bundle = '{BUNDLE}'
    AND campaign.os = '{OS}'
    AND date_utc >= DATE('{START}')
  GROUP BY 1, 2
)
SELECT week_start, geo,
  SAFE_DIVIDE(rev_d3,     spend_usd) AS d3_roas,
  SAFE_DIVIDE(rev_d7,     spend_usd) AS d7_roas,
  SAFE_DIVIDE(cap_rev_d3, spend_usd) AS d3_croas,
  SAFE_DIVIDE(cap_rev_d7, spend_usd) AS d7_croas,
  spend_usd
FROM base ORDER BY 1, 2
"""

print("Running BQ queries...")
df_overall = client.query(Q_OVERALL).result().to_dataframe()
df_geo     = client.query(Q_GEO).result().to_dataframe()
print(f"  Overall: {len(df_overall)} rows | Geo: {len(df_geo)} rows")

df_overall['week_start']    = pd.to_datetime(df_overall['week_start'])
df_overall['d3_pct']        = df_overall['d3_roas']  * 100
df_overall['d7_pct']        = df_overall['d7_roas']  * 100
df_overall['d3_capped_pct'] = df_overall['d3_croas'] * 100
df_overall['d7_capped_pct'] = df_overall['d7_croas'] * 100

df_geo['week_start']    = pd.to_datetime(df_geo['week_start'])
df_geo['d3_pct']        = df_geo['d3_roas']  * 100
df_geo['d7_pct']        = df_geo['d7_roas']  * 100
df_geo['d3_capped_pct'] = df_geo['d3_croas'] * 100
df_geo['d7_capped_pct'] = df_geo['d7_croas'] * 100

# Last week is partial — flag it
df_complete = df_overall.iloc[:-1]
df_partial  = df_overall.iloc[-1:]

# ── Chart builders ─────────────────────────────────────────────────────────

CHART_LAYOUT = dict(
    paper_bgcolor='white',
    plot_bgcolor='#f9fafb',
    font=dict(family='Inter, sans-serif', size=13, color='#1a1d23'),
    margin=dict(l=60, r=30, t=50, b=60),
    legend=dict(bgcolor='rgba(255,255,255,0.9)', bordercolor='#e2e8f0', borderwidth=1),
    xaxis=dict(gridcolor='#e5e7eb', showgrid=False, tickformat='%b %d'),
    yaxis=dict(gridcolor='#e5e7eb', gridwidth=1, ticksuffix='%'),
    hovermode='x unified',
)


def make_overall_chart(metric, target, color, title):
    fig = go.Figure()

    # Shaded area
    fig.add_trace(go.Scatter(
        x=df_complete['week_start'], y=df_complete[metric],
        fill='tozeroy', fillcolor=f'rgba({int(color[1:3],16)},{int(color[3:5],16)},{int(color[5:7],16)},0.08)',
        line=dict(width=0), showlegend=False, hoverinfo='skip'
    ))

    # Main line (complete weeks)
    fig.add_trace(go.Scatter(
        x=df_complete['week_start'], y=df_complete[metric],
        mode='lines+markers',
        line=dict(color=color, width=2.5),
        marker=dict(size=6, color=color),
        name=metric.replace('_pct','').upper() + ' ROAS',
        hovertemplate='%{x|%b %d}: <b>%{y:.1f}%</b><extra></extra>'
    ))

    # Partial week (dashed)
    bridge_x = [df_complete['week_start'].iloc[-1], df_partial['week_start'].iloc[0]]
    bridge_y = [df_complete[metric].iloc[-1], df_partial[metric].iloc[0]]
    fig.add_trace(go.Scatter(
        x=bridge_x, y=bridge_y,
        mode='lines+markers',
        line=dict(color=color, width=1.5, dash='dot'),
        marker=dict(size=5, color=color, symbol='circle-open'),
        name='Partial week',
        hovertemplate='%{x|%b %d}: <b>%{y:.1f}%</b> (partial)<extra></extra>'
    ))

    # Target line
    x_range = [df_overall['week_start'].min(), df_overall['week_start'].max()]
    fig.add_trace(go.Scatter(
        x=x_range, y=[target, target],
        mode='lines',
        line=dict(color='#ef4444', width=1.5, dash='dash'),
        name=f'Target ({target:.0f}%)',
        hoverinfo='skip'
    ))
    fig.add_annotation(
        x=x_range[0], y=target + 1.5,
        text=f'Target {target:.0f}%', showarrow=False,
        font=dict(color='#ef4444', size=11), xanchor='left'
    )

    fig.update_layout(title=dict(text=title, font=dict(size=15, color='#1a1d23')), **CHART_LAYOUT)
    return fig


def make_geo_chart(metric, target, title):
    fig = go.Figure()

    for geo in FOCUS_GEOS:
        sub = df_geo[df_geo['geo'] == geo].copy()
        if sub.empty:
            continue
        fig.add_trace(go.Scatter(
            x=sub['week_start'], y=sub[metric],
            mode='lines+markers',
            line=dict(color=GEO_COLORS.get(geo, '#6b7280'), width=2),
            marker=dict(size=5),
            name=geo,
            hovertemplate=f'{geo} — %{{x|%b %d}}: <b>%{{y:.1f}}%</b><extra></extra>'
        ))

    x_range = [df_overall['week_start'].min(), df_overall['week_start'].max()]
    fig.add_trace(go.Scatter(
        x=x_range, y=[target, target],
        mode='lines',
        line=dict(color='#374151', width=1.2, dash='dash'),
        opacity=0.55,
        name=f'Target ({target:.0f}%)',
        hoverinfo='skip'
    ))

    fig.update_layout(title=dict(text=title, font=dict(size=15, color='#1a1d23')), **CHART_LAYOUT)
    return fig


print("Building charts...")
fig_d3_overall = make_overall_chart(
    'd3_pct', D3_TGT, '#10b981',
    'MapleStory Idle (AOS) — Overall Weekly D3 ROAS'
)
fig_d3_geo = make_geo_chart(
    'd3_pct', D3_TGT,
    'MapleStory Idle (AOS) — Weekly D3 ROAS by Geo'
)
fig_d7_overall = make_overall_chart(
    'd7_pct', D7_TGT, '#4f46e5',
    'MapleStory Idle (AOS) — Overall Weekly D7 ROAS'
)
fig_d7_geo = make_geo_chart(
    'd7_pct', D7_TGT,
    'MapleStory Idle (AOS) — Weekly D7 ROAS by Geo'
)

# cROAS charts (capped at $200/user)
fig_d3_croas_overall = make_overall_chart(
    'd3_capped_pct', D3_TGT, '#10b981',
    'MapleStory Idle (AOS) — Overall Weekly D3 cROAS (Capped)'
)
fig_d3_croas_geo = make_geo_chart(
    'd3_capped_pct', D3_TGT,
    'MapleStory Idle (AOS) — Weekly D3 cROAS by Geo (Capped)'
)
fig_d7_croas_overall = make_overall_chart(
    'd7_capped_pct', D7_TGT, '#4f46e5',
    'MapleStory Idle (AOS) — Overall Weekly D7 cROAS (Capped)'
)
fig_d7_croas_geo = make_geo_chart(
    'd7_capped_pct', D7_TGT,
    'MapleStory Idle (AOS) — Weekly D7 cROAS by Geo (Capped)'
)

# Export as HTML divs (no plotly.js — will load from CDN once in the page)
cfg = dict(responsive=True)
d3_overall_div       = fig_d3_overall.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d3_geo_div           = fig_d3_geo.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d7_overall_div       = fig_d7_overall.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d7_geo_div           = fig_d7_geo.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d3_croas_overall_div = fig_d3_croas_overall.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d3_croas_geo_div     = fig_d3_croas_geo.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d7_croas_overall_div = fig_d7_croas_overall.to_html(full_html=False, include_plotlyjs=False, config=cfg)
d7_croas_geo_div     = fig_d7_croas_geo.to_html(full_html=False, include_plotlyjs=False, config=cfg)

# ── Summary stats for KPI cards ────────────────────────────────────────────
ss_d3 = df_complete['d3_pct'].iloc[-4:].mean()   # last 4 complete weeks
ss_d7 = df_complete['d7_pct'].iloc[-4:].mean()
peak_d3 = df_complete['d3_pct'].max()
peak_d7 = df_complete['d7_pct'].max()

# ── HTML ───────────────────────────────────────────────────────────────────
html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>MapleStory Idle AOS — ROAS Trend (D3 &amp; D7)</title>
<script src="https://cdn.plot.ly/plotly-2.32.0.min.js" charset="utf-8"></script>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"/>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: 'Inter', sans-serif; background: #f8f9fb; color: #1a1d23; line-height: 1.6; }}

  .sidebar {{
    position: fixed; top: 0; left: 0; width: 220px; height: 100vh;
    background: #1e2130; padding: 28px 16px; overflow-y: auto; z-index: 100;
  }}
  .sidebar h2 {{ color: #a5b4fc; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px; }}
  .sidebar .nav-section-label {{
    font-size: 10px; color: #475569; text-transform: uppercase;
    letter-spacing: 0.8px; padding: 4px 10px; margin-top: 14px; display: block;
  }}
  .sidebar a {{
    display: block; color: #cbd5e1; text-decoration: none; font-size: 13px;
    padding: 6px 10px; border-radius: 6px; margin-bottom: 2px; transition: background 0.15s;
  }}
  .sidebar a:hover {{ background: #2d3148; color: #e2e8f0; }}

  .main {{ margin-left: 220px; padding: 36px 40px 60px; max-width: 1120px; }}

  .report-header {{
    background: linear-gradient(135deg, #1e2130 0%, #2d3148 100%);
    color: #f1f5f9; border-radius: 12px; padding: 28px 32px; margin-bottom: 28px;
  }}
  .report-header h1 {{ font-size: 22px; font-weight: 700; margin-bottom: 6px; }}
  .report-header .subtitle {{ color: #94a3b8; font-size: 13px; }}
  .meta-grid {{
    display: grid; grid-template-columns: repeat(auto-fill, minmax(175px, 1fr));
    gap: 10px; margin-top: 18px;
  }}
  .meta-item {{ background: rgba(255,255,255,0.06); border-radius: 8px; padding: 10px 14px; }}
  .meta-item .label {{ font-size: 11px; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; }}
  .meta-item .value {{ font-size: 13px; color: #e2e8f0; font-weight: 500; margin-top: 2px; }}

  .kpi-cards {{ display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 36px; }}
  .kpi-card {{
    background: white; border-radius: 10px; padding: 20px 24px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.07); border-top: 4px solid;
  }}
  .kpi-card.d3 {{ border-color: #10b981; }}
  .kpi-card.d7 {{ border-color: #6366f1; }}
  .kpi-card .kpi-label {{ font-size: 11px; text-transform: uppercase; letter-spacing: 0.8px; color: #6b7280; margin-bottom: 6px; }}
  .kpi-card .kpi-target {{ font-size: 30px; font-weight: 700; }}
  .kpi-card.d3 .kpi-target {{ color: #059669; }}
  .kpi-card.d7 .kpi-target {{ color: #4f46e5; }}
  .kpi-card .kpi-stats {{ font-size: 13px; color: #6b7280; margin-top: 6px; display: flex; gap: 18px; }}
  .kpi-card .kpi-stats span strong {{ color: #ef4444; }}

  .chapter {{ margin: 44px 0 20px; }}
  .chapter-title {{
    font-size: 18px; font-weight: 700; color: #1e2130;
    display: flex; align-items: center; gap: 12px;
    padding-bottom: 10px; border-bottom: 3px solid;
  }}
  .chapter-title.d3 {{ border-color: #10b981; }}
  .chapter-title.d7 {{ border-color: #6366f1; }}
  .chapter-badge {{
    font-size: 12px; font-weight: 600; padding: 3px 10px; border-radius: 20px;
  }}
  .chapter-badge.d3 {{ background: #d1fae5; color: #065f46; }}
  .chapter-badge.d7 {{ background: #eef2ff; color: #3730a3; }}

  .section {{ margin-bottom: 32px; }}
  .section-title {{
    font-size: 14px; font-weight: 600; color: #374151;
    margin-bottom: 12px; padding-bottom: 6px; border-bottom: 1px solid #e5e7eb;
  }}
  .section-title span {{
    font-size: 11px; font-weight: 500; color: #6366f1;
    background: #eef2ff; padding: 2px 7px; border-radius: 4px; margin-left: 8px;
    vertical-align: middle;
  }}

  .chart-card {{
    background: white; border-radius: 10px; padding: 20px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.07); margin-bottom: 14px;
  }}

  .interpretation {{
    border-left: 4px solid; border-radius: 0 8px 8px 0;
    padding: 14px 18px; font-size: 13.5px; line-height: 1.65; margin-bottom: 8px;
  }}
  .interpretation.d3 {{ background: #ecfdf5; border-color: #10b981; color: #064e3b; }}
  .interpretation.d3 strong {{ color: #065f46; }}
  .interpretation.d7 {{ background: #eef2ff; border-color: #6366f1; color: #312e81; }}
  .interpretation.d7 strong {{ color: #4338ca; }}

  .obs-card {{
    background: white; border-radius: 10px; padding: 24px 28px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.07); margin-bottom: 16px;
  }}
  .obs-card h3 {{ font-size: 14px; font-weight: 700; color: #374151; margin-bottom: 12px; padding-bottom: 6px; border-bottom: 1px solid #f3f4f6; }}
  .obs-card ol {{ padding-left: 20px; }}
  .obs-card li {{ font-size: 13.5px; color: #374151; margin-bottom: 10px; line-height: 1.65; }}
  .obs-card li strong {{ color: #1e2130; }}

  .target-badge {{
    display: inline-block; background: #fef2f2; color: #b91c1c;
    border: 1px solid #fecaca; font-size: 12px; font-weight: 600;
    padding: 2px 8px; border-radius: 4px;
  }}
  /* ── cROAS expandable ── */
  .croas-expand {{
    border-radius: 10px; overflow: hidden;
    box-shadow: 0 1px 4px rgba(0,0,0,0.07); margin-bottom: 24px;
  }}
  .croas-expand summary {{
    background: #f1f5f9; padding: 11px 18px; font-size: 13px;
    font-weight: 600; color: #374151; cursor: pointer; user-select: none;
    display: flex; align-items: center; gap: 8px; list-style: none;
  }}
  .croas-expand summary::-webkit-details-marker {{ display: none; }}
  .croas-expand summary::before {{
    content: '▶'; font-size: 10px; color: #9ca3af; transition: transform 0.18s;
    display: inline-block;
  }}
  .croas-expand[open] summary::before {{ transform: rotate(90deg); }}
  .croas-expand .croas-body {{ padding: 16px 0 4px; background: #f8f9fb; }}
  .interpretation.croas {{ background: #fefce8; border-color: #ca8a04; color: #78350f; }}
  .interpretation.croas strong {{ color: #92400e; }}

  .footer {{
    margin-top: 48px; padding-top: 16px;
    border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;
  }}

  /* ── Queries section ── */
  .query-block {{
    background: white; border-radius: 10px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.07); margin-bottom: 20px; overflow: hidden;
  }}
  .query-header {{
    display: flex; align-items: center; justify-content: space-between;
    padding: 14px 20px; background: #1e2130; cursor: pointer;
    user-select: none;
  }}
  .query-header h4 {{ font-size: 13px; font-weight: 600; color: #e2e8f0; margin: 0; }}
  .query-header .query-meta {{ font-size: 11px; color: #64748b; }}
  .query-header .copy-btn {{
    background: #2d3148; color: #a5b4fc; border: 1px solid #3d4468;
    border-radius: 5px; padding: 4px 10px; font-size: 11px; font-family: 'Inter', sans-serif;
    cursor: pointer; transition: background 0.15s; white-space: nowrap;
  }}
  .query-header .copy-btn:hover {{ background: #3d4468; }}
  .query-header .toggle-icon {{ color: #64748b; font-size: 12px; margin-left: 12px; transition: transform 0.2s; }}
  .query-body {{ display: none; }}
  .query-body.open {{ display: block; }}
  pre.sql {{
    margin: 0; padding: 20px 24px; overflow-x: auto;
    font-family: 'Fira Code', 'Fira Mono', 'Cascadia Code', monospace;
    font-size: 12.5px; line-height: 1.7; background: #0f1117; color: #e2e8f0;
    tab-size: 2;
  }}
  /* SQL keyword highlighting via spans */
  .kw  {{ color: #c792ea; font-weight: 600; }}
  .fn  {{ color: #82aaff; }}
  .str {{ color: #c3e88d; }}
  .cmt {{ color: #546e7a; font-style: italic; }}
  .num {{ color: #f78c6c; }}
</style>
</head>
<body>

<nav class="sidebar">
  <h2>MapleStory Idle AOS</h2>
  <a href="#overview">Overview</a>
  <span class="nav-section-label">D3 ROAS · Target 25%</span>
  <a href="#d3-overall">↳ Overall trend</a>
  <a href="#d3-geo">↳ By geo</a>
  <a href="#d3-obs">↳ Observations</a>
  <span class="nav-section-label">D7 ROAS · Target 39%</span>
  <a href="#d7-overall">↳ Overall trend</a>
  <a href="#d7-geo">↳ By geo</a>
  <a href="#d7-obs">↳ Observations</a>
  <span class="nav-section-label">Reference</span>
  <a href="#queries">↳ SQL queries</a>
</nav>

<div class="main">

  <!-- Header -->
  <div class="report-header" id="overview">
    <h1>MapleStory Idle AOS — D3 &amp; D7 ROAS Weekly Trend</h1>
    <div class="subtitle">Nexon · Android · {START} → present</div>
    <div class="meta-grid">
      <div class="meta-item"><div class="label">Bundle</div><div class="value">com.nexon.ma</div></div>
      <div class="meta-item"><div class="label">OS</div><div class="value">Android</div></div>
      <div class="meta-item"><div class="label">Period</div><div class="value">{START} → today</div></div>
      <div class="meta-item"><div class="label">D3 Target</div><div class="value"><span class="target-badge">25%</span></div></div>
      <div class="meta-item"><div class="label">D7 Target</div><div class="value"><span class="target-badge">39%</span></div></div>
      <div class="meta-item"><div class="label">Data source</div><div class="value">fact_dsp_core</div></div>
      <div class="meta-item"><div class="label">Author</div><div class="value">Haewon Yum · KOR GDS</div></div>
      <div class="meta-item"><div class="label">Created</div><div class="value">2026-04-29</div></div>
    </div>
  </div>

  <!-- KPI summary cards -->
  <div class="kpi-cards">
    <div class="kpi-card d3">
      <div class="kpi-label">D3 ROAS — Nexon Target</div>
      <div class="kpi-target">25%</div>
      <div class="kpi-stats">
        <span>Steady state: <strong>~{ss_d3:.0f}%</strong></span>
        <span>Peak: ~{peak_d3:.0f}%</span>
      </div>
    </div>
    <div class="kpi-card d7">
      <div class="kpi-label">D7 ROAS — Nexon Target</div>
      <div class="kpi-target">39%</div>
      <div class="kpi-stats">
        <span>Steady state: <strong>~{ss_d7:.0f}%</strong></span>
        <span>Peak: ~{peak_d7:.0f}%</span>
      </div>
    </div>
  </div>

  <!-- ══════════════════════ D3 ROAS ══════════════════════ -->
  <div class="chapter">
    <div class="chapter-title d3" id="d3-section">
      <span class="chapter-badge d3">D3 ROAS</span>
      Day-3 Return on Ad Spend · Target: 25%
    </div>
  </div>

  <div class="section" id="d3-overall">
    <div class="section-title">Overall Weekly Trend <span>Interactive</span></div>
    <div class="chart-card">{d3_overall_div}</div>
    <div class="interpretation d3">
      💡 <strong>Interpretation:</strong> D3 ROAS has never reached the 25% target since launch. The peak of ~{peak_d3:.0f}% occurred at the Jan 27 launch week, with a brief secondary spike around Feb 24. Since early March, D3 ROAS has settled to a <strong>~{ss_d3:.0f}% steady state</strong> — roughly one-fifth of target — confirming that early payer conversion is structurally low and not recovering as the campaign matures.
    </div>
  </div>

  <div class="section" id="d3-geo">
    <div class="section-title">By Geo <span>Interactive</span></div>
    <div class="chart-card">{d3_geo_div}</div>
    <div class="interpretation d3">
      💡 <strong>Interpretation:</strong> <strong>KOR</strong> opened at ~24% (just below target) at launch before declining rapidly to a 5–10% band, consistent with front-loaded payer exhaustion under rising CPI. <strong>USA</strong> spiked to ~56% the week of Feb 24 — a thin high-LTV cohort, not scalable — then dropped to near zero. <strong>THA</strong> is the most consistent geo (5–13%) with periodic recoveries and low CPI, making it the best candidate for incremental scale. <strong>TWN</strong> shows no meaningful D3 monetization signal across the full period.
    </div>
  </div>

  <details class="croas-expand">
    <summary>cROAS reference — D3 capped ROAS (capped_revenue_d3 / spend)</summary>
    <div class="croas-body">
      <div class="chart-card">{d3_croas_overall_div}</div>
      <div class="interpretation croas">
        💡 <strong>cROAS note:</strong> Capped ROAS applies a $200/user revenue ceiling, removing whale-user outliers. D3 cROAS tracks closely with standard D3 ROAS for this title because D3 payer volumes are thin — a single high-value user can meaningfully skew the uncapped figure. Use cROAS as a sanity check when any geo shows an outsized weekly spike.
      </div>
      <div class="chart-card">{d3_croas_geo_div}</div>
    </div>
  </details>

  <div class="section" id="d3-obs">
    <div class="section-title">Key Observations — D3 ROAS</div>
    <div class="obs-card">
      <h3>Summary vs. 25% D3 ROAS Target</h3>
      <ol>
        <li><strong>Target never reached overall.</strong> The ceiling was ~{peak_d3:.0f}% (Jan 27 and Feb 24) — roughly 8 pp below the 25% target across all geos combined.</li>
        <li><strong>Steady-state D3 ROAS is ~{ss_d3:.0f}% since early March</strong> — one-fifth of target. Early payer conversion is structurally low and declining as the accessible audience narrows.</li>
        <li><strong>KOR briefly approached target at launch</strong> (~24%) before rapid decline — front-loaded payer cohort exhausting under rising CPI (launch ~$17 → now $30+).</li>
        <li><strong>THA is the most consistent geo</strong> for D3 signal (5–13%), with low CPI making it the best candidate for incremental budget allocation without sacrificing efficiency.</li>
        <li><strong>TWN shows no D3 monetization signal</strong> across the full period — spend allocation is not justified by return data.</li>
      </ol>
    </div>
  </div>

  <!-- ══════════════════════ D7 ROAS ══════════════════════ -->
  <div class="chapter">
    <div class="chapter-title d7" id="d7-section">
      <span class="chapter-badge d7">D7 ROAS</span>
      Day-7 Return on Ad Spend · Target: 39%
    </div>
  </div>

  <div class="section" id="d7-overall">
    <div class="section-title">Overall Weekly Trend <span>Interactive</span></div>
    <div class="chart-card">{d7_overall_div}</div>
    <div class="interpretation d7">
      💡 <strong>Interpretation:</strong> D7 ROAS has never reached the 39% target. The launch week (Jan 27) opened at ~{peak_d7:.0f}% — the highest recorded — before declining sharply. Steady state since early March is <strong>~{ss_d7:.0f}%</strong>, roughly one-quarter of target. The D7 shortfall is larger in absolute terms than D3 (target gap ~27 pp vs. ~18 pp), indicating that late-cohort revenue recovery is weak — incremental payer spend from days 4–7 is not compensating for the low D3 payer base.
    </div>
  </div>

  <div class="section" id="d7-geo">
    <div class="section-title">By Geo <span>Interactive</span></div>
    <div class="chart-card">{d7_geo_div}</div>
    <div class="interpretation d7">
      💡 <strong>Interpretation:</strong> No geo sustains target-level D7 ROAS in steady state. <strong>KOR</strong> briefly exceeded target at launch (~43%) before declining to a 10–12% band as CPI rose and audience quality eroded. <strong>USA</strong> hit 79% the week of Feb 24 (same high-LTV batch as D3) then near-zero thereafter. <strong>THA</strong> tracks 5–12% D7 ROAS with more stability; at ~$5.89 CPI it retains the strongest unit economics across all geos. <strong>TWN</strong> sits at near-zero throughout — consistent with its D3 pattern, confirming no payer recovery between day 3 and day 7.
    </div>
  </div>

  <details class="croas-expand">
    <summary>cROAS reference — D7 capped ROAS (capped_revenue_d7 / spend)</summary>
    <div class="croas-body">
      <div class="chart-card">{d7_croas_overall_div}</div>
      <div class="interpretation croas">
        💡 <strong>cROAS note:</strong> D7 cROAS removes the influence of any single high-LTV user from the cohort, providing a more conservative efficiency floor. The USA Feb 24 spike (78% uncapped D7 ROAS) will appear materially lower in cROAS — that spike was driven by a small number of high-value installs. If cROAS and standard ROAS diverge sharply in a given week, investigate payer concentration in that cohort.
      </div>
      <div class="chart-card">{d7_croas_geo_div}</div>
    </div>
  </details>

  <div class="section" id="d7-obs">
    <div class="section-title">Key Observations — D7 ROAS</div>
    <div class="obs-card">
      <h3>Summary vs. 39% D7 ROAS Target</h3>
      <ol>
        <li><strong>No geo sustains target-level ROAS.</strong> Jan 27 KOR (~43%) was the only week any geo crossed 39% in meaningful volume. USA's Feb 24 peak (79%) was volume-thin and non-repeatable.</li>
        <li><strong>KOR (72% of spend) runs at ~10–16% D7 ROAS in steady state</strong> — roughly ⅓ of target. CPI rose from ~$17 at launch to $30+ now: classic audience exhaustion in the primary geo.</li>
        <li><strong>USA is the most efficient geo on a full-period basis</strong> (~28% D7 ROAS, ~$15.56 CPI) but is significantly underleveraged (~$44K total vs. ~$997K in KOR).</li>
        <li><strong>THA shows healthy unit economics</strong> (~$5.89 CPI, ~16% D7 ROAS) with more stability than USA. Low scale (~$12K) but the quality signal is real and consistent.</li>
        <li><strong>TWN near-zero ROAS throughout</strong> — ~$153K spend, ~1.4% D7 ROAS. Warrants a formal continuation review before further budget is allocated.</li>
        <li><strong>The most recent week is partial</strong> (D7 cohort not yet matured) — shown as a dotted line; exclude from target-vs-actual comparisons.</li>
      </ol>
    </div>
  </div>

  <!-- ══════════════════════ QUERIES ══════════════════════ -->
  <div class="chapter">
    <div class="chapter-title" style="border-color:#94a3b8" id="queries">
      <span class="chapter-badge" style="background:#f1f5f9;color:#374151">SQL</span>
      Queries — Replication Reference
    </div>
  </div>

  <div class="section">
    <p style="font-size:13.5px;color:#6b7280;margin-bottom:16px;">
      Both queries run against <code>moloco-ae-view.athena.fact_dsp_core</code> on project <code>moloco-ods</code>.
      Click a header to expand, then use <strong>Copy</strong> to grab the SQL.
    </p>

    <!-- Query 1 -->
    <div class="query-block">
      <div class="query-header" onclick="toggleQuery('q1')">
        <div>
          <h4>Query 1 — Overall Weekly D3 &amp; D7 ROAS</h4>
          <div class="query-meta">Returns 1 row per week · aggregates all geos · {len(df_overall)} rows returned</div>
        </div>
        <div style="display:flex;align-items:center;gap:8px;">
          <button class="copy-btn" onclick="event.stopPropagation();copySQL('sql-overall')">Copy</button>
          <span class="toggle-icon" id="icon-q1">▶</span>
        </div>
      </div>
      <div class="query-body" id="q1">
        <pre class="sql" id="sql-overall"><span class="kw">SELECT</span>
  <span class="fn">DATE_TRUNC</span>(date_utc, <span class="fn">WEEK</span>(MONDAY))                                         <span class="kw">AS</span> week_start,
  <span class="fn">SUM</span>(gross_spend_usd)                                                         <span class="kw">AS</span> spend_usd,
  <span class="fn">SUM</span>(installs)                                                                <span class="kw">AS</span> installs,
  <span class="fn">SAFE_DIVIDE</span>(<span class="fn">SUM</span>(revenue_d3),         <span class="fn">SUM</span>(gross_spend_usd))                  <span class="kw">AS</span> d3_roas,
  <span class="fn">SAFE_DIVIDE</span>(<span class="fn">SUM</span>(revenue_d7),         <span class="fn">SUM</span>(gross_spend_usd))                  <span class="kw">AS</span> d7_roas,
  <span class="fn">SAFE_DIVIDE</span>(<span class="fn">SUM</span>(capped_revenue_d3),  <span class="fn">SUM</span>(gross_spend_usd))                  <span class="kw">AS</span> d3_croas,
  <span class="fn">SAFE_DIVIDE</span>(<span class="fn">SUM</span>(capped_revenue_d7),  <span class="fn">SUM</span>(gross_spend_usd))                  <span class="kw">AS</span> d7_croas
<span class="kw">FROM</span> `moloco-ae-view.athena.fact_dsp_core`
<span class="kw">WHERE</span>
  product.app_market_bundle = <span class="str">'{BUNDLE}'</span>
  <span class="kw">AND</span> campaign.os           = <span class="str">'{OS}'</span>
  <span class="kw">AND</span> date_utc              &gt;= <span class="fn">DATE</span>(<span class="str">'{START}'</span>)
<span class="kw">GROUP BY</span> <span class="num">1</span>
<span class="kw">ORDER BY</span> <span class="num">1</span></pre>
      </div>
    </div>

    <!-- Query 2 -->
    <div class="query-block">
      <div class="query-header" onclick="toggleQuery('q2')">
        <div>
          <h4>Query 2 — Weekly D3 &amp; D7 ROAS by Geo</h4>
          <div class="query-meta">Returns 1 row per week × geo · focus geos + Other bucket · {len(df_geo)} rows returned</div>
        </div>
        <div style="display:flex;align-items:center;gap:8px;">
          <button class="copy-btn" onclick="event.stopPropagation();copySQL('sql-geo')">Copy</button>
          <span class="toggle-icon" id="icon-q2">▶</span>
        </div>
      </div>
      <div class="query-body" id="q2">
        <pre class="sql" id="sql-geo"><span class="kw">WITH</span> base <span class="kw">AS</span> (
  <span class="kw">SELECT</span>
    <span class="fn">DATE_TRUNC</span>(date_utc, <span class="fn">WEEK</span>(MONDAY)) <span class="kw">AS</span> week_start,
    <span class="kw">CASE</span>
      <span class="kw">WHEN</span> campaign.country <span class="kw">IN</span> (<span class="str">'KOR'</span>, <span class="str">'TWN'</span>, <span class="str">'USA'</span>, <span class="str">'THA'</span>, <span class="str">'CAN'</span>, <span class="str">'SGP'</span>, <span class="str">'MYS'</span>) <span class="kw">THEN</span> campaign.country
      <span class="kw">ELSE</span> <span class="str">'Other'</span>
    <span class="kw">END</span> <span class="kw">AS</span> geo,
    <span class="fn">SUM</span>(revenue_d3)         <span class="kw">AS</span> rev_d3,
    <span class="fn">SUM</span>(revenue_d7)         <span class="kw">AS</span> rev_d7,
    <span class="fn">SUM</span>(capped_revenue_d3)  <span class="kw">AS</span> cap_rev_d3,
    <span class="fn">SUM</span>(capped_revenue_d7)  <span class="kw">AS</span> cap_rev_d7,
    <span class="fn">SUM</span>(gross_spend_usd)    <span class="kw">AS</span> spend_usd
  <span class="kw">FROM</span> `moloco-ae-view.athena.fact_dsp_core`
  <span class="kw">WHERE</span>
    product.app_market_bundle = <span class="str">'{BUNDLE}'</span>
    <span class="kw">AND</span> campaign.os           = <span class="str">'{OS}'</span>
    <span class="kw">AND</span> date_utc              &gt;= <span class="fn">DATE</span>(<span class="str">'{START}'</span>)
  <span class="kw">GROUP BY</span> <span class="num">1</span>, <span class="num">2</span>
)
<span class="kw">SELECT</span>
  week_start, geo,
  <span class="fn">SAFE_DIVIDE</span>(rev_d3,     spend_usd) <span class="kw">AS</span> d3_roas,
  <span class="fn">SAFE_DIVIDE</span>(rev_d7,     spend_usd) <span class="kw">AS</span> d7_roas,
  <span class="fn">SAFE_DIVIDE</span>(cap_rev_d3, spend_usd) <span class="kw">AS</span> d3_croas,
  <span class="fn">SAFE_DIVIDE</span>(cap_rev_d7, spend_usd) <span class="kw">AS</span> d7_croas,
  spend_usd
<span class="kw">FROM</span> base
<span class="kw">ORDER BY</span> <span class="num">1</span>, <span class="num">2</span></pre>
      </div>
    </div>
  </div>

  <div class="footer">
    Generated 2026-04-29 · Period: {START} → present · Source: <code>moloco-ae-view.athena.fact_dsp_core</code>
  </div>

</div>

<script>
function toggleQuery(id) {{
  const body = document.getElementById(id);
  const icon = document.getElementById('icon-' + id);
  const isOpen = body.classList.contains('open');
  body.classList.toggle('open', !isOpen);
  icon.textContent = isOpen ? '▶' : '▼';
  icon.style.transform = isOpen ? '' : 'rotate(0deg)';
}}

function copySQL(id) {{
  const pre = document.getElementById(id);
  const text = pre.innerText;
  navigator.clipboard.writeText(text).then(() => {{
    const btn = event.target;
    const orig = btn.textContent;
    btn.textContent = 'Copied!';
    btn.style.background = '#1a3a2a';
    btn.style.color = '#34d399';
    setTimeout(() => {{ btn.textContent = orig; btn.style.background = ''; btn.style.color = ''; }}, 1800);
  }});
}}
</script>
</body>
</html>"""

out = '/Users/haewon.yum/Documents/Queries/premium_support/nexon/2604_android_perf/2604_maple_idle_aos_roas_trend.html'
with open(out, 'w') as f:
    f.write(html)

print(f"\n✅ Written: {out}")
print(f"   Size: {len(html):,} bytes")
print(f"\n   D3 steady-state: {ss_d3:.1f}%  peak: {peak_d3:.1f}%")
print(f"   D7 steady-state: {ss_d7:.1f}%  peak: {peak_d7:.1f}%")
