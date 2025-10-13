/* https://mlc.atlassian.net/browse/ODSB-11310 */ 

### UPDATED LTV D7 > 10 ### 

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
WITH
  # raw table with all data
  event_t AS (
  SELECT * 
  FROM `focal-elf-631.prod_stream_view.pb`
  WHERE
    timestamp BETWEEN TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR), HOUR) - INTERVAL 7 DAY AND TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR), HOUR)
    AND app.bundle IN ("com.percent.aos.luckydefense", "id6482291732")
    AND device.country in ('KOR', 'USA', 'TWN' )
  ),
 
  # installs only
  install_event AS (
  SELECT 
    event.event_at AS install_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id
  FROM event_t
  WHERE LOWER(event.name) = "install" 
  ),

  # purchase only
  purchase_event AS (
  SELECT 
    event.event_at AS purchase_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifv) THEN "ifv:" || device.ifv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa) THEN "ifa:" || device.ifa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id,
    event.revenue_usd.amount AS revenue
  FROM event_t
  WHERE LOWER(event.name) = "af_purchase" 
  ),
  
  # derived d7 ltv
  ltv AS (
  SELECT 
    purchase_event.user_match_id,
    purchase_time,
    purchase_event.bundle,
    SUM(CASE WHEN DATE_DIFF(purchase_time,install_time,day) BETWEEN 0 AND 6 THEN revenue ELSE 0 END)
      OVER(PARTITION BY purchase_event.user_match_id ORDER BY purchase_time ASC) AS d7_ltv
  FROM install_event
  INNER JOIN purchase_event
  ON install_event.user_match_id = purchase_event.user_match_id
    AND install_event.bundle = purchase_event.bundle
  WHERE install_event.user_match_id IS NOT NULL
  ),

  # raw purchase events
  raw AS (
  SELECT *
  FROM `focal-elf-631.df_accesslog.pb`
  WHERE timestamp BETWEEN TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR), HOUR) AND TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR), HOUR)
    AND LOWER(event.name) = "af_purchase" 
    AND app.bundle IN ("com.percent.aos.luckydefense", "id6482291732")
    AND device.country in ('KOR', 'USA', 'TWN' )
  )

# raw purchase events where d7 ltv is higher than 10, select only one hour purchase events to avoid duplications over previous run 
SELECT 
  raw.*, 
  'purchase_value_d7_10' AS new_event_name
FROM raw
INNER JOIN ltv
ON CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END = ltv.user_match_id
AND raw.event.event_at = ltv.purchase_time
WHERE d7_ltv > 10
;


#### af_level_9__AND__af_purchase ####
# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

WITH
  # raw table with all data
  event_t AS (
  SELECT * 
  FROM `focal-elf-631.df_accesslog.pb`
  WHERE
    timestamp BETWEEN TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR), HOUR) - INTERVAL 7 DAY AND TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR), HOUR)
    AND app.bundle IN ("com.percent.aos.luckydefense", "id6482291732")
    AND device.country in ('KOR', 'USA', 'TWN')
  ),
 
  # installs only
  install_event AS (
  SELECT 
    event.event_at AS install_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id
  FROM event_t
  WHERE LOWER(event.name) = "install" 
  ),

  # purchase event only (af_purchase)
  purchase_event AS (
  SELECT 
    event.event_at AS purchase_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id,
    event.revenue_usd.amount AS revenue
  FROM event_t
  WHERE LOWER(event.name) = "af_purchase" 
  ),
  
  # non-purchase event only (af_level_9)
  non_purchase_event AS (
  SELECT
    event.event_at AS event_time,
    app.bundle AS bundle,
    CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END AS user_match_id,
    0 AS revenue
  FROM event_t
  WHERE LOWER(event.name) = 'af_level_9'
  ),

  # af_level_9__AND__af_purchase
  merged_event AS (
  SELECT 
    purchase_event.user_match_id,
    purchase_time,
    event_time,
    purchase_event.bundle,
    COUNT(CASE WHEN DATE_DIFF(purchase_time,install_time,day) BETWEEN 0 AND 6 AND DATE_DIFF(event_time,install_time,day) BETWEEN 0 AND 6
      THEN 1 ELSE 0 END) OVER(PARTITION BY purchase_event.user_match_id) AS af_level_9__AND__af_purchase,
    SUM(CASE WHEN DATE_DIFF(purchase_time,install_time,day) BETWEEN 0 AND 6 AND DATE_DIFF(event_time,install_time,day) BETWEEN 0 AND 6
      THEN purchase_event.revenue ELSE 0 END) OVER(PARTITION BY purchase_event.user_match_id) AS af_level_9__AND__af_purchase_revenue
  FROM install_event
  INNER JOIN purchase_event
    ON install_event.user_match_id = purchase_event.user_match_id
      AND install_event.bundle = purchase_event.bundle
  INNER JOIN non_purchase_event
    ON install_event.user_match_id = non_purchase_event.user_match_id
      AND install_event.bundle = non_purchase_event.bundle
  WHERE install_event.user_match_id IS NOT NULL
  ),

  # raw events
  raw AS (
    SELECT 
      *
    FROM event_t
    WHERE timestamp BETWEEN TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 HOUR), HOUR) AND TIMESTAMP_TRUNC(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR), HOUR)
      AND LOWER(event.name) IN ("af_purchase", "af_level_9")
      AND app.bundle IN ("com.percent.aos.luckydefense", "id6482291732")
      AND device.country in ('KOR', 'USA', 'TWN' )
  )

# raw events where both af_purchase and af_level_9 happened within d7, select only one hour events to avoid duplications over previous run 
SELECT raw.*, 
  'af_level_9__AND__af_purchase' AS new_event_name
FROM raw
INNER JOIN merged_event
ON CASE
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfv) THEN "ifv:" || device.idfv
      WHEN `moloco-ods.general_utils.is_idfa_truly_available`(device.idfa) THEN "ifa:" || device.idfa
      WHEN `moloco-ml.lat_utils.is_userid_truly_available` (mmp.device_id) THEN 'device:' || mmp.device_id
      ELSE NULL
    END = merged_event.user_match_id
AND ((raw.event.event_at = merged_event.purchase_time) OR (raw.event.event_at = merged_event.event_time))
WHERE af_level_9__AND__af_purchase > 0;