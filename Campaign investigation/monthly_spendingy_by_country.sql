-- 월별 국가별 예산

SELECT
  *,
  ROW_NUMBER() OVER (
    PARTITION BY
      os,
      store_bundle
    ORDER BY
      spend DESC
  ) AS spend_rank
FROM
  (
    SELECT
      campaign.os,
      campaign.country,
      SELECT FORMAT_DATE('%Y-%m', date_utc) AS mon,
      product.app_market_bundle AS store_bundle,
      COALESCE(SUM(gross_spend_usd), 0) AS spend
    FROM
      `moloco-ae-view.athena.fact_dsp_daily`
    WHERE
      date_utc BETWEEN '{start_date}' AND '{end_date}'
      AND platform = '{platform}'
      AND product.app_market_bundle IN ({store_bundle})
    GROUP BY
      ALL
  )