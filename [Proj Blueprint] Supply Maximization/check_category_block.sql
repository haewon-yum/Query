DECLARE spend_date_start DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY);
DECLARE spend_date_end DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);

WITH
advertiser_tab AS (
SELECT
    office,
    CASE
    WHEN office = 'EMEA' THEN 'EMEA'
    WHEN office = 'USA' THEN 'AMER'
    WHEN office IN ('KOR', 'IND', 'JPN', 'SGP', 'CHN') THEN 'APAC'
    ELSE 'Other'
    END AS region,
    tier,
    account_manager,
    advertiser_id
FROM
    (
    SELECT
        date_utc,
        ROW_NUMBER() OVER(PARTITION BY advertiser_id ORDER BY date_utc DESC, effective_date DESC) AS rnk,
        advertiser_id,
        office,
        account_manager,
        tier,
        effective_date,
        end_date
    FROM
        `moloco-ae-view.athena.dim2_platform_advertiser_daily`
    )
WHERE
    rnk = 1
),

campaign_tab as (
SELECT
    office,
    region,
    tier,
    account_manager,
    platform_name,
    advertiser_name AS advertiser_id,
    advertiser_display_name AS advertiser,
    store_bundle,
    tracking_bundle,
    product_category,
    CASE
    WHEN app.is_gaming = true THEN 'gaming'
    WHEN app.is_gaming = false THEN 'non-gaming'
    ELSE 'N/A'
    END AS gaming,
    a.os,
    JSON_EXTRACT_SCALAR(campaign_goal, "$.type") AS campaign_goal,
    campaign_name AS campaign_id,
    campaign_display_name AS campaign,
    DATE(created_timestamp_nano) AS campaign_start_date
FROM
    `ads-bpd-guard-china.prod.campaign_digest_merged_latest` a
LEFT JOIN
    advertiser_tab b
ON
    a.advertiser_name = b.advertiser_id
LEFT JOIN
    `ads-bpd-guard-china.athena.dim1_product` c
ON
    a.product_name = c.product_id
WHERE
    state = "ACTIVE"
    AND enabled
    AND a.os IN ('IOS', 'ANDROID')
),

adgroup_tab as (
SELECT
    ad_group_id,
    campaign_id,
    target_id
FROM
    `ads-bpd-guard-china.standard_digest.ad_group_digest`
CROSS JOIN
    UNNEST(JSON_VALUE_ARRAY(original_json, "$.user_targets")) as target_id
WHERE
    NOT is_archived
    AND JSON_EXTRACT_SCALAR(original_json, "$.disabled") = 'false'
),

################### <START> CTE''s of exclusion targeting ###################
target_tab AS (
SELECT
    id AS target_id,
    JSON_QUERY(original_json, "$.condition") AS condition_json,
FROM
    `focal-elf-631.standard_digest.audience_target_digest`
),

potential_blocked_dimension AS (
SELECT
    DISTINCT 
    office,
    region,
    tier,
    account_manager,
    platform_name,
    advertiser_id,
    advertiser,
    store_bundle,
    tracking_bundle,
    product_category,
    os,
    campaign_goal,
    campaign_id,
    campaign,
    campaign_start_date,
    ad_group_id,                  
    target_id,
    condition_json,
    JSON_EXTRACT(condition_json, '$.blocked_categories') AS blocked_categories,
    JSON_EXTRACT_ARRAY(condition_json, '$.blocked_categories') AS blocked_categories_2,
FROM
    campaign_tab
JOIN
    adgroup_tab
USING
    (campaign_id)
JOIN
    target_tab
USING
    (target_id)
),

campaigns_with_spend AS (
  SELECT 
    campaign_id,
    SUM(gross_spend_usd) AS total_spend
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE date_utc BETWEEN spend_date_start AND spend_date_end
    AND campaign.os IN ('IOS','ANDROID')
  GROUP BY 1
  HAVING total_spend > 0
),

blocked_flattened AS (
  SELECT 
    campaign_id,
    ad_group_id,
    JSON_EXTRACT_SCALAR(cat) AS category
  FROM potential_blocked_dimension,
    UNNEST(
      IF(
        JSON_EXTRACT_ARRAY(condition_json, '$.blocked_categories') IS NULL 
        OR ARRAY_LENGTH(JSON_EXTRACT_ARRAY(condition_json, '$.blocked_categories')) = 0,
        [], 
        JSON_EXTRACT_ARRAY(condition_json, '$.blocked_categories')
      )
    ) AS cat
  WHERE JSON_EXTRACT_SCALAR(cat) IS NOT NULL 
),

global_summary AS (
  SELECT
    c.office,
    c.region,
    c.tier,
    c.account_manager,
    c.platform_name,
    c.advertiser_id,
    c.advertiser,
    c.store_bundle,
    c.tracking_bundle,
    c.product_category,
    c.os,
    c.campaign_goal,
    c.campaign_id,
    c.campaign,
    c.campaign_start_date,
    s.total_spend,
    IF(
      COUNT(b.category) = 0,
      [],  -- category 없음 → 빈 배열
      ARRAY_AGG(DISTINCT b.category ORDER BY b.category)
    ) AS blocked_categories

  FROM campaign_tab c
  LEFT JOIN blocked_flattened b
    ON c.campaign_id = b.campaign_id
  LEFT JOIN campaigns_with_spend s 
    ON c.campaign_id = s.campaign_id
  GROUP BY
    c.office, c.region, c.tier, c.account_manager, c.platform_name, c.advertiser_id,
    c.advertiser, c.store_bundle, c.tracking_bundle, c.product_category,
    c.os, c.campaign_goal, c.campaign_id, c.campaign, c.campaign_start_date, s.total_spend
)

SELECT 
  IF(ARRAY_LENGTH(blocked_categories)> 0, 'has_block', 'no_blocks') ,
  COUNT(1) AS cnt,
  ROUND(SUM(total_spend),0) AS spend
FROM global_summary
GROUP BY 1
