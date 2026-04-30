"""
Parameterized BigQuery query builders for Blueprint Seller Insight.
BQ jobs billed to gds-apac; tables fully-qualified against moloco-ods / moloco-dsp-data-view.
"""

import os
from google.cloud import bigquery
from google.oauth2.credentials import Credentials

BQ_PROJECT = "ads-bpd-guard-china"
BLUEPRINT_TABLE = "ads-bpd-guard-china.blueprint.project_blueprint_combined_data"
DIM_APP_TABLE = "moloco-dsp-data-view.athena.dim1_app_v3_rmg_vertical"


def get_client() -> bigquery.Client:
    """
    Return a BQ client that runs as the currently logged-in user (Cloud Run)
    or falls back to Application Default Credentials (local dev / SA).
    """
    try:
        from auth import get_current_access_token
        from flask import session
        token = get_current_access_token()
    except RuntimeError:
        # Outside Flask request context (e.g. startup)
        token = None

    if token:
        creds = Credentials(
            token=token,
            refresh_token=session.get("refresh_token", ""),  # type: ignore[name-defined]
            token_uri="https://oauth2.googleapis.com/token",
            client_id=os.environ.get("GOOGLE_CLIENT_ID", ""),
            client_secret=os.environ.get("GOOGLE_CLIENT_SECRET", ""),
            scopes=["https://www.googleapis.com/auth/bigquery"],
        )
        return bigquery.Client(project=BQ_PROJECT, credentials=creds)

    # Local dev: ADC (gcloud auth application-default login)
    return bigquery.Client(project=BQ_PROJECT)


# ---------------------------------------------------------------------------
# Filter option loaders (populate dropdowns)
# ---------------------------------------------------------------------------

def load_platforms() -> list[dict]:
    """Distinct platform_ids for the top-level required filter."""
    sql = f"""
    SELECT DISTINCT platform_id
    FROM `{BLUEPRINT_TABLE}`
    WHERE platform_id IS NOT NULL
    ORDER BY platform_id
    """
    rows = get_client().query(sql).result()
    return [{"label": r.platform_id, "value": r.platform_id} for r in rows]


def load_advertisers(platform_id: str) -> list[dict]:
    sql = f"""
    SELECT DISTINCT advertiser_id, advertiser_title
    FROM `{BLUEPRINT_TABLE}`
    WHERE platform_id = @platform_id
      AND advertiser_id IS NOT NULL
    ORDER BY advertiser_title
    """
    job_config = bigquery.QueryJobConfig(
        query_parameters=[bigquery.ScalarQueryParameter("platform_id", "STRING", platform_id)]
    )
    rows = get_client().query(sql, job_config=job_config).result()
    return [{"label": f"{r.advertiser_title} ({r.advertiser_id})", "value": r.advertiser_id} for r in rows]


def load_bundles(platform_id: str, advertiser_id: str | None = None) -> list[dict]:
    where = "WHERE platform_id = @platform_id"
    params = [bigquery.ScalarQueryParameter("platform_id", "STRING", platform_id)]
    if advertiser_id:
        where += " AND advertiser_id = @advertiser_id"
        params.append(bigquery.ScalarQueryParameter("advertiser_id", "STRING", advertiser_id))
    sql = f"""
    SELECT DISTINCT app_market_bundle, app_name
    FROM `{BLUEPRINT_TABLE}`
    {where}
      AND app_market_bundle IS NOT NULL
    ORDER BY app_name
    """
    rows = get_client().query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params)).result()
    return [{"label": f"{r.app_name} ({r.app_market_bundle})", "value": r.app_market_bundle} for r in rows]


def load_peer_filter_options(platform_id: str) -> dict:
    """
    Load distinct options for all peer filter dropdowns scoped to the platform.
    Returns a dict keyed by filter name → list[{label, value}].
    """
    sql = f"""
    SELECT
      d.moloco.vertical     AS vertical,
      d.moloco.sub_vertical AS sub_vertical,
      d.moloco.genre        AS genre
    FROM `{BLUEPRINT_TABLE}` b
    LEFT JOIN `{DIM_APP_TABLE}` d ON b.app_market_bundle = d.app_market_bundle
    WHERE b.platform_id = @platform_id
    """
    params = [bigquery.ScalarQueryParameter("platform_id", "STRING", platform_id)]
    rows = get_client().query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params)).result().to_dataframe()

    def _opts(col):
        vals = sorted(rows[col].dropna().unique())
        return [{"label": v, "value": v} for v in vals]

    return {
        "vertical":     _opts("vertical"),
        "sub_vertical": _opts("sub_vertical"),
        "genre":        _opts("genre"),
    }


def load_entity_os(platform_id: str, advertiser_id: str | None = None, app_market_bundle: str | None = None) -> str | None:
    """
    Return the single OS value if unambiguous (all campaigns for the entity share one OS),
    otherwise None (let the user choose).
    Only considers ANDROID / IOS.
    """
    conditions = ["platform_id = @platform_id", "UPPER(os) IN ('ANDROID', 'IOS')", "spend_L7 > 0"]
    params = [bigquery.ScalarQueryParameter("platform_id", "STRING", platform_id)]
    if app_market_bundle:
        conditions.append("app_market_bundle = @bundle")
        params.append(bigquery.ScalarQueryParameter("bundle", "STRING", app_market_bundle))
    elif advertiser_id:
        conditions.append("advertiser_id = @advertiser_id")
        params.append(bigquery.ScalarQueryParameter("advertiser_id", "STRING", advertiser_id))
    else:
        return None

    sql = f"""
    SELECT DISTINCT UPPER(os) AS os
    FROM `{BLUEPRINT_TABLE}`
    WHERE {' AND '.join(conditions)}
    """
    rows = list(get_client().query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params)).result())
    return rows[0].os if len(rows) == 1 else None


def load_bundle_taxonomy(app_market_bundle: str) -> dict:
    """Look up the dim1_app taxonomy for a specific bundle. Returns a dict with vertical/sub_vertical/genre."""
    sql = f"""
    SELECT
      moloco.vertical     AS vertical,
      moloco.sub_vertical AS sub_vertical,
      moloco.genre        AS genre
    FROM `{DIM_APP_TABLE}`
    WHERE app_market_bundle = @bundle
    LIMIT 1
    """
    params = [bigquery.ScalarQueryParameter("bundle", "STRING", app_market_bundle)]
    rows = list(get_client().query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params)).result())
    if not rows:
        return {"vertical": None, "sub_vertical": None, "genre": None}
    r = rows[0]
    return {"vertical": r.vertical, "sub_vertical": r.sub_vertical, "genre": r.genre}


def load_campaigns(platform_id: str, app_market_bundle: str) -> list[dict]:
    sql = f"""
    SELECT DISTINCT campaign_id, campaign_title
    FROM `{BLUEPRINT_TABLE}`
    WHERE platform_id = @platform_id
      AND app_market_bundle = @bundle
      AND campaign_id IS NOT NULL
    ORDER BY campaign_title
    """
    params = [
        bigquery.ScalarQueryParameter("platform_id", "STRING", platform_id),
        bigquery.ScalarQueryParameter("bundle", "STRING", app_market_bundle),
    ]
    rows = get_client().query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params)).result()
    return [{"label": f"{r.campaign_title} ({r.campaign_id})", "value": r.campaign_id} for r in rows]


# ---------------------------------------------------------------------------
# Main data query
#
# Returns a single dataframe with two kinds of rows, distinguished by is_focal:
#
#   is_focal = False  — global peer group rows (one per bundle × pillar × blueprint_index,
#                        NOT filtered by platform_id). Used for box plot distribution.
#   is_focal = True   — focal entity rows (platform + entity filtered, campaign-level).
#                        Used for the focal dot, detail text, and recommendations.
#
# Peer group counts (for fallback logic) are computed globally so that bundles
# on the focal platform are not under-counted.
# ---------------------------------------------------------------------------

def load_scores(
    platform_id: str,
    advertiser_id: str | None = None,
    app_market_bundle: str | None = None,
    campaign_id: str | None = None,
    vertical: str | None = None,
    sub_vertical: str | None = None,
    genre: str | None = None,
    os: str | None = None,
) -> "pd.DataFrame":
    import pandas as pd  # local import — only needed when query runs

    params: list[bigquery.ScalarQueryParameter] = [
        bigquery.ScalarQueryParameter("platform_id", "STRING", platform_id)
    ]

    # Taxonomy filters: define the peer group composition — applied ONLY to global_enriched.
    # Do NOT apply to focal_enriched: the focal entity's taxonomy is determined by its bundle,
    # not by the user's filter selection. Applying taxonomy filters to focal would eliminate
    # the focal entity when its dim1_app LEFT JOIN returns NULL (e.g. new/untagged bundles).
    taxonomy_filter_sql = ""
    def _taxonomy(field: str, param_name: str, value: str | None):
        nonlocal taxonomy_filter_sql
        if value:
            taxonomy_filter_sql += f"\n  AND {field} = @{param_name}"
            params.append(bigquery.ScalarQueryParameter(param_name, "STRING", value))

    _taxonomy("d.moloco.vertical",     "vertical",     vertical)
    _taxonomy("d.moloco.sub_vertical", "sub_vertical", sub_vertical)
    _taxonomy("d.moloco.genre",        "genre",        genre)

    # Context filters: campaign/office attributes applied to BOTH global and focal pools.
    # These are safe to apply to focal_enriched because they come from the blueprint table
    # directly (no JOIN dependency) and reflect real campaign attributes.
    context_filter_sql = ""
    def _context(field: str, param_name: str, value: str | None):
        nonlocal context_filter_sql
        if value:
            context_filter_sql += f"\n  AND {field} = @{param_name}"
            params.append(bigquery.ScalarQueryParameter(param_name, "STRING", value))

    _context("UPPER(b.os)", "os", os)   # case-insensitive: blueprint table stores mixed-case os

    # Focal-only filters: entity scoping — applied only to the focal pool
    focal_filter_sql = ""
    def _focal(field: str, param_name: str, value: str | None):
        nonlocal focal_filter_sql
        if value:
            focal_filter_sql += f"\n  AND {field} = @{param_name}"
            params.append(bigquery.ScalarQueryParameter(param_name, "STRING", value))

    _focal("b.advertiser_id",      "advertiser_id",      advertiser_id)
    _focal("b.app_market_bundle",  "app_market_bundle",  app_market_bundle)
    _focal("b.campaign_id",        "campaign_id",        campaign_id)

    sql = f"""
    -- ── GLOBAL PEER POOL ──────────────────────────────────────────────────
    -- All platforms, taxonomy + peer filters only. Used for box plot distribution
    -- and peer group counts.
    WITH global_enriched AS (
      SELECT
        b.app_market_bundle,
        b.app_name,
        b.pillar,
        b.blueprint_index,
        b.score                   AS campaign_check_score,
        b.overall_blueprint_score AS campaign_overall_score,
        b.spend_L7,
        d.moloco.vertical         AS moloco_vertical,
        d.moloco.sub_vertical     AS moloco_sub_vertical,
        d.moloco.genre            AS moloco_genre
      FROM `{BLUEPRINT_TABLE}` b
      LEFT JOIN `{DIM_APP_TABLE}` d ON b.app_market_bundle = d.app_market_bundle
      WHERE b.spend_L7 > 0
        {taxonomy_filter_sql}
        {context_filter_sql}
    ),

    -- Bundle-level weighted avg scores (one row per bundle × pillar × blueprint_index)
    global_bundle_scores AS (
      SELECT
        app_market_bundle,
        app_name,
        moloco_vertical,
        moloco_sub_vertical,
        moloco_genre,
        pillar,
        blueprint_index,
        SAFE_DIVIDE(
          SUM(campaign_overall_score * spend_L7) OVER (PARTITION BY app_market_bundle),
          SUM(spend_L7)                          OVER (PARTITION BY app_market_bundle)
        ) AS bundle_overall_score,
        SAFE_DIVIDE(
          SUM(campaign_check_score * spend_L7) OVER (PARTITION BY app_market_bundle, pillar, blueprint_index),
          SUM(spend_L7)                        OVER (PARTITION BY app_market_bundle, pillar, blueprint_index)
        ) AS bundle_check_score,
        SUM(spend_L7) OVER (PARTITION BY app_market_bundle) AS bundle_spend_L7
      FROM global_enriched
      QUALIFY ROW_NUMBER() OVER (PARTITION BY app_market_bundle, pillar, blueprint_index ORDER BY spend_L7 DESC) = 1
    ),

    -- Peer group counts per taxonomy level (global — no platform filter)
    peer_counts AS (
      SELECT DISTINCT
        app_market_bundle,
        moloco_vertical,
        moloco_sub_vertical,
        moloco_genre,
        COUNT(DISTINCT app_market_bundle) OVER (PARTITION BY moloco_genre)        AS n_genre,
        COUNT(DISTINCT app_market_bundle) OVER (PARTITION BY moloco_sub_vertical) AS n_sub_vertical,
        COUNT(DISTINCT app_market_bundle) OVER (PARTITION BY moloco_vertical)     AS n_vertical
      FROM global_bundle_scores
      WHERE moloco_vertical IS NOT NULL
    ),

    peer_resolved AS (
      SELECT
        app_market_bundle,
        CASE
          WHEN moloco_genre IS NOT NULL        AND n_genre >= 10        THEN 'genre'
          WHEN moloco_sub_vertical IS NOT NULL AND n_sub_vertical >= 10 THEN 'sub_vertical'
          WHEN moloco_vertical IS NOT NULL     AND n_vertical >= 10     THEN 'vertical'
          ELSE 'insufficient'
        END AS peer_level,
        CASE
          WHEN moloco_genre IS NOT NULL        AND n_genre >= 10        THEN moloco_genre
          WHEN moloco_sub_vertical IS NOT NULL AND n_sub_vertical >= 10 THEN moloco_sub_vertical
          WHEN moloco_vertical IS NOT NULL     AND n_vertical >= 10     THEN moloco_vertical
          ELSE NULL
        END AS peer_key,
        CASE
          WHEN moloco_genre IS NOT NULL        AND n_genre >= 10        THEN n_genre
          WHEN moloco_sub_vertical IS NOT NULL AND n_sub_vertical >= 10 THEN n_sub_vertical
          WHEN moloco_vertical IS NOT NULL     AND n_vertical >= 10     THEN n_vertical
          ELSE NULL
        END AS peer_n
      FROM peer_counts
    ),

    -- ── FOCAL ENTITY POOL ─────────────────────────────────────────────────
    -- Platform-filtered + entity filters. Campaign-level rows for detail text.
    focal_enriched AS (
      SELECT
        b.platform_id,
        b.advertiser_id,
        b.advertiser_title,
        b.campaign_id,
        b.campaign_title,
        b.campaign_goal,
        b.app_market_bundle,
        b.app_name,
        b.pillar,
        b.blueprint_index,
        b.score                   AS campaign_check_score,
        b.overall_blueprint_score AS campaign_overall_score,
        b.detail,
        b.recommendations,
        b.spend_L7,
        b.office_region,
        b.office
      FROM `{BLUEPRINT_TABLE}` b
      WHERE b.platform_id = @platform_id
        {context_filter_sql}
        {focal_filter_sql}
    ),

    -- ── UNION: peer rows + focal rows ──────────────────────────────────────
    peer_rows AS (
      SELECT
        g.app_market_bundle,
        g.app_name,
        g.moloco_vertical,
        g.moloco_sub_vertical,
        g.moloco_genre,
        g.pillar,
        g.blueprint_index,
        g.bundle_overall_score,
        g.bundle_check_score,
        g.bundle_spend_L7,
        CAST(NULL AS STRING) AS platform_id,
        CAST(NULL AS STRING) AS campaign_id,
        CAST(NULL AS STRING) AS campaign_title,
        CAST(NULL AS FLOAT64) AS campaign_check_score,
        CAST(NULL AS FLOAT64) AS campaign_overall_score,
        CAST(NULL AS STRING) AS detail,
        CAST(NULL AS STRING) AS recommendations,
        CAST(NULL AS FLOAT64) AS spend_L7,
        p.peer_level,
        p.peer_key,
        p.peer_n,
        FALSE AS is_focal
      FROM global_bundle_scores g
      LEFT JOIN peer_resolved p USING (app_market_bundle)
    ),

    focal_rows AS (
      SELECT
        f.app_market_bundle,
        COALESCE(g.app_name, f.app_name)             AS app_name,
        g.moloco_vertical,
        g.moloco_sub_vertical,
        g.moloco_genre,
        f.pillar,
        f.blueprint_index,
        g.bundle_overall_score,
        g.bundle_check_score,
        g.bundle_spend_L7,
        f.platform_id,
        f.campaign_id,
        f.campaign_title,
        f.campaign_check_score,
        f.campaign_overall_score,
        f.detail,
        f.recommendations,
        f.spend_L7,
        p.peer_level,
        p.peer_key,
        p.peer_n,
        TRUE AS is_focal
      FROM focal_enriched f
      LEFT JOIN global_bundle_scores g USING (app_market_bundle, pillar, blueprint_index)
      LEFT JOIN peer_resolved p USING (app_market_bundle)
    )

    SELECT * FROM peer_rows
    UNION ALL
    SELECT * FROM focal_rows
    """

    df = get_client().query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params)).result().to_dataframe()
    return df
