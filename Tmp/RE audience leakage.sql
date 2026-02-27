
-- Adveritser:          Pinterest (xKyZqGz6fPKKRM2F)
-- Campaign ID:         PLB_US_MO_Android_Rez_ReEng_InAppEvent_af_neworrez (aNO75VZYemtE1FbY)
-- Ad Group ID:         default (wrX3zdbhL1XdqfSJ)
-- Include Target ID:   US Android - Inclusion (New 10 '24) (vnxDLXrddLAqUBJQ)
-- Exclude Target ID:   US Android - Exclusion (New 10 '24) (cHpy9jOzYimzHXet)
-- Include Audience ID: PPM_Growth_AF_US_Android_Rez_LaunchedApp_DND_ContentView_28d (RTcB7Gmwh9Px0TpG)
-- Exclude Audience ID: PPM_Growth_AF_US_Android_Rez_LaunchedApp_28d_ContentView_28d (exclusion) (NVVcGqXRRKmbZ40v)

DECLARE report_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
DECLARE campaign STRING DEFAULT 'aNO75VZYemtE1FbY';
DECLARE adgroup STRING DEFAULT 'wrX3zdbhL1XdqfSJ';
DECLARE analysis_start TIMESTAMP DEFAULT TIMESTAMP('2025-06-27 19:05:00');

WITH
  customer_set_inc AS (
   SELECT
      maid AS user_id
   FROM `focal-elf-631.auto_tagging.xKyZqGz6fPKKRM2F_RTcB7Gmwh9Px0TpG_20250627185743`
  ),
  
  customer_set_exc AS (
   SELECT
      key AS user_id
    FROM `focal-elf-631.df_bigtable.upt_tagging_latest`
    WHERE CONTAINS_SUBSTR(qualifier, 'NVVcGqXRRKmbZ40v')
      AND DATE(timestamp) = DATE('2025-06-07')
  ),


  impr AS (
   SELECT
      bid.maid AS user_id,
      bid.timestamp AS bid_time,
      imp.win_price_usd.amount_micro / 1e6 AS win_price_usd
   FROM `focal-elf-631.prod_stream_view.imp`
   WHERE 1=1
      AND `moloco-ods.general_utils.is_userid_truly_available`(req.device.ifa)
      AND api.adgroup.id = adgroup
      AND api.campaign.id = campaign
      AND timestamp >= TIMESTAMP_ADD(analysis_start, INTERVAL 5 MINUTE)
      AND timestamp <= report_timestamp
      AND bid.timestamp >= TIMESTAMP_ADD(analysis_start, INTERVAL 5 MINUTE)
      AND bid.timestamp <= report_timestamp
  ),


  impr_combined AS (
    SELECT
      'xKyZqGz6fPKKRM2F' AS advertiser_id,
      campaign,
      adgroup,
      report_timestamp,
      PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', report_timestamp, 'America/Los_Angeles')) AS report_timestamp_pst,
      included,
      excluded,
      COUNT(*) AS cnt_imps
    FROM (
      SELECT
        user_id,
        bid_time,
        (customer_set_inc.user_id IS NOT NULL) AS included,
        (customer_set_exc.user_id IS NOT NULL) AS excluded
      FROM impr
      LEFT JOIN customer_set_inc USING (user_id)
      LEFT JOIN customer_set_exc USING (user_id)
    )
  GROUP BY 1, 2, 3, 4, 5, 6, 7
  )


SELECT
  advertiser_id,
  campaign,
  adgroup,
  analysis_start AS analysis_start_timestamp,
  report_timestamp,
  report_timestamp_pst,
  SUM(CASE WHEN included AND excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_a,
  SUM(CASE WHEN included AND NOT excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_b,
  SUM(CASE WHEN NOT included AND excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_c,
  SUM(CASE WHEN NOT included AND NOT excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_d
FROM impr_combined
GROUP BY 1, 2, 3, 4, 5, 6
"""
 
 
 	
Query (aNO75VZYemtE1FbY):
"""
-- Adveritser:          Pinterest (xKyZqGz6fPKKRM2F)
-- Campaign ID:         PLB_US_MO_Android_Rez_ReEng_InAppEvent_af_neworrez (aNO75VZYemtE1FbY)
-- Ad Group ID:         default (wrX3zdbhL1XdqfSJ)
-- Include Target ID:   US Android - Inclusion (New 10 '24) (vnxDLXrddLAqUBJQ)
-- Exclude Target ID:   US Android - Exclusion (New 10 '24) (cHpy9jOzYimzHXet)
-- Include Audience ID: PPM_Growth_AF_US_Android_Rez_LaunchedApp_DND_ContentView_28d (RTcB7Gmwh9Px0TpG)
-- Exclude Audience ID: PPM_Growth_AF_US_Android_Rez_LaunchedApp_28d_ContentView_28d (exclusion) (NVVcGqXRRKmbZ40v)

DECLARE report_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
DECLARE campaign STRING DEFAULT 'aNO75VZYemtE1FbY';
DECLARE adgroup STRING DEFAULT 'wrX3zdbhL1XdqfSJ';
DECLARE analysis_start TIMESTAMP DEFAULT TIMESTAMP('2025-06-27 19:05:00');

WITH
  customer_set_inc AS (
   SELECT
      maid AS user_id
   FROM `focal-elf-631.auto_tagging.xKyZqGz6fPKKRM2F_RTcB7Gmwh9Px0TpG_20250627185743`
  ),
  
  customer_set_exc AS (
   SELECT
      key AS user_id
    FROM `focal-elf-631.df_bigtable.upt_tagging_latest`
    WHERE CONTAINS_SUBSTR(qualifier, 'NVVcGqXRRKmbZ40v')
      AND DATE(timestamp) = DATE('2025-06-07')
  ),


  impr AS (
   SELECT
      bid.maid AS user_id,
      bid.timestamp AS bid_time,
      imp.win_price_usd.amount_micro / 1e6 AS win_price_usd
   FROM `focal-elf-631.prod_stream_view.imp`
   WHERE 1=1
      AND `moloco-ods.general_utils.is_userid_truly_available`(req.device.ifa)
      AND api.adgroup.id = adgroup
      AND api.campaign.id = campaign
      AND timestamp >= TIMESTAMP_ADD(analysis_start, INTERVAL 5 MINUTE)
      AND timestamp <= report_timestamp
      AND bid.timestamp >= TIMESTAMP_ADD(analysis_start, INTERVAL 5 MINUTE)
      AND bid.timestamp <= report_timestamp
  ),


  impr_combined AS (
    SELECT
      'xKyZqGz6fPKKRM2F' AS advertiser_id,
      campaign,
      adgroup,
      report_timestamp,
      PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', report_timestamp, 'America/Los_Angeles')) AS report_timestamp_pst,
      included,
      excluded,
      COUNT(*) AS cnt_imps
    FROM (
      SELECT
        user_id,
        bid_time,
        (customer_set_inc.user_id IS NOT NULL) AS included,
        (customer_set_exc.user_id IS NOT NULL) AS excluded
      FROM impr
      LEFT JOIN customer_set_inc USING (user_id)
      LEFT JOIN customer_set_exc USING (user_id)
    )
  GROUP BY 1, 2, 3, 4, 5, 6, 7
  )


SELECT
  advertiser_id,
  campaign,
  adgroup,
  analysis_start AS analysis_start_timestamp,
  report_timestamp,
  report_timestamp_pst,
  SUM(CASE WHEN included AND excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_a,
  SUM(CASE WHEN included AND NOT excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_b,
  SUM(CASE WHEN NOT included AND excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_c,
  SUM(CASE WHEN NOT included AND NOT excluded THEN cnt_imps ELSE 0 END) AS bid_cnt_scenario_d
FROM impr_combined
GROUP BY 1, 2, 3, 4, 5, 6
