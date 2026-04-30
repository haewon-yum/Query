"""
Dash callbacks — wires filters → BQ queries → plots.
Import order matters: app must be created before this module is imported.
"""

import pandas as pd
import plotly.graph_objects as go
from dash import Input, Output, State, callback, html, dcc, no_update
from dash.exceptions import PreventUpdate

import queries

# ---------------------------------------------------------------------------
# 1. Populate platform dropdown on load
# ---------------------------------------------------------------------------

@callback(
    Output("dd-platform", "options"),
    Input("dd-platform", "id"),  # fires once on mount
)
def populate_platforms(_):
    return queries.load_platforms()


# ---------------------------------------------------------------------------
# 2. Platform → populate all peer filter options
# ---------------------------------------------------------------------------

@callback(
    Output("dd-vertical",    "options"),
    Output("dd-sub-vertical","options"),
    Output("dd-genre",       "options"),
    Input("dd-platform", "value"),
)
def populate_peer_filter_options(platform_id):
    empty = ([], [], [])
    if not platform_id:
        return empty
    opts = queries.load_peer_filter_options(platform_id)
    return opts["vertical"], opts["sub_vertical"], opts["genre"]


# ---------------------------------------------------------------------------
# 2b. Bundle selected → auto-fill vertical / sub-vertical / genre values
# ---------------------------------------------------------------------------

@callback(
    Output("dd-vertical",    "value"),
    Output("dd-sub-vertical","value"),
    Output("dd-genre",       "value"),
    Output("dd-os",          "value"),
    Input("dd-bundle",       "value"),
    Input("dd-advertiser",   "value"),
    State("dd-platform",     "value"),
)
def autofill_taxonomy(bundle, advertiser_id, platform_id):
    if not platform_id:
        return None, None, None, None

    os_val = queries.load_entity_os(platform_id, advertiser_id=advertiser_id, app_market_bundle=bundle)

    if not bundle:
        return None, None, None, os_val

    tax = queries.load_bundle_taxonomy(bundle)
    return tax["vertical"], tax["sub_vertical"], tax["genre"], os_val


# ---------------------------------------------------------------------------
# 3. Cascade: platform → advertiser options
# (note: peer filter options handled in callback 2 above)
# ---------------------------------------------------------------------------

@callback(
    Output("dd-advertiser", "options"),
    Output("dd-advertiser", "disabled"),
    Input("dd-platform", "value"),
)
def populate_advertisers(platform_id):
    if not platform_id:
        return [], True
    return queries.load_advertisers(platform_id), False


# ---------------------------------------------------------------------------
# 3. Cascade: platform + advertiser → bundle options
# ---------------------------------------------------------------------------

@callback(
    Output("dd-bundle", "options"),
    Output("dd-bundle", "disabled"),
    Input("dd-platform", "value"),
    Input("dd-advertiser", "value"),
)
def populate_bundles(platform_id, advertiser_id):
    if not platform_id:
        return [], True
    return queries.load_bundles(platform_id, advertiser_id), False


# ---------------------------------------------------------------------------
# 4. Cascade: bundle → campaign options
# ---------------------------------------------------------------------------

@callback(
    Output("dd-campaign", "options"),
    Output("dd-campaign", "disabled"),
    Input("dd-platform", "value"),
    Input("dd-bundle", "value"),
)
def populate_campaigns(platform_id, bundle):
    if not platform_id or not bundle:
        return [], True
    return queries.load_campaigns(platform_id, bundle), False


# ---------------------------------------------------------------------------
# 5. Run button → fetch scores → store
# ---------------------------------------------------------------------------

@callback(
    Output("store-scores", "data"),
    Output("run-status", "children"),
    Output("btn-run", "disabled"),
    Output("btn-run", "children"),
    Input("btn-run", "n_clicks"),
    State("dd-platform", "value"),
    State("dd-advertiser", "value"),
    State("dd-bundle", "value"),
    State("dd-campaign", "value"),
    State("dd-os", "value"),
    State("dd-vertical", "value"),
    State("dd-sub-vertical", "value"),
    State("dd-genre", "value"),
    prevent_initial_call=True,
)
def fetch_scores(n_clicks, platform_id, advertiser_id, bundle, campaign_id,
                 os, vertical, sub_vertical, genre):
    if not platform_id:
        return no_update, "⚠ Select a platform first.", False, "Run"
    try:
        df = queries.load_scores(
            platform_id=platform_id,
            advertiser_id=advertiser_id,
            app_market_bundle=bundle,
            campaign_id=campaign_id,
            vertical=vertical,
            sub_vertical=sub_vertical,
            genre=genre,
            os=os,
        )
        return df.to_json(date_format="iso", orient="split"), f"✓ {len(df):,} rows loaded.", False, "Run"
    except Exception as e:
        return no_update, f"✗ Query failed: {e}", False, "Run"


# ---------------------------------------------------------------------------
# 6. Peer banner
# ---------------------------------------------------------------------------

@callback(
    Output("peer-banner", "children"),
    Input("store-scores", "data"),
)
def update_peer_banner(data):
    if not data:
        return ""
    df = pd.read_json(data, orient="split")
    if df.empty or "peer_level" not in df.columns:
        return ""

    # Derive peer context from focal rows (they carry the resolved peer level)
    focal_rows = df[df["is_focal"] == True]
    ref_rows = focal_rows if not focal_rows.empty else df
    ref_rows = ref_rows[ref_rows["peer_level"].notna()]

    if ref_rows.empty:
        return html.Div("⚠ No valid peer group found at any taxonomy level.", style=_banner_style("warning"))

    peer_level = ref_rows["peer_level"].iloc[0]
    peer_key   = ref_rows["peer_key"].iloc[0]
    peer_n     = ref_rows["peer_n"].iloc[0]

    if peer_level == "insufficient":
        return html.Div("⚠ Peer group insufficient (< 10 bundles at all taxonomy levels).", style=_banner_style("warning"))

    level_label = {"genre": "genre", "sub_vertical": "sub-vertical", "vertical": "vertical"}.get(peer_level, peer_level)
    return html.Div([
        html.Span(f"Peers: {int(peer_n)} bundles · {level_label}: {peer_key}"),
        html.Span(
            " (auto-resolved from focal bundle's taxonomy)",
            style={"fontWeight": "400", "opacity": "0.75", "marginLeft": "6px", "fontSize": "12px"},
        ),
    ], style=_banner_style("info"))


def _banner_style(kind: str) -> dict:
    colors = {"info": ("#cfe2ff", "#084298"), "warning": ("#fff3cd", "#856404")}
    bg, fg = colors.get(kind, ("#e2e3e5", "#41464b"))
    return {
        "padding": "10px 14px",
        "borderRadius": "6px",
        "background": bg,
        "color": fg,
        "fontSize": "13px",
        "fontWeight": "500",
    }


# ---------------------------------------------------------------------------
# 7. Custom tab buttons → sync hidden dcc.Tabs + style active button
# ---------------------------------------------------------------------------

@callback(
    Output("tabs",       "value"),
    Output("tab-btn-v1", "style"),
    Output("tab-btn-v2", "style"),
    Output("tab-btn-v3", "style"),
    Input("tab-btn-v1",  "n_clicks"),
    Input("tab-btn-v2",  "n_clicks"),
    Input("tab-btn-v3",  "n_clicks"),
    State("tabs",        "value"),
    prevent_initial_call=False,
)
def switch_tab(n1, n2, n3, current_tab):
    from dash import ctx
    from layout import _tab_btn_style
    clicked = ctx.triggered_id
    if clicked == "tab-btn-v2":
        tab = "tab-v2"
    elif clicked == "tab-btn-v3":
        tab = "tab-v3"
    else:
        tab = "tab-v1"
    return tab, _tab_btn_style(tab == "tab-v1"), _tab_btn_style(tab == "tab-v2"), _tab_btn_style(tab == "tab-v3")


# ---------------------------------------------------------------------------
# 8. Tab content router
# ---------------------------------------------------------------------------

@callback(
    Output("tab-content", "children"),
    Input("tabs", "value"),
    Input("store-scores", "data"),
    Input("toggle-view", "value"),
    State("dd-bundle", "value"),
    State("dd-campaign", "value"),
    State("store-selected-pillar", "data"),
)
def render_tab(tab, data, view_mode, focal_bundle, focal_campaign, selected_pillar):
    if not data:
        return html.Div("Configure filters and click Run.", style={"color": "#6c757d"})

    df = pd.read_json(data, orient="split")
    if df.empty:
        return html.Div("No data returned for the selected filters.", style={"color": "#6c757d"})

    if tab == "tab-v1":
        return _view1(df, view_mode)
    if tab == "tab-v2":
        return _view2_layout(df, selected_pillar)
    if tab == "tab-v3":
        return _view3(df, focal_bundle)
    return no_update


# ---------------------------------------------------------------------------
# View 1 — Horizontal pillar box plots (single figure, all pillars + overall)
# ---------------------------------------------------------------------------

def _view1(df: pd.DataFrame, view_mode: str) -> html.Div:
    peer_df  = df[df["is_focal"] == False]
    focal_df = df[df["is_focal"] == True]

    # ── Peer scores (always bundle-level) ─────────────────────────────────────
    peer_pillar = (
        peer_df.groupby(["app_market_bundle", "pillar"])["bundle_check_score"]
        .mean().reset_index().rename(columns={"bundle_check_score": "score"})
    )
    peer_overall_scores = (
        peer_df.drop_duplicates("app_market_bundle")["bundle_overall_score"].dropna()
    )

    # ── Focal: ALWAYS bundle-level for comparison (apples-to-apples) ──────────
    focal_pillar = (
        focal_df.groupby("pillar")["bundle_check_score"]
        .mean().reset_index().rename(columns={"bundle_check_score": "score"})
    )
    focal_overall_score = (
        focal_df["bundle_overall_score"].dropna().iloc[0] if len(focal_df) > 0 else None
    )

    # ── Campaign spread (campaign view only — individual dots + range column) ──
    # Per-campaign pillar scores for secondary chart markers
    camp_pillar_df = None
    # Per-pillar min/max for the table "Campaign Range" column
    camp_range = None
    camp_overall_range = None
    if view_mode == "campaign" and len(focal_df) > 0:
        cp = (
            focal_df.groupby(["campaign_id", "campaign_title", "pillar"])["campaign_check_score"]
            .mean().reset_index()
        )
        if not cp.empty:
            camp_pillar_df = cp
            camp_range = cp.groupby("pillar")["campaign_check_score"].agg(["min", "max"])
        co = focal_df.drop_duplicates("campaign_id")["campaign_overall_score"].dropna()
        if len(co) > 0:
            camp_overall_range = (co.min(), co.max())

    pillars    = sorted(peer_pillar["pillar"].unique())
    all_labels = pillars + ["overall"]
    fig = go.Figure()

    # ── Pillar box plots (peers) + focal dots ─────────────────────────────────
    for i, pillar in enumerate(pillars):
        peer_scores = peer_pillar[peer_pillar["pillar"] == pillar]["score"].dropna()
        fig.add_trace(go.Box(
            x=peer_scores, y=[pillar] * len(peer_scores),
            orientation="h", name="Peers",
            boxpoints="all", jitter=0.4, pointpos=0,
            marker=dict(color="#adb5bd", size=4, opacity=0.55),
            line=dict(color="#6c757d"), fillcolor="rgba(108,117,125,0.12)",
            showlegend=(i == 0),
        ))

        # Campaign spread: small semi-transparent circles (campaign view only)
        if camp_pillar_df is not None:
            c_sub = camp_pillar_df[camp_pillar_df["pillar"] == pillar]
            if not c_sub.empty:
                fig.add_trace(go.Scatter(
                    x=c_sub["campaign_check_score"], y=[pillar] * len(c_sub),
                    mode="markers", name="Campaigns",
                    marker=dict(color="#dc3545", size=8, opacity=0.5, symbol="circle",
                                line=dict(color="white", width=1)),
                    text=c_sub["campaign_title"],
                    hovertemplate="%{text}<br>Campaign score: %{x:.1f}<extra></extra>",
                    showlegend=(i == 0),
                ))

        # Primary focal diamond: bundle score
        f_sub = focal_pillar[focal_pillar["pillar"] == pillar]
        if not f_sub.empty:
            fig.add_trace(go.Scatter(
                x=f_sub["score"], y=[pillar] * len(f_sub),
                mode="markers", name="Focal (bundle)",
                marker=dict(color="#0d6efd", size=14, symbol="diamond",
                            line=dict(color="white", width=1.5)),
                hovertemplate=f"Bundle score: %{{x:.1f}}<extra></extra>",
                showlegend=(i == 0),
            ))

    # ── Overall traces ────────────────────────────────────────────────────────
    fig.add_trace(go.Box(
        x=peer_overall_scores, y=["overall"] * len(peer_overall_scores),
        orientation="h", name="Peers",
        boxpoints="all", jitter=0.4, pointpos=0,
        marker=dict(color="#6ea8fe", size=4, opacity=0.55),
        line=dict(color="#0d6efd"), fillcolor="rgba(13,110,253,0.08)",
        showlegend=False,
    ))
    if camp_overall_range is not None:
        co_min, co_max = camp_overall_range
        # Individual campaign overall scores
        co_vals = focal_df.drop_duplicates("campaign_id")[["campaign_id", "campaign_title", "campaign_overall_score"]].dropna(subset=["campaign_overall_score"])
        fig.add_trace(go.Scatter(
            x=co_vals["campaign_overall_score"], y=["overall"] * len(co_vals),
            mode="markers", name="Campaigns",
            marker=dict(color="#dc3545", size=8, opacity=0.5, symbol="circle",
                        line=dict(color="white", width=1)),
            text=co_vals["campaign_title"],
            hovertemplate="%{text}<br>Campaign score: %{x:.1f}<extra></extra>",
            showlegend=False,
        ))
    if focal_overall_score is not None:
        fig.add_trace(go.Scatter(
            x=[focal_overall_score], y=["overall"],
            mode="markers", name="Focal (bundle)",
            marker=dict(color="#0d6efd", size=16, symbol="diamond",
                        line=dict(color="white", width=2)),
            hovertemplate=f"Bundle score: {focal_overall_score:.1f}<extra></extra>",
            showlegend=False,
        ))

    fig.update_layout(
        xaxis=dict(range=[0, 102], title="Score"),
        yaxis=dict(title="", categoryorder="array", categoryarray=pillars[::-1] + ["overall"]),
        height=max(360, len(all_labels) * 90),
        showlegend=True,
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        margin=dict(l=180, r=20, t=40, b=40),
        hovermode="closest",
        boxmode="overlay",
        shapes=[dict(
            type="line", xref="paper", x0=0, x1=1,
            yref="y", y0=0.5, y1=0.5,
            line=dict(color="#dee2e6", width=1, dash="dot"),
        )],
    )

    headline = _view1_headline(peer_overall_scores, focal_overall_score, peer_pillar, focal_pillar)
    summary  = _view1_summary(peer_pillar, focal_pillar, peer_overall_scores, focal_overall_score,
                               view_mode, camp_range, camp_overall_range)
    return html.Div([headline, dcc.Graph(figure=fig), summary])


# ---------------------------------------------------------------------------
# View 1 — Headline insight card (top)
# ---------------------------------------------------------------------------

def _view1_headline(
    peer_overall: pd.Series,
    focal_overall: float | None,
    peer_pillar: pd.DataFrame,
    focal_pillar: pd.DataFrame,
) -> html.Div:
    if focal_overall is None or peer_overall.empty:
        return html.Div()

    # Overall percentile
    pct = (peer_overall <= focal_overall).mean() * 100
    pct_color = "#198754" if pct >= 50 else "#dc3545"

    # Per-pillar gaps vs peer median
    peer_medians = peer_pillar.groupby("pillar")["score"].median()
    focal_means  = focal_pillar.groupby("pillar")["score"].mean()
    gaps = (focal_means - peer_medians).dropna()

    most_lagged   = gaps.idxmin() if not gaps.empty else None
    most_advanced = gaps.idxmax() if not gaps.empty else None

    lines = [
        html.Div([
            html.Span("Overall Blueprint Score: ", style={"fontWeight": "600"}),
            html.Span(
                f"{pct:.0f}th percentile",
                style={"color": pct_color, "fontWeight": "700", "fontSize": "15px"},
            ),
            html.Span(f" within peer group  (score: {focal_overall:.1f})",
                      style={"color": "#6c757d", "fontSize": "12px"}),
        ], style={"marginBottom": "6px"}),
    ]

    if most_lagged and gaps[most_lagged] < 0:
        lines.append(html.Div([
            html.Span("⚠ Most lagged: ", style={"fontWeight": "600", "color": "#dc3545"}),
            html.Span(most_lagged, style={"fontWeight": "700"}),
            html.Span(f"  (gap vs peer median: {gaps[most_lagged]:+.1f})",
                      style={"color": "#6c757d", "fontSize": "12px"}),
        ], style={"marginBottom": "4px"}))

    if most_advanced and gaps[most_advanced] > 0:
        lines.append(html.Div([
            html.Span("▲ Relative advantage: ", style={"fontWeight": "600", "color": "#198754"}),
            html.Span(most_advanced, style={"fontWeight": "700"}),
            html.Span(f"  (gap vs peer median: {gaps[most_advanced]:+.1f})",
                      style={"color": "#6c757d", "fontSize": "12px"}),
        ]))

    border = pct_color
    return html.Div(lines, style={
        "padding": "14px 18px",
        "borderRadius": "8px",
        "border": f"1.5px solid {border}",
        "background": "#f8f9fa",
        "marginBottom": "16px",
        "fontSize": "13px",
        "lineHeight": "1.8",
    })


def _view1_summary(
    peer_pillar: pd.DataFrame,
    focal_pillar: pd.DataFrame,
    peer_overall: pd.Series,
    focal_overall: float | None,
    view_mode: str,
    camp_range=None,        # DataFrame indexed by pillar with columns min/max (campaign view)
    camp_overall_range=None,  # (min, max) tuple for overall (campaign view)
) -> html.Div:
    """Summary table + narrative below View 1 chart.
    Bundle view: PILLAR | BUNDLE SCORE | PEER MEDIAN | PEER IQR | GAP | STATUS
    Campaign view: adds CAMPAIGN RANGE column showing min–max across campaigns.
    """
    peer_stats = (
        peer_pillar.groupby("pillar")["score"]
        .describe(percentiles=[0.1, 0.25, 0.5, 0.75])
        .reset_index()
    )

    STATUS_ABOVE    = ("▲ Above peers",   "#198754")
    STATUS_INLINE   = ("→ In line",       "#6c757d")
    STATUS_GAP      = ("↓ Gap to close",  "#fd7e14")
    STATUS_CRITICAL = ("⚠ Critical gap",  "#dc3545")

    above, inline_p, gap_p, critical_p = [], [], [], []
    table_rows = []
    show_camp_range = view_mode == "campaign" and camp_range is not None

    td = {"padding": "6px 10px"}

    def _camp_range_cell(lo, hi):
        return html.Td(
            f"{lo:.1f} – {hi:.1f}",
            style={**td, "color": "#dc3545", "fontSize": "11px", "textAlign": "right"},
        )

    # ── Overall row ───────────────────────────────────────────────────────────
    if focal_overall is not None and not peer_overall.empty:
        ov_p25    = peer_overall.quantile(0.25)
        ov_median = peer_overall.median()
        ov_p75    = peer_overall.quantile(0.75)
        ov_p10    = peer_overall.quantile(0.10)
        ov_gap    = focal_overall - ov_median

        if focal_overall > ov_p75:      ov_label, ov_color = STATUS_ABOVE
        elif focal_overall >= ov_p25:   ov_label, ov_color = STATUS_INLINE
        elif focal_overall >= ov_p10:   ov_label, ov_color = STATUS_GAP
        else:                           ov_label, ov_color = STATUS_CRITICAL

        ov_bg = {"backgroundColor": "#f0f4ff"}
        row_cells = [
            html.Td("Overall", style={**td, **ov_bg, "fontWeight": "700", "textAlign": "left", "color": "#0d6efd"}),
            html.Td(f"{focal_overall:.1f}", style={**td, **ov_bg, "color": ov_color, "fontWeight": "700", "textAlign": "right"}),
        ]
        if show_camp_range:
            if camp_overall_range:
                row_cells.append(_camp_range_cell(*camp_overall_range))
            else:
                row_cells.append(html.Td("—", style={**td, **ov_bg, "textAlign": "right"}))
        row_cells += [
            html.Td(f"{ov_median:.1f}",              style={**td, **ov_bg, "color": "#6c757d", "textAlign": "right"}),
            html.Td(f"{ov_p25:.1f} – {ov_p75:.1f}", style={**td, **ov_bg, "color": "#6c757d", "fontSize": "11px", "textAlign": "right"}),
            html.Td(f"{ov_gap:+.1f}",                style={**td, **ov_bg, "color": "#198754" if ov_gap >= 0 else "#dc3545", "fontWeight": "700", "textAlign": "right"}),
            html.Td(ov_label,                        style={**td, **ov_bg, "color": ov_color, "fontWeight": "700", "textAlign": "left"}),
        ]
        table_rows.append(html.Tr(row_cells))

    # ── Pillar rows ───────────────────────────────────────────────────────────
    for _, stat in peer_stats.iterrows():
        pillar = stat["pillar"]
        p10    = stat.get("10%", stat["min"])
        p25, median, p75 = stat["25%"], stat["50%"], stat["75%"]

        f_row = focal_pillar[focal_pillar["pillar"] == pillar]
        if f_row.empty:
            continue
        focal_score = f_row["score"].values[0]
        gap_val = focal_score - median

        if focal_score > p75:      label, color = STATUS_ABOVE;    above.append(pillar)
        elif focal_score >= p25:   label, color = STATUS_INLINE;   inline_p.append(pillar)
        elif focal_score >= p10:   label, color = STATUS_GAP;      gap_p.append(pillar)
        else:                      label, color = STATUS_CRITICAL; critical_p.append(pillar)

        row_cells = [
            html.Td(pillar,               style={**td, "fontWeight": "500", "textAlign": "left"}),
            html.Td(f"{focal_score:.1f}", style={**td, "color": color, "fontWeight": "700", "textAlign": "right"}),
        ]
        if show_camp_range:
            if pillar in camp_range.index:
                row_cells.append(_camp_range_cell(camp_range.loc[pillar, "min"], camp_range.loc[pillar, "max"]))
            else:
                row_cells.append(html.Td("—", style={**td, "textAlign": "right"}))
        row_cells += [
            html.Td(f"{median:.1f}",          style={**td, "color": "#6c757d", "textAlign": "right"}),
            html.Td(f"{p25:.1f} – {p75:.1f}", style={**td, "color": "#6c757d", "fontSize": "11px", "textAlign": "right"}),
            html.Td(f"{gap_val:+.1f}",        style={**td, "color": "#198754" if gap_val >= 0 else "#dc3545", "fontWeight": "600", "textAlign": "right"}),
            html.Td(label,                    style={**td, "color": color, "fontWeight": "600", "textAlign": "left"}),
        ]
        table_rows.append(html.Tr(row_cells))

    # ── Narrative ─────────────────────────────────────────────────────────────
    parts = []
    if above:
        parts.append(f"{len(above)} pillar(s) above peer p75 ({', '.join(above)})")
    if critical_p:
        parts.append(f"{len(critical_p)} critical gap(s) below peer p10 ({', '.join(critical_p)})")
    elif gap_p:
        parts.append(f"{len(gap_p)} gap(s) to close ({', '.join(gap_p)})")
    narrative = "; ".join(parts) + "." if parts else f"All {len(table_rows)} pillars are within the peer interquartile range."

    if view_mode == "bundle":
        view_note = "Bundle score = spend-weighted avg across all campaigns. Peer comparison is at bundle level."
    else:
        view_note = "Bundle score anchors peer comparison. Campaign range shows min–max across individual campaigns."

    # ── Column headers ────────────────────────────────────────────────────────
    if show_camp_range:
        COL_WIDTHS = ["22%", "12%", "14%", "11%", "16%", "9%", "16%"]
    else:
        COL_WIDTHS = ["28%", "13%", "13%", "18%", "10%", "18%"]

    def _th(label, align="left", i=0):
        return html.Th(label, style={
            "padding": "6px 10px", "textAlign": align,
            "borderBottom": "2px solid #dee2e6", "fontSize": "11px",
            "color": "#6c757d", "textTransform": "uppercase",
            "width": COL_WIDTHS[i],
        })

    headers = [
        _th("Pillar",          "left",  0),
        _th("Bundle Score",    "right", 1),
    ]
    if show_camp_range:
        headers.append(_th("Campaign Range", "right", 2))
    headers += [
        _th("Peer Median", "right", 2 + show_camp_range),
        _th("Peer IQR",    "right", 3 + show_camp_range),
        _th("Gap",         "right", 4 + show_camp_range),
        _th("Status",      "left",  5 + show_camp_range),
    ]

    return html.Div([
        html.P(narrative, style={"marginTop": "20px", "fontSize": "13px", "color": "#333", "fontWeight": "500"}),
        html.P(view_note, style={"fontSize": "11px", "color": "#6c757d", "marginTop": "-8px", "marginBottom": "10px"}),
        html.Table(
            [html.Thead(html.Tr(headers)), html.Tbody(table_rows)],
            style={"borderCollapse": "collapse", "width": "100%", "fontSize": "13px", "tableLayout": "fixed"},
        ),
    ], style={"marginTop": "8px", "padding": "0 4px"})


# ---------------------------------------------------------------------------
# View 2 — Pillar Drill-Down (sub-score box plots + diagnosis text)
# ---------------------------------------------------------------------------

def _view2_layout(df: pd.DataFrame, selected_pillar: str | None = None) -> html.Div:
    pillars = sorted(df["pillar"].dropna().unique())
    value = selected_pillar if selected_pillar in pillars else None
    return html.Div([
        html.Div([
            html.Label("Pillar:", style={"fontWeight": "600", "marginRight": "10px", "lineHeight": "36px", "whiteSpace": "nowrap"}),
            dcc.Dropdown(
                id="dd-pillar-v2",
                options=[{"label": p, "value": p} for p in pillars],
                value=value,
                placeholder="Select a pillar to drill down...",
                clearable=False,
                style={"width": "320px", "display": "inline-block", "verticalAlign": "middle"},
            ),
        ], style={"marginBottom": "20px", "display": "flex", "alignItems": "center"}),
        html.Div(id="view2-drilldown"),
    ])


@callback(
    Output("store-selected-pillar", "data"),
    Input("dd-pillar-v2", "value"),
)
def persist_pillar(pillar):
    return pillar


@callback(
    Output("view2-drilldown", "children"),
    Input("dd-pillar-v2", "value"),
    State("store-scores", "data"),
    State("toggle-view", "value"),
)
def render_view2_drilldown(pillar, data, view_mode):
    if not pillar or not data:
        return html.Div("Select a pillar above.", style={"color": "#6c757d", "marginTop": "12px"})
    df = pd.read_json(data, orient="split")
    return _view2(df, pillar, view_mode)


@callback(
    Output("view2-detail-table", "children"),
    Input("dd-subpillar-v2", "value"),
    State("store-scores", "data"),
    State("toggle-view", "value"),
    State("dd-pillar-v2", "value"),
)
def render_view2_table(subpillar, data, view_mode, pillar):
    if not data or not pillar:
        raise PreventUpdate
    df = pd.read_json(data, orient="split")
    peer_df  = df[(df["is_focal"] == False) & (df["pillar"] == pillar)]
    focal_df = df[(df["is_focal"] == True)  & (df["pillar"] == pillar)]
    focal_filtered = focal_df if (not subpillar or subpillar == "__all__") else focal_df[focal_df["blueprint_index"] == subpillar]
    return _view2_tables(peer_df, focal_df, focal_filtered, view_mode)


def _view2_pillar_callout(peer_df: pd.DataFrame, focal_df: pd.DataFrame, pillar: str) -> html.Div:
    """Headline insight card for the selected pillar — focal vs peer benchmark."""
    if focal_df.empty or peer_df.empty:
        return html.Div()

    # Bundle-level peer scores per sub-pillar (deduplicated)
    peer_bundle = peer_df.drop_duplicates(["app_market_bundle", "blueprint_index"])

    # Pillar-level score: mean of sub-pillar bundle_check_scores per bundle
    peer_pillar_scores = peer_bundle.groupby("app_market_bundle")["bundle_check_score"].mean().dropna()
    focal_pillar_score = focal_df["bundle_check_score"].dropna().mean()

    if pd.isna(focal_pillar_score) or peer_pillar_scores.empty:
        return html.Div()

    pct = (peer_pillar_scores <= focal_pillar_score).mean() * 100
    pct_color = "#198754" if pct >= 50 else "#dc3545"

    # Per-sub-pillar gaps vs peer median
    peer_sub_medians = peer_bundle.groupby("blueprint_index")["bundle_check_score"].median()
    focal_sub_scores = focal_df.groupby("blueprint_index")["bundle_check_score"].first()
    gaps = (focal_sub_scores - peer_sub_medians).dropna()

    most_lagged   = gaps.idxmin() if not gaps.empty else None
    most_advanced = gaps.idxmax() if not gaps.empty else None

    lines = [
        html.Div([
            html.Span(f"{pillar} — ", style={"fontWeight": "600", "color": "#495057"}),
            html.Span(f"{pct:.0f}th percentile vs peers",
                      style={"color": pct_color, "fontWeight": "700", "fontSize": "15px"}),
            html.Span(f"  (bundle score: {focal_pillar_score:.1f})",
                      style={"color": "#6c757d", "fontSize": "12px"}),
        ], style={"marginBottom": "6px"}),
    ]
    if most_lagged and gaps[most_lagged] < 0:
        lines.append(html.Div([
            html.Span("⚠ Most lagged sub-pillar: ", style={"fontWeight": "600", "color": "#dc3545"}),
            html.Span(most_lagged, style={"fontWeight": "700"}),
            html.Span(f"  (gap vs peer median: {gaps[most_lagged]:+.1f})",
                      style={"color": "#6c757d", "fontSize": "12px"}),
        ], style={"marginBottom": "4px"}))
    if most_advanced and gaps[most_advanced] > 0:
        lines.append(html.Div([
            html.Span("▲ Relative strength: ", style={"fontWeight": "600", "color": "#198754"}),
            html.Span(most_advanced, style={"fontWeight": "700"}),
            html.Span(f"  (gap vs peer median: {gaps[most_advanced]:+.1f})",
                      style={"color": "#6c757d", "fontSize": "12px"}),
        ]))

    return html.Div(lines, style={
        "padding": "14px 18px",
        "borderRadius": "8px",
        "border": f"1.5px solid {pct_color}",
        "background": "#f8f9fa",
        "marginBottom": "16px",
        "fontSize": "13px",
        "lineHeight": "1.8",
    })


def _view2_benchmark_summary(peer_df: pd.DataFrame, focal_df: pd.DataFrame) -> html.Table:
    """Per-sub-pillar benchmark table: Bundle Score | Peer Median | Peer IQR | Gap | Status."""
    checks = sorted(focal_df["blueprint_index"].dropna().unique())
    peer_bundle = peer_df.drop_duplicates(["app_market_bundle", "blueprint_index"])

    STATUS_ABOVE    = ("▲ Above peers",  "#198754")
    STATUS_INLINE   = ("→ In line",      "#6c757d")
    STATUS_GAP      = ("↓ Gap to close", "#fd7e14")
    STATUS_CRITICAL = ("⚠ Critical gap", "#dc3545")

    td = {"padding": "6px 10px"}
    th_s = {
        "padding": "7px 10px", "borderBottom": "2px solid #dee2e6",
        "fontSize": "11px", "color": "#6c757d", "textTransform": "uppercase", "fontWeight": "700",
    }

    rows = []
    for check in checks:
        peer_scores  = peer_bundle[peer_bundle["blueprint_index"] == check]["bundle_check_score"].dropna()
        focal_scores = focal_df[focal_df["blueprint_index"] == check]["bundle_check_score"].dropna()
        if peer_scores.empty or focal_scores.empty:
            continue

        focal_score = focal_scores.iloc[0]
        p10  = peer_scores.quantile(0.10)
        p25  = peer_scores.quantile(0.25)
        median = peer_scores.median()
        p75  = peer_scores.quantile(0.75)
        gap  = focal_score - median

        if focal_score > p75:    label, color = STATUS_ABOVE
        elif focal_score >= p25: label, color = STATUS_INLINE
        elif focal_score >= p10: label, color = STATUS_GAP
        else:                    label, color = STATUS_CRITICAL

        rows.append(html.Tr([
            html.Td(check,                        style={**td, "fontWeight": "500"}),
            html.Td(f"{focal_score:.1f}",         style={**td, "color": color, "fontWeight": "700", "textAlign": "right"}),
            html.Td(f"{median:.1f}",              style={**td, "color": "#6c757d", "textAlign": "right"}),
            html.Td(f"{p25:.1f} – {p75:.1f}",    style={**td, "color": "#6c757d", "fontSize": "11px", "textAlign": "right"}),
            html.Td(f"{gap:+.1f}",               style={**td, "color": "#198754" if gap >= 0 else "#dc3545", "fontWeight": "600", "textAlign": "right"}),
            html.Td(label,                        style={**td, "color": color, "fontWeight": "600"}),
        ]))

    if not rows:
        return html.Div()

    headers = html.Tr([
        html.Th("Sub-pillar",   style={**th_s, "textAlign": "left"}),
        html.Th("Bundle Score", style={**th_s, "textAlign": "right"}),
        html.Th("Peer Median",  style={**th_s, "textAlign": "right"}),
        html.Th("Peer IQR",     style={**th_s, "textAlign": "right"}),
        html.Th("Gap",          style={**th_s, "textAlign": "right"}),
        html.Th("Status",       style={**th_s, "textAlign": "left"}),
    ])
    return html.Table(
        [html.Thead(headers), html.Tbody(rows)],
        style={"borderCollapse": "collapse", "width": "100%", "fontSize": "13px", "marginBottom": "4px"},
    )


def _view2_tables(peer_df, focal_df_full, focal_df_filtered, view_mode) -> html.Div:
    """Benchmark summary (always full pillar) + campaign detail (filtered by sub-pillar)."""
    return html.Div([
        html.H6("Peer Benchmark by Sub-pillar",
                style={"marginBottom": "8px", "color": "#333", "fontSize": "13px", "fontWeight": "700"}),
        _view2_benchmark_summary(peer_df, focal_df_full),
        html.Hr(style={"margin": "20px 0", "borderColor": "#dee2e6"}),
        html.H6("Campaign Detail",
                style={"marginBottom": "8px", "color": "#333", "fontSize": "13px", "fontWeight": "700"}),
        _view2_detail_table(focal_df_filtered, view_mode),
    ])


def _view2(df: pd.DataFrame, pillar: str, view_mode: str) -> html.Div:
    peer_df  = df[(df["is_focal"] == False) & (df["pillar"] == pillar)]
    focal_df = df[(df["is_focal"] == True)  & (df["pillar"] == pillar)]

    focal_score_col = "bundle_check_score" if view_mode == "bundle" else "campaign_check_score"
    focal_color     = "#0d6efd" if view_mode == "bundle" else "#dc3545"
    focal_label     = "Focal (bundle)" if view_mode == "bundle" else "Focal (campaign)"

    checks = sorted(df[df["pillar"] == pillar]["blueprint_index"].dropna().unique())
    fig = go.Figure()

    for i, check in enumerate(checks):
        peer_sub = peer_df[peer_df["blueprint_index"] == check].drop_duplicates("app_market_bundle")
        peer_scores = peer_sub["bundle_check_score"].dropna()

        fig.add_trace(go.Box(
            x=peer_scores, y=[check] * len(peer_scores),
            orientation="h", name="Peers",
            boxpoints="all", jitter=0.4, pointpos=0,
            marker=dict(color="#adb5bd", size=4, opacity=0.55),
            line=dict(color="#6c757d"), fillcolor="rgba(108,117,125,0.12)",
            showlegend=(i == 0),
        ))

        focal_sub    = focal_df[focal_df["blueprint_index"] == check]
        focal_scores = focal_sub[focal_score_col].dropna()
        if not focal_scores.empty:
            hover_col  = "campaign_title" if "campaign_title" in focal_sub.columns else "app_name"
            hover_text = focal_sub[hover_col].fillna("")
            fig.add_trace(go.Scatter(
                x=focal_scores, y=[check] * len(focal_scores),
                mode="markers", name=focal_label,
                marker=dict(color=focal_color, size=14, symbol="diamond",
                            line=dict(color="white", width=1.5)),
                text=hover_text,
                hovertemplate="%{text}<br>Score: %{x:.1f}<extra></extra>",
                showlegend=(i == 0),
            ))

    fig.update_layout(
        xaxis=dict(range=[0, 102], title="Score"),
        yaxis=dict(title="", categoryorder="array", categoryarray=checks[::-1]),
        height=max(320, len(checks) * 80),
        showlegend=True,
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        margin=dict(l=260, r=20, t=40, b=40),
        hovermode="closest",
        boxmode="overlay",
    )

    subpillar_opts = [{"label": "All sub-pillars", "value": "__all__"}] + [
        {"label": c, "value": c} for c in checks
    ]

    return html.Div([
        _view2_pillar_callout(peer_df, focal_df, pillar),
        dcc.Graph(figure=fig),
        html.Div(
            style={"display": "flex", "alignItems": "center", "marginTop": "24px", "marginBottom": "16px"},
            children=[
                html.Label("Sub-pillar:", style={"fontWeight": "600", "marginRight": "10px", "whiteSpace": "nowrap"}),
                dcc.Dropdown(
                    id="dd-subpillar-v2",
                    options=subpillar_opts,
                    value="__all__",
                    clearable=False,
                    style={"width": "360px"},
                ),
            ],
        ),
        html.Div(
            id="view2-detail-table",
            children=_view2_tables(peer_df, focal_df, focal_df, view_mode),
        ),
    ])


def _view2_detail_table(focal_df: pd.DataFrame, view_mode: str) -> html.Div:
    """Structured table: Sub-pillar | Campaign | Spend L7 | Score | Detail | Recommendation."""
    if focal_df.empty:
        return html.Div("No focal entity data.", style={"color": "#6c757d"})

    score_col = "bundle_check_score" if view_mode == "bundle" else "campaign_check_score"

    td = {"padding": "8px 10px", "borderBottom": "1px solid #f0f0f0", "verticalAlign": "top", "fontSize": "12px"}
    th_style = {
        "padding": "7px 10px", "borderBottom": "2px solid #dee2e6",
        "fontSize": "11px", "color": "#6c757d", "textTransform": "uppercase",
        "fontWeight": "700", "textAlign": "left",
    }

    rows = []
    for _, row in focal_df.sort_values(["blueprint_index", "campaign_title"]).iterrows():
        score = row.get(score_col)
        score_color = _score_color(score)
        score_str = f"{score:.1f}" if pd.notna(score) else "—"

        spend = row.get("spend_L7")
        spend_str = f"${spend:,.0f}" if pd.notna(spend) and spend > 0 else "—"

        camp_id    = row.get("campaign_id") or ""
        camp_title = row.get("campaign_title") or ""
        camp_cell  = html.Div([
            html.Div(camp_title, style={"fontWeight": "500"}),
            html.Div(camp_id, style={"color": "#adb5bd", "fontSize": "11px", "marginTop": "2px"}),
        ]) if camp_id else html.Span("—", style={"color": "#adb5bd"})

        detail = str(row.get("detail") or "").strip()
        reco   = str(row.get("recommendations") or "").strip()

        rows.append(html.Tr([
            html.Td(row.get("blueprint_index", "—"), style={**td, "fontWeight": "500", "whiteSpace": "nowrap"}),
            html.Td(camp_cell, style={**td, "minWidth": "180px"}),
            html.Td(spend_str, style={**td, "textAlign": "right", "whiteSpace": "nowrap"}),
            html.Td(score_str, style={**td, "color": score_color, "fontWeight": "700", "textAlign": "right"}),
            html.Td(detail, style={**td, "color": "#444", "maxWidth": "280px"}),
            html.Td(reco,   style={**td, "color": "#0d6efd", "fontStyle": "italic", "maxWidth": "280px"}),
        ]))

    headers = html.Tr([
        html.Th("Sub-pillar",     style=th_style),
        html.Th("Campaign",       style=th_style),
        html.Th("Spend L7",       style={**th_style, "textAlign": "right"}),
        html.Th("Score",          style={**th_style, "textAlign": "right"}),
        html.Th("Detail",         style=th_style),
        html.Th("Recommendation", style=th_style),
    ])

    return html.Div(
        html.Table(
            [html.Thead(headers), html.Tbody(rows)],
            style={"borderCollapse": "collapse", "width": "100%", "fontSize": "13px"},
        ),
        style={"overflowX": "auto"},
    )


def _score_color(score_val) -> str:
    if pd.isna(score_val):
        return "#6c757d"
    return "#198754" if score_val >= 80 else ("#fd7e14" if score_val >= 50 else "#dc3545")


def _diagnosis_card_UNUSED(check: str, rows: pd.DataFrame, view_mode: str) -> html.Div:
    card_style = {"padding": "14px 0", "borderBottom": "1px solid #dee2e6"}

    if view_mode == "bundle":
        # ── Bundle view ────────────────────────────────────────────────────
        # Score = spend-weighted avg (bundle_check_score, same for all rows)
        bundle_score = rows["bundle_check_score"].iloc[0]
        score_str    = f"{bundle_score:.1f}" if pd.notna(bundle_score) else "—"
        color        = _score_color(bundle_score)

        # Campaign spread
        camp_scores = rows["campaign_check_score"].dropna()
        n_camps     = len(rows)
        spread_str  = (
            f"{camp_scores.min():.1f} – {camp_scores.max():.1f}"
            if len(camp_scores) > 1
            else f"{camp_scores.iloc[0]:.1f}" if len(camp_scores) == 1 else "—"
        )

        # Auto-generate framing
        raw_reco = str(rows["recommendations"].dropna().iloc[0]) if rows["recommendations"].notna().any() else ""
        reco_text = (
            f"Across campaigns for this app: {raw_reco}"
            if raw_reco
            else "No specific recommendations available."
        )
        detail_text = str(rows["detail"].dropna().iloc[0]) if rows["detail"].notna().any() else ""

        return html.Div([
            html.Div([
                html.Span(check, style={"fontWeight": "700", "fontSize": "13px"}),
                html.Span(f"  {score_str}", style={"color": color, "fontWeight": "700", "marginLeft": "8px", "fontSize": "14px"}),
                html.Span(
                    f"  ·  spend-wtd avg across {n_camps} campaign(s)  |  campaign range: {spread_str}",
                    style={"fontSize": "11px", "color": "#6c757d", "marginLeft": "8px"},
                ),
            ]),
            html.Div(detail_text, style={"fontSize": "12px", "color": "#444", "marginTop": "5px"}) if detail_text else None,
            html.Div(reco_text, style={
                "fontSize": "12px", "color": "#0d6efd", "marginTop": "4px", "fontStyle": "italic"
            }),
        ], style=card_style)

    else:
        # ── Campaign view ─────────────────────────────────────────────────
        # Show per-campaign row (may be multiple if no campaign filter applied)
        campaign_cards = []
        for _, row in rows.iterrows():
            camp_score = row.get("campaign_check_score")
            score_str  = f"{camp_score:.1f}" if pd.notna(camp_score) else "—"
            color      = _score_color(camp_score)
            spend      = row.get("spend_L7")
            spend_str  = f"${spend:,.0f}" if pd.notna(spend) else "—"
            camp_name  = row.get("campaign_title") or row.get("campaign_id") or "Unknown campaign"
            detail_text = str(row.get("detail") or "")
            reco_text   = str(row.get("recommendations") or "")

            campaign_cards.append(html.Div([
                html.Div([
                    html.Span(check, style={"fontWeight": "700", "fontSize": "13px"}),
                    html.Span(f"  {score_str}", style={"color": color, "fontWeight": "700", "marginLeft": "8px", "fontSize": "14px"}),
                    html.Span(
                        f"  ·  {camp_name}  |  Spend L7: {spend_str}",
                        style={"fontSize": "11px", "color": "#6c757d", "marginLeft": "8px"},
                    ),
                ]),
                html.Div(detail_text, style={"fontSize": "12px", "color": "#444", "marginTop": "5px"}) if detail_text else None,
                html.Div(reco_text, style={
                    "fontSize": "12px", "color": "#0d6efd", "marginTop": "4px", "fontStyle": "italic"
                }) if reco_text else None,
            ], style={"marginBottom": "6px"}))

        return html.Div(campaign_cards, style=card_style)


# ---------------------------------------------------------------------------
# View 3 — Peer Group Leaderboard
# ---------------------------------------------------------------------------

def _view3(df: pd.DataFrame, focal_bundle: str | None = None) -> html.Div:
    peer_df  = df[df["is_focal"] == False]
    focal_df = df[df["is_focal"] == True]

    # Resolve focal bundle from data if not passed explicitly
    if not focal_bundle and not focal_df.empty:
        focal_bundle = focal_df["app_market_bundle"].iloc[0]

    pillars = sorted(df["pillar"].dropna().unique())

    # ── Bundle-level overall scores (peer pool) ───────────────────────────────
    leaderboard = (
        peer_df.drop_duplicates(subset=["app_market_bundle"])
        [["app_market_bundle", "app_name", "bundle_overall_score"]]
        .sort_values("bundle_overall_score", ascending=False)
        .reset_index(drop=True)
    )
    leaderboard["rank"] = leaderboard.index + 1

    # ── Per-pillar bundle scores (pivot) ──────────────────────────────────────
    pillar_pivot = (
        peer_df.groupby(["app_market_bundle", "pillar"])["bundle_check_score"]
        .mean()
        .unstack(fill_value=None)
    )
    leaderboard = leaderboard.join(pillar_pivot, on="app_market_bundle")

    # ── Also include focal bundle if it's not already in the peer pool ────────
    focal_bundle_in_peers = focal_bundle in leaderboard["app_market_bundle"].values
    if focal_bundle and not focal_bundle_in_peers and not focal_df.empty:
        focal_row_data = focal_df.drop_duplicates("app_market_bundle")
        focal_overall = focal_df["bundle_overall_score"].dropna().iloc[0] if focal_df["bundle_overall_score"].notna().any() else None
        focal_entry = {
            "app_market_bundle": focal_bundle,
            "app_name": focal_df["app_name"].iloc[0] if not focal_df.empty else focal_bundle,
            "bundle_overall_score": focal_overall,
            "rank": None,
        }
        for p in pillars:
            sub = focal_df[focal_df["pillar"] == p]["bundle_check_score"]
            focal_entry[p] = sub.mean() if not sub.empty else None
        leaderboard = pd.concat([leaderboard, pd.DataFrame([focal_entry])], ignore_index=True)
        leaderboard = leaderboard.sort_values("bundle_overall_score", ascending=False, na_position="last").reset_index(drop=True)
        leaderboard["rank"] = leaderboard["bundle_overall_score"].rank(ascending=False, method="min", na_option="bottom").astype(int)

    td = {"padding": "7px 10px", "borderBottom": "1px solid #f0f0f0"}

    def _score_td(val, is_focal_row=False):
        if val is None or (hasattr(val, '__class__') and val.__class__.__name__ == 'float' and pd.isna(val)):
            return html.Td("—", style={**td, "color": "#adb5bd", "textAlign": "right"})
        color = "#198754" if val >= 80 else ("#fd7e14" if val >= 50 else "#dc3545")
        return html.Td(
            f"{val:.1f}",
            style={**td, "color": color, "fontWeight": "700" if is_focal_row else "500", "textAlign": "right"},
        )

    table_rows = []
    for _, r in leaderboard.iterrows():
        bundle = r["app_market_bundle"]
        is_focal_row = (bundle == focal_bundle)
        row_bg = {"backgroundColor": "#e8f0fe"} if is_focal_row else {}
        rank_str = f"#{int(r['rank'])}" if pd.notna(r.get("rank")) else "—"

        cells = [
            html.Td(rank_str, style={**td, **row_bg, "color": "#6c757d", "fontSize": "11px", "width": "40px", "textAlign": "center"}),
            html.Td(
                [
                    html.Span("★ " if is_focal_row else "", style={"color": "#0d6efd"}),
                    html.Span(r["app_name"] or bundle, style={"fontWeight": "700" if is_focal_row else "500"}),
                ],
                style={**td, **row_bg},
            ),
            html.Td(bundle, style={**td, **row_bg, "color": "#6c757d", "fontSize": "11px"}),
        ]
        # Overall score cell
        ov = r.get("bundle_overall_score")
        cells.append(_score_td(ov if not (hasattr(ov, '__class__') and pd.isna(ov)) else None, is_focal_row))

        # Per-pillar score cells
        for p in pillars:
            val = r.get(p)
            cells.append(_score_td(val if (val is not None and not pd.isna(val)) else None, is_focal_row))

        table_rows.append(html.Tr(cells, style=row_bg))

    # Header
    th_style = {
        "padding": "7px 10px", "borderBottom": "2px solid #dee2e6",
        "fontSize": "11px", "color": "#6c757d", "textTransform": "uppercase",
        "textAlign": "right", "fontWeight": "700",
    }
    headers = [
        html.Th("#",       style={**th_style, "textAlign": "center", "width": "40px"}),
        html.Th("App",     style={**th_style, "textAlign": "left"}),
        html.Th("Bundle",  style={**th_style, "textAlign": "left", "fontSize": "10px"}),
        html.Th("Overall", style={**th_style, "color": "#0d6efd"}),
    ] + [html.Th(p, style={**th_style}) for p in pillars]

    n_peers = len(leaderboard[leaderboard["app_market_bundle"] != focal_bundle]) if focal_bundle and not focal_bundle_in_peers else len(leaderboard)
    subtitle = f"{n_peers} bundles in peer group · ranked by overall Blueprint score"
    if focal_bundle:
        rank_val = leaderboard.loc[leaderboard["app_market_bundle"] == focal_bundle, "rank"]
        if not rank_val.empty:
            subtitle += f" · focal bundle ranked #{int(rank_val.iloc[0])}"

    return html.Div([
        html.P(subtitle, style={"fontSize": "12px", "color": "#6c757d", "marginBottom": "12px"}),
        html.Div(
            html.Table(
                [html.Thead(html.Tr(headers)), html.Tbody(table_rows)],
                style={"borderCollapse": "collapse", "width": "100%", "fontSize": "13px"},
            ),
            style={"overflowX": "auto"},
        ),
    ])


# ---------------------------------------------------------------------------
# View 4 — Spend-Priority Scatter
# ---------------------------------------------------------------------------

def _view4(df: pd.DataFrame) -> html.Div:
    peer_df  = df[df["is_focal"] == False].drop_duplicates(subset=["app_market_bundle"])
    focal_df = df[df["is_focal"] == True].drop_duplicates(subset=["app_market_bundle"])

    bundle_df = peer_df[["app_market_bundle", "app_name", "bundle_overall_score", "bundle_spend_L7"]].rename(
        columns={"bundle_overall_score": "score", "bundle_spend_L7": "spend"}
    )
    is_focal = bundle_df["app_market_bundle"].isin(focal_df["app_market_bundle"])

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=bundle_df.loc[~is_focal, "score"],
        y=bundle_df.loc[~is_focal, "spend"],
        mode="markers",
        text=bundle_df.loc[~is_focal, "app_name"],
        marker=dict(color="#adb5bd", size=8),
        name="Peers",
    ))
    if is_focal.any():
        fig.add_trace(go.Scatter(
            x=bundle_df.loc[is_focal, "score"],
            y=bundle_df.loc[is_focal, "spend"],
            mode="markers",
            text=bundle_df.loc[is_focal, "app_name"],
            marker=dict(color="#0d6efd", size=14, symbol="star"),
            name="Focal",
        ))

    # Quadrant lines at score=50, spend=median
    median_spend = bundle_df["spend"].median()
    fig.add_hline(y=median_spend, line_dash="dot", line_color="#dee2e6")
    fig.add_vline(x=50, line_dash="dot", line_color="#dee2e6")

    fig.update_layout(
        xaxis=dict(title="Bundle Overall Score", range=[0, 100]),
        yaxis=dict(title="Spend L7 (USD)"),
        height=500,
        hovermode="closest",
    )
    return dcc.Graph(figure=fig)
