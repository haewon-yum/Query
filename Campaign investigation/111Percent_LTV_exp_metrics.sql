
/* DX revenue and unique users */ 
DECLARE run_from_date DATE DEFAULT "2024-12-05";
DECLARE run_to_date DATE DEFAULT "2025-01-20";

WITH
  advertiser AS (
    SELECT
      *,
      COALESCE(DATE_SUB(LAG(effective_date_local) OVER(PARTITION BY platform_id, advertiser_id ORDER BY effective_date_local DESC), INTERVAL 1 DAY), run_to_date) AS last_effective_date_local,
    FROM
    (
      SELECT
        DISTINCT
            effective_date_local,
            platform.id AS platform_id,
            advertiser.id AS advertiser_id,
            advertiser.timezone AS advertiser_timezone,
            platform.serving_cost_percent AS platform_serving_cost_percent,
            platform.contract_markup_percent AS platform_markup_percent
      FROM
        `moloco-dsp-data-source.costbook.costbook`
      WHERE
        campaign.country = 'KOR'
      AND
        advertiser.id IN ('t52aeGmi7ov3wppl')
      AND
        DATE_DIFF(run_to_date, effective_date_local, DAY) >=0
    )
  ),

  advertiser_timezone AS (
    SELECT
      DISTINCT
      platform_id,
      advertiser_id,
      advertiser_timezone
    FROM
      advertiser
  ),

  imp_t AS (
    SELECT
      I.api.campaign.id AS campaign_id,
      DATE(I.timestamp, A.advertiser_timezone) AS local_date,
      A.platform_serving_cost_percent,
      A.platform_markup_percent,
      SUM(I.imp.win_price_usd.amount_micro / 1e6) AS win_price_usd,
      COUNT(*) AS imp,
    FROM
      `focal-elf-631.prod_stream_view.imp` AS I
    INNER JOIN
      advertiser AS A
    ON I.platform_id=A.platform_id
      AND I.advertiser_id=A.advertiser_id
      AND A.effective_date_local<=DATE(I.timestamp, A.advertiser_timezone)
      AND DATE(I.timestamp, A.advertiser_timezone)<=A.last_effective_date_local
    WHERE
      DATE(I.timestamp) BETWEEN run_from_date AND run_to_date
      AND I.api.campaign.id IN ('u4GbncOKq6TU9clm', 'Jo6awKyW7Q9G2pKt')
    --   AND I.api.advertiser.id IN ('t52aeGmi7ov3wppl') -- 111Percent
    GROUP BY ALL
  ), 

    click_t AS (
        SELECT
            api.campaign.id AS campaign_id,
            COUNT(*) AS click
            -- click.generated_click_url,
            -- REGEXP_EXTRACT(click.generated_click_url, r'&af_dp=([^&]*)') AS catalog_item_id,
            -- imp.win_price_usd.amount_micro AS media_cost
        FROM
        `focal-elf-631.prod_stream_view.click`
        WHERE 
            DATE(timestamp) BETWEEN run_from_date AND run_to_date
            AND api.campaign.id IN ('u4GbncOKq6TU9clm', 'Jo6awKyW7Q9G2pKt')
        GROUP BY ALL
  ),

    cv_t AS (
        SELECT
            campaign_id, 
            SUM(CASE WHEN LOWER(pb_event) = 'install' or LOWER(pb_event) = 'installs' THEN 1 ELSE NULL END) AS install,
            SUM(CASE WHEN on_day < 7 THEN total_revenue ELSE 0 END) AS d7_revenue,
            COUNT(DISTINCT CASE WHEN on_day < 7 AND total_revenue > 0 THEN mtid ELSE NULL END) AS d7_payer,
            SUM(CASE WHEN on_day < 7 AND total_revenue > 0 THEN count_event ELSE 0 END) AS d7_purchase, 
            SUM(CASE WHEN on_day < 7 AND event = 'CUSTOM_KPI_ACTION' THEN count_event ELSE 0 END) AS d7_kpi_action,
            COUNT(DISTINCT CASE WHEN on_day < 7 AND event = 'CUSTOM_KPI_ACTION' THEN mtid ELSE NULL END) AS d7_kpi_action_user,
            
            SUM(CASE WHEN on_day < 14 THEN total_revenue ELSE 0 END) AS d14_revenue,
            COUNT(DISTINCT CASE WHEN on_day < 14 AND total_revenue > 0 THEN mtid ELSE NULL END) AS d14_payer,
            SUM(CASE WHEN on_day < 14 AND total_revenue > 0 THEN count_event ELSE 0 END) AS d14_purchase, 
            SUM(CASE WHEN on_day < 14 AND event = 'CUSTOM_KPI_ACTION' THEN count_event ELSE 0 END) AS d14_kpi_action,
            COUNT(DISTINCT CASE WHEN on_day < 14 AND event = 'CUSTOM_KPI_ACTION' THEN mtid ELSE NULL END) AS d14_kpi_action_user,

            SUM(CASE WHEN on_day < 30 THEN total_revenue ELSE 0 END) AS d30_revenue,
            COUNT(DISTINCT CASE WHEN on_day < 30 AND total_revenue > 0 THEN mtid ELSE NULL END) AS d30_payer,
            SUM(CASE WHEN on_day < 30 AND total_revenue > 0 THEN count_event ELSE 0 END) AS d30_purchase, 
            SUM(CASE WHEN on_day < 30 AND event = 'CUSTOM_KPI_ACTION' THEN count_event ELSE 0 END) AS d30_kpi_action,
            COUNT(DISTINCT CASE WHEN on_day < 30 AND event = 'CUSTOM_KPI_ACTION' THEN mtid ELSE NULL END) AS d30_kpi_action_user,
            
        FROM `moloco-dsp-data-view.standard_cs_v5.i2r_rolling`
        WHERE 
            DATE(install_time_bucket) BETWEEN run_from_date AND run_to_date
            AND campaign_id IN ('u4GbncOKq6TU9clm', 'Jo6awKyW7Q9G2pKt')
        GROUP BY ALL
    ),

    imp_spend AS (
        SELECT
            I.campaign_id,        
            SAFE_CAST(SUM(I.win_price_usd * (1 + I.platform_serving_cost_percent/100) * (1 + I.platform_markup_percent/100)) AS FLOAT64) AS gross_spending_usd,
            SUM(I.imp) AS imp,
        FROM imp_t I
        GROUP BY ALL
    )

SELECT
    I.campaign_id,
    I.gross_spending_usd,
    I.imp,
    C.click,
    CV.*
FROM 
    imp_spend AS I
        LEFT JOIN click_t AS C USING(campaign_id)
        LEFT JOIN cv_t AS CV USING(campaign_id)
