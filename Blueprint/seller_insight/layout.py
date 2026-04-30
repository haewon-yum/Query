"""
Dash layout — filter panel (left sidebar) + tabbed views (main area).
"""

from dash import dcc, html

_DOT_SPINNER = dict(type="circle", color="#0d6efd", style={"height": "36px"})


def create_layout() -> html.Div:
    return html.Div(
        style={"display": "flex", "height": "100vh", "fontFamily": "Inter, sans-serif", "fontSize": "13px"},
        children=[
            _sidebar(),
            _main_area(),
            dcc.Store(id="store-scores"),
            dcc.Store(id="store-selected-pillar"),
        ],
    )


def _sidebar() -> html.Div:
    return html.Div(
        style={
            "width": "260px",
            "minWidth": "260px",
            "background": "#ffffff",
            "borderRight": "1px solid #e9ecef",
            "padding": "20px 16px",
            "overflowY": "auto",
        },
        children=[
            html.Div(
                "Blueprint Seller Insight",
                style={"fontWeight": "700", "fontSize": "14px", "marginBottom": "20px", "color": "#212529"},
            ),

            # --- Required ---
            _section("Required"),
            _label("Platform"),
            dcc.Dropdown(
                id="dd-platform", placeholder="Select platform…", clearable=False,
                style=_dd_style(),
            ),

            # --- Focal Entity ---
            _section("Focal Entity", margin_top=18),
            _label("Advertiser"),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(id="dd-advertiser", placeholder="All advertisers", disabled=True, style=_dd_style())
            ),
            _label("App Bundle", margin_top=8),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(id="dd-bundle", placeholder="All bundles", disabled=True, style=_dd_style())
            ),
            _label("Campaign", margin_top=8),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(id="dd-campaign", placeholder="All campaigns", disabled=True, style=_dd_style())
            ),

            # --- Peer Filters ---
            _section("Peer Filters", margin_top=18),
            _label("OS"),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(
                    id="dd-os",
                    options=[{"label": "Android", "value": "ANDROID"}, {"label": "iOS", "value": "IOS"}],
                    placeholder="All OS",
                    style=_dd_style(),
                )
            ),
            _label("Vertical", margin_top=8),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(id="dd-vertical", placeholder="All verticals", style=_dd_style())
            ),
            _label("Sub-vertical", margin_top=8),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(id="dd-sub-vertical", placeholder="All sub-verticals", style=_dd_style())
            ),
            _label("Genre", margin_top=8),
            dcc.Loading(**_DOT_SPINNER, children=
                dcc.Dropdown(id="dd-genre", placeholder="All genres", style=_dd_style())
            ),

            html.Div(style={"height": "18px"}),
            html.Button(
                "Run",
                id="btn-run",
                n_clicks=0,
                style={
                    "width": "100%",
                    "padding": "9px",
                    "background": "#0d6efd",
                    "color": "white",
                    "border": "none",
                    "borderRadius": "6px",
                    "cursor": "pointer",
                    "fontWeight": "600",
                    "fontSize": "13px",
                    "letterSpacing": "0.02em",
                },
            ),
            dcc.Loading(
                type="circle",
                color="#0d6efd",
                style={"height": "28px"},
                children=html.Div(
                    id="run-status",
                    style={"marginTop": "6px", "fontSize": "11px", "color": "#6c757d", "textAlign": "center"},
                ),
            ),
        ],
    )


def _main_area() -> html.Div:
    return html.Div(
        style={"flex": "1", "padding": "24px 28px", "overflowY": "auto", "position": "relative", "background": "#fafafa"},
        children=[
            html.Div(id="peer-banner", style={"marginBottom": "14px"}),

            # View toggle + custom tab bar on same row
            html.Div(
                style={
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "space-between",
                    "borderBottom": "1px solid #dee2e6",
                    "marginBottom": "20px",
                },
                children=[
                    # Custom tab buttons
                    html.Div(
                        style={"display": "flex", "gap": "0"},
                        children=[
                            html.Button(
                                "Overall & Pillar Scores",
                                id="tab-btn-v1",
                                n_clicks=0,
                                style=_tab_btn_style(active=True),
                            ),
                            html.Button(
                                "Pillar Drill-Down",
                                id="tab-btn-v2",
                                n_clicks=0,
                                style=_tab_btn_style(active=False),
                            ),
                            html.Button(
                                "Peer Leaderboard",
                                id="tab-btn-v3",
                                n_clicks=0,
                                style=_tab_btn_style(active=False),
                            ),
                        ],
                    ),
                    # View toggle on the right
                    dcc.RadioItems(
                        id="toggle-view",
                        options=[
                            {"label": " Campaign", "value": "campaign"},
                            {"label": " Bundle",   "value": "bundle"},
                        ],
                        value="bundle",
                        inline=True,
                        inputStyle={"marginRight": "3px"},
                        labelStyle={"marginRight": "14px", "fontWeight": "500", "fontSize": "12px", "color": "#495057"},
                    ),
                ],
            ),

            # Hidden dcc.Tabs drives actual tab switching (value synced by callbacks)
            dcc.Tabs(
                id="tabs",
                value="tab-v1",
                style={"display": "none"},
                children=[
                    dcc.Tab(value="tab-v1"),
                    dcc.Tab(value="tab-v2"),
                    dcc.Tab(value="tab-v3"),
                ],
            ),

            dcc.Loading(
                id="loading-main",
                type="default",
                color="#0d6efd",
                overlay_style={
                    "visibility": "visible",
                    "opacity": 0.4,
                    "backgroundColor": "white",
                    "zIndex": 999,
                },
                custom_spinner=html.Div([
                    html.Div(
                        "Querying BigQuery…",
                        style={
                            "background": "#0d6efd",
                            "color": "white",
                            "padding": "12px 22px",
                            "borderRadius": "8px",
                            "fontWeight": "600",
                            "fontSize": "13px",
                            "boxShadow": "0 4px 16px rgba(13,110,253,0.3)",
                        }
                    )
                ], style={"display": "flex", "justifyContent": "center", "paddingTop": "80px"}),
                children=html.Div(id="tab-content"),
            ),
        ],
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _dd_style() -> dict:
    return {"fontSize": "12px"}


def _tab_btn_style(active: bool) -> dict:
    return {
        "background": "none",
        "border": "none",
        "borderBottom": "2px solid #0d6efd" if active else "2px solid transparent",
        "color": "#0d6efd" if active else "#6c757d",
        "fontWeight": "600" if active else "400",
        "fontSize": "12px",
        "padding": "8px 16px",
        "cursor": "pointer",
        "marginBottom": "-1px",  # sit on top of the border-bottom of the container
        "transition": "color 0.15s, border-color 0.15s",
        "fontFamily": "Inter, sans-serif",
    }


def _section(title: str, margin_top: int = 0) -> html.Div:
    return html.Div(
        title,
        style={
            "fontSize": "10px",
            "fontWeight": "700",
            "color": "#adb5bd",
            "textTransform": "uppercase",
            "letterSpacing": "0.07em",
            "marginTop": f"{margin_top}px",
            "marginBottom": "6px",
        },
    )


def _label(text: str, margin_top: int = 0) -> html.Div:
    return html.Div(
        text,
        style={"fontSize": "11px", "fontWeight": "500", "color": "#495057", "marginTop": f"{margin_top}px", "marginBottom": "3px"},
    )
