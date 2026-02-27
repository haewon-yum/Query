  WITH

  premium AS (
    WITH 
    
    premium_account AS (
      SELECT
        platform_id AS platform,
        advertiser_id
      FROM `moloco-ods.jira.premium_v2`
      WHERE quarter = "2025-Q1" AND region IN ("KOR (Korea)", "CHN (China)")
    )     
    SELECT
      DISTINCT
        a.advertiser_id,
        a.product_id,
        a.app_store_bundle AS app_market_bundle,
        c.platform,
        c.advertiser_id,
    FROM `focal-elf-631.standard_digest.product_digest` a
      JOIN premium_account c USING(platform)
    WHERE a.advertiser_id = c.advertiser_id OR c.advertiser_id IS NULL
  ),
  premium_titles AS(
    SELECT
      app_market_bundle,
      os,
      dataai.app_name,
      dataai.unified_app_name AS title,
      dataai.app_release_date_utc,
      dataai.company_id,
      dataai.parent_company_id,
      premium.platform
    FROM `moloco-ae-view.athena.dim1_app`
      JOIN premium USING(app_market_bundle)
  )

  SELECT
    DISTINCT
      app_market_bundle,
      os,
      dataai.app_name,
      dataai.unified_app_name AS title,
      dataai.app_release_date_utc,
      a.dataai.company_id,
      a.dataai.company_name,
      a.dataai.parent_company_id,
      a.dataai.parent_company_name,
      b.platform
  FROM `moloco-ae-view.athena.dim1_app` a JOIN ( SELECT DISTINCT company_id, parent_company_id, platform FROM premium_titles ) b
    ON a.dataai.company_id = b.company_id OR a.dataai.parent_company_id = b.parent_company_id
  WHERE dataai.app_release_date_utc BETWEEN '{start_date_release}' AND '{end_date_release}'
