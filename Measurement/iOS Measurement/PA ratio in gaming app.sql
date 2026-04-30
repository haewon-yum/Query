-- PA status by genre (+sub genre) // (2024/07/01 이후 campaign enalbeld 된 iOS App 대상) 앱별 PA 설정 비율 (단위: 앱)

WITH campaign_digest AS(
-- 0701-0903 campaign enabled 된 앱
SELECT
-- product_category,
store_bundle,
tracking_bundle
FROM `focal-elf-631.prod.campaign_digest_merged_20*`
WHERE
_TABLE_SUFFIX between FORMAT_DATE('%y%m%d', DATE('2024-07-01')) AND FORMAT_DATE('%y%m%d', DATE('2024-09-03'))
AND enabled = TRUE
GROUP BY ALL
),
pa_status AS(
SELECT
    dataai.genre,
    dataai.sub_genre,
    dataai.is_gaming,
    CASE WHEN verdict.fp_status = 'ENABLED' then 'ENABLED' ELSE 'DISABLED' END AS status2,
    dataai.app_id,
    count(utc_date) as cnt_date,
FROM
`focal-elf-631.mmp_pb_summary.app_status` a
    JOIN campaign_digest b ON a.tracking_bundle = b.tracking_bundle
    LEFT JOIN `moloco-ae-view.athena.dim1_app` c ON b.store_bundle = CAST(c.dataai.app_id AS String)
WHERE
utc_date between "2024-07-01" AND "2024-09-03"
-- AND spend.total > 0
GROUP BY 1,2,3,4,5
),

-- 0701-0903 기간 중 ENABLED 기간이 DISABLED 기간 보다 많으면, "ENABLED"로 카운트.
pa_status_summary AS(
SELECT
    is_gaming,
    app_id,
    COALESCE(MAX(cnt_enabled_date),0) as cnt_enabled_date,
    COALESCE(MAX(cnt_disabled_date),0) as cnt_disabled_date
FROM(
    SELECT
    is_gaming,
    app_id,
    CASE WHEN status2 = 'ENABLED' then cnt_date END as cnt_enabled_date,
    CASE WHEN status2 = 'DISABLED' then cnt_date END AS cnt_disabled_date
    FROM pa_status
)t
GROUP BY 1,2
)
SELECT
    is_gaming,
    COUNT(CASE WHEN cnt_enabled_date >= cnt_disabled_date then 1 else NULL END) AS cnt_enabled_app,
    COUNT(CASE WHEN cnt_enabled_date < cnt_disabled_date then 1 else NULL END) AS cnt_disabled_app,
FROM pa_status_summary
GROUP BY 1