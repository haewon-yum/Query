import json
from google.cloud import bigquery
from app.cache import cached_scores, cached_activation

BILLING_PROJECT = "gds-apac"  # SA has bigquery.jobs.create here; data lives in moloco-ods
_client = None


def _bq() -> bigquery.Client:
    global _client
    if _client is None:
        _client = bigquery.Client(project=BILLING_PROJECT)
    return _client


def _run(sql: str) -> list[dict]:
    df = _bq().query(sql).result().to_dataframe(create_bqstorage_client=False)
    # Round-trip through pandas JSON so NaN/NaT become null instead of crashing FastAPI's serializer
    return json.loads(df.to_json(orient="records"))


def _run_json(sql: str) -> bytes:
    """Returns pre-serialized JSON bytes — avoids 700MB+ Python list overhead for large tables."""
    df = _bq().query(sql).result().to_dataframe(create_bqstorage_client=False)
    return df.to_json(orient="records").encode()


_SCORES_SQL = """
    SELECT
      campaign_id,
      ANY_VALUE(campaign_title)         AS campaign_title,
      ANY_VALUE(campaign_goal)          AS campaign_goal,
      ANY_VALUE(advertiser_id)          AS advertiser_id,
      ANY_VALUE(advertiser_title)       AS advertiser_title,
      ANY_VALUE(platform_id)            AS platform_id,
      ANY_VALUE(office_region)          AS office_region,
      ANY_VALUE(office)                 AS office,
      ANY_VALUE(growth_pod)             AS growth_pod,
      ANY_VALUE(gm)                     AS gm,
      ANY_VALUE(vertical)               AS vertical,
      ANY_VALUE(sub_genre)              AS sub_vertical,
      ANY_VALUE(genre)                  AS genre,
      ANY_VALUE(app_name)               AS app_name,
      ANY_VALUE(product_id)             AS product_id,
      ANY_VALUE(os)                     AS os,
      ANY_VALUE(mmp_name)               AS mmp_name,
      MAX(spend_L7)                     AS spend_l7,
      ANY_VALUE(overall_blueprint_score) AS overall_score,
      AVG(IF(pillar = 'data_and_signals',      score, NULL)) AS pillar_data_signals,
      AVG(IF(pillar = 'optimization_strategy', score, NULL)) AS pillar_opt_strategy,
      AVG(IF(pillar = 'supply',                score, NULL)) AS pillar_supply,
      AVG(IF(pillar = 'creative',              score, NULL)) AS pillar_creative,
      AVG(IF(pillar = 'duplication',           score, NULL)) AS pillar_duplication,
      MAX(IF(blueprint_index = '1_signal_quality',                         score, NULL)) AS score_signal_quality,
      MAX(IF(blueprint_index = '2_unattributed_installs',                  score, NULL)) AS score_unattrib,
      MAX(IF(blueprint_index = '3_probabilistic_attribution',              score, NULL)) AS score_prob_attr,
      MAX(IF(blueprint_index = '1_budget_mode',                            score, NULL)) AS score_budget_mode,
      MAX(IF(blueprint_index = '2_kpi_event_volume',                       score, NULL)) AS score_kpi_events,
      MAX(IF(blueprint_index = '1_target_accessible_supply_bidreq_score',  score, NULL)) AS score_target_supply,
      MAX(IF(blueprint_index = '2_traffic_accessible_supply_bidreq_score', score, NULL)) AS score_traffic_supply,
      MAX(IF(blueprint_index = '3_os_coverage_supply_score',               score, NULL)) AS score_os_coverage,
      MAX(IF(blueprint_index = '1_creative_format_adoption',               score, NULL)) AS score_creative_format,
      MAX(IF(blueprint_index = '2_1_video_length_mix',                     score, NULL)) AS score_video_length,
      MAX(IF(blueprint_index = '2_2_video_orientation_mix',                score, NULL)) AS score_video_orient,
      MAX(IF(blueprint_index = '2_3_video_end_cards_mix',                  score, NULL)) AS score_video_endcards,
      MAX(IF(blueprint_index = '3_1_image_dimension_mix',                  score, NULL)) AS score_image_dims,
      MAX(IF(blueprint_index = '4_1_creative_fatigue',                     score, NULL)) AS score_creative_fatigue,
      MAX(IF(blueprint_index = '5_1_campaign_duplication',                 score, NULL)) AS score_duplication
    FROM `moloco-ods.alaricjames.project_blueprint_combined_data`
    WHERE spend_L7 > 0
    GROUP BY campaign_id
"""


_DETAIL_SQL = """
    SELECT
      MAX(IF(blueprint_index = '1_signal_quality',                         detail, NULL)) AS detail_signal,
      MAX(IF(blueprint_index = '2_unattributed_installs',                  detail, NULL)) AS detail_unattrib,
      MAX(IF(blueprint_index = '3_probabilistic_attribution',              detail, NULL)) AS detail_prob_attr,
      MAX(IF(blueprint_index = '1_budget_mode',                            detail, NULL)) AS detail_budget_mode,
      MAX(IF(blueprint_index = '2_kpi_event_volume',                       detail, NULL)) AS detail_kpi_events,
      MAX(IF(blueprint_index = '1_target_accessible_supply_bidreq_score',  detail, NULL)) AS detail_target_supply,
      MAX(IF(blueprint_index = '1_creative_format_adoption',               detail, NULL)) AS detail_creative_format,
      MAX(IF(blueprint_index = '4_1_creative_fatigue',                     detail, NULL)) AS detail_creative_fatigue,
      MAX(IF(blueprint_index = '5_1_campaign_duplication',                 detail, NULL)) AS detail_duplication,
      MAX(IF(blueprint_index = '1_signal_quality',                         recommendations, NULL)) AS rec_signal,
      MAX(IF(blueprint_index = '2_unattributed_installs',                  recommendations, NULL)) AS rec_unattrib,
      MAX(IF(blueprint_index = '3_probabilistic_attribution',              recommendations, NULL)) AS rec_prob_attr,
      MAX(IF(blueprint_index = '1_budget_mode',                            recommendations, NULL)) AS rec_budget_mode,
      MAX(IF(blueprint_index = '2_kpi_event_volume',                       recommendations, NULL)) AS rec_kpi_events,
      MAX(IF(blueprint_index = '1_target_accessible_supply_bidreq_score',  recommendations, NULL)) AS rec_target_supply,
      MAX(IF(blueprint_index = '1_creative_format_adoption',               recommendations, NULL)) AS rec_creative_format,
      MAX(IF(blueprint_index = '4_1_creative_fatigue',                     recommendations, NULL)) AS rec_creative_fatigue,
      MAX(IF(blueprint_index = '5_1_campaign_duplication',                 recommendations, NULL)) AS rec_duplication
    FROM `moloco-ods.alaricjames.project_blueprint_combined_data`
    WHERE campaign_id = @campaign_id
"""


def fetch_campaign_detail(campaign_id: str) -> dict:
    sql = _DETAIL_SQL.replace("@campaign_id", f"'{campaign_id.replace(chr(39), '')}'")
    rows = _run(sql)
    return rows[0] if rows else {}


def fetch_scores() -> bytes:
    """Returns pre-serialized JSON bytes; cached as ~40MB instead of 700MB+ of Python dicts."""
    return cached_scores(lambda: _run_json(_SCORES_SQL))


_COMBINED_SQL_TEMPLATE = """
    SELECT
      campaign_id,
      ANY_VALUE(campaign_title)         AS campaign_title,
      ANY_VALUE(campaign_goal)          AS campaign_goal,
      ANY_VALUE(advertiser_id)          AS advertiser_id,
      ANY_VALUE(advertiser_title)       AS advertiser_title,
      ANY_VALUE(platform_id)            AS platform_id,
      ANY_VALUE(office_region)          AS office_region,
      ANY_VALUE(office)                 AS office,
      ANY_VALUE(growth_pod)             AS growth_pod,
      ANY_VALUE(gm)                     AS gm,
      ANY_VALUE(vertical)               AS vertical,
      ANY_VALUE(sub_genre)              AS sub_vertical,
      ANY_VALUE(genre)                  AS genre,
      ANY_VALUE(app_name)               AS app_name,
      ANY_VALUE(product_id)             AS product_id,
      ANY_VALUE(os)                     AS os,
      ANY_VALUE(mmp_name)               AS mmp_name,
      MAX(spend_L7)                     AS spend_l7,
      ANY_VALUE(overall_blueprint_score) AS overall_score,
      AVG(IF(pillar = 'data_and_signals',      score, NULL)) AS pillar_data_signals,
      AVG(IF(pillar = 'optimization_strategy', score, NULL)) AS pillar_opt_strategy,
      AVG(IF(pillar = 'supply',                score, NULL)) AS pillar_supply,
      AVG(IF(pillar = 'creative',              score, NULL)) AS pillar_creative,
      AVG(IF(pillar = 'duplication',           score, NULL)) AS pillar_duplication,
      MAX(IF(blueprint_index = '1_signal_quality',                         score, NULL)) AS score_signal_quality,
      MAX(IF(blueprint_index = '2_unattributed_installs',                  score, NULL)) AS score_unattrib,
      MAX(IF(blueprint_index = '3_probabilistic_attribution',              score, NULL)) AS score_prob_attr,
      MAX(IF(blueprint_index = '1_budget_mode',                            score, NULL)) AS score_budget_mode,
      MAX(IF(blueprint_index = '2_kpi_event_volume',                       score, NULL)) AS score_kpi_events,
      MAX(IF(blueprint_index = '1_target_accessible_supply_bidreq_score',  score, NULL)) AS score_target_supply,
      MAX(IF(blueprint_index = '2_traffic_accessible_supply_bidreq_score', score, NULL)) AS score_traffic_supply,
      MAX(IF(blueprint_index = '3_os_coverage_supply_score',               score, NULL)) AS score_os_coverage,
      MAX(IF(blueprint_index = '1_creative_format_adoption',               score, NULL)) AS score_creative_format,
      MAX(IF(blueprint_index = '2_1_video_length_mix',                     score, NULL)) AS score_video_length,
      MAX(IF(blueprint_index = '2_2_video_orientation_mix',                score, NULL)) AS score_video_orient,
      MAX(IF(blueprint_index = '2_3_video_end_cards_mix',                  score, NULL)) AS score_video_endcards,
      MAX(IF(blueprint_index = '3_1_image_dimension_mix',                  score, NULL)) AS score_image_dims,
      MAX(IF(blueprint_index = '4_1_creative_fatigue',                     score, NULL)) AS score_creative_fatigue,
      MAX(IF(blueprint_index = '5_1_campaign_duplication',                 score, NULL)) AS score_duplication,
      MAX(IF(blueprint_index = '1_signal_quality',                         detail, NULL)) AS detail_signal,
      MAX(IF(blueprint_index = '2_unattributed_installs',                  detail, NULL)) AS detail_unattrib,
      MAX(IF(blueprint_index = '3_probabilistic_attribution',              detail, NULL)) AS detail_prob_attr,
      MAX(IF(blueprint_index = '1_budget_mode',                            detail, NULL)) AS detail_budget_mode,
      MAX(IF(blueprint_index = '2_kpi_event_volume',                       detail, NULL)) AS detail_kpi_events,
      MAX(IF(blueprint_index = '1_target_accessible_supply_bidreq_score',  detail, NULL)) AS detail_target_supply,
      MAX(IF(blueprint_index = '1_creative_format_adoption',               detail, NULL)) AS detail_creative_format,
      MAX(IF(blueprint_index = '4_1_creative_fatigue',                     detail, NULL)) AS detail_creative_fatigue,
      MAX(IF(blueprint_index = '5_1_campaign_duplication',                 detail, NULL)) AS detail_duplication,
      MAX(IF(blueprint_index = '1_signal_quality',                         recommendations, NULL)) AS rec_signal,
      MAX(IF(blueprint_index = '2_unattributed_installs',                  recommendations, NULL)) AS rec_unattrib,
      MAX(IF(blueprint_index = '3_probabilistic_attribution',              recommendations, NULL)) AS rec_prob_attr,
      MAX(IF(blueprint_index = '1_budget_mode',                            recommendations, NULL)) AS rec_budget_mode,
      MAX(IF(blueprint_index = '2_kpi_event_volume',                       recommendations, NULL)) AS rec_kpi_events,
      MAX(IF(blueprint_index = '1_target_accessible_supply_bidreq_score',  recommendations, NULL)) AS rec_target_supply,
      MAX(IF(blueprint_index = '1_creative_format_adoption',               recommendations, NULL)) AS rec_creative_format,
      MAX(IF(blueprint_index = '4_1_creative_fatigue',                     recommendations, NULL)) AS rec_creative_fatigue,
      MAX(IF(blueprint_index = '5_1_campaign_duplication',                 recommendations, NULL)) AS rec_duplication
    FROM `moloco-ods.alaricjames.project_blueprint_combined_data`
    WHERE spend_L7 > 0
      {extra_where}
    GROUP BY campaign_id
    ORDER BY spend_l7 DESC
"""

# Allowlist of column names that are safe to filter on (prevents injection via column names).
_ALLOWED_FILTER_COLS = {
    'office_region', 'office', 'growth_pod', 'vertical', 'os',
    'platform_id', 'advertiser_title', 'app_name', 'campaign_id',
}


def fetch_combined_filtered(conditions: list[str]) -> bytes:
    """Run the combined scores+detail SQL with optional WHERE conditions.

    Each condition must start with a column name from _ALLOWED_FILTER_COLS to
    prevent SQL injection via column names. Values are trusted as-is (they
    originate from BQ data and are SQL-escaped by the client).

    Args:
        conditions: List of SQL condition strings, e.g. ["office_region = 'APAC'"].

    Returns:
        CSV bytes of the query result.

    Raises:
        ValueError: If any condition references a column not in _ALLOWED_FILTER_COLS.
    """
    for cond in conditions:
        col = cond.split()[0]
        if col not in _ALLOWED_FILTER_COLS:
            raise ValueError(f"Filter column '{col}' is not allowed.")
    extra = ('  AND ' + '\n  AND '.join(conditions)) if conditions else ''
    sql = _COMBINED_SQL_TEMPLATE.replace('{extra_where}', extra)
    df = _bq().query(sql).result().to_dataframe(create_bqstorage_client=False)
    return df.to_csv(index=False).encode()


def fetch_activation() -> dict:
    def _query():
        summary = _run("""
            SELECT
              activation_date, region, advertiser_id, advertiser_title, platform_id, latest_date,
              baseline_campaigns, baseline_suboptimal_campaigns,
              baseline_suboptimal_spend, baseline_total_spend, baseline_pct_suboptimal,
              latest_campaigns, latest_suboptimal_campaigns,
              latest_suboptimal_spend, latest_total_spend, latest_pct_suboptimal,
              delta_suboptimal_campaigns, delta_suboptimal_spend, pct_spend_change
            FROM `moloco-ods.alaricjames.blueprint_activation_summary`
            ORDER BY COALESCE(baseline_suboptimal_spend, 0) DESC
        """)
        campaigns = _run("""
            SELECT
              activation_date, region, advertiser_id, advertiser_title, platform_id,
              campaign_id, campaign_title, campaign_goal, gm, growth_pod, office,
              mcp_link,
              baseline_spend_L7, baseline_is_suboptimal,
              latest_spend_L7, latest_is_suboptimal, latest_date,
              latest_duplication_type, latest_bid_overlap_pct, latest_flag_supply_block,
              campaign_status, change_status, issue_detail, recommendations
            FROM `moloco-ods.alaricjames.blueprint_activation_campaigns`
            ORDER BY advertiser_id, COALESCE(CAST(latest_spend_L7 AS FLOAT64), 0) DESC
        """)
        return {"summary": summary, "campaigns": campaigns}

    return cached_activation(_query)
