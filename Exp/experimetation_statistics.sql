DECLARE start_date DATE DEFAULT CURRENT_DATE()-90;
WITH employees AS
(
  SELECT DISTINCT
  work_email,
  job_title,
  job_function,
  job_department,
  region
  FROM moloco-data-prod.ops_portal.employee
  WHERE TIMESTAMP_TRUNC(_PARTITIONTIME, DAY) > TIMESTAMP(start_date)
  AND (manager_work_email IN ('sasha.clarke@moloco.com','angela.venus@moloco.com', 'cyan.lee@moloco.com')
  OR job_function = 'Account Management'
  AND left_date IS null)
  )
,experiments  AS
(
SELECT DISTINCT
        DATE(TIMESTAMP_TRUNC(schedule.start, MONTH)) AS Start_Month,
        CASE
          WHEN (LOWER(name) LIKE 't4g%' OR LOWER(description) LIKE 't4g%' OR LOWER(id) LIKE 't4g%') THEN 'T4G'
          WHEN (id LIKE 'CREATIVE%' OR id LIKE 'TARGET%') THEN 'MCP'
          ELSE 'Other'
        END AS T4G,
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
        WHERE DATE(timestamp) > start_date
        AND authors[SAFE_OFFSET(0)] LIKE '%moloco.com'
        AND type = 'CREATE_EXPERIMENT'
        QUALIFY ROW_NUMBER() OVER(PARTITION BY exp_group_id ORDER BY timestamp DESC) = 1
        )
, 
summary AS (
  SELECT 
      exp_group_id,
      platform,
      SUM(spend) AS spend
FROM moloco-ods.nadav.precomputed_summary_explab 
WHERE
  utc_date > start_date
GROUP BY ALL ),

result_raw AS (
  SELECT  
    Start_Month, 
    T4G, 
    platform,
    test_id,
    work_email,
    region,
    SUM(spend) AS spend_on_test
    FROM experiments E
    INNER JOIN employees M  ON E.authors = M.work_email
    LEFT JOIN summary S ON E.exp_group_id = S.exp_group_id
    GROUP BY ALL
  ),

spend AS (
    SELECT
        platform_id,
        SUM(gross_spend_usd) AS spend,
        SUM(revenue_d7) AS rev_d7,
        SUM(revenue_d30) AS rev_d30
    FROM `moloco-ae-view.athena.fact_dsp_core`
    WHERE
        date_utc > start_date        
        AND product.is_gaming = True
    GROUP BY 1
    HAVING spend > 90000
)

SELECT 
    s.platform_id,
    -- r.T4G,
    IFNULL(COUNT(DISTINCT r.test_id), 0) as num_test,
    IFNULL(SUM(r.spend_on_test), 0) AS spend_on_test,
    ANY_VALUE(s.spend) AS spend,
    ANY_VALUE(s.rev_d7) AS rev_d7,
    ANY_VALUE(s.rev_d30) AS rev_d30
FROM spend s 
    LEFT JOIN result_raw r  ON s.platform_id = r.platform
GROUP BY 1
ORDER BY spend DESC