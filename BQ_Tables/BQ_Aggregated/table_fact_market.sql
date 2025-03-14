/* 
    `moloco-ae-view.market_share.fact_market`

*/

SELECT
    install_date_utc,
    SAFE_DIVIDE(COALESCE(SUM(moloco.installs ), 0), 
        COALESCE(SUM(moloco.installs ), 0) + COALESCE(SUM(non_moloco.installs ), 0)) AS fact_market_share_of_installs,
    SAFE_DIVIDE(COALESCE(SUM(moloco.revenue_d7 ), 0), 
        COALESCE(SUM(moloco.revenue_d7 ), 0) + COALESCE(SUM(non_moloco.revenue_d7 ), 0)) AS fact_market_share_of_revenue_d7
FROM `moloco-ae-view.market_share.fact_market`  AS fact_market
WHERE (app_market_bundle ) 
    IN ('6451475891', 'com.tripeaks.fun') 
    AND ((( install_date_utc  ) >= (DATE('2023-09-23')) AND ( install_date_utc  ) < (DATE('2025-10-01'))))
GROUP BY ALL