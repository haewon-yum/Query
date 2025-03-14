  /* 
    `moloco-ae-view.athena.fact_app`
  */


  /* fact app joining with dim1_app   */
  
  SELECT
      IFNULL(dim1_app.dataai.company_name, 'N/A')  AS company_name,
      IFNULL(dim1_app.dataai.company_name, 'N/A')  AS company_hq_country,
      IFNULL(dim1_app.dataai.app_name, 'N/A')  AS app_name,
      dim1_app.app_market_bundle  AS app_market_bundle,
      dim1_app.os  AS os,
      dim1_app.dataai.genre  AS genre,
      dim1_app.dataai.app_release_date_utc AS app_release_date_utc,
      fact_app.date_utc AS date_utc,
      fact_app.country  AS country,
      COALESCE(SUM(fact_app.daily.downloads ), 0) AS daily_downloads,
      COALESCE(SUM(fact_app.daily.active_users ), 0) AS daily_active_users,
      COALESCE(SUM(fact_app.daily.revenue ), 0) AS daily_revenue,
      COALESCE(SUM(fact_app.monthly.active_users ), 0) AS monthly_active_users,
  FROM `moloco-ae-view.athena.fact_app`  AS fact_app
    LEFT JOIN `moloco-ae-view.athena.dim1_app`  AS dim1_app ON CAST(dim1_app.dataai.app_id AS STRING) = fact_app.app_id
  WHERE fact_app.date_utc BETWEEN '{start_date_release}' AND '{end_date_analysis}'
      AND fact_app.app_market_bundle IN ({tgt_bundles_str})
  GROUP BY ALL