/*
- focal-elf-631.prod_stream_view.clicks
- Clicks from a Moloco campaign

SCHEMA
- timestamp
- platform_id
- advertiser_id
- req
- bid
- api
  - platform
  - advertiser
  - product
  - campaign
    - id
    - title
    - skan_id
    - skan_tr_suffix
  - trgroup
  - adgroup
  - crgroup
  - creative
  - tracking_links
- imp
- imp_extra
- ev
- ec
- click
- compliance
*/


-- impact of click without catalog_id

DECLARE run_from_date DATE DEFAULT "2024-01-01";
DECLARE run_to_date DATE DEFAULT "2024-12-09";

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
# impressions with bid_region=’ASIA’, clicks and click url w.o. catalog_id

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
        advertiser.id IN ('HKRCcBXgyO9rR9Pb', 'DyD0GQNf7zlp4hwy')
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
  
  click_raw_t AS (
    SELECT
        platform_id,
        advertiser_id,
        click.happened_at as timestamp,
        bid.mtid,
        click.generated_click_url,
        REGEXP_EXTRACT(click.generated_click_url, r'&af_dp=([^&]*)') AS catalog_item_id,
        imp.win_price_usd.amount_micro AS media_cost
    FROM
      `focal-elf-631.prod_stream_view.click`
    WHERE 
      DATE(timestamp) BETWEEN run_from_date AND run_to_date
      AND advertiser_id IN ('HKRCcBXgyO9rR9Pb', 'DyD0GQNf7zlp4hwy')
      AND req.bid_region = 'ASIA'
      AND api.creative.cr_format in ("di", "db")
  ),

  click_join_t AS (
    SELECT
      C.platform_id,
      C.advertiser_id,
      DATE(C.timestamp, A.advertiser_timezone) AS local_date,
      A.platform_serving_cost_percent,
      A.platform_markup_percent,
      SUM(C.media_cost / 1e6) AS win_price_usd,
      COUNT(DISTINCT C.mtid) AS imp,
    FROM click_raw_t C
    JOIN  advertiser AS A
    ON C.platform_id=A.platform_id
      AND C.advertiser_id=A.advertiser_id
      AND A.effective_date_local<=DATE(C.timestamp, A.advertiser_timezone)
      AND DATE(C.timestamp, A.advertiser_timezone)<=A.last_effective_date_local
    WHERE
      catalog_item_id IS NULL
    GROUP BY ALL
  )

SELECT
  C.platform_id,
  C.advertiser_id,
  C.local_date,
  SAFE_CAST(SUM(C.win_price_usd * (1 + C.platform_serving_cost_percent/100) * (1 + C.platform_markup_percent/100)) AS FLOAT64) AS gross_spending_usd,
  SUM(C.imp) AS imp,
FROM
  click_join_t AS C
GROUP BY ALL
