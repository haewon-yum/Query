-- ODSB-16084: Rocket Now - Geo Performance Analysis
-- Request: Campaign performance by geo (시/현 level)
-- Format: Month, OS, Campaign Goal, Region(시/현 level), Spend, Actions D7, CPA D7
-- Bundle: com.cpone.customer (로켓나우)

-- Note on Data Quality:
-- - Region data comes from req.device.geo.region field
-- - City level accuracy is ~80% (IP2Location)
-- - State/Region level accuracy is ~98%+
-- - Some bid requests may have missing location data

-- Step 1: Get spend data by region
WITH spend_by_region AS (
  SELECT
    FORMAT_DATE('%Y-%m', date_utc) AS month,
    platform_id,
    CASE 
      WHEN device.os IN ('IOS', 'ios', 'iOS') THEN 'iOS'
      WHEN device.os IN ('ANDROID', 'android', 'Android') THEN 'Android'
      ELSE device.os
    END AS os,
    campaign.goal AS campaign_goal,
    campaign.id AS campaign_id,
    campaign.title AS campaign_title,
    -- Region mapping for Korea
    CASE 
      WHEN req.device.geo.region IN ('Seoul', 'Seoul-teukbyeolsi', '서울', '서울특별시', '11') THEN '서울특별시'
      WHEN req.device.geo.region IN ('Busan', 'Busan-gwangyeoksi', '부산', '부산광역시', '26') THEN '부산광역시'
      WHEN req.device.geo.region IN ('Incheon', 'Incheon-gwangyeoksi', '인천', '인천광역시', '28') THEN '인천광역시'
      WHEN req.device.geo.region IN ('Daegu', 'Daegu-gwangyeoksi', '대구', '대구광역시', '27') THEN '대구광역시'
      WHEN req.device.geo.region IN ('Daejeon', 'Daejeon-gwangyeoksi', '대전', '대전광역시', '30') THEN '대전광역시'
      WHEN req.device.geo.region IN ('Gwangju', 'Gwangju-gwangyeoksi', '광주', '광주광역시', '29') THEN '광주광역시'
      WHEN req.device.geo.region IN ('Ulsan', 'Ulsan-gwangyeoksi', '울산', '울산광역시', '31') THEN '울산광역시'
      WHEN req.device.geo.region IN ('Sejong', 'Sejong-teukbyeoljachisi', '세종', '세종특별자치시', '36') THEN '세종특별자치시'
      WHEN req.device.geo.region IN ('Gyeonggi', 'Gyeonggi-do', '경기', '경기도', '41') THEN '경기도'
      WHEN req.device.geo.region IN ('Gangwon', 'Gangwon-do', '강원', '강원도', '42') THEN '강원도'
      WHEN req.device.geo.region IN ('North Chungcheong', 'Chungcheongbuk-do', '충북', '충청북도', '43') THEN '충청북도'
      WHEN req.device.geo.region IN ('South Chungcheong', 'Chungcheongnam-do', '충남', '충청남도', '44') THEN '충청남도'
      WHEN req.device.geo.region IN ('North Jeolla', 'Jeollabuk-do', '전북', '전라북도', '45') THEN '전라북도'
      WHEN req.device.geo.region IN ('South Jeolla', 'Jeollanam-do', '전남', '전라남도', '46') THEN '전라남도'
      WHEN req.device.geo.region IN ('North Gyeongsang', 'Gyeongsangbuk-do', '경북', '경상북도', '47') THEN '경상북도'
      WHEN req.device.geo.region IN ('South Gyeongsang', 'Gyeongsangnam-do', '경남', '경상남도', '48') THEN '경상남도'
      WHEN req.device.geo.region IN ('Jeju', 'Jeju-teukbyeoljachido', '제주', '제주특별자치도', '50') THEN '제주특별자치도'
      WHEN req.device.geo.region IS NULL OR req.device.geo.region = '' THEN 'Unknown'
      ELSE req.device.geo.region
    END AS region,
    SUM(gross_spend_usd) AS spend_usd,
    SUM(installs) AS installs
  FROM `moloco-ae-view.athena.fact_dsp_core`
  WHERE advertiser.mmp_bundle_id = 'com.cpone.customer'
    AND date_utc >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)  -- Adjust date range as needed
    AND date_utc < CURRENT_DATE()
    AND req.device.geo.country = 'KR'
  GROUP BY 1, 2, 3, 4, 5, 6, 7
),

-- Step 2: Get D7 actions from conversion data
d7_actions AS (
  SELECT
    FORMAT_DATE('%Y-%m', DATE(cv.pb.event.install_at)) AS install_month,
    api.product.app.tracking_bundle AS bundle,
    CASE 
      WHEN cv.pb.device.os IN ('IOS', 'ios', 'iOS') THEN 'iOS'
      WHEN cv.pb.device.os IN ('ANDROID', 'android', 'Android') THEN 'Android'
      ELSE cv.pb.device.os
    END AS os,
    api.campaign.goal AS campaign_goal,
    api.campaign.id AS campaign_id,
    -- Region mapping
    CASE 
      WHEN cv.pb.device.geo.region IN ('Seoul', 'Seoul-teukbyeolsi', '서울', '서울특별시', '11') THEN '서울특별시'
      WHEN cv.pb.device.geo.region IN ('Busan', 'Busan-gwangyeoksi', '부산', '부산광역시', '26') THEN '부산광역시'
      WHEN cv.pb.device.geo.region IN ('Incheon', 'Incheon-gwangyeoksi', '인천', '인천광역시', '28') THEN '인천광역시'
      WHEN cv.pb.device.geo.region IN ('Daegu', 'Daegu-gwangyeoksi', '대구', '대구광역시', '27') THEN '대구광역시'
      WHEN cv.pb.device.geo.region IN ('Daejeon', 'Daejeon-gwangyeoksi', '대전', '대전광역시', '30') THEN '대전광역시'
      WHEN cv.pb.device.geo.region IN ('Gwangju', 'Gwangju-gwangyeoksi', '광주', '광주광역시', '29') THEN '광주광역시'
      WHEN cv.pb.device.geo.region IN ('Ulsan', 'Ulsan-gwangyeoksi', '울산', '울산광역시', '31') THEN '울산광역시'
      WHEN cv.pb.device.geo.region IN ('Sejong', 'Sejong-teukbyeoljachisi', '세종', '세종특별자치시', '36') THEN '세종특별자치시'
      WHEN cv.pb.device.geo.region IN ('Gyeonggi', 'Gyeonggi-do', '경기', '경기도', '41') THEN '경기도'
      WHEN cv.pb.device.geo.region IN ('Gangwon', 'Gangwon-do', '강원', '강원도', '42') THEN '강원도'
      WHEN cv.pb.device.geo.region IN ('North Chungcheong', 'Chungcheongbuk-do', '충북', '충청북도', '43') THEN '충청북도'
      WHEN cv.pb.device.geo.region IN ('South Chungcheong', 'Chungcheongnam-do', '충남', '충청남도', '44') THEN '충청남도'
      WHEN cv.pb.device.geo.region IN ('North Jeolla', 'Jeollabuk-do', '전북', '전라북도', '45') THEN '전라북도'
      WHEN cv.pb.device.geo.region IN ('South Jeolla', 'Jeollanam-do', '전남', '전라남도', '46') THEN '전라남도'
      WHEN cv.pb.device.geo.region IN ('North Gyeongsang', 'Gyeongsangbuk-do', '경북', '경상북도', '47') THEN '경상북도'
      WHEN cv.pb.device.geo.region IN ('South Gyeongsang', 'Gyeongsangnam-do', '경남', '경상남도', '48') THEN '경상남도'
      WHEN cv.pb.device.geo.region IN ('Jeju', 'Jeju-teukbyeoljachido', '제주', '제주특별자치도', '50') THEN '제주특별자치도'
      WHEN cv.pb.device.geo.region IS NULL OR cv.pb.device.geo.region = '' THEN 'Unknown'
      ELSE cv.pb.device.geo.region
    END AS region,
    COUNT(DISTINCT CASE 
      WHEN TIMESTAMP_DIFF(cv.pb.event.event_at, cv.pb.event.install_at, DAY) BETWEEN 0 AND 7 
      THEN COALESCE(cv.pb.device.ifa, cv.pb.device.ifv) 
    END) AS actions_d7
  FROM `focal-elf-631.prod_stream_view.cv`
  WHERE api.product.app.tracking_bundle = 'com.cpone.customer'
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND DATE(timestamp) < CURRENT_DATE()
    AND cv.pb.device.geo.country = 'KR'
    -- Filter for relevant conversion events (adjust based on campaign goal)
    AND (
      cv.event_pb IN ('af_purchase', 'purchase', 'first_purchase', 'complete_registration', 'af_complete_registration')
      OR cv.event_pb LIKE '%purchase%'
      OR cv.event_pb LIKE '%order%'
    )
  GROUP BY 1, 2, 3, 4, 5, 6
)

-- Final output: Join spend and actions
SELECT
  s.month,
  s.os,
  s.campaign_goal,
  s.campaign_id,
  s.campaign_title,
  s.region,
  ROUND(SUM(s.spend_usd), 2) AS spend_usd,
  SUM(s.installs) AS installs,
  COALESCE(SUM(a.actions_d7), 0) AS actions_d7,
  ROUND(SAFE_DIVIDE(SUM(s.spend_usd), NULLIF(SUM(a.actions_d7), 0)), 2) AS cpa_d7
FROM spend_by_region s
LEFT JOIN d7_actions a
  ON s.month = a.install_month
  AND s.os = a.os
  AND s.campaign_goal = a.campaign_goal
  AND s.campaign_id = a.campaign_id
  AND s.region = a.region
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY month DESC, spend_usd DESC;


-- ============================================
-- Alternative: Simplified query using df_accesslog.pb
-- This provides more accurate region data from bid request
-- ============================================

/*
WITH campaign_region_data AS (
  SELECT
    FORMAT_DATE('%Y-%m', DATE(timestamp)) AS month,
    CASE 
      WHEN device.os IN ('IOS', 'ios', 'iOS') THEN 'iOS'
      WHEN device.os IN ('ANDROID', 'android', 'Android') THEN 'Android'
      ELSE device.os
    END AS os,
    -- Campaign info would need to be joined from another source
    device.geo.region AS raw_region,
    CASE 
      WHEN device.geo.region IN ('Seoul', '11', 'KR-11') THEN '서울특별시'
      WHEN device.geo.region IN ('Busan', '26', 'KR-26') THEN '부산광역시'
      WHEN device.geo.region IN ('Incheon', '28', 'KR-28') THEN '인천광역시'
      WHEN device.geo.region IN ('Gyeonggi-do', '41', 'KR-41') THEN '경기도'
      -- Add more mappings as needed
      ELSE COALESCE(device.geo.region, 'Unknown')
    END AS region,
    COUNT(*) AS impressions
  FROM `focal-elf-631.df_accesslog.pb`
  WHERE app.bundle = 'com.cpone.customer'
    AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND device.country = 'KR'
    AND event.name = 'impression'
  GROUP BY 1, 2, 3, 4
)
SELECT * FROM campaign_region_data
ORDER BY month DESC, impressions DESC;
*/
