DECLARE start_date DATE DEFAULT DATE '2025-07-01';
DECLARE end_date   DATE DEFAULT DATE '2025-08-25';
DECLARE advertiser_id STRING DEFAULT 'MiKsOLLsnkAbjDx1';
DECLARE campaign_id   STRING DEFAULT 'eEh1zk9dF6kh6zM3';
DECLARE crgroup_id    STRING DEFAULT 'I1ys8iYYk6CK8PMP';


CREATE OR REPLACE TABLE `moloco-ods.haewon.naverwebtoon_dpa_performance` AS
-- 1) Map products (items) exposed per mtid from dcr_selection*
WITH
  product_data AS (
  SELECT
    mtid,
    ANY_VALUE(selected.item)       AS item,
    -- If there are multiple items per mtid, use the first/representative one
    ANY_VALUE(selected.item_title) AS item_title,
    ANY_VALUE(app_bundle)          AS app_bundle
  FROM
    `focal-elf-631.prod.dcr_selection*`,
    UNNEST(dcr.selected_items) AS selected
  WHERE
    advertiser = advertiser_id
    -- Filter table shards (suffix) by date range (YYYYMMDD)
    AND _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', start_date)
                         AND FORMAT_DATE('%Y%m%d', end_date)
  GROUP BY mtid
),

-- 2) Impressions that meet the conditions (product mapping + spend per impression)
imp_base AS (
  SELECT
    im.bid.mtid               AS mtid,
    pd.item,
    pd.item_title,
    -- Spend per impression in USD (amount_micro -> USD)
    COALESCE(
      im.imp.cost.analysis.demand_charge_cost.usd.amount_micro / 1e6,
      0.0
    ) AS spend_usd
  FROM `focal-elf-631.prod_stream_view.imp` AS im
  JOIN product_data AS pd
    ON pd.mtid = im.bid.mtid
  WHERE
    im.api.advertiser.id = advertiser_id
    AND im.api.campaign.id   = campaign_id
    AND im.api.crgroup.id    = crgroup_id
    AND im.api.creative.cr_format IN ('di','db')
    -- Partition/date filter for imp
    AND DATE(im.timestamp) BETWEEN start_date AND end_date
),

-- 3) Pre-aggregate: impressions & spend per item
imp_item AS (
  SELECT
    item,
    ANY_VALUE(item_title) AS item_title,
    COUNT(*)              AS impressions,
    SUM(spend_usd)        AS spend_usd
  FROM imp_base
  GROUP BY item
),

-- 4) Clicks matched to impressions (CTR = clicks / impressions)
click_item AS (
  SELECT
    ib.item,
    COUNT(*) AS clicks
  FROM `focal-elf-631.prod_stream_view.click` AS ck
  JOIN imp_base AS ib
    ON ib.mtid = ck.bid.mtid
  WHERE
    ck.api.advertiser.id = advertiser_id
    AND ck.api.campaign.id   = campaign_id
    -- Partition/date filter for click: start_date or later
    AND DATE(ck.timestamp) >= start_date
  GROUP BY ib.item
),

-- 5) Install records (one per mtid)
installs AS (
  SELECT
    cv.bid.mtid              AS mtid,
    cv.install.install_at_pb AS install_at
  FROM `focal-elf-631.prod_stream_view.cv` AS cv
  WHERE
    cv.api.advertiser.id = advertiser_id
    AND cv.api.campaign.id   = campaign_id
    -- Install events only
    AND cv.install.event_pb  = 'install'
    -- Date filters (install-based + partition)
    AND DATE(cv.install.install_at_pb) BETWEEN start_date AND end_date
    AND DATE(cv.timestamp) >= start_date
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY cv.bid.mtid
    ORDER BY cv.install.install_at_pb
  ) = 1
),

-- 6) Installs per item
install_item AS (
  SELECT
    ib.item,
    COUNT(*) AS installs
  FROM installs i
  JOIN imp_base ib
    ON ib.mtid = i.mtid
  GROUP BY ib.item
),

-- 7) D7 revenue per mtid (7-day window from install time)
revenue_7d_per_mtid AS (
  SELECT
    i.mtid,
    SUM(cv2.cv.revenue_usd.amount) AS revenue_7d_usd
  FROM installs i
  JOIN `focal-elf-631.prod_stream_view.cv` AS cv2
    ON cv2.bid.mtid = i.mtid
   AND cv2.cv.revenue_usd.amount > 0
   -- Partition/date filter for cv
   AND DATE(cv2.timestamp) >= start_date
   -- Use pb.event.event_at if available, otherwise cv.happened_at
   AND COALESCE(cv2.cv.pb.event.event_at, cv2.cv.happened_at) >= i.install_at
   AND COALESCE(cv2.cv.pb.event.event_at, cv2.cv.happened_at) <  i.install_at + INTERVAL 7 DAY
  GROUP BY i.mtid
),

-- 8) D7 revenue per item
revenue_item AS (
  SELECT
    ib.item,
    SUM(r.revenue_7d_usd) AS revenue_7d_usd
  FROM revenue_7d_per_mtid r
  JOIN imp_base ib
    ON ib.mtid = r.mtid
  GROUP BY ib.item
)

-- 9) Final: item-level KPIs (CTR, Installs, Spend, CPI, D7 Revenue, ROAS D7)
SELECT
  im.item,
  im.item_title,
  im.impressions,
  COALESCE(ci.clicks, 0)                    AS clicks,
  SAFE_DIVIDE(COALESCE(ci.clicks, 0), im.impressions) AS ctr,
  COALESCE(ii.installs, 0)                  AS installs,
  im.spend_usd                               AS spend_usd,
  -- CPI = total spend / installs
  SAFE_DIVIDE(im.spend_usd, COALESCE(ii.installs, 0)) AS cpi,
  COALESCE(ri.revenue_7d_usd, 0.0)          AS revenue_7d_usd,
  -- ROAS D7 = D7 revenue / spend
  SAFE_DIVIDE(COALESCE(ri.revenue_7d_usd, 0.0), NULLIF(im.spend_usd, 0)) AS roas_d7
FROM imp_item im
LEFT JOIN click_item   ci ON ci.item = im.item
LEFT JOIN install_item ii ON ii.item = im.item
LEFT JOIN revenue_item ri ON ri.item = im.item
ORDER BY roas_d7 DESC, revenue_7d_usd DESC, installs DESC, clicks DESC;




#### Refined ####

  DECLARE start_date DATE DEFAULT DATE '2025-07-01';
  DECLARE end_date   DATE DEFAULT DATE '2025-09-03';
  DECLARE advertiser_id STRING DEFAULT 'MiKsOLLsnkAbjDx1';
  DECLARE campaign_id   STRING DEFAULT 'eEh1zk9dF6kh6zM3';
  DECLARE crgroup_id    STRING DEFAULT 'I1ys8iYYk6CK8PMP';


  WITH
    product_data AS (
    SELECT
      mtid,
      selected.item AS item_id
    FROM
      `focal-elf-631.prod.dcr_selection*`,
      UNNEST(dcr.selected_items) AS selected
    WHERE
      advertiser = advertiser_id
      AND campaign = campaign_id
      AND cr_group = crgroup_id
      AND _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', start_date)
                          AND FORMAT_DATE('%Y%m%d', end_date)
  ),
  -- 2) Impressions that meet the conditions (product mapping + spend per impression)
    imp_base AS (
      SELECT
        im.bid.mtid               AS mtid,
        pd.item_id,
        -- pd.item_title,
        -- Spend per impression in USD (amount_micro -> USD)
        COALESCE(
          im.imp.cost.analysis.demand_charge_cost.usd.amount_micro / 1e6,
          0.0
        ) AS spend_usd
      FROM `focal-elf-631.prod_stream_view.imp` AS im
      JOIN product_data AS pd
        ON pd.mtid = im.bid.mtid
      WHERE
        im.api.advertiser.id = advertiser_id
        AND im.api.campaign.id   = campaign_id
        AND im.api.crgroup.id    = crgroup_id
        AND DATE(im.timestamp) BETWEEN start_date AND end_date
    ),

 -- 3) Click
    click AS (
    SELECT
        DATE(timestamp) date,
        bid.mtid,      
        click.dcr.catalog_item_id AS item_id,  
    FROM
      `focal-elf-631.prod_stream_view.click`
    WHERE 
      DATE(timestamp) >= start_date
      AND api.campaign.id = campaign_id
      AND api.crgroup.id = crgroup_id      
  ),

  -- 4) Install records (one per mtid)
  installs AS (
    SELECT
      cv.bid.mtid              AS mtid,
      click.dcr.catalog_item_id AS item_id,
      IF(click.dcr.catalog_item_id IS NULL, 'VT', 'CT') AS install_type,
      cv.install.install_at_pb AS install_at
    FROM `focal-elf-631.prod_stream_view.cv` AS cv
    WHERE
      cv.api.advertiser.id = advertiser_id
      AND cv.api.campaign.id   = campaign_id
      AND cv.api.crgroup.id = crgroup_id
      -- Install events only
      AND UPPER(cv.cv.event) = 'INSTALL'
      AND DATE(cv.install.install_at_pb) BETWEEN start_date AND DATE_ADD(end_date, INTERVAL 1 DAY)
      AND DATE(cv.timestamp) >= start_date
    QUALIFY ROW_NUMBER() OVER (PARTITION BY cv.bid.mtid ORDER BY cv.install.install_at_pb) = 1
  ),

  joined AS (

    SELECT 
      imp_base.mtid,
      imp_base.spend_usd,
      imp_base.item_id AS view_item_id,
      click.item_id AS click_item_id,
      installs.mtid AS install_mtid,
    FROM imp_base 
    LEFT JOIN click USING(mtid, item_id)
    LEFT JOIN installs USING(mtid)
    -- LIMIT 100
  ),

  CT AS (
    SELECT 
      mtid, 
      click_item_id
    FROM joined
    WHERE 
      view_item_id = click_item_id
      AND click_item_id IS NOT NULL
  ),

  filtered_joined AS (
  ## If CT , relgardless of install, keep only one mtid / item_id
    SELECT joined.*, 
      'CT' AS attr_type
    FROM joined 
      JOIN CT
      ON joined.mtid = CT.mtid AND joined.view_item_id = CT.click_item_id

    UNION ALL

  ## For VT, relgardless of install, keep every mtid / item_id
    SELECT *,
      'VT' AS attr_type
    FROM joined 
    WHERE mtid NOT IN (SELECT DISTINCT mtid FROM CT_install)

  ),


  SELECT 
    view_item_id,
    attr_type,
    COUNT(DISTINCT mtid) AS cnt_impression,
    SUM(spend_usd) AS spend,
    COUNT(DISTINCT install_mtid) AS cnt_install,
    SUM(spend_usd) / COUNT(DISTINCT install_mtid) AS cpi
  FROM filtered_joined 
  GROUP BY ALL 

--   -- 7) D7 revenue per mtid (7-day window from install time)
--   revenue_7d_per_mtid AS (
--     SELECT
--       i.mtid,
--       SUM(cv2.cv.revenue_usd.amount) AS revenue_7d_usd
--     FROM installs i
--     JOIN `focal-elf-631.prod_stream_view.cv` AS cv2
--       ON cv2.bid.mtid = i.mtid
--     AND cv2.cv.revenue_usd.amount > 0
--     -- Partition/date filter for cv
--     AND DATE(cv2.timestamp) >= start_date
--     -- Use pb.event.event_at if available, otherwise cv.happened_at
--     AND cv2.cv.pb.event.event_at >= i.install_at
--     AND cv2.cv.pb.event.event_at <  i.install_at + INTERVAL 7 DAY
--     GROUP BY i.mtid
--   )


    -- SELECT
    --   *
    -- FROM `focal-elf-631.prod_stream_view.cv` 
    -- WHERE
    --   api.advertiser.id = advertiser_id
    --   AND api.campaign.id   = campaign_id
    --   AND api.crgroup.id = crgroup_id
    --   AND cv.revenue_usd.amount > 0
    --   -- Partition/date filter for cv
    --   AND DATE(timestamp) >= start_date
    --   -- Use pb.event.event_at if available, otherwise cv.happened_at
    --   AND cv.pb.event.event_at >= cv.install_at_pb
    --   AND cv.pb.event.event_at <  cv.install_at_pb + INTERVAL 7 DAY
    --   -- GROUP BY i.mtid






-- SELECT *
-- FROM installs
-- WHERE item_id IS NOT NULL

  --   click AS (
  --   SELECT
  --     DATE(timestamp) date,
  --     click.dcr.catalog_item_id AS id,
  --     COUNT(1) click
  --   FROM
  --     `focal-elf-631.prod_stream_view.click`
  --   WHERE
  --     DATE(timestamp) >= start_date
  --     AND api.campaign.id = campaign_id
  --     AND api.crgroup.id = crgroup_id
  --   GROUP BY
  --     1,
  --     2),
  --   install AS (
  --   SELECT
  --     DATE(timestamp) date,
  --     click.dcr.catalog_item_id AS id,
  --     COUNT(1) install
  --   FROM
  --     `focal-elf-631.prod_stream_view.cv`
  --   WHERE
  --     DATE(timestamp) >= start_date
  --     AND api.campaign.id = campaign_id
  --     AND api.crgroup.id = crgroup_id
  --     AND cv.event = 'INSTALL'
  --   GROUP BY
  --     1,
  --     2 ),
  --   action AS (
  --   SELECT
  --     DATE(timestamp) date,
  --     click.dcr.catalog_item_id AS id,
  --     COUNT(1) action,
  --     SUM(cv.revenue_usd.amount) AS total_revenue
  --   FROM
  --     `focal-elf-631.prod_stream_view.cv`
  --   WHERE
  --     DATE(timestamp) >= start_date
  --     AND api.campaign.id = campaign_id
  --     AND api.crgroup.id = crgroup_id
  --     AND cv.event = 'CUSTOM_KPI_ACTION'
  --   GROUP BY
  --     1,
  --     2 )
  -- SELECT
  --   COALESCE(imp.date, click.date, install.date, action.date) AS date,
  --   COALESCE(imp.id, click.id, install.id, action.id) AS id,
  --   imp.item_title,
  --   imp.imp,
  --   imp.sum_of_win_price,
  --   click.click,
  --   install.install,
  --   action.action,
  --   action.total_revenue
  -- FROM
  --   imp
  -- FULL OUTER JOIN
  --   click
  -- USING
  --   (date, id)
  -- FULL OUTER JOIN
  --   install
  -- USING
  --   (date, id)
  -- FULL OUTER JOIN
  --   action
  -- USING
  --   (date, id)
  -- ORDER BY
  --   date, id