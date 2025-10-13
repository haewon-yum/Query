# top 10 publisher by date 
# ODSB-13833

-- 일자별 gross_spend_usd TOP 10
WITH fact_dsp_publisher AS (
  SELECT *
  FROM `ads-bpd-guard-china.athena.fact_dsp_publisher`
  WHERE TIMESTAMP(date_utc) >= TIMESTAMP('2025-08-01 00:00:00')
    AND TIMESTAMP(date_utc) <  TIMESTAMP('2025-09-24 00:00:00')
    -- 아래의 1=1 필터들은 불필요해서 제거했어요 (필요하면 되살리면 됩니다)
),
agg AS (
  SELECT
    DATE(TIMESTAMP(date_utc)) AS utc_date,
    publisher.app_market_bundle AS app_market_bundle,
    SUM(gross_spend_usd) AS gross_spend_usd
  FROM fact_dsp_publisher
  WHERE (campaign.title_id) = 'MolocoDSPInstall_NxK_UAGL_AOS(Ne6jBHMofOsE811P)'
  GROUP BY 1, 2
)
SELECT
  utc_date,
  app_market_bundle,
  gross_spend_usd
FROM agg
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY utc_date
  ORDER BY gross_spend_usd DESC
) <= 10
ORDER BY utc_date DESC, gross_spend_usd DESC;



## top 10 publishers with spend and i2p 

-- 일자별 gross_spend_usd TOP 10
WITH fact_dsp_publisher AS (
  SELECT *
  FROM `ads-bpd-guard-china.athena.fact_dsp_publisher`
  WHERE TIMESTAMP(date_utc) >= TIMESTAMP('2025-09-12 00:00:00')
    AND TIMESTAMP(date_utc) <  TIMESTAMP('2025-09-24 00:00:00')
    -- 아래의 1=1 필터들은 불필요해서 제거했어요 (필요하면 되살리면 됩니다)
),
agg AS (
  SELECT
    DATE(TIMESTAMP(date_utc)) AS utc_date,
    publisher.app_market_bundle AS app_market_bundle,
    SUM(installs) AS installs,
    SUM(kpi_payers_d7) AS kpi_payers,
    SAFE_DIVIDE(COALESCE(SUM(kpi_payers_d7), 0), COALESCE(SUM(installs ), 0)) AS i2p_d7,
    SUM(gross_spend_usd) AS gross_spend_usd
  FROM fact_dsp_publisher
  WHERE (campaign_id) = 'byJy685EjCDQ8Mri'
  GROUP BY 1, 2
)
SELECT
  utc_date,
  app_market_bundle,
  i2p_d7,
  gross_spend_usd
FROM agg
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY utc_date
  ORDER BY gross_spend_usd DESC
) <= 10
ORDER BY utc_date DESC, gross_spend_usd DESC;
