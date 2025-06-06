/* 
    - credit @gilseung
    - https://docs.google.com/spreadsheets/d/1EkKJA76XO7RHn03yhqikzDLs9EaYVmbmGBc-Mmgzv-M/edit?gid=514940038#gid=514940038
*/

# THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL
WITH
  campaign_target_bundle_T AS
  (
    SELECT
      DISTINCT
        campaign_id,
        campaign_os,
        target_bundle,        
    FROM 
      (
        SELECT
          campaign_id,
          campaign_os,
          ARRAY_CONCAT_AGG([COALESCE(JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.ANDROID"), ''),
                            COALESCE(JSON_VALUE(original_json, "$.goal.optimize_ctv_assist_for_app_ua.target_app_bundles.IOS"), '')]) AS target_bundles
        FROM
          `focal-elf-631.standard_digest.campaign_digest`
        WHERE
          campaign_os = 'CTV'
        GROUP BY ALL),
        UNNEST(target_bundles) AS target_bundle
        WHERE target_bundle != ''  
  UNION ALL
    SELECT
      DISTINCT 
        campaign_id,
        campaign_os,
        app_tracking_bundle AS target_bundle
    FROM
      `focal-elf-631.standard_digest.campaign_digest`
    JOIN
      `focal-elf-631.standard_digest.product_digest`
    USING
      (advertiser_id, product_id)
    WHERE
      campaign_os IN ('IOS', 'ANDROID')
      AND app_tracking_bundle IS NOT NULL  
      AND campaign_goal LIKE '%UA%' AND campaign_goal NOT LIKE '%WEB%'
  ),

  target_campaign_target_bundle_T AS
  (
    SELECT
      *
    FROM 
      campaign_target_bundle_T
    WHERE
      target_bundle IN 
      (
        SELECT target_bundle
        FROM 
          (
            SELECT
              target_bundle,
              (SUM(CASE WHEN campaign_os = 'CTV' THEN spend ELSE 0 END) > 0) AND (SUM(CASE WHEN campaign_os IN ('ANDROID', 'IOS') THEN spend ELSE 0 END) > 0) AS is_included
            FROM campaign_target_bundle_T
            JOIN 
            (
              SELECT
                campaign_id,
                SUM(gross_spend_usd) AS spend
              FROM `moloco-ae-view.athena.fact_dsp_core`
              WHERE
                date_utc BETWEEN DATE('2025-01-01') AND DATE('2025-01-31')
              GROUP BY 1
              HAVING spend > 0
            )
            USING (campaign_id)
            GROUP BY 1
            HAVING is_included = True 
          )
      )
  ),

  CTV_imp_T AS 
  (
    SELECT 
      req.device.ip AS ip,
      imp.happened_at AS imp_time,
      target_bundle,
    FROM `focal-elf-631.prod_stream_view.imp` A
    JOIN target_campaign_target_bundle_T B
    ON A.api.campaign.id = B.campaign_id
    WHERE
      DATE(timestamp) BETWEEN DATE('2025-01-01') AND DATE('2025-01-31')
      AND req.device.ip != ''
      AND campaign_os = 'CTV'
  ),

  mobile_imp_T AS 
  (
    SELECT DISTINCT
      CASE WHEN C.ip IS NULL THEN FALSE ELSE TRUE END AS watched_CTV,
      bid.mtid,
      B.target_bundle,
      req.device.ip AS ip,
      imp.happened_at AS imp_time,
      pl.pred AS pred_install,
    FROM
      `focal-elf-631.prod_stream_view.imp` A,
      UNNEST (bid.MODEL.prediction_logs) AS pl
    JOIN target_campaign_target_bundle_T B
        ON A.api.campaign.id = B.campaign_id
    LEFT JOIN CTV_imp_T C
        ON
        A.req.device.ip = C.ip
        AND TIMESTAMP_DIFF(A.imp.happened_at, C.imp_time, SECOND) BETWEEN 0 AND 24 * 60 * 60
    WHERE      
      DATE(timestamp) BETWEEN DATE('2025-01-01') AND DATE('2025-01-31')
      AND req.device.ip != ''
      AND campaign_os != 'CTV'
      AND pl.type = 'I2I_TF_JOINT'
      AND pl.pred BETWEEN 0 AND 1      
  ),

  install_T AS
  (
    SELECT
      DISTINCT bid.mtid,
    FROM `focal-elf-631.prod_stream_view.cv` A
    JOIN target_campaign_target_bundle_T B
        ON A.api.campaign.id = B.campaign_id
    WHERE
      DATE(timestamp) BETWEEN DATE('2025-01-01') AND DATE('2025-01-31')
      AND req.device.ip != ''
      AND campaign_os != 'CTV'
      AND cv.event = 'INSTALL'
  )

  SELECT
    watched_CTV,
    target_bundle,    
    COUNT(1) AS count_imp,
    SUM(CASE WHEN install_T.mtid IS NOT NULL THEN 1 ELSE 0 END) AS count_install,
    SUM(pred_install) AS pred_install,
    SAFE_DIVIDE(SUM(CASE WHEN install_T.mtid IS NOT NULL THEN 1 ELSE 0 END), COUNT(1)) * 1000 AS IPM,
    SAFE_DIVIDE(SUM(CASE WHEN install_T.mtid IS NOT NULL THEN 1 ELSE 0 END), SUM(pred_install)) AS a_over_p
  FROM mobile_imp_T
    LEFT JOIN install_T
    USING (mtid)
  GROUP BY 1,2

 
 
