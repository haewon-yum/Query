/* AMR reference */

WITH ios_publisher_list AS (
SELECT
  a.campaign.os,
  publisher.app_market_bundle AS publisher_bundle,
  trackCensoredName AS publisher_name,
  trackContentRating AS content_rating,
  trackViewUrl AS market_url,
  SUM(IF(date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), bid_price_usd, 0)) AS spend_later_week,
  SUM(IF(date_utc < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), bid_price_usd, 0)) AS spend_former_week
FROM
  `moloco-ae-view.athena.fact_dsp_publisher` a
LEFT JOIN
  `moloco-dsp-supply-prod.matters42.iab_v3_ios` b
ON
  a.publisher.app_market_bundle = b.trackId
WHERE
  date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND a.campaign.os = 'IOS'
  AND a.campaign.country IN ('ARG', 'BRA', 'CAN', 'DEU', 'IRL', 'MEX', 'NLD', 'NZL', 'PER', 'PHL', 'ZAF', 'GBR', 'VEN')
  AND a.publisher.app_market_bundle IS NOT NULL
GROUP BY 1,2,3,4,5
)

SELECT
  os,
  publisher_bundle,
  publisher_name,
  content_rating,
  market_url
FROM
  ios_publisher_list
WHERE
  content_rating = '17+'
  AND spend_later_week > 0
  AND (spend_former_week = 0 OR spend_former_week IS NULL)
ORDER BY
  spend_later_week DESC
LIMIT 100

WITH android_publisher_list AS (
SELECT
  a.campaign.os,
  publisher.app_market_bundle AS publisher_bundle,
  title AS publisher_name,
  content_rating,
  market_url,
  SUM(IF(date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), bid_price_usd, 0)) AS spend_later_week,
  SUM(IF(date_utc < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), bid_price_usd, 0)) AS spend_former_week
FROM
  `moloco-ae-view.athena.fact_dsp_publisher` a
LEFT JOIN
  `moloco-dsp-supply-prod.matters42.iab_v3_android` b
ON
  a.publisher.app_market_bundle = b.package_name
WHERE
  date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND a.campaign.os = 'ANDROID'
  AND a.campaign.country IN ('ARG', 'BRA', 'CAN', 'DEU', 'IRL', 'MEX', 'NLD', 'NZL', 'PER', 'PHL', 'ZAF', 'GBR', 'VEN')
  AND a.publisher.app_market_bundle IS NOT NULL
GROUP BY 1,2,3,4,5
)

SELECT
  os,
  publisher_bundle,
  publisher_name,
  content_rating,
  market_url
FROM
  android_publisher_list
WHERE
  content_rating IN ('Mature 17+', 'Adults only 18+', 'PEGI 18', 'Rated for 18+', 'Restricted to 18+', 'USK: Ages 18+', 'Rated 18+', '18+')
  AND spend_later_week > 0
  AND (spend_former_week = 0 OR spend_former_week IS NULL)
ORDER BY
  spend_later_week DESC
LIMIT 100


/* Modified code for KOR RMG customer */ 

WITH ios_publisher_list_l60 AS (
SELECT
  a.campaign.os,
  publisher.app_market_bundle AS publisher_bundle,
  trackCensoredName AS publisher_name,
  trackContentRating AS content_rating,
  trackViewUrl AS market_url,
  SUM(IF(date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY), bid_price_usd, 0)) AS spend_l60,
  -- SUM(IF(date_utc < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), bid_price_usd, 0)) AS spend_former_week
FROM
  `moloco-ae-view.athena.fact_dsp_publisher` a
LEFT JOIN
  `moloco-dsp-supply-prod.matters42.iab_v3_ios` b
ON
  a.publisher.app_market_bundle = b.trackId
WHERE
  date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND a.campaign.os = 'IOS'
  AND a.campaign.country IN ('ARG', 'BRA', 'CAN', 'DEU', 'IRL', 'MEX', 'NLD', 'NZL', 'PER', 'PHL', 'ZAF', 'GBR', 'VEN')
  AND a.publisher.app_market_bundle IS NOT NULL
GROUP BY 1,2,3,4,5
)

SELECT
  os,
  publisher_bundle,
  publisher_name,
  content_rating,
  market_url, 
  spend_l60
FROM
  ios_publisher_list_l60
WHERE
  content_rating = '17+'
  AND spend_l60 > 0
  -- AND (spend_former_week = 0 OR spend_former_week IS NULL)
ORDER BY
  spend_l60 DESC
-- LIMIT 100

WITH android_publisher_list AS (
SELECT
  a.campaign.os,
  publisher.app_market_bundle AS publisher_bundle,
  title AS publisher_name,
  content_rating,
  market_url,
  SUM(IF(date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY), bid_price_usd, 0)) AS spend_l60,
--   SUM(IF(date_utc < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY), bid_price_usd, 0)) AS spend_former_week
FROM
  `moloco-ae-view.athena.fact_dsp_publisher` a
LEFT JOIN
  `moloco-dsp-supply-prod.matters42.iab_v3_android` b
ON
  a.publisher.app_market_bundle = b.package_name
WHERE
  date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND a.campaign.os = 'ANDROID'
  AND a.campaign.country IN ('ARG', 'BRA', 'CAN', 'DEU', 'IRL', 'MEX', 'NLD', 'NZL', 'PER', 'PHL', 'ZAF', 'GBR', 'VEN')
  AND a.publisher.app_market_bundle IS NOT NULL
GROUP BY 1,2,3,4,5
)

SELECT
  os,
  publisher_bundle,
  publisher_name,
  content_rating,
  market_url
FROM
  android_publisher_list
WHERE
  content_rating IN ('Mature 17+', 'Adults only 18+', 'PEGI 18', 'Rated for 18+', 'Restricted to 18+', 'USK: Ages 18+', 'Rated 18+', '18+')
  AND spend_l60 > 0
--   AND (spend_former_week = 0 OR spend_former_week IS NULL)
ORDER BY
  spend_l60 DESC

/* Check rating distribtuion */
/* Modified code for KOR RMG customer */ 

SELECT  
    content_rating,
    count(1) as cnt
FROM ios_publisher_list_l60
GROUP BY 1


/* EMEA Reference */
WITH br AS (
  SELECT
    app_bundle,
    ANY_VALUE(rating) AS matters_content_rating,
    ANY_VALUE(dataai.app_name) AS app_name,
    ANY_VALUE(dataai.genre) AS dataai_app_genre,
    ANY_VALUE(dataai.sub_genre) AS dataai_app_sub_genre,
    CASE 
      WHEN inventory_format = "I" THEN "Interstitial"
      WHEN inventory_format = "B" THEN "Banner"
      WHEN inventory_format = "N" THEN "Native"
    END AS inventory_format,
    SUM(1 / sample_rate) AS bid_requests,
    SUM(
      CASE 
        WHEN inventory_format = "I" THEN 1 / sample_rate * 20 * 0.05 / 1000
        WHEN inventory_format = "B" THEN 1 / sample_rate * 0.2 * 0.2 / 1000
        WHEN inventory_format = "N" THEN 1 / sample_rate * 0.15 * 0.1 / 1000
      END
    ) AS estimated_spend_potential
  FROM `focal-elf-631.prod.bidrequest20*` br
  LEFT JOIN (
    SELECT
      trackId AS app_bundle,
      trackContentRating AS rating
    FROM `moloco-dsp-supply-prod.matters42.iab_v3_ios` 
    UNION ALL     
    SELECT
      package_name AS app_bundle,
      content_rating AS rating
    FROM `moloco-dsp-supply-prod.matters42.iab_v3_android` 
  ) USING (app_bundle)
  LEFT JOIN `moloco-ae-view.athena.dim1_app` ON app_market_bundle = app_bundle
  WHERE
    _TABLE_SUFFIX BETWEEN FORMAT_DATE('%y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY))
    AND FORMAT_DATE('%y%m%d', CURRENT_DATE())
    AND country = "GBR"
    AND UPPER(br.os) IN ("ANDROID", "IOS")
  GROUP BY 1,6
)
SELECT
  app_bundle,
  matters_content_rating,
  app_name,
  dataai_app_genre,
  dataai_app_sub_genre,
  SUM(CASE WHEN inventory_format = "Interstitial" THEN bid_requests ELSE 0 END) AS interstitial_bid_requests,
  SUM(CASE WHEN inventory_format = "Banner" THEN bid_requests ELSE 0 END) AS banner_bid_requests,
  SUM(CASE WHEN inventory_format = "Native" THEN bid_requests ELSE 0 END) AS native_bid_requests,
  SUM(CASE WHEN inventory_format = "Interstitial" THEN estimated_spend_potential ELSE 0 END) AS interstitial_estimated_spend,
  SUM(CASE WHEN inventory_format = "Banner" THEN estimated_spend_potential ELSE 0 END) AS banner_estimated_spend,
  SUM(CASE WHEN inventory_format = "Native" THEN estimated_spend_potential ELSE 0 END) AS native_estimated_spend
FROM br
GROUP BY 1, 2, 3, 4, 5
ORDER BY 
  (SUM(CASE WHEN inventory_format = "Interstitial" THEN bid_requests ELSE 0 END) +
   SUM(CASE WHEN inventory_format = "Banner" THEN bid_requests ELSE 0 END) +
   SUM(CASE WHEN inventory_format = "Native" THEN bid_requests ELSE 0 END)) DESC;



### req to imp ratio and CPM KOR CUSTOMER TARGET COUNTRIES
WITH supply_metrics AS (
    SELECT
    country,
    os,
    CASE WHEN LOWER(inventory_format) IN ('interstitial', 'video interstitial') THEN 'Interstitial' ELSE inventory_format END AS inventory_format,
    SUM(req) AS req,
    SUM(bid) AS bid,
    SUM(imp) AS imp,
    SAFE_DIVIDE(COALESCE(SUM(imp),0), COALESCE(SUM(req),0)) AS req_to_imp_ratio,
    SAFE_DIVIDE(COALESCE(SUM(media_cost),0), COALESCE(SUM(imp),0)) * 1000 AS cpm
    FROM `moloco-data-prod.exchange_monitoring.supply_side_raw_prod`
    WHERE
    utc_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    AND country = 'CAN'
    AND os in ('ANDROID', 'IOS')
    GROUP BY ALL
    ORDER BY country, os
),
br AS (
  SELECT
    app_bundle,
    br.os,
    ANY_VALUE(rating) AS matters_content_rating,
    ANY_VALUE(dataai.app_name) AS app_name,
    ANY_VALUE(dataai.genre) AS dataai_app_genre,
    ANY_VALUE(dataai.sub_genre) AS dataai_app_sub_genre,
    CASE 
      WHEN br.inventory_format = "I" THEN "Interstitial"
      WHEN br.inventory_format = "B" THEN "Banner"
      WHEN br.inventory_format = "N" THEN "Native"
    END AS inventory_format,
    SUM(1 / sample_rate) AS bid_requests,
    SUM(
      1 / sample_rate * sm.cpm * sm.req_to_imp_ratio / 1000
    ) AS estimated_spend_potential
  FROM `focal-elf-631.prod.bidrequest20*` br
    LEFT JOIN supply_metrics sm 
        ON br.country = sm.country AND
            LOWER(br.os) = LOWER(sm.os) AND
            LOWER(CASE 
                WHEN br.inventory_format = "I" THEN "Interstitial"
                WHEN br.inventory_format = "B" THEN "Banner"
                WHEN br.inventory_format = "N" THEN "Interstitial"
                END ) = LOWER(sm.inventory_format)
    LEFT JOIN (
        SELECT
        trackId AS app_bundle,
        trackContentRating AS rating
        FROM `moloco-dsp-supply-prod.matters42.iab_v3_ios` 
        UNION ALL     
        SELECT
        package_name AS app_bundle,
        content_rating AS rating
        FROM `moloco-dsp-supply-prod.matters42.iab_v3_android` 
  ) USING (app_bundle)
  LEFT JOIN `moloco-ae-view.athena.dim1_app` ON app_market_bundle = app_bundle
  WHERE 
    _TABLE_SUFFIX BETWEEN FORMAT_DATE('%y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY))
        AND FORMAT_DATE('%y%m%d', CURRENT_DATE())
    AND br.country = "CAN"
    AND UPPER(br.os) in ('ANDROID', 'IOS')
    AND rating IN ('17+','Mature 17+', 'Adults only 18+', 'PEGI 18', 'Rated for 18+', 'Restricted to 18+', 'USK: Ages 18+', 'Rated 18+', '18+')
GROUP BY 1, 2, 7
),

publisher AS (
    SELECT 
        *,
        interstitial_bid_requests + banner_bid_requests + native_bid_requests AS total_bid_requests,
        interstitial_estimated_spend + banner_estimated_spend + native_estimated_spend AS total_est_spends
    FROM (

        SELECT
            os,
            app_bundle, 
            matters_content_rating,
            app_name,
            dataai_app_genre,
            dataai_app_sub_genre,
            SUM(CASE WHEN inventory_format = "Interstitial" THEN bid_requests ELSE 0 END) AS interstitial_bid_requests,
            SUM(CASE WHEN inventory_format = "Banner" THEN bid_requests ELSE 0 END) AS banner_bid_requests,
            SUM(CASE WHEN inventory_format = "Native" THEN bid_requests ELSE 0 END) AS native_bid_requests,
            SUM(CASE WHEN inventory_format = "Interstitial" THEN estimated_spend_potential ELSE 0 END) AS interstitial_estimated_spend,
            SUM(CASE WHEN inventory_format = "Banner" THEN estimated_spend_potential ELSE 0 END) AS banner_estimated_spend,
            SUM(CASE WHEN inventory_format = "Native" THEN estimated_spend_potential ELSE 0 END) AS native_estimated_spend
        FROM br
        GROUP BY 1,2,3,4,5,6
    )
    ORDER BY total_est_spends DESC
)

SELECT 
    fact_dsp_publisher.campaign.os,
    fact_dsp_publisher.exchange  AS fact_dsp_publisher_exchange,
    COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS fact_dsp_publisher_gross_spend_usd
FROM `moloco-ae-view.athena.fact_dsp_publisher` AS fact_dsp_publisher
WHERE fact_dsp_publisher.publisher.app_market_bundle IN (SELECT app_bundle FROM publisher)
    AND fact_dsp_publisher.date_utc BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY) AND CURRENT_DATE()
    AND (fact_dsp_publisher.campaign.country ) IN ('CAN')
GROUP BY 1,2

/* Top spending publishers for campaigns from app bundles with IAB9-7 
    AND exchang edistribution for the last 90 days
*/

WITH publisher_app_bundle AS (
    SELECT 
        fact_dsp_publisher.campaign.os,
        publisher.app_market_bundle AS publisher_app_market_bundle,
        publisher_dim1_app.dataai.genre  AS genre,
        publisher_dim1_app.dataai.sub_genre  AS sub_genre,
        COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS spend
    FROM `moloco-ae-view.athena.fact_dsp_publisher` AS fact_dsp_publisher
        LEFT JOIN `moloco-ae-view.athena.dim1_app`  AS publisher_dim1_app 
        ON fact_dsp_publisher.publisher.app_market_bundle = publisher_dim1_app.app_market_bundle
    WHERE   
        ((( TIMESTAMP(fact_dsp_publisher.date_utc)  ) >= ((TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY))) 
            AND ( TIMESTAMP(fact_dsp_publisher.date_utc)  ) < ((TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY), INTERVAL 90 DAY))))) 
        AND (fact_dsp_publisher.product.iab_category ) = 'IAB9-7' 
        AND (fact_dsp_publisher.campaign.country ) IN ('CAN', 'USA')
    GROUP BY 1,2,3,4
    HAVING spend > 1000
)

SELECT
    publisher_app_bundle.os,
    fact_dsp_publisher.exchange  AS fact_dsp_publisher_exchange,
    COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS fact_dsp_publisher_gross_spend_usd
FROM `moloco-ae-view.athena.fact_dsp_publisher` AS fact_dsp_publisher
    INNER JOIN publisher_app_bundle ON fact_dsp_publisher.publisher.app_market_bundle = publisher_app_bundle.publisher_app_market_bundle
WHERE 
    ((( TIMESTAMP(fact_dsp_publisher.date_utc)  ) >= ((TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY))) 
            AND ( TIMESTAMP(fact_dsp_publisher.date_utc)  ) < ((TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY), INTERVAL 90 DAY))))) 
        -- AND (fact_dsp_publisher.product.iab_category ) = 'IAB9-7' 
        AND (fact_dsp_publisher.campaign.country ) IN ('CAN', 'USA')
GROUP BY 1, 2


/* Contents Rating Distribution For the publishers reached by IAB9-7 campaigns over the past 90 days with spend>1000 */

--- IOS 
WITH publisher_app_bundle AS (
    SELECT 
        fact_dsp_publisher.campaign.os,
        publisher.app_market_bundle AS publisher_app_market_bundle,
        publisher_dim1_app.dataai.genre  AS genre,
        publisher_dim1_app.dataai.sub_genre  AS sub_genre,
        COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS spend
    FROM `moloco-ae-view.athena.fact_dsp_publisher` AS fact_dsp_publisher
        LEFT JOIN `moloco-ae-view.athena.dim1_app`  AS publisher_dim1_app 
        ON fact_dsp_publisher.publisher.app_market_bundle = publisher_dim1_app.app_market_bundle
    WHERE   
        ((( TIMESTAMP(fact_dsp_publisher.date_utc)  ) >= ((TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY))) 
            AND ( TIMESTAMP(fact_dsp_publisher.date_utc)  ) < ((TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY), INTERVAL 90 DAY))))) 
        AND (fact_dsp_publisher.product.iab_category ) = 'IAB9-7' 
        AND (fact_dsp_publisher.campaign.country ) IN ('CAN', 'USA')
    GROUP BY 1,2,3,4
    HAVING spend > 1000
)

SELECT
    publisher_app_bundle.*,
    iab.trackCensoredName AS publisher_name,
    iab.trackContentRating AS content_rating,
    iab.trackViewUrl AS market_url
FROM 
    publisher_app_bundle 
    LEFT JOIN `moloco-dsp-supply-prod.matters42.iab_v3_ios` iab
        ON publisher_app_bundle.publisher_app_market_bundle = iab.trackId
WHERE publisher_app_bundle.os = 'IOS'

--- ANDROID


WITH publisher_app_bundle AS (
    SELECT 
        fact_dsp_publisher.campaign.os,
        publisher.app_market_bundle AS publisher_app_market_bundle,
        publisher_dim1_app.dataai.genre  AS genre,
        publisher_dim1_app.dataai.sub_genre  AS sub_genre,
        COALESCE(SUM(fact_dsp_publisher.gross_spend_usd ), 0) AS spend
    FROM `moloco-ae-view.athena.fact_dsp_publisher` AS fact_dsp_publisher
        LEFT JOIN `moloco-ae-view.athena.dim1_app`  AS publisher_dim1_app 
        ON fact_dsp_publisher.publisher.app_market_bundle = publisher_dim1_app.app_market_bundle
    WHERE   
        ((( TIMESTAMP(fact_dsp_publisher.date_utc)  ) >= ((TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY))) 
            AND ( TIMESTAMP(fact_dsp_publisher.date_utc)  ) < ((TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP_TRUNC(TIMESTAMP(FORMAT_TIMESTAMP('%F %H:%M:%E*S', CURRENT_TIMESTAMP(), 'UTC')), DAY), INTERVAL -89 DAY), INTERVAL 90 DAY))))) 
        AND (fact_dsp_publisher.product.iab_category ) = 'IAB9-7' 
        AND (fact_dsp_publisher.campaign.country ) IN ('CAN', 'USA')
    GROUP BY 1,2,3,4
    HAVING spend > 1000
)

SELECT
    publisher_app_bundle.*,
    iab.package_name AS publisher_name,
    iab.content_rating,
    iab.market_url
FROM 
    publisher_app_bundle 
    LEFT JOIN `moloco-dsp-supply-prod.matters42.iab_v3_android` iab 
        ON publisher_app_bundle.publisher_app_market_bundle = iab.package_name
WHERE publisher_app_bundle.os = 'ANDROID'


