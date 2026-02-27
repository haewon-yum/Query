WITH
  exp_group AS (
    SELECT DISTINCT
        DATE(TIMESTAMP_TRUNC(schedule.start, MONTH)) AS Start_Month,
        E.groups[SAFE_OFFSET(0)].target[SAFE_OFFSET(0)].campaign,
        E.groups[SAFE_OFFSET(0)].group_id AS exp_group_id,
        DATE(schedule.start) AS start_date,
        DATE(schedule.end) AS end_date,
        name AS test_name,
        description,
        id AS test_id,
        authors[SAFE_OFFSET(0)] AS authors
        FROM
        explab-298609.exp_prod.experiment_digest_v2 E
        WHERE  
            timestamp > '2024-11-01'
            AND
            id IN (
                'UPLIFT-com-nexon-bluearchive-4mpNZ',
                'UPLIFT-com-nexon-bluearchive-4X9Im',
                'UPLIFT-com-nexon-bluearchive-EvAzw',
                'UPLIFT-com-nexon-bluearchive-Jp2iM',
                'UPLIFT-com-nexon-bluearchive-qWaw0',
                'UPLIFT-com-nexon-bluearchive-rs6n0',
                'UPLIFT-com-nexon-bluearchive-SouYN',
                'UPLIFT-com-nexon-er-r8Y9L',
                'UPLIFT-com-nexon-er-rjFN9',
                'UPLIFT-com-nexon-fmk-GsWji',
                'UPLIFT-com-nexon-fmk-iClih',
                'UPLIFT-com-nexon-hit2-1G4CQ',
                'UPLIFT-com-nexon-hit2-szCs1',
                'UPLIFT-com-nexon-maplem-global-3x1px',
                'UPLIFT-com-nexon-maplem-global-aCuIn',
                'UPLIFT-com-nexon-maplem-global-AK0B8',
                'UPLIFT-com-nexon-maplem-global-bqOxX',
                'UPLIFT-com-nexon-maplem-global-CfJ6C',
                'UPLIFT-com-nexon-maplem-global-GJJU4',
                'UPLIFT-com-nexon-maplem-global-manual-launch',
                'UPLIFT-com-nexon-maplem-global-RU4Ed',
                'UPLIFT-com-nexon-maplem-global-SOSqT',
                'UPLIFT-com-nexon-mdnf-A1x7z',
                'UPLIFT-com-nexon-mdnf-ynrW8',
                'UPLIFT-com-nexon-nsc-maplem-jgv0D',
                'UPLIFT-com-nexon-nsc-maplem-O1k2f'
            )

  )

SELECT
  exp_group_id,
  advertiser_id,
  campaign_id,
  os,
  country
FROM `explab-298609.summary_v2.experiment_summary`
  JOIN exp_group USING (exp_group_id)
WHERE 
  utc_date >= '2024-11-01'
