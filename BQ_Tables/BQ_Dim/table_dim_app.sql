/*
- moloco-ae-view.athena.dim1_app

SCHEMA
- app_market_bundle
- os
- v2
- dataai
  - app_name
  - is_gaming
  - genre
  - sub_genre,
  ...
    
*/


SELECT 
  app_market_bundle,
  os,
  dataai.app_name,
  dataai.app_release_date_utc,
FROM `moloco-ae-view.athena.dim1_app`
WHERE DATE(dataai.app_release_date_utc) >= '2024-01-01'
