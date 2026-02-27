WITH tgt AS (
  SELECT 
    date_utc AS dt,
    SUBSTR(target_maid, 1, 2) AS prefix, 
    CASE WHEN SUBSTR(target_maid, 1, 2) = 'f:' THEN SUBSTR(target_maid, 3) END AS idfv,
    CASE WHEN SUBSTR(target_maid, 1, 2) = 'i:' THEN SUBSTR(target_maid, 3) END AS idfa,
    mpid,
  FROM `moloco-ods.pds_re.ios_re_closed_alpha_danggeun_target_IDs`
  -- WHERE date_utc = '2025-11-10'
),

imp AS (
  SELECT 
    DATE(timestamp) AS dt,
    req.device.ifa AS idfa,
    req.ext.skadn.ifv AS idfv
  FROM `focal-elf-631.prod_stream_view.imp`
  WHERE DATE(timestamp) BETWEEN '2025-10-01' AND '2025-11-12'
    AND api.campaign.id = 'JCbqtZCd2NehCzLL'
)

SELECT 
  -- *
  COUNT(DISTINCT tgt.mpid) AS cnt_tgt,
  COUNT (DISTINCT CASE WHEN imp.idfa IS NOT NULL OR imp.idfv IS NOT NULL THEN tgt.mpid ELSE NULL END) AS cnt_reach
FROM tgt 
  LEFT JOIN imp 
  ON tgt.dt = imp.dt
  AND (tgt.idfv = imp.idfv OR tgt.idfa = imp.idfa)
-- LIMIT 100
-- WHERE tgt.dt = '2025-11-11'

-- GROUP BY ALL


-- SELECT *
-- FROM tgt
-- LIMIT 100