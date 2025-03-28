/* 
    e.g. coupang eats RE target publishers (excpet for ib)
    https://colab.research.google.com/drive/1ocNx1g4G2wTDJfrBXsUXAs9EZ-LTyd7n#scrollTo=vguAL8YEgbwu
*/

DECLARE standard_date DATE DEFAULT '2024-11-30';

  WITH spending AS(
    SELECT
      app_bundle AS publisher_bundle,
      SUM(total_revenue) AS gross_spend_usd,
      SUM(total_pb_revenue) AS pb_revenue_usd
    FROM `moloco-dsp-data-view.standard_cs_v5.all_events_extended_utc`
    WHERE DATE(time_bucket) BETWEEN DATE_SUB(standard_date, INTERVAL 90 DAY) AND DATE_ADD(standard_date, INTERVAL 1 DAY)
      AND campaign_id IN ({purchase_re_campaigns_str})
      AND cr_format <> 'ib'
    GROUP BY ALL
  ),
  actions AS(
      SELECT
        req.app.bundle AS publisher_bundle,
        COUNT(1) AS purchases,
        COALESCE(SUM(cv.revenue_usd.amount), 0) AS revenue
      FROM
        `focal-elf-631.prod_stream_view.cv`
      WHERE
        DATE(timestamp) BETWEEN DATE_SUB(standard_date, INTERVAL 90 DAY) AND DATE_ADD(standard_date, INTERVAL 30 DAY)
        AND cv.revenue_usd.amount > 0
        AND api.creative.cr_format <> 'ib'
        AND api.campaign.id IN ({purchase_re_campaigns_str})
      GROUP BY
        ALL
    )
  SELECT
    a.publisher_bundle,
    a.gross_spend_usd,
    a.pb_revenue_usd,
    b.purchases,
    SAFE_DIVIDE(a.gross_spend_usd, b.purchases) AS cpa,
    SAFE_DIVIDE(a.pb_revenue_usd, a.gross_spend_usd) AS ROAS
  FROM spending a LEFT JOIN actions b USING(publisher_bundle)
  WHERE gross_spend_usd > 5
  ORDER BY cpa


  -- Top spending publishers for vi and IPM metric

  DECLARE start_date DATE DEFAULT '2024-11-10';
  DECLARE end_date DATE DEFAULT '2024-12-09';

  WITH spending AS(
    SELECT
      app_bundle AS publisher_bundle,
      SUM(total_revenue) AS gross_spend_usd,
      SUM(total_pb_revenue) AS pb_revenue_usd
    FROM `moloco-dsp-data-view.standard_cs_v5.all_events_extended_utc`
    WHERE DATE(time_bucket) BETWEEN start_date AND end_date
      AND campaign_id IN ('u4GbncOKq6TU9clm')
      AND cr_format IS 'vi'
    GROUP BY ALL
  ),
  actions AS(
      SELECT
        req.app.bundle AS publisher_bundle,
        COUNT(1) AS purchases,
        COALESCE(SUM(cv.revenue_usd.amount), 0) AS revenue
      FROM
        `focal-elf-631.prod_stream_view.cv`
      WHERE
        DATE(timestamp) BETWEEN DATE_SUB(standard_date, INTERVAL 90 DAY) AND DATE_ADD(standard_date, INTERVAL 30 DAY)
        AND cv.revenue_usd.amount > 0
        AND api.creative.cr_format <> 'ib'
        AND api.campaign.id IN ({purchase_re_campaigns_str})
      GROUP BY
        ALL
    )
  SELECT
    a.publisher_bundle,
    a.gross_spend_usd,
    a.pb_revenue_usd,
    b.purchases,
    SAFE_DIVIDE(a.gross_spend_usd, b.purchases) AS cpa,
    SAFE_DIVIDE(a.pb_revenue_usd, a.gross_spend_usd) AS ROAS
  FROM spending a LEFT JOIN actions b USING(publisher_bundle)
  WHERE gross_spend_usd > 5
  ORDER BY cpa