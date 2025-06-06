### CTV ANALYSIS ###

# start date on CTV with Moloco
DECLARE ctv_products DEFAULT ARRAY<STRING> [
      'Age of Origins CTV',
      'WAO CTV',
      'Talkie',
      'Travel Town CTV',
      'Bingo Blitz',
      'Caesars Casino',
      'House of Fun',
      'Slotomania',
      'Solitaire Grand Harvest',
      'WSOP',
      'CTV - Fanatics Sportsbook',
      'Total Battle',
      'Gin Rummy Plus CTV',
      'Spades Plus - CTV Campaign'
];
DECLARE ctv_products_unified_app_name DEFAULT ARRAY<STRING> [
    'Talkie: Soulful AI, AI Friend',
    'Caesars Slots',
    'World Series of Poker',
    'Age of Origins',
    'BINGO Blitz',
    'Total Battle',
    'War and Order',
    'Solitaire - Grand Harvest',
    'Fanatics Sportsbook',
    'Travel Town',
    'Slots - House of Fun',
    'Slotomania',
    'Gin Rummy',
    'Spades'
];

CREATE OR REPLACE TABLE `moloco-ods.haewon.ctv_plc_250423` AS
WITH daily_ctv_spend AS (
  SELECT
    product.title AS title,
    date_utc,
    SUM(gross_spend_usd) AS daily_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`

  WHERE 
    product.title IN UNNEST(
        ctv_products
    )
    AND date_utc <= DATE('2025-04-23')
  GROUP BY 1,2
  HAVING daily_spend > 0
),

ctv_start_date AS (
SELECT
  CASE
    WHEN title = 'Travel Town CTV' THEN 'Travel Town'
    WHEN title = 'Total Battle' THEN 'Total Battle'
    WHEN title = 'Bingo Blitz' THEN 'BINGO Blitz'
    WHEN title = 'Talkie' THEN 'Talkie: Soulful AI, AI Friend'
    WHEN title = 'Age of Origins CTV' THEN 'Age of Origins'
    WHEN title = 'Solitaire Grand Harvest' THEN 'Solitaire - Grand Harvest'
    WHEN title = 'WAO CTV' THEN 'War and Order'
    WHEN title = 'Slotomania' THEN 'Slotomania'
    WHEN title = 'House of Fun' THEN 'Slots - House of Fun'
    WHEN title = 'WSOP' THEN 'World Series of Poker'
    WHEN title = 'CTV - Fanatics Sportsbook' THEN 'Fanatics Sportsbook'
    WHEN title = 'Caesars Casino' THEN 'Caesars Slots'
    WHEN title = 'Gin Rummy Plus CTV' THEN 'Gin Rummy'
    WHEN title = 'Spades Plus - CTV Campaign' THEN 'Spades'
  END AS `unified_app`,
  title,
  MIN(date_utc) AS ctv_start_date
FROM
  daily_ctv_spend
GROUP BY 1, 2
),

product_titles AS (
  WITH tmp AS(
    SELECT
        app_market_bundle,
        dataai.unified_app_name
    FROM `moloco-ae-view.athena.dim1_app`
    WHERE dataai.unified_app_name IN (SELECT unified_app from ctv_start_date)
    )
  SELECT 
    DISTINCT 
      product.title,
      unified_app_name
  FROM `moloco-ae-view.athena.fact_dsp_core` core JOIN tmp ON core.product.app_market_bundle = tmp.app_market_bundle
  WHERE date_utc = '2025-04-23'
),

app_release_date AS (
  SELECT
    dataai.unified_app_name,
    MIN(dataai.app_release_date_utc) AS app_release_date_utc
  FROM `moloco-ae-view.athena.dim1_app`
  GROUP BY 1
),
daily_download AS (
  SELECT
      dim1_app.unified_app_name,
      fact_app.date_utc,
      COALESCE(SUM(fact_app.daily.downloads ), 0) AS daily_downloads,
      COALESCE(SUM(fact_app.daily.active_users), 0) AS daily_active_users,
      SUM(CASE WHEN country='USA' THEN fact_app.daily.downloads ELSE 0 END) AS daily_downloads_usa,
      SUM(CASE WHEN country='USA' THEN fact_app.daily.active_users ELSE 0 END) AS daily_active_users_usa
    FROM `moloco-ae-view.athena.fact_app` fact_app
    WHERE 1=1
      AND fact_app.date_utc BETWEEN '2020-03-01' AND '2025-04-20'
      AND dim1_app.unified_app_name IN UNNEST(ctv_products_unified_app_name)
    GROUP BY 1,2
),
spend_performance AS (
    SELECT
        CASE 
          WHEN p.unified_app_name IS NULL AND product.title  = 'Travel Town CTV' THEN 'Travel Town'
          WHEN p.unified_app_name IS NULL AND product.title = 'Talkie' THEN 'Talkie: Soulful AI, AI Friend'
          WHEN p.unified_app_name IS NULL AND product.title = 'Age of Origins CTV' THEN 'Age of Origins'
          WHEN p.unified_app_name IS NULL AND product.title = 'WAO CTV' THEN 'War and Order'
          WHEN p.unified_app_name IS NULL AND product.title = 'CTV - Fanatics Sportsbook' THEN 'Fanatics Sportsbook'
          WHEN p.unified_app_name IS NULL AND product.title = 'Gin Rummy Plus CTV' THEN 'Gin Rummy'
          WHEN p.unified_app_name IS NULL AND product.title = 'Spades Plus - CTV Campaign' THEN 'Spades'
        ELSE p.unified_app_name END AS unified_app_name,
        date_utc,
        SUM(gross_spend_usd) AS spend,
        SUM(revenue_d7) AS d7_revenue,
        SUM(installs) AS installs,
        SUM(CASE WHEN campaign.os IN ('IOS','ANDROID') THEN gross_spend_usd ELSE 0 END) AS mobile_spend,
        SUM(CASE WHEN campaign.os IN ('CTV') THEN gross_spend_usd ELSE 0 END) AS ctv_spend,
        SUM(CASE WHEN campaign.os IN ('IOS','ANDROID') THEN revenue_d7 ELSE 0 END) AS mobile_revenue_d7,
        SUM(CASE WHEN campaign.os IN ('CTV') THEN revenue_d7 ELSE 0 END) AS ctv_revenue_d7,
        SUM(CASE WHEN campaign.os IN ('IOS','ANDROID') THEN installs ELSE 0 END) AS mobile_installs,
        SUM(CASE WHEN campaign.os IN ('CTV') THEN installs ELSE 0 END) AS ctv_installs,
        SUM(CASE WHEN campaign.country='USA' THEN gross_spend_usd ELSE 0 END) AS spend_usa,
        SUM(CASE WHEN campaign.country='USA' THEN revenue_d7 ELSE 0 END) AS d7_revenue_usa,
        SUM(CASE WHEN campaign.country='USA' THEN installs ELSE 0 END) AS d7_installs_usa,
        SUM(CASE WHEN campaign.country='USA' AND campaign.os IN ('IOS','ANDROID') THEN gross_spend_usd ELSE 0 END) AS mobile_spend_usa,
        SUM(CASE WHEN campaign.country='USA' AND campaign.os IN ('CTV') THEN gross_spend_usd ELSE 0 END) AS ctv_spend_usa,
        SUM(CASE WHEN campaign.country='USA' AND campaign.os IN ('IOS','ANDROID') THEN revenue_d7 ELSE 0 END) AS mobile_revenue_d7_usa,
        SUM(CASE WHEN campaign.country='USA' AND campaign.os IN ('CTV') THEN revenue_d7 ELSE 0 END) AS ctv_revenue_d7_usa,
        SUM(CASE WHEN campaign.country='USA' AND campaign.os IN ('IOS','ANDROID') THEN installs ELSE 0 END) AS mobile_installs_usa,
        SUM(CASE WHEN campaign.country='USA' AND campaign.os IN ('CTV') THEN installs ELSE 0 END) AS ctv_installs_usa,
    FROM `moloco-ae-view.athena.fact_dsp_core` c LEFT JOIN product_titles p
      ON c.product.title = p.title
    WHERE 1=1
        AND date_utc BETWEEN DATE('2020-03-01') AND DATE('2025-04-20')
        AND (product.title IN (SELECT DISTINCT title FROM product_titles) OR product.title IN UNNEST(ctv_products))
    GROUP BY 1,2
)

SELECT
    s.unified_app,
    r.app_release_date_utc,
    s.ctv_start_date,
    d.date_utc,
    DATE_DIFF(d.date_utc, r.app_release_date_utc, day) AS days_diff,
    d.daily_downloads,
    d.daily_downloads_usa,
    d.daily_active_users,
    d.daily_active_users_usa,
    p.spend,
    p.d7_revenue,
    p.installs,
    p.mobile_spend,
    p.ctv_spend,
    p.mobile_revenue_d7,
    p.ctv_revenue_d7,
    p.mobile_installs,
    p.ctv_installs,
    p.spend_usa,
    p.d7_revenue_usa,
    p.mobile_spend_usa,
    p.ctv_spend_usa,
    p.mobile_revenue_d7_usa,
    p.ctv_revenue_d7_usa,
    p.mobile_installs_usa,
    p.ctv_installs_usa,
    SAFE_DIVIDE(p.mobile_revenue_d7_usa, p.mobile_spend_usa) AS mobile_roas_d7_usa,
    SAFE_DIVIDE(p.ctv_revenue_d7_usa, p.mobile_spend_usa) AS ctv_roas_d7_usa,
    SAFE_DIVIDE(p.mobile_spend_usa, p.mobile_installs_usa) AS mobile_cpi_usa,
    SAFE_DIVIDE(p.ctv_spend_usa, p.ctv_installs_usa) AS ctv_cpi_usa,
FROM ctv_start_date s
    LEFT JOIN app_release_date r ON s.unified_app = r.unified_app_name
    LEFT JOIN daily_download d ON s.unified_app = d.unified_app_name
    LEFT JOIN spend_performance p ON s.unified_app = p.unified_app_name AND d.date_utc = p.date_utc
WHERE r.app_release_date_utc < d.date_utc