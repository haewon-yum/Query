
## vt install from fact_dsp_all ##

WITH raw AS (
  SELECT 
    campaign_id,
    DATE(timestamp_utc) AS dt,
    SUM(skan_installs) AS skan_installs,
    SUM(skan_installs_ct) AS skan_installs_ct,
    SUM(skan_installs_vt) AS skan_installs_vt
  FROM `moloco-ae-view.athena.fact_dsp_all` 
  WHERE campaign_id = 'VST5gOpqGhChTPKd'
    AND DATE(timestamp_utc) BETWEEN '2024-05-31' AND '2024-06-13'
  GROUP BY ALL
),
summary AS (
  SELECT 
    campaign_id,
    dt,
    skan_installs,
    skan_installs_vt,
    raw.skan_installs_ct,
    skan_installs_vt / skan_installs AS vt_ratio
  FROM raw
)
SELECT *
FROM summary