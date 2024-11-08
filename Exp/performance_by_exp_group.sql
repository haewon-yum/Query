SELECT
	if(exp_group_id=4661,'control','test') as exp_group,
	SUM(count_imp) as imp,
	SUM(count_click) as click,
	SUM(count_install) as install,
	SUM(total_moloco_spent) as spend,
	SUM(count_kpi_d7) as d7action,
	SUM(count_distinct_kpi_d7) as d7distinct_action,
	sum(total_revenue_kpi_d7) as d7_revenue
FROM
	`explab-298609.summary_v2.experiment_summary`
WHERE
	utc_date BETWEEN '2023-12-15' AND '2024-01-04'
	AND campaign_id IN ('WhNQQYcrMHHvt31d','YJLPTUb4y4kzGren')
	AND exp_group_id IN (4661, 4662, 4663)
GROUP BY 1